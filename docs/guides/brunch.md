## Brunch Configuration for Torch

### Using Sass Variables

Update your `brunch-config.js` SASS settings to make it watch your node_modules directory:

NOTE: We recommend you use yarn for best results rather than npm. NPM >5.0 is currently less stable than yarn.

```js
plugins: {
  sass: {
    mode: 'native',
    includePaths: ['node_modules']
  }
}
```

### Using Precompiled Assets

1. Add `node_modules` to the watched directories for `stylesheets`.

```js
stylesheets: {
  joinTo: {
    'css/app.css': /^(web|node_modules)/
  }
}
```

2. Add `torch` to the npm configuration:

```js
npm: {
  enabled: true
  styles: {
    torch: [
      'priv/static/torch.css'
    ]
  }
}
```