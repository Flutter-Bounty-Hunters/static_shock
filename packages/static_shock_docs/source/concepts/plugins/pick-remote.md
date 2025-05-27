---
title: Pick From Remote Sources
---
It can be convenient to load pages, assets, and data from remote sources, such
as servers. 

For example, consider Flutter Bounty Hunter (FBH) documentation websites.
FBH maintains many packages, with many documentation websites. It's convenient
for many of those documentation websites to share visual styling and contribution
instructions. With remote picking, each documentation website can pick layouts
and content from a single set of files hosted on GitHub.

Plugins can pick remote data, pages, assets, layouts, and components.

```dart
@override
FutureOr<void> configure(
  StaticShockPipeline pipeline,
  StaticShockPipelineContext context,
  StaticShockCache pluginCache,
) {
  pipeline.pickRemote(
    layouts: {
      RemoteInclude(
        url: "https://raw.githubusercontent.com/my-repo/_includes/layouts/post.jinja?raw=true",
        name: "post",
        extension: "jinja",
      ),
    },
    components: {/*...*/},
    data: {/*...*/},
    assets: {
      RemoteFile(
        url: "https://raw.githubusercontent.com/my-repo/images/flutter-logo.svg?raw=true",
        buildPath: FileRelativePath("images/branding/", "flutter-logo", "svg"),
      ),
    },
    pages: {/*...*/},
  );
}
```
