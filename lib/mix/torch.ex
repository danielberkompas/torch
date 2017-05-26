defmodule Mix.Torch do
  @moduledoc false

  @valid_attributes [:integer, :float, :decimal, :boolean, :map, :string,
                     :array, :references, :text, :date, :time, :datetime,
                     :uuid, :binary, :file]

  @doc """
  Copies files from source dir to target dir
  according to the given map.

  Files are evaluated against EEx according to
  the given binding.
  """
  def copy_from(apps, source_dir, target_dir, binding, mapping) when is_list(mapping) do
    roots = Enum.map(apps, &to_app_source(&1, source_dir))

    for {format, source_file_path, target_file_path} <- mapping do
      source =
        Enum.find_value(roots, fn root ->
          source = Path.join(root, source_file_path)
          if File.exists?(source), do: source
        end) || raise "could not find #{source_file_path} in any of the sources"

      target = Path.join(target_dir, target_file_path)

      contents =
        case format do
          :text -> File.read!(source)
          :eex  -> EEx.eval_file(source, binding)
        end

      Mix.Generator.create_file(target, contents)
    end
  end

  defp to_app_source(path, source_dir) when is_binary(path),
    do: Path.join(path, source_dir)
  defp to_app_source(app, source_dir) when is_atom(app),
    do: Application.app_dir(app, source_dir)

  @doc """
  Inflect path, scope, alias and more from the given name.

      iex> Mix.Torch.inflect("user")
      [alias: "User",
       human: "User",
       base: "Phoenix",
       module: "Phoenix.User",
       scoped: "User",
       singular: "user",
       path: "user"]

      iex> Mix.Torch.inflect("Admin.User")
      [alias: "User",
       human: "User",
       base: "Phoenix",
       module: "Phoenix.Admin.User",
       scoped: "Admin.User",
       singular: "user",
       path: "admin/user"]

      iex> Mix.Torch.inflect("Admin.SuperUser")
      [alias: "SuperUser",
       human: "Super user",
       base: "Phoenix",
       module: "Phoenix.Admin.SuperUser",
       scoped: "Admin.SuperUser",
       singular: "super_user",
       path: "admin/super_user"]
  """
  def inflect(namespace, singular) do
    scoped = Phoenix.Naming.camelize(singular)
    path = Phoenix.Naming.underscore(scoped)
    singular =
      path
      |> String.split("/")
      |> List.last
    module =
      base()
      |> Module.concat(namespace)
      |> Module.concat(scoped)
      |> inspect
    alias =
      module
      |> String.split(".")
      |> List.last
    human = Phoenix.Naming.humanize(singular)

    [alias: alias,
     human: human,
     base: base(),
     module: module,
     scoped: scoped,
     singular: singular,
     path: path]
  end

  @doc """
  Returns a list of the attrs marked "readonly"
  """
  def readonly_attrs(attrs) do
    attrs
    |> Enum.filter(&String.ends_with?(&1, ":readonly"))
    |> Enum.map(fn attr ->
      attr
      |> String.split(":", parts: 3)
      |> hd
      |> String.to_atom
    end)
  end

  @doc """
  Parses the attrs as received by generators.
  """
  def attrs(attrs) do
    Enum.map(attrs, fn attr ->
      attr
      |> drop_unique()
      |> drop_readonly()
      |> String.split(":", parts: 3)
      |> list_to_attr()
      |> validate_attr!()
    end)
  end

  @doc """
  Fetches the unique attributes from attrs.
  """
  def uniques(attrs) do
    attrs
    |> Enum.filter(&String.ends_with?(&1, ":unique"))
    |> Enum.map(&do_unique/1)
  end

  defp do_unique(attr) do
    attr
    |> String.split(":", parts: 2)
    |> hd
    |> String.to_atom
  end

  @doc """
  Generates some sample params based on the parsed attributes.
  """
  def params(attrs) do
    attrs
    |> Enum.reject(fn
        {_, {:references, _}} -> true
        {_, _} -> false
       end)
    |> Enum.into(%{}, fn {k, t} -> {k, type_to_default(t)} end)
  end

  @doc """
  Checks the availability of a given module name.
  """
  def check_module_name_availability!(name) do
    name = Module.concat(Elixir, name)
    if Code.ensure_loaded?(name) do
      Mix.raise "Module name #{inspect name} is already taken, please choose another name"
    end
  end

  @doc """
  Returns the module base name based on the configuration value.
      config :my_app
        namespace: My.App
  """
  def base do
    app = otp_app()

    case Application.get_env(app, :namespace, app) do
      ^app -> app |> to_string |> Phoenix.Naming.camelize
      mod  -> mod |> inspect
    end
  end

  @doc """
  Returns the otp app from the Mix project configuration.
  """
  def otp_app do
    Mix.Project.config |> Keyword.fetch!(:app)
  end

  @doc """
  Returns all compiled modules in a project.
  """
  def modules do
    Mix.Project.compile_path
    |> Path.join("*.beam")
    |> Path.wildcard
    |> Enum.map(&beam_to_module/1)
  end

  defp beam_to_module(path) do
    path |> Path.basename(".beam") |> String.to_atom()
  end

  defp drop_unique(info) do
    drop_postfix(info, ":unique")
  end

  defp drop_readonly(info) do
    drop_postfix(info, ":readonly")
  end

  defp drop_postfix(info, postfix) do
    prefix = byte_size(info) - byte_size(postfix)
    case info do
      <<attr::size(prefix)-binary>> <> ^postfix -> attr
      _ -> info
    end
  end

  defp list_to_attr([key]), do: {String.to_atom(key), :string}
  defp list_to_attr([key, value]), do: {String.to_atom(key), String.to_atom(value)}
  defp list_to_attr([key, "references", data]) do
    [assoc, fields] = String.split(to_string(data), ":")
    [assoc_singular, assoc_plural] = String.split(assoc, ",")
    [primary_key, display_name] = String.split(fields, ",")

    value = [
      assoc_singular: String.to_atom(assoc_singular),
      assoc_plural: String.to_atom(assoc_plural),
      primary_key: String.to_atom(primary_key),
      display_name: String.to_atom(display_name)
    ]
    {String.to_atom(key), {:references, value}}
  end
  defp list_to_attr([key, comp, value]) do
    {String.to_atom(key), {String.to_atom(comp), String.to_atom(value)}}
  end

  defp type_to_default(t) do
    case t do
        {:array, _} -> []
        :integer    -> 42
        :float      -> "120.5"
        :decimal    -> "120.5"
        :boolean    -> true
        :map        -> %{}
        :text       -> "some content"
        :date       -> %{year: 2010, month: 4, day: 17}
        :time       -> %{hour: 14, min: 0, sec: 0}
        :datetime   -> %{year: 2010, month: 4, day: 17, hour: 14, min: 0, sec: 0}
        :uuid       -> "7488a646-e31f-11e4-aace-600308960662"
        _           -> "some content"
    end
  end

  defp validate_attr!({_name, type} = attr) when type in @valid_attributes, do: attr
  defp validate_attr!({_name, {type, _}} = attr) when type in @valid_attributes, do: attr
  defp validate_attr!({_, type}), do: Mix.raise "Unknown type `#{type}` given to generator"
end
