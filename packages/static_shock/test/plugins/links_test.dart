import 'dart:io';

import 'package:static_shock/static_shock.dart';
import 'package:test/test.dart';

void main() {
  group("Links plugin >", () {
    test("finds and reports bad external and internal URIs (no base URL set)", () async {
      final errorLog = ErrorLog();
      final context = _createFakeSite(Directory("test/fake/"), errorLog);

      await BrokenLinkFinderFinisher().execute(context);

      expect(errorLog.hasWarnings, isTrue);
      expect(errorLog.warnings, [
        StaticShockError.warning(
          "Bad external URL found on page '/guides/getting-started' (Getting Started): 'https://staticshock.io/does/not/exist'",
        ),
        StaticShockError.warning(
          "Bad internal URL/path found on page '/guides/getting-started' (Getting Started): '/root/relative/url/'",
        ),
        StaticShockError.warning(
          "Bad internal URL/path found on page '/guides/getting-started' (Getting Started): '/guides/getting-started/relative/url/index.html'",
        ),
      ]);
    });

    test("finds and reports bad external and internal URIs (with base URL set)", () async {
      final errorLog = ErrorLog();
      final context = _createFakeSite(Directory("test/fake/"), errorLog);
      context.dataIndex.mergeAtPath(DirectoryRelativePath("/"), {
        "baseUrl": "https://staticshock.io",
      });

      await BrokenLinkFinderFinisher().execute(context);

      expect(errorLog.hasWarnings, isTrue);
      expect(errorLog.warnings, [
        StaticShockError.warning(
          "Bad internal URL/path found on page '/guides/getting-started' (Getting Started): 'https://staticshock.io/does/not/exist'",
        ),
        StaticShockError.warning(
          "Bad internal URL/path found on page '/guides/getting-started' (Getting Started): '/root/relative/url/'",
        ),
        StaticShockError.warning(
          "Bad internal URL/path found on page '/guides/getting-started' (Getting Started): '/guides/getting-started/relative/url/index.html'",
        ),
      ]);
    });

    // TODO: Add test for relative links

    // TODO: Add test that shows drafting pages are ignored

    group("HTML URL finder >", () {
      test("finds URLs in HTML", () {
        final linkFinder = HtmlLinkFinder();
        final links = linkFinder.findAnchorLinks(_fakeHtml);

        expect(
          links,
          [
            Uri.parse("https://google.com"),
            Uri.parse("https://www.flutter.dev"),
            Uri.parse("/root/relative/url"),
            Uri.parse("/root/relative/url/"),
            Uri.parse("/root/relative/url/index.html"),
            Uri.parse("relative/url"),
            Uri.parse("relative/url/"),
            Uri.parse("relative/url/index.html"),
          ],
        );
      });

      test("identifies bad URLs", () async {
        final urlValidator = UrlValidator();
        final badUrls = await urlValidator.findDeadUrls([
          Uri.parse("https://google.com"),
          Uri.parse("https://staticshock.io/does/not/exist/"),
          Uri.parse("https://flutter.dev"),
          Uri.parse("https://www.staticshock.io/nothing.html"),
        ]);

        expect(badUrls, [
          Uri.parse("https://staticshock.io/does/not/exist/"),
          Uri.parse("https://www.staticshock.io/nothing.html"),
        ]);
      });
    });

    group("URI selector >", () {
      // Create one test for each of the possible ways that the base site might be
      // encoded by the user, e.g., "https://staticshock.io" vs "www.staticshock.io"
      // vs "staticshock.io".
      for (final siteUrlPrefix in _SiteUrlPrefix.values) {
        test("with base URL, finds external URLs, internal URLs, and internal paths (${siteUrlPrefix.name})", () async {
          final baseUri = siteUrlPrefix.makeUrl("staticshock.io");

          // A list of links that might exist in a real website.
          final uris = [
            Uri.parse("https://google.com"),
            Uri.parse("http://google.com"),
            Uri.parse("www.flutter.dev"),
            Uri.parse("superdeclarative.com"),
            Uri.parse("https://staticshock.io"),
            Uri.parse("www.staticshock.io"),
            Uri.parse("staticshock.io"),
            Uri.parse("https://staticshock.io/welcome"),
            Uri.parse("/guides/getting-started"),
            Uri.parse("subpath/to/somewhere"),
          ];

          // Ensure that we can pick out the links that point to other websites.
          expect(uris.whereRemote(baseUri).toList(), [
            Uri.parse("https://google.com"),
            Uri.parse("http://google.com"),
            Uri.parse("www.flutter.dev"),
            Uri.parse("superdeclarative.com"),
          ]);

          // Ensure that we can pick out the links that point to our website.
          expect(uris.whereLocal(baseUri).toList(), [
            Uri.parse("https://staticshock.io"),
            Uri.parse("www.staticshock.io"),
            Uri.parse("staticshock.io"),
            Uri.parse("https://staticshock.io/welcome"),
            Uri.parse("/guides/getting-started"),
            Uri.parse("subpath/to/somewhere"),
          ]);
        });
      }

      test("with no URL, finds external URLs, internal URLs, and internal paths", () async {
        final baseUri = null;

        // A list of links that might exist in a real website.
        final uris = [
          Uri.parse("https://google.com"),
          Uri.parse("http://google.com"),
          Uri.parse("www.flutter.dev"),
          Uri.parse("superdeclarative.com"),
          Uri.parse("https://staticshock.io"),
          Uri.parse("www.staticshock.io"),
          Uri.parse("staticshock.io"),
          Uri.parse("https://staticshock.io/welcome"),
          Uri.parse("/guides/getting-started"),
          Uri.parse("subpath/to/somewhere"),
        ];

        // Ensure that we can pick out the links that point to other websites.
        expect(uris.whereRemote(baseUri).toList(), [
          Uri.parse("https://google.com"),
          Uri.parse("http://google.com"),
          Uri.parse("www.flutter.dev"),
          Uri.parse("superdeclarative.com"),
          Uri.parse("https://staticshock.io"),
          Uri.parse("www.staticshock.io"),
          Uri.parse("staticshock.io"),
          Uri.parse("https://staticshock.io/welcome"),
        ]);

        // Ensure that we can pick out paths from URLs.
        expect(uris.whereLocal(baseUri).toList(), [
          Uri.parse("/guides/getting-started"),
          Uri.parse("subpath/to/somewhere"),
        ]);
      });
    });
  });
}

enum _SiteUrlPrefix {
  fullyQualified,
  justScheme,
  justWWW,
  none;

  Uri makeUrl(String domain) {
    switch (this) {
      case _SiteUrlPrefix.fullyQualified:
        return Uri.parse("https://www.$domain");
      case _SiteUrlPrefix.justScheme:
        return Uri.parse("https://$domain");
      case _SiteUrlPrefix.justWWW:
        return Uri.parse("www.$domain");
      case _SiteUrlPrefix.none:
        return Uri.parse(domain);
    }
  }

  String get name {
    switch (this) {
      case _SiteUrlPrefix.fullyQualified:
        return "fully-qualified";
      case _SiteUrlPrefix.justScheme:
        return "just scheme";
      case _SiteUrlPrefix.justWWW:
        return "just WWW";
      case _SiteUrlPrefix.none:
        return "no prefix";
    }
  }
}

StaticShockPipelineContext _createFakeSite(Directory sourceDirectory, [ErrorLog? errorLog]) {
  final context = StaticShockPipelineContext(
    sourceDirectory: sourceDirectory,
    errorLog: errorLog ?? ErrorLog(),
  );

  context.dataIndex.mergeAtPath(DirectoryRelativePath("/"), {
    "basePath": "/",
  });

  context.pagesIndex.addPage(
    Page(
      FileRelativePath("guides/getting-started.md", "fake", "md"),
      "",
      data: {
        PageKeys.title: "Getting Started",
      },
    ) //
      ..destinationContent = _gettingStartedHtml
      ..pagePath = "/guides/getting-started",
  );

  return context;
}

const _fakeHtml = '''
<!--suppress HtmlUnknownTarget, HtmlRequiredLangAttribute -->
<html>
<!--suppress HtmlRequiredTitleElement -->
<head></head>
<body>
  <ul>
    <li><a href="https://google.com">Google</a></li>
    <li><a title="Flutter" href='https://www.flutter.dev'>Flutter</a></li>
    <li><a class="link" href="/root/relative/url">Root relative directory no /</a></li>
    <li><a href='/root/relative/url/' class="link">Root relative directory with /</a></li>
    <li><a href='/root/relative/url/index.html'>Root relative HTML page</a></li>
    <li><a href="relative/url">Relative directory no /</a></li>
    <li><a href='relative/url/'>Relative directory with /</a></li>
    <li><a href='relative/url/index.html'>Relative HTML page</a></li>
    <li><a href='#some-section'>This shouldn't be picked up at all</a></li>
  </ul>
</body>
</html>''';

const _gettingStartedHtml = '''
<!--suppress HtmlUnknownTarget, HtmlRequiredLangAttribute -->
<html>
<!--suppress HtmlRequiredTitleElement -->
<head>
  <title>Welcome</title>
</head>
<body>
  <ul>
    <li><a href='https://flutter.dev'>Flutter</a></li>
    <li><a href='https://staticshock.io/does/not/exist'>Flutter</a></li>
    <li><a href='/root/relative/url/' class="link">Root relative directory with /</a></li>
    <li><a href='relative/url/index.html'>Relative HTML page</a></li>
  </ul>
</body>
</html>''';
