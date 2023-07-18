---
title: Copy Assets
---
# Copy Images, CSS, JS
A static site typically contains many assets. An asset is a file served by a web server, which isn't a page.

Typically an asset, like an image, should be copied directly from the source set to the build set.

To copy a file from your source set to your build set, use the `pick()` method on `StaticShock` with a `FilePicker`.

```dart
final staticShock = StaticShock()
  ..pick(FilePicker.parse("images/header.png"))
  ..pick(FilePicker.parse("scripts/highlight.js"));
```

To copy an entire directory, use a `DirectoryPicker`.

```dart
final staticShock = StaticShock()
  ..pick(DirectoryPicker.parse("images"))
  ..pick(DirectoryPicker.parse("scripts"));
```

<div class="alert alert-danger" role="alert">
  TODO: Create hooks for transforms in the asset pipeline
</div>
<div class="alert alert-danger" role="alert">
  TODO: Write guide for how to transform assets
</div>