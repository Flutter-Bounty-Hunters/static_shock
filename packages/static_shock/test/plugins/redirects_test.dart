import 'dart:io';

import 'package:collection/collection.dart';
import 'package:static_shock/static_shock.dart';

import 'package:mason_logger/mason_logger.dart';
import 'package:test/test.dart';

void main() {
  group("Plugins > redirects >", () {
    test("handles variety of redirect paths", () async {
      // Sets up a `Page` that requests a redirect from `redirectFrom` to the given page,
      // and then verifies that a dedicated redirect page was created for the old URL.
      void redirectsFrom(String redirectFrom, String redirectTo) {
        final context = StaticShockPipelineContext(Logger(), Directory("test/fake/"));
        final page = Page(FileRelativePath("./fake_source", "fake", "md"), "") //
          ..destinationContent = _basicHtml
          ..data["url"] = redirectTo
          ..data["redirectFrom"] = redirectFrom;
        context.pagesIndex.addPage(page);

        RedirectsFinisher().execute(context);

        final redirectPage = context.pagesIndex.pages.firstWhereOrNull((page) => page.url == redirectFrom);
        expect(redirectPage, isNotNull);
      }

      redirectsFrom("/old/dir", "new/dir");
      redirectsFrom("/old/dir/", "new/dir");
      redirectsFrom("/old/dir/file.html", "new/dir");
    });

    test("does not attempt to redirect a fully specified URL", () {
      // We can't handle something like "http://mysite.com/old/path/" because we're not building "mysite.com"
      final context = StaticShockPipelineContext(Logger(), Directory("test/fake/"));
      final page = Page(FileRelativePath("./fake_source", "fake", "md"), "") //
        ..destinationContent = _basicHtml
        ..data["url"] = "new/path"
        ..data["redirectFrom"] = "http://mysite.com/old/path";
      context.pagesIndex.addPage(page);

      RedirectsFinisher().execute(context);

      final redirectPage = context.pagesIndex.pages.firstWhereOrNull((page) => page.url == "mysite.com/old/path");
      expect(redirectPage, isNull);
    });

    test("does not attempt to redirect a partially specified URL", () {
      // We can't handle something like "mysite.com/old/path/" because we're not building "mysite.com"
      final context = StaticShockPipelineContext(Logger(), Directory("test/fake/"));
      final page = Page(FileRelativePath("./fake_source", "fake", "md"), "") //
        ..destinationContent = _basicHtml
        ..data["url"] = "new/path"
        ..data["redirectFrom"] = "mysite.com/old/path";
      context.pagesIndex.addPage(page);

      RedirectsFinisher().execute(context);

      final redirectPage = context.pagesIndex.pages.firstWhereOrNull((page) => page.url == "mysite.com/old/path");
      expect(redirectPage, isNull);
    });

    test("inserts redirect tag in variety of HTML", () {
      void insertsRedirectTag(String html) {
        final context = StaticShockPipelineContext(Logger(), Directory("test/fake/"));
        final page = Page(FileRelativePath("./fake_source", "fake", "md"), "") //
          ..destinationContent = html
          ..data["url"] = "new/dir"
          ..data["redirectFrom"] = "/old/dir";
        context.pagesIndex.addPage(page);

        RedirectsFinisher().execute(context);

        final redirectPage = context.pagesIndex.pages.firstWhereOrNull((page) => page.url == "/old/dir");
        expect(redirectPage, isNotNull);
        expect(redirectPage!.destinationContent, isNotNull);
        expect(
          redirectPage.destinationContent,
          stringContainsInOrder(['<meta http-equiv="refresh" content="0; url=/new/dir" />']),
        );
      }

      // Lowercase "<head>"
      insertsRedirectTag(_basicHtml);

      // Uppercase "<HEAD>"
      insertsRedirectTag(_basicHtml.toUpperCase());

      // Mixed-case "<HeAd>"
      insertsRedirectTag(_mixedCaseHtml);
    });

    test("does not redirect when missing HEAD tag", () {
      final context = StaticShockPipelineContext(Logger(), Directory("test/fake/"));
      final page = Page(FileRelativePath("./fake_source", "fake", "md"), "") //
        ..destinationContent = _missingHeadHtml
        ..data["url"] = "new/dir"
        ..data["redirectFrom"] = "/old/dir";
      context.pagesIndex.addPage(page);

      RedirectsFinisher().execute(context);

      final redirectPage = context.pagesIndex.pages.firstWhereOrNull((page) => page.url == "/old/dir");
      expect(redirectPage, isNull);
    });
  });
}

const _basicHtml = '''<!doctype html>

<html>
<head>
  <meta charset="utf-8">
  <title>Fake Title</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body>
  <p>Basic HTML</p>
</body>
</html>''';

const _mixedCaseHtml = '''<!DoCtYpE hTmL>

<hTmL>
<HeAd>
  <MEta charset="utf-8">
  <tItLe>Fake Title</tItLe>
  <meTA name="viewport" content="width=device-width, initial-scale=1.0">
</HeAd>
<BoDy>
  <p>Basic HTML</p>
</BoDy>
</hTmL>''';

const _missingHeadHtml = '''<!doctype html>

<html>
<body>
  <p>Basic HTML</p>
</body>
</html>''';
