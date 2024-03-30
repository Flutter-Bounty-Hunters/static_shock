import 'dart:async';
import 'dart:math';

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
    pipeline
      ..pick(const ExtensionPicker("md"))
      ..loadPages(MarkdownPageLoader(context.log))
      ..renderPages(MarkdownPageRenderer(context.log));

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

    print("Markdown content:");
    print(markdown.content ?? "");

    final destinationPath = path.copyWith(extension: "html");

    return Page(
      path,
      markdown.content ?? "",
      data: {
        ...markdown.data,
        "tableOfContents": _createTableOfContents(destinationPath.value, markdown.content ?? ""),
      },
      destinationPath: destinationPath,
    );
  }

  Map<String, dynamic> _createTableOfContents(String pageUrl, String markdown) {
    final links = <Map<String, dynamic>>[];
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
        links.add({
          "title": title!,
          // The following title assignment applies the same ID naming convention as the Markdown
          // package. This is required, because the URL needs to link to the HTML header on this
          // page, which was created by the Markdown parser.
          "url": "#${title.toLowerCase().replaceAll(" ", "-")}",
          "level": level,
        });
      }
    }

    return {
      "links": links,
      "isEmpty": links.isEmpty,
      "isEmptyBeyondLevel": (int level) => _linkCountBeyondLevel(links, level) == 0,
      "hasMultipleBeyondLevel": (int level) => _linkCountBeyondLevel(links, level) > 1,
      "linkCountBeyondLevel": (int level) => _linkCountBeyondLevel(links, level),
      "renderMultiLevelList": ({int? startingLevel}) => _renderMultiLevelList(links, startingLevel),
    };
  }

  int _linkCountBeyondLevel(List<Map<String, dynamic>> links, int level) {
    return links.where((link) => link["level"] > level).fold(0, (prev, link) => prev + 1);
  }

  String _renderMultiLevelList(List<Map<String, dynamic>> links, [int? startingLevel]) {
    final visibleLinks = startingLevel == null ? links : links.where((link) => link["level"] >= startingLevel);
    if (visibleLinks.isEmpty) {
      return "";
    }

    int baseLevel = visibleLinks.fold(6, (prev, link) => link["level"] < prev ? link["level"] : prev);
    if (startingLevel != null) {
      baseLevel = max(startingLevel, baseLevel);
    }

    final tocMarkdown = StringBuffer();
    for (final link in visibleLinks) {
      final indent = List.generate((link["level"] - baseLevel), (index) => "  ").join("");
      tocMarkdown.writeln("${indent}1. [${link["title"]}](${link["url"]})");
    }

    print("Table of contents rendered list:");
    print(tocMarkdown.toString());

    final html = markdownToHtml(tocMarkdown.toString());
    print("---");
    print("HTML version:");
    print(html);

    return html;
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
    final contentHtml = markdownToHtml(
      page.sourceContent,
      blockSyntaxes: [
        HeaderWithIdSyntax(),
      ],
    );
    page.destinationContent = contentHtml;
  }
}
