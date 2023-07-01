---
title: Copy Assets
layout: layouts/guides.jinja
docs_menu:
  - title: Add a Page
    id: add-a-page
  - title: Copy CSS, JS, Images
    id: copy-assets
  - title: Compile Sass
    id: compile-sass
  - title: Display Directory of Pages
    id: display-directory-of-pages
  - title: Use Remote CSS and JS
    id: use-remote-css-and-js
  - title: Create RSS Feed
    id: create-rss-feed
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