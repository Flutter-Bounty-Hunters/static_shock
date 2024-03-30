---
title: Create a Plugin
tags: extensions
---
## What is a plugin?
A plugin is a collection of Static Shock configurations that's easy to share across projects and
across the community. For example, a plugin might pick specific files for the pipeline, apply
certain asset transformations, implement HTML templating, etc.

In Static Shock, plugins don't have any special power. There's nothing that a plugin can do, that
you can't do with a `StaticShock` pipeline, directly. Plugins are just about code organization.

## Static Shock is one big pipeline
To understand how to implement a Static Shock plugin, it's important to first understand that all
of Static Shock comes down to a class called `StaticShockPipeline`. That `StaticShockPipeline` 
object, as the name implies, is one big pipeline. Your source files go in one end of that pipeline, 
and your final static website build files come out the other end.

All Static Shock build behavior is the result of configuring the `StaticShockPipeline`, including
plugin behavior.

The Static Shock pipeline is assembled from the following objects:

 * `Picker`s: choose which files and/or directories to push into the pipeline.
 * `DataLoader`s: load external data and makes that data available for `Page` rendering.
 * `AssetTransformer`s: transform asset file content, such as transforming Sass to CSS.
 * `PageLoader`s: identify source files that represent pages, and loads them into `Page` objects.
 * `PageTransformer`s: transform `Page` objects before the `Page`s are rendered.
 * `PageRenderer`s: render `Page`s to their final HTML files.
 * `Finisher`s: execute arbitrary behavior after all pages have been rendered.

A plugin can add any number of pipeline objects, as needed, to implement some kind of feature.

A plugin's API is a single method that lets the plugin configure a `StaticShockPipeline`.

```dart
class MyPlugin implements StaticShockPlugin {
  const MyPlugin();

  @override
  FutureOr<void> configure(StaticShockPipeline pipeline, StaticShockPipelineContext context) {
    // TODO: configure the pipeline.
    // TODO: the "context" provides supplemental tools, such as a Logger, and file access.
  }
}
```

Let's look at some real-world examples.

## Sass Plugin
The following plugin implementation finds Sass files, transforms Sass to CSS, and writes the CSS
to file.

```dart
import 'dart:async';

import 'package:mason_logger/mason_logger.dart';
import 'package:sass/sass.dart' as sass;
import 'package:static_shock/static_shock.dart';

class SassPlugin implements StaticShockPlugin {
  const SassPlugin();

  @override
  FutureOr<void> configure(StaticShockPipeline pipeline, StaticShockPipelineContext context) {
    pipeline
      ..pick(ExtensionPicker("sass"))
      ..pick(ExtensionPicker("scss"))
      ..transformAssets(
        SassAssetTransformer(context.log),
      );
  }
}

class SassAssetTransformer implements AssetTransformer {
  static const _extensions = ["sass", "scss"];

  const SassAssetTransformer(this._log);

  final Logger _log;

  @override
  FutureOr<void> transformAsset(StaticShockPipelineContext context, Asset asset) async {
    if (!_extensions.contains(asset.sourcePath.extension.toLowerCase())) {
      // This isn't a Sass asset. Ignore it.
      return;
    }

    asset.destinationPath = asset.destinationPath!.copyWith(
      extension: "css",
    );
    asset.destinationContent = AssetContent.text(
      sass
          .compileToResult(
            context.resolveSourceFile(asset.sourcePath).path,
          )
          .css,
    );

    _log.detail("Compiled Sass to CSS for '${asset.sourcePath}' -> '${asset.destinationPath}'");
  }
}
```

## Markdown Plugin
The following plugin loads Markdown files as `Page`s and renders the Markdown content to HTML.

```dart
import 'dart:async';

import 'package:fbh_front_matter/fbh_front_matter.dart' as front_matter;
import 'package:markdown/markdown.dart';
import 'package:mason_logger/mason_logger.dart';

import 'package:static_shock/src/files.dart';
import 'package:static_shock/src/pages.dart';
import 'package:static_shock/src/pipeline.dart';
import 'package:static_shock/src/static_shock.dart';

class MarkdownPlugin implements StaticShockPlugin {
  const MarkdownPlugin();

  @override
  FutureOr<void> configure(StaticShockPipeline pipeline, StaticShockPipelineContext context) {
    pipeline.pick(const ExtensionPicker("md"));
    pipeline.loadPages(MarkdownPageLoader(context.log));
    pipeline.renderPages(MarkdownPageRenderer(context.log));
  }
}

class MarkdownPageLoader implements PageLoader {
  const MarkdownPageLoader(this._log);

  final Logger _log;

  @override
  bool canLoad(FileRelativePath path) {
    return path.extension == "md";
  }

  @override
  FutureOr<Page> loadPage(FileRelativePath path, String content) async {
    late final front_matter.FrontMatterDocument markdown;
    try {
      markdown = front_matter.parse(content);
    } catch (exception) {
      _log.err("Caught exception while parsing Front Matter for page ($path):\n$exception");
      rethrow;
    }

    return Page(
      path,
      markdown.content ?? "",
      data: {...markdown.data},
      destinationPath: path.copyWith(extension: "html"),
    );
  }
}

class MarkdownPageRenderer implements PageRenderer {
  const MarkdownPageRenderer(this._log);

  final Logger _log;

  @override
  FutureOr<void> renderPage(StaticShockPipelineContext context, Page page) async {
    if (page.sourcePath.extension != "md") {
      // This isn't a markdown page. Nothing for us to do.
      return;
    }

    _log.detail("Transforming Markdown page: ${page.sourcePath}");
    final contentHtml = markdownToHtml(page.sourceContent);
    page.destinationContent = contentHtml;
  }
}
```