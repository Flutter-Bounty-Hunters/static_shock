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
