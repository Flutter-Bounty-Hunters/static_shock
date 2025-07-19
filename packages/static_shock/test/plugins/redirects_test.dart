import 'dart:io';

import 'package:collection/collection.dart';
import 'package:static_shock/static_shock.dart';
import 'package:test/test.dart';

void main() {
  group("Plugins > redirects >", () {
    test("handles variety of redirect paths", () async {
      // Sets up a `Page` that requests a redirect from `redirectFrom` to the given page,
      // and then verifies that a dedicated redirect page was created for the old URL.
      void redirectsFrom(String redirectFrom, String redirectTo) {
        final context = StaticShockPipelineContext(
          sourceDirectory: Directory("test/fake/"),
          errorLog: ErrorLog(),
        );
        final page = Page(FileRelativePath("./fake_source", "fake", "md"), "") //
          ..destinationContent = _basicHtml
          ..pagePath = redirectTo
          ..data[PageKeys.redirectFrom] = redirectFrom;
        context.pagesIndex.addPage(page);

        RedirectsFinisher().execute(context);

        final redirectPage = context.pagesIndex.pages.firstWhereOrNull((page) => page.pagePath == redirectFrom);
        expect(redirectPage, isNotNull);
      }

      redirectsFrom("old/dir", "new/dir");
      redirectsFrom("old/dir/", "new/dir");
      redirectsFrom("old/dir/file.html", "new/dir");
    });

    test("does not try to redirect when given an absolute path", () async {
      // Pages can't control the base path of a website, so absolute paths
      // make no sense as a redirect path.
      final context = StaticShockPipelineContext(
        sourceDirectory: Directory("test/fake/"),
        errorLog: ErrorLog(),
      );
      final page = Page(FileRelativePath("./fake_source", "fake", "md"), "") //
        ..destinationContent = _basicHtml
        ..pagePath = "new/dir"
        ..data[PageKeys.redirectFrom] = "/old/dir";
      context.pagesIndex.addPage(page);

      RedirectsFinisher().execute(context);

      // Expect that no additional page was added for redirect.
      expect(context.pagesIndex.pages.length, 1);
    });

    test("inserts redirect tag in variety of HTML with standard base path", () {
      void insertsRedirectTag(String html) {
        final context = StaticShockPipelineContext(
          sourceDirectory: Directory("test/fake/"),
          errorLog: ErrorLog(),
        );
        final page = Page(FileRelativePath("./fake_source", "fake", "md"), "") //
          ..destinationContent = html
          ..pagePath = "new/dir"
          ..data[PageKeys.redirectFrom] = "old/dir";
        context.pagesIndex.addPage(page);

        RedirectsFinisher().execute(context);

        final redirectPage = context.pagesIndex.pages.firstWhereOrNull((page) => page.pagePath == "old/dir");
        expect(redirectPage, isNotNull);
        expect(redirectPage!.destinationContent, isNotNull);
        expect(
          redirectPage.destinationContent,
          stringContainsInOrder([
            '<meta http-equiv="refresh" content="0; url=/new/dir" />',
            '<link rel="canonical" href="/new/dir" />',
          ]),
        );
      }

      // Lowercase "<head>"
      insertsRedirectTag(_basicHtml);

      // Uppercase "<HEAD>"
      insertsRedirectTag(_basicHtml.toUpperCase());

      // Mixed-case "<HeAd>"
      insertsRedirectTag(_mixedCaseHtml);
    });

    test("inserts redirect tag in variety of HTML with custom base path", () {
      void insertsRedirectTag(String html) {
        final context = StaticShockPipelineContext(
          sourceDirectory: Directory("test/fake/"),
          errorLog: ErrorLog(),
        );
        final page = Page(FileRelativePath("./fake_source", "fake", "md"), "") //
          ..destinationContent = html
          ..pagePath = "new/dir"
          ..data[PageKeys.redirectFrom] = "old/dir";
        context.pagesIndex.addPage(page);

        RedirectsFinisher(basePath: "/static_shock/").execute(context);

        final redirectPage = context.pagesIndex.pages.firstWhereOrNull((page) => page.pagePath == "old/dir");
        expect(redirectPage, isNotNull);
        expect(redirectPage!.destinationContent, isNotNull);
        expect(
          redirectPage.destinationContent,
          stringContainsInOrder([
            '<meta http-equiv="refresh" content="0; url=/static_shock/new/dir" />',
            '<link rel="canonical" href="/static_shock/new/dir" />'
          ]),
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
      final context = StaticShockPipelineContext(
        sourceDirectory: Directory("test/fake/"),
        errorLog: ErrorLog(),
      );
      final page = Page(FileRelativePath("./fake_source", "fake", "md"), "") //
        ..destinationContent = _missingHeadHtml
        ..pagePath = "new/dir"
        ..data[PageKeys.redirectFrom] = "old/dir";
      context.pagesIndex.addPage(page);

      RedirectsFinisher().execute(context);

      final redirectPage = context.pagesIndex.pages.firstWhereOrNull((page) => page.pagePath == "old/dir");
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
