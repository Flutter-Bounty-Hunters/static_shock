---
title: Find Missing Pages
---
When editing a static site, it's easy to forget that every page that you've deployed
now has a public URL that others might depend upon. Users might add a URL to their
bookmarks, or they might share the URL on social media. Therefore, it's typically
recommended that you never remove an existing URL - you should only redirect it.

The first step in making sure you don't break a public URL is to make sure that
URL doesn't disappear from your website build. Another way to say the same thing
is that you need to make sure pages don't disappear from one deployment to another.

The `LinksPlugin` includes support for watching your pages from one deployment to
the next, and it can alert you when pages disappear.

```dart
final site = StaticShock(...)
  ..plugin(const LinksPlugin());
```

By default, the `LinksPlugin` updates its list of pages when you run a production build,
but not when you run a development build. This is because what you're guarding against
is the loss of published pages. Similarly, by default, the plugin ignores all pages in
draft mode. 

You can override these defaults.

```dart
final site = StaticShock(...)
  ..plugin(const LinksPlugin(
    pageManifestUpdatePolicy: PageManifestUpdatePolicy.forceUpdate,
    includeDraftPagesInPageManifest: true,
  ));
```

By default, the `LinksPlugin` reports missing pages as warnings in dev mode, and as errors
in production mode. However, you can override the default behavior to report them however
you'd like.

```dart
final site = StaticShock(...)
  ..plugin(const LinksPlugin(
    reportMissingPagesAtErrorLevel: StaticShockErrorLevel.warning,
  ));
```

## Committing the page manifest
You need to commit your page manifest. The only way for this plugin to compare the current pages
to your previous set of pages is if you retain the list of those pages.

If you manually run your website build and deployment then all you need to do is make sure
that you add `[source]/.shock/cache/` to version control.

If you build and deploy with CI, then you need your CI system to watch out for changes to the
cache every time it builds. When your CI finds changes to the cache, you need to configure CI
to generate a new PR into your repo, which includes the cache changes.

If you use a GitHub workflow to build and deploy your website, you can find instructions for
committing cache changes in the [deploy to github pages](/guides/deploy-to-github-pages) guide.