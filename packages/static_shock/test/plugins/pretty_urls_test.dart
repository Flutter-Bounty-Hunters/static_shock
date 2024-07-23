import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:static_shock/static_shock.dart';
import 'package:test/test.dart';

void main() {
  group("Plugins > pretty URLs >", () {
    test("pretties URL for page with single source file", () async {
      final context = StaticShockPipelineContext(Logger(), Directory("/User/Fake/website"));
      final page = Page(FileRelativePath("./posts/news", "fake", "md"), "");
      context.pagesIndex.addPage(page);

      PrettyPathPageTransformer().transformPage(context, page);

      expect(page.url, "/posts/news/fake/");
    });

    test("pretties URL for page with explicit index file", () async {
      final context = StaticShockPipelineContext(Logger(), Directory("/User/Fake/website"));
      final page = Page(FileRelativePath("./posts/news/fake", "index", "md"), "");
      context.pagesIndex.addPage(page);

      PrettyPathPageTransformer().transformPage(context, page);

      expect(page.url, "/posts/news/fake/");
    });

    test("pretties URL for root-level page", () async {
      final context = StaticShockPipelineContext(Logger(), Directory("/User/Fake/website"));
      final page = Page(FileRelativePath("./", "fake", "md"), "");
      context.pagesIndex.addPage(page);

      PrettyPathPageTransformer().transformPage(context, page);

      expect(page.url, "/fake/");
    });

    test("keeps root level index HTML file as-is", () async {
      final context = StaticShockPipelineContext(Logger(), Directory("/User/Fake/website"));
      final page = Page(FileRelativePath("./", "index", "html"), "");
      context.pagesIndex.addPage(page);

      PrettyPathPageTransformer().transformPage(context, page);

      expect(page.url, "/");
    });

    test("keeps root level index Markdown file as-is", () async {
      final context = StaticShockPipelineContext(Logger(), Directory("/User/Fake/website"));
      final page = Page(FileRelativePath("./", "index", "md"), "");
      context.pagesIndex.addPage(page);

      PrettyPathPageTransformer().transformPage(context, page);

      expect(page.url, "/");
    });
  });
}
