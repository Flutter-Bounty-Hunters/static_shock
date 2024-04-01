---
title: Draft Articles
tags: drafting
---
When writing documentation, blog entries, or news articles, it's convenient to be able to work on
those pages within the static site project, but without publishing those pages to the final build.
The drafting plugin makes this possible.

Add the drafting plugin to your project.

```dart
final staticShock = StaticShock()
  ..plugin(DraftingPlugin());
```

The drafting plugin excludes all pages that are marked as drafts. To mark a page as a draft, set
the property `draft` to `true`.

```markdown
---
title: My Work In Progress
draft: true
---
# My Work In Progress
I'm still working on this!
```

You can still build a version of your website that includes the draft pages by configuring the
plugin to show them.

```dart
final staticShock = StaticShock()
  ..plugin(DraftingPlugin(showDrafts: true));
```

It may not be convenient to alter the `DraftingPlugin` code every time you want to switch to/from
draft mode. You can leverage the application arguments to implement your own concept of a configurable
preview mode. For example, you might update your `main.dart` file to do the following.

```dart
void main(List<String> arguments) {
  final isPreviewMode = arguments.contains("preview");
  
  // Configure the static website generator.
  final staticShock = StaticShock()
    // other configuration...
    ..plugin(
      DraftingPlugin(
        showDrafts: isPreviewMode,
      ),
    );

  // Generate the static website.
  await staticShock.generateSite();
}
```

With the concept of a preview mode, enabled by a "preview" command-line option, you can make the
decision about preview mode whenever you build or serve your website.

```bash
# Regular build.
shock build

# Build with draft pages.
shock build preview

# Regular server.
shock serve

# Serve with draft pages.
shock serve preview
```

The use of "preview" as the command-line argument is arbitrary. You can use whatever term you'd like.
You need to configure your `main()` method to honor whatever value you choose.