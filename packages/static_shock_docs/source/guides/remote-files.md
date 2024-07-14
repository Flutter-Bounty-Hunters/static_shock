---
title: Include Remote Files
tags: drafting
---
When creating multiple, related websites, it can be useful to share layouts, components,
and assets between those sites. To help with sharing files, Static Shock supports the
inclusion of remote files.

Static Shock supports the inclusion of two types of artifacts: a "remote file", which can
be included as data, a page, or an asset, and a "remote include" such as a layout or a
component.

Include individual remote files with `RemoteFile` and `RemoteInclude`.

```dart
final staticShock = StaticShock()
  ..pickRemote(
    layouts: {
      RemoteInclude(
        url: "https://raw.githubusercontent.com/my-repo/_includes/layouts/post.jinja?raw=true",
        name: "post",
        extension: "jinja",
      ),
    },
    assets: {
      RemoteFile(
        url: "https://raw.githubusercontent.com/my-repo/images/flutter-logo.svg?raw=true",
        buildPath: FileRelativePath("images/branding/", "flutter-logo", "svg"),
      ),
    },
  );
```

In some cases, multiple related remote files need to be included. For example, a Favicon
requires a bunch of related files. To reduce the verbosity of including remote files,
files accessed via URL can be grouped together.

```dart
final staticShock = StaticShock()
  ..pickRemote(
    assets: {
      HttpFileGroup.fromUrlTemplate(
        "https://github.com/my-repo/favicon/\$?raw=true",
        buildDirectory: "favicon/",
        files: {
          "android-chrome-192x192.png",
          "android-chrome-512x512.png",
          "apple-touch-icon.png",
          "browserconfig.xml",
          "favicon-16x16.png",
          "favicon-32x32.png",
          "favicon.ico",
          "mstile-150x150.png",
          "site.webmanifest",
        },
      ),
    },
  );
```

With the help of remote file inclusion, you can create dozens of documentation websites
that share common images, contributor attributions, and theming with ease.