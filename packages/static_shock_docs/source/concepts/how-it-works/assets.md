---
title: Assets
---
Assets are data structures that essentially represent any output file that isn't
a [page](contributing/how-it-works/pages/). An asset might be a CSS file, JavaScript
file, image, video, etc.

An `Asset` data structure only has two pieces of information: a source, and a destination.
Both the source and the destination include a file path, and content.

An asset can hold text data or binary data.

## Loading Assets
There are two ways to load assets.

First, asset files can be picked using the standard file picking APIs.

For example, the Sass plugin picks all Sass files:
```dart
pipeline
  // Load all local Sass files as assets.
  ..pick(ExtensionPicker("sass"))
  ..pick(ExtensionPicker("scss"))
```

Second, when file picking isn't enough, assets can be loaded with `AssetLoader`s.
This is useful for when an asset comes from a location other than a file.

For example, the website screenshots plugin includes an `AssetLoader` that takes
screenshots of websites during the build process, and makes those screenshots
available as assets for the website.

## Transforming Assets
Assets can be transformed after they're loaded, by implementing an `AssetTransformer`.

For example, the Sass plugin includes an `AssetTransformer` that takes in a Sass
file, runs the Sass compiler to turn it into CSS, and then changes the destination
path so that the final file has a `.css` extension instead of a `.scss` extension.

