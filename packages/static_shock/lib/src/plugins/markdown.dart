import 'dart:async';
import 'dart:math';

import 'package:fbh_front_matter/fbh_front_matter.dart' as front_matter;
import 'package:markdown/markdown.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:static_shock/src/cache.dart';

import 'package:static_shock/src/files.dart';
import 'package:static_shock/src/pages.dart';
import 'package:static_shock/src/pipeline.dart';
import 'package:static_shock/src/static_shock.dart';

class MarkdownPlugin implements StaticShockPlugin {
  const MarkdownPlugin({
    this.renderOptions = const MarkdownRenderOptions(),
  });

  @override
  final id = "io.staticshock.markdown";

  final MarkdownRenderOptions renderOptions;

  @override
  FutureOr<void> configure(
    StaticShockPipeline pipeline,
    StaticShockPipelineContext context,
    StaticShockCache pluginCache,
  ) {
    pipeline
      ..pick(const ExtensionPicker("md"))
      ..loadPages(MarkdownPageLoader(context.log))
      ..renderPages(MarkdownPageRenderer(context.log, renderOptions));

    context.putTemplateFunction("md", (String markdown) => markdownToHtml(markdown, inlineOnly: true));
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

    final destinationPath = path.copyWith(extension: "html");

    return Page(
      path,
      markdown.content ?? "",
      data: {
        // Note: assign "pagePath" before including Markdown data so that the Markdown data can override it.
        "pagePath": destinationPath.value,
        if (!markdown.data.containsKey("contentRenderers")) //
          "contentRenderers": ["markdown"],
        ...markdown.data,
        "tableOfContents": _createTableOfContents(destinationPath.value, markdown.content ?? ""),
      },
      destinationPath: destinationPath,
    );
  }

  Map<String, dynamic> _createTableOfContents(String pageUrl, String markdown) {
    final items = <Map<String, dynamic>>[];
    final lines = markdown.split("\n");
    bool ignoreCurrentBlock = false;
    for (final line in lines) {
      if (line == "```" || (line.startsWith("```") && !line.endsWith("```"))) {
        // This line either starts or ends a code block. We want to ignore all content
        // in code blocks so that we don't add lines of code to the table of contents.
        ignoreCurrentBlock = !ignoreCurrentBlock;
      }

      if (ignoreCurrentBlock) {
        continue;
      }

      int? level;
      String? title;

      if (line.startsWith("# ")) {
        level = 0;
        title = line.substring(2);
      } else if (line.startsWith("## ")) {
        level = 1;
        title = line.substring(3);
      } else if (line.startsWith("### ")) {
        level = 2;
        title = line.substring(4);
      } else if (line.startsWith("#### ")) {
        level = 3;
        title = line.substring(5);
      } else if (line.startsWith("##### ")) {
        level = 4;
        title = line.substring(6);
      } else if (line.startsWith("###### ")) {
        level = 5;
        title = line.substring(7);
      }

      if (level != null) {
        items.add({
          "title": title!,
          // The following section ID assignment applies the same ID naming convention as the Markdown
          // package. This is required, because the URL needs to link to the HTML header on this
          // page, which was created by the Markdown parser.
          //
          // Example: "#my-section-title"
          "sectionId": "#${title.toLowerCase().replaceAll(" ", "-")}",
          "level": level,
        });
      }
    }

    return {
      "items": items,
      "isEmpty": items.isEmpty,
      "isEmptyBeyondLevel": (int level) => _linkCountBeyondLevel(items, level) == 0,
      "hasMultipleBeyondLevel": (int level) => _linkCountBeyondLevel(items, level) > 1,
      "linkCountBeyondLevel": (int level) => _linkCountBeyondLevel(items, level),
      "renderHtmlList": ({int? startingLevel}) => _renderHtmlList(items, startingLevel),
    };
  }

  int _linkCountBeyondLevel(List<Map<String, dynamic>> links, int level) {
    return links.where((link) => link["level"] > level).fold(0, (prev, link) => prev + 1);
  }

  String _renderHtmlList(List<Map<String, dynamic>> links, [int? startingLevel]) {
    final visibleLinks = startingLevel == null ? links : links.where((link) => link["level"] >= startingLevel);
    if (visibleLinks.isEmpty) {
      return "";
    }

    int baseLevel = visibleLinks.fold(6, (prev, link) => link["level"] < prev ? link["level"] : prev);
    if (startingLevel != null) {
      baseLevel = max(startingLevel, baseLevel);
    }

    // Create a Markdown list of links for every header. We'll convert it to HTML next.
    final tocMarkdown = StringBuffer();
    for (final link in visibleLinks) {
      final indent = List.generate((link["level"] - baseLevel), (index) => "   ").join("");
      tocMarkdown.writeln("${indent}1. [${link["title"]}](${link["sectionId"]})");
    }

    // Convert the markdown link list to an HTML list, which can be used as a table of contents.
    return markdownToHtml(tocMarkdown.toString());
  }
}

class MarkdownPageRenderer implements PageRenderer {
  const MarkdownPageRenderer(this._log, this._renderOptions);

  // ignore: unused_field
  final Logger _log;
  final MarkdownRenderOptions _renderOptions;

  @override
  String get id => "markdown";

  @override
  FutureOr<void> renderContent(StaticShockPipelineContext context, Page page) {
    final contentHtml = markdownToHtml(
      page.destinationContent ?? page.sourceContent,
      blockSyntaxes: [
        HeaderWithIdSyntax(),
        ..._renderOptions.blockSyntaxes,
      ],
      inlineSyntaxes: _renderOptions.inlineSyntaxes,
      extensionSet: _renderOptions.extensionSet,
      linkResolver: _renderOptions.linkResolver,
      imageLinkResolver: _renderOptions.imageLinkResolver,
      inlineOnly: _renderOptions.inlineOnly,
      encodeHtml: _renderOptions.encodeHtml,
      enableTagfilter: _renderOptions.enableTagFilter,
      withDefaultBlockSyntaxes: _renderOptions.withDefaultBlockSyntaxes,
      withDefaultInlineSyntaxes: _renderOptions.withDefaultInlineSyntaxes,
    );
    page.destinationContent = contentHtml;
  }

  @override
  FutureOr<void> renderLayout(StaticShockPipelineContext context, Page page) async {
    // No-op. Markdown doesn't render page layouts.
  }
}

/// Options for how to render Markdown to HTML.
class MarkdownRenderOptions {
  const MarkdownRenderOptions({
    this.blockSyntaxes = const [],
    this.inlineSyntaxes = const [],
    this.extensionSet,
    this.linkResolver,
    this.imageLinkResolver,
    this.inlineOnly = false,
    this.encodeHtml = true,
    this.enableTagFilter = false,
    this.withDefaultBlockSyntaxes = true,
    this.withDefaultInlineSyntaxes = true,
  });

  final Iterable<BlockSyntax> blockSyntaxes;
  final Iterable<InlineSyntax> inlineSyntaxes;
  final ExtensionSet? extensionSet;
  final Resolver? linkResolver;
  final Resolver? imageLinkResolver;
  final bool inlineOnly;
  final bool encodeHtml;
  final bool enableTagFilter;
  final bool withDefaultBlockSyntaxes;
  final bool withDefaultInlineSyntaxes;

  MarkdownRenderOptions copyWith({
    Iterable<BlockSyntax>? blockSyntaxes,
    Iterable<InlineSyntax>? inlineSyntaxes,
    ExtensionSet? extensionSet,
    Resolver? linkResolver,
    Resolver? imageLinkResolver,
    bool? inlineOnly,
    bool? encodeHtml,
    bool? enableTagFilter,
    bool? withDefaultBlockSyntaxes,
    bool? withDefaultInlineSyntaxes,
  }) {
    return MarkdownRenderOptions(
      blockSyntaxes: blockSyntaxes ?? this.blockSyntaxes,
      inlineSyntaxes: inlineSyntaxes ?? this.inlineSyntaxes,
      extensionSet: extensionSet ?? this.extensionSet,
      linkResolver: linkResolver ?? this.linkResolver,
      imageLinkResolver: imageLinkResolver ?? this.imageLinkResolver,
      inlineOnly: inlineOnly ?? this.inlineOnly,
      encodeHtml: encodeHtml ?? this.encodeHtml,
      enableTagFilter: enableTagFilter ?? this.enableTagFilter,
      withDefaultBlockSyntaxes: withDefaultBlockSyntaxes ?? this.withDefaultBlockSyntaxes,
      withDefaultInlineSyntaxes: withDefaultInlineSyntaxes ?? this.withDefaultInlineSyntaxes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkdownRenderOptions &&
          runtimeType == other.runtimeType &&
          blockSyntaxes == other.blockSyntaxes &&
          inlineSyntaxes == other.inlineSyntaxes &&
          extensionSet == other.extensionSet &&
          linkResolver == other.linkResolver &&
          imageLinkResolver == other.imageLinkResolver &&
          inlineOnly == other.inlineOnly &&
          encodeHtml == other.encodeHtml &&
          enableTagFilter == other.enableTagFilter &&
          withDefaultBlockSyntaxes == other.withDefaultBlockSyntaxes &&
          withDefaultInlineSyntaxes == other.withDefaultInlineSyntaxes;

  @override
  int get hashCode =>
      blockSyntaxes.hashCode ^
      inlineSyntaxes.hashCode ^
      extensionSet.hashCode ^
      linkResolver.hashCode ^
      imageLinkResolver.hashCode ^
      inlineOnly.hashCode ^
      encodeHtml.hashCode ^
      enableTagFilter.hashCode ^
      withDefaultBlockSyntaxes.hashCode ^
      withDefaultInlineSyntaxes.hashCode;
}
