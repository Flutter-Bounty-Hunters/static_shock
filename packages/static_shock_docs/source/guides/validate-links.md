---
title: Validate Links
---
When it's time to deploy your website, it's important to know that all
of your links work. It's easy to write links that you forget to update.
Use the `LinksPlugin` to validate every internal and external anchor
tag in your website.

```dart
final site = StaticShock(...)
  ..plugin(const LinksPlugin());
```

By default, the `LinksPlugin` will fail the build for any broken links
when building for production, but will only log warnings for broken links
when building for development. The build mode is controlled by the
`buildMode` property in `StaticShock`.

You can directly control the error/warning mode by configuring the `LinksPlugin`.

```dart
final site = StaticShock(...)
  ..plugin(const LinksPlugin(
    shouldRunLinkVerification: true,
    failBuildOnBrokenLinks: true,
  ));
```