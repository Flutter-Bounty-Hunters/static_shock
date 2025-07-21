import 'dart:async';

import 'package:collection/collection.dart';
import 'package:http/http.dart';
import 'package:path/path.dart' as path;
import 'package:static_shock/src/cache.dart';
import 'package:static_shock/src/files.dart';
import 'package:static_shock/src/finishers.dart';
import 'package:static_shock/src/pages.dart';
import 'package:static_shock/src/pipeline.dart';
import 'package:static_shock/src/static_shock.dart';
import 'package:yaml/yaml.dart';

/// A [StaticShockPlugin] that adds various link behaviors, such as creating page redirects,
/// and finding bad links in the final website build.
///
/// To configure redirects, add the `redirectFrom` property to a page.
///
/// Example: A single old URL:
///
///     ---
///     redirectFrom: /my/old/url/page.html
///     ---
///
/// Example: Multiple old URLs:
///
///     ---
///     redirectFrom:
///       - /my/old/url/1/page.html
///       - /my/old/url/2/page.html
///     ---
class LinksPlugin implements StaticShockPlugin {
  const LinksPlugin({
    this.shouldRunLinkVerification,
    this.failBuildOnBrokenLinks = true,
    this.pageManifestUpdatePolicy,
    this.reportMissingPagesAtErrorLevel,
    this.includeDraftPagesInPageManifest = false,
  });

  /// Whether this plugin should verify all links, or not, or `null` to let
  /// this plugin decide whether to verify links based on the website build
  /// mode, e.g., dev vs production.
  final bool? shouldRunLinkVerification;

  /// Whether to report a build failure if any broken links are found.
  ///
  /// The functional difference is that when this property is `true`, broken
  /// links are reported to Static Shock as errors, rather than warnings.
  final bool failBuildOnBrokenLinks;

  /// The policy that determines whether the page manifest cache is updated during this build.
  ///
  /// When `null`, defers to the current build mode. In "production" the page manifest is updated
  /// no matter what. In "dev" the page manifest isn't updated at all.
  ///
  /// This generation should only be done on publication of the website, because
  /// the purpose of this manifest is to avoid losing previously published internal
  /// URLs.
  final PageManifestUpdatePolicy? pageManifestUpdatePolicy;

  /// The error level to use when reporting pages that are missing from the previous build.
  ///
  /// Defaults to "warning" for dev builds, and "error" for production builds.
  ///
  /// See the [ErrorLog] to understand the implications of different levels.
  final StaticShockErrorLevel? reportMissingPagesAtErrorLevel;

  /// Whether draft (not yet published) pages should be included in the list of all
  /// pages, when checking for missing pages, and when saving a new manifest.
  final bool includeDraftPagesInPageManifest;

  @override
  String get id => "io.staticshock.links";

  @override
  FutureOr<void> configure(
    StaticShockPipeline pipeline,
    StaticShockPipelineContext context,
    StaticShockCache pluginCache,
  ) {
    // Apply the redirects finisher before checking for broken links or  missing pages so that
    // we account for all public URLs before validating them.
    pipeline.finish(
      RedirectsFinisher(
        basePath: context.dataIndex.getAtPath(["basePath"]) as String,
      ),
    );

    // Check for broken internal and external links.
    pipeline.finish(
      BrokenLinkFinderFinisher(
        shouldRunLinkVerification: true == shouldRunLinkVerification ||
            (shouldRunLinkVerification == null && context.buildMode == StaticShockBuildMode.production),
        reportBrokenLinksAsErrors: failBuildOnBrokenLinks,
      ),
    );

    // Check for any pages that used to exist but are gone now.
    pipeline.finish(
      FindMissingPagesFinisher(
        cache: pluginCache,
        reportMissingPagesAtErrorLevel: reportMissingPagesAtErrorLevel ??
            switch (context.buildMode) {
              StaticShockBuildMode.production => StaticShockErrorLevel.error,
              StaticShockBuildMode.dev => StaticShockErrorLevel.warning,
            },
        cacheUpdatePolicy: pageManifestUpdatePolicy ??
            switch (context.buildMode) {
              StaticShockBuildMode.production => PageManifestUpdatePolicy.forceUpdate,
              StaticShockBuildMode.dev => PageManifestUpdatePolicy.noUpdate,
            },
        includeDraftPages: includeDraftPagesInPageManifest,
      ),
    );
  }
}

/// [Finisher] that copies pages with redirects and adds appropriate HTML for the redirect.
///
/// To setup redirects without a server, each page with 1+ listed redirect is copied. The copy
/// has its URL set to the `redirectFrom` value
class RedirectsFinisher implements Finisher {
  static final _urlRegExp = RegExp(r'^((?:https?://)?[^./]+(?:\.[^./]+)+(?:/.*)?)$');

  const RedirectsFinisher({
    this.basePath = '/',
  });

  /// The base path for all URLs in the final website.
  ///
  /// Typically `/`, but can also be any value that a server might want.
  final String basePath;

  @override
  void execute(StaticShockPipelineContext context) {
    final pagesWithRedirects = context.pagesIndex.pages
        .where(
          (page) => page.data[PageKeys.redirectFrom] != null,
        )
        .toList();
    if (pagesWithRedirects.isEmpty) {
      return;
    }

    for (final page in pagesWithRedirects) {
      // Parse the 1+ redirects from YAML front-matter.
      final redirects = <String>{};
      final redirectsValue = page.data[PageKeys.redirectFrom];
      if (redirectsValue is YamlList) {
        final desiredRedirects = redirectsValue.value.cast<String>();
        final validRedirects = desiredRedirects.where(_isValidRedirectPath);
        final invalidRedirects = desiredRedirects.where((redirect) => !_isValidRedirectPath(redirect));

        redirects.addAll(validRedirects);

        if (invalidRedirects.isNotEmpty) {
          // TODO: Add an ability to report errors to the `context` and then report this, so that
          // during dev the build won't blow up, but when building for production, it will.
          context.log.warn("Found invalid page redirect path(s). New path: '${page.pagePath}'. From invalid paths:");
          for (final invalidRedirect in invalidRedirects) {
            context.log.warn(" - '$invalidRedirect'");
          }
        }
      } else if (redirectsValue is String) {
        if (redirectsValue.isEmpty) {
          // The user added a redirect key, but didn't include a value.
          context.log.warn(
            "Page ${page.pagePath} has a 'redirectsValue' field, but no corresponding value. To setup a redirect, please add a redirect URL.",
          );
          continue;
        }

        if (!_isValidRedirectPath(redirectsValue)) {
          context.log.warn(
            "Found invalid page redirect path. New path: '${page.pagePath}'. From invalid path: '$redirectsValue'",
          );
          continue;
        }

        redirects.add(redirectsValue);
      }

      context.log.detail("Setting up redirects for page: ${page.pagePath}");
      context.log.detail("Redirecting from:");
      for (final redirect in redirects) {
        context.log.detail(" - $redirect");
        final redirectDestinationFilePath = _mapRedirectUrlToBuildFilePath(context, redirect);
        if (redirectDestinationFilePath == null) {
          context.log.warn("Failed to convert a 'redirectFrom' URL path to a file path. URL path: '$redirect'");
          continue;
        }
        if (page.destinationContent == null) {
          context.log.warn(
              "Tried to setup a redirect for page at URL '${page.pagePath}' - but the page has no content. Therefore, no redirect will be created.");
          continue;
        }

        // Add a redirect tag to the original HTML.
        final originalHtml = page.destinationContent!;
        final redirectTags =
            '    <!-- Page redirect tags -->\n    <meta http-equiv="refresh" content="0; url=$basePath${page.pagePath}" />\n    <link rel="canonical" href="$basePath${page.pagePath}" />';
        final headRegExp = RegExp(r'<head>', caseSensitive: false);
        final headMatch = headRegExp.firstMatch(originalHtml);
        if (headMatch == null) {
          // TODO: deal with missing head tag.
          continue;
        }
        context.log.detail("HEAD match: ${headMatch.end}");
        final redirectPageHtml =
            "${originalHtml.substring(0, headMatch.end)}\n$redirectTags\n${originalHtml.substring(headMatch.end)}";

        final redirectPage = page.copy() //
          ..pagePath = redirect.startsWith("/") ? redirect.substring(1) : redirect
          ..destinationPath = redirectDestinationFilePath
          ..destinationContent = redirectPageHtml;

        context.pagesIndex.addPage(redirectPage);
      }
    }
  }

  /// Returns `true` if the given path is a valid redirect path, or `false`
  /// otherwise.
  ///
  /// Empty paths are invalid because they don't point anywhere.
  ///
  /// Absolute paths are invalid because this plugin doesn't have any
  /// control over the final base path of the website. E.g., accept
  /// `old/dir` but reject `/old/dir`.
  ///
  /// Full URLs (with a domain) are invalid because this plugin doesn't
  /// have any control over choosing a domain.
  bool _isValidRedirectPath(String redirect) =>
      redirect.isNotEmpty && !redirect.startsWith("/") && !_urlRegExp.hasMatch(redirect);

  FileRelativePath? _mapRedirectUrlToBuildFilePath(StaticShockPipelineContext context, String redirect) {
    if (path.extension(redirect).isEmpty) {
      // The redirect path is a directory, not a file. We will treat it as a pretty
      // URL with a corresponding index file.
      //
      // Examples:
      //  - path/to/directory
      //  - path/to/directory/
      //  - /path/to/directory
      //  - /path/to/directory/
      context.log.detail("This redirect is a directory");

      final directory = redirect.split("/").where((segment) => segment.isNotEmpty).join(path.separator);
      final destinationFilePath = FileRelativePath("$directory/", "index", "html");
      context.log.detail("Redirect destination path: ${destinationFilePath.value}");

      return destinationFilePath;
    } else {
      // The redirect path is a file, so we want to replicate the redirect path exactly.
      context.log.detail("This redirect is a file");

      final directory = path.dirname(redirect).split("/").where((segment) => segment.isNotEmpty).join(path.separator);
      final destinationFilePath = FileRelativePath(
        "$directory/",
        path.basenameWithoutExtension(redirect),
        path.extension(redirect).substring(1),
      );
      context.log.detail("Redirect destination path: ${destinationFilePath.value}");

      return destinationFilePath;
    }
  }
}

class BrokenLinkFinderFinisher implements Finisher {
  const BrokenLinkFinderFinisher({
    required this.shouldRunLinkVerification,
    this.reportBrokenLinksAsErrors = false,
  });

  /// Whether to run link verification or not.
  final bool shouldRunLinkVerification;

  /// Whether to report broken links as errors, rather than warnings.
  ///
  /// Errors are typically handled as build failures, whereas warnings still
  /// report a successful build.
  final bool reportBrokenLinksAsErrors;

  @override
  Future<void> execute(StaticShockPipelineContext context) async {
    if (!shouldRunLinkVerification) {
      context.log.info("Skipping link verification for this build");
      return;
    }

    context.log.info("Validating all external and internal links in the built website.");

    final linkFinder = HtmlLinkFinder();
    final urlValidator = UrlValidator();
    final thisSiteBaseUrl = context.dataIndex.inheritDataForPath(DirectoryRelativePath("/"))["baseUrl"] as String?;
    final thisSiteBaseUri = thisSiteBaseUrl != null && thisSiteBaseUrl.isNotEmpty //
        ? Uri.parse(thisSiteBaseUrl)
        : null;

    final checkedExternalUrls = <Uri>{};
    int badExternalUrlCount = 0;
    final checkedInternalUris = <Uri>{};
    int badInternalUriCount = 0;
    final errorLevel = reportBrokenLinksAsErrors ? StaticShockErrorLevel.error : StaticShockErrorLevel.warning;
    for (final page in context.pagesIndex.pages) {
      if (page.tags.contains("drafting")) {
        continue;
      }

      final links = linkFinder //
          .findAnchorLinks(page.destinationContent!)
          .normalizeUris();

      // Validate URLs that are expected to be live on the internet.
      final externalUrls = links.whereRemote(thisSiteBaseUri).removeAll(checkedExternalUrls).toList(growable: false);
      checkedExternalUrls.addAll(externalUrls);
      final badExternalUrls = await urlValidator.findDeadUrls(externalUrls);
      for (final badUrl in badExternalUrls) {
        context.errorLog
            .log(errorLevel, "Bad external URL found on page '${page.pagePath}' (${page.title}): '$badUrl'");
        badExternalUrlCount += 1;
      }

      // Validate URLs and paths within this website, which probably are not live yet.
      final internalUris = links
          .whereLocal(thisSiteBaseUri)
          .resolveRelative(page.pagePath!)
          .removeAll(checkedInternalUris)
          .toList(growable: true);
      checkedInternalUris.addAll(internalUris);
      for (final otherPage in context.pagesIndex.pages) {
        internalUris.removeWhere((internalUri) =>
            // Check for trailing and non-trailing "/", e.g., "/guides/getting-started"
            // and "/guides/getting-started/".
            otherPage.makeUrl(context.dataIndex.basePath)! == internalUri.path ||
            otherPage.makeUrl(context.dataIndex.basePath)! == "${internalUri.path}/");
      }
      final badInternalUris = internalUris;
      for (final badInternalUri in badInternalUris) {
        context.errorLog.log(
            errorLevel, "Bad internal URL/path found on page '${page.pagePath}' (${page.title}): '$badInternalUri'");
        badInternalUriCount += 1;
      }
    }

    if (badExternalUrlCount == 0 && badInternalUriCount == 0) {
      context.log.detail("All links look good!");
    } else {
      context.log.warn("Found $badExternalUrlCount bad external URLs, and $badInternalUriCount bad internal URIs.");
    }
  }
}

/// [Finisher] that finds every page in this build, ensure that no pages were lost from
/// the last build, and saves an updated page manifest for future build checks.
class FindMissingPagesFinisher implements Finisher {
  static const pageManifestCacheKey = "pages-manifest.json";

  FindMissingPagesFinisher({
    required this.cache,
    this.cacheUpdatePolicy = PageManifestUpdatePolicy.noUpdate,
    this.reportMissingPagesAtErrorLevel = StaticShockErrorLevel.warning,
    this.includeDraftPages = false,
  });

  /// The cache where the previous list of pages was stored, and where the
  /// new list will be stored.
  final StaticShockCache cache;

  /// The policy that determines whether the page cache is updated during this build.
  final PageManifestUpdatePolicy cacheUpdatePolicy;

  /// Whether the website build should fail if any of the pages from the existing cached list
  /// no longer exist in the current website build.
  final StaticShockErrorLevel reportMissingPagesAtErrorLevel;

  /// Whether to save page URLs for draft (not yet published) pages.
  final bool includeDraftPages;

  @override
  Future<void> execute(StaticShockPipelineContext context) async {
    context.log.info("Checking for any missing pages from the previous build");

    final currentBuildPages = _collectAllPagePaths(context);
    context.log.detail("Found ${currentBuildPages.length} pages in the current build.");

    final previousBuildPagesJson = await cache.loadJsonList(pageManifestCacheKey);
    final previousBuildPages = previousBuildPagesJson?.cast<String>().toSet();

    final missingPages = <String>{};
    if (previousBuildPages != null) {
      // We have a previous build to compare to. Find any missing pages.
      context.log.detail("Found ${previousBuildPages.length} pages in the previous build.");

      for (final existingPage in previousBuildPages) {
        if (!currentBuildPages.contains(existingPage)) {
          missingPages.add(existingPage);
        }
      }

      context.log.detail("Found ${missingPages.length} missing pages");
    } else {
      context.log.detail("No existing page manifest was found. Nothing to compare to.");
    }

    if (cacheUpdatePolicy == PageManifestUpdatePolicy.forceUpdate ||
        (cacheUpdatePolicy == PageManifestUpdatePolicy.updateIfNoMissingPages && missingPages.isEmpty)) {
      context.log.detail("Updating the page manifest based on the pages in the current build.");
      await cache.putJsonList(pageManifestCacheKey, currentBuildPages.toList(growable: false));
    } else {
      context.log.detail("Not updating page cache in this build.");
    }

    // Log missing pages (and maybe) fail the build.
    if (missingPages.isNotEmpty) {
      final message = [
        "Found ${missingPages.length} missing pages in the current build.",
        ...missingPages.map((path) => " • '$path'"),
      ].join("\n");

      context.errorLog.log(reportMissingPagesAtErrorLevel, message);
    }
  }

  Set<String> _collectAllPagePaths(StaticShockPipelineContext context) {
    return context.pagesIndex.pages //
        .where((page) => includeDraftPages ? true : !page.tags.contains("drafting"))
        // Note: These are page paths, not links, so we expect every page path
        // to define itself with an absolute path - no relative paths. Therefore,
        // we shouldn't need to do any relative path resolution here.
        .map((page) => page.pagePath!)
        .toSet();
  }
}

enum PageManifestUpdatePolicy {
  noUpdate,
  updateIfNoMissingPages,
  forceUpdate;
}

extension NormalizeUris on Iterable<Uri> {
  Iterable<Uri> normalizeUris() => map(_normalizeUri);

  Uri _normalizeUri(Uri uri) {
    late final Uri url;
    if (uri.host.isNotEmpty) {
      // This URI is a URL.
      url = uri;
    } else if (_looksLikeDomain(uri)) {
      final tryUrl = Uri.tryParse("https://${uri.path}");
      if (tryUrl == null || tryUrl.host.isEmpty) {
        // This is a path, e.g., "/guides/getting-started". There's nothing to
        // normalize for a path.
        return uri;
      }

      // This URI is a URL.
      url = tryUrl;
    } else {
      // This URI has no host and doesn't look like a domain. It must
      // be a path. There's nothing to normalize for a path.
      return uri;
    }

    // We have a URL. Restructure it so that all of our URLs are represented
    // in a comparable way.
    return url.replace(
      scheme: "https",
      host: uri.host.replaceFirst(RegExp(r'^www\.'), ""),
    );
  }

  bool _looksLikeDomain(Uri uri) {
    // No scheme or host, and path resembles a domain (e.g. www.flutter.dev)
    final path = uri.path;
    return !uri.hasScheme && //
        uri.host.isEmpty &&
        !path.startsWith('/') &&
        RegExp(r'^[^/\s]+\.[^/\s]+$').hasMatch(path);
  }
}

/// Inspects HTML and extracts all link [Uri]s that can be found.
class HtmlLinkFinder {
  static final _anchorRegExp = RegExp(r'<a\b[^>]*>(.*?)<\/a>', caseSensitive: false, dotAll: true);
  static final _urlFromAnchor = RegExp('href\\s*=\\s*["\\\']([^"\\\']+)["\\\']', caseSensitive: false);

  List<Uri> findAnchorLinks(String html) {
    final uris = <Uri>[];

    final anchors = _anchorRegExp.allMatches(html);
    for (final anchorMatch in anchors) {
      final anchor = anchorMatch.group(0);
      if (anchor == null) {
        continue;
      }

      final links = _urlFromAnchor.firstMatch(anchor)?.group(1);
      if (links != null && !links.startsWith("#")) {
        uris.add(Uri.parse(links));
      }
    }

    return uris;
  }
}

/// Validates given URLs, such as pinging the URL to see if it returns a good status code.
class UrlValidator {
  /// Pings each URL in [links] and returns all [Uri]s that fail the ping.
  Future<List<Uri>> findDeadUrls(List<Uri> links) async {
    final urls = links.where((link) => link.hasScheme);

    final badUrls = <Uri>[];
    final urlChecks = <Future<Object>>[
      for (final url in urls) //
        () async {
          try {
            return await get(url);
          } catch (exception) {
            return url;
          }
        }(),
    ];
    final responses = await Future.wait(urlChecks);
    for (final response in responses) {
      if (response is Uri) {
        // An exception was thrown when calling the URL. What was returned was
        // the URL so we can report it as bad.
        badUrls.add(response);
        continue;
      }

      if (response is! Response) {
        throw Exception("We expected an HTTP Response but got a ${response.runtimeType}");
      }
      if (200 <= response.statusCode && response.statusCode < 400) {
        // This URL is fine.
        continue;
      }

      badUrls.add(response.request!.url);
    }

    return badUrls;
  }
}

extension GroupRemoval on Iterable<Uri> {
  Iterable<Uri> removeAll(Iterable<Uri> blacklist) => whereNot((item) => blacklist.contains(item));
}

extension UriSelector on Iterable<Uri> {
  Iterable<Uri> whereLocal(Uri? thisSiteBaseUri) {
    return whereNot(_selectRemoteUrls(thisSiteBaseUri));
  }

  Iterable<Uri> resolveRelative(String currentPagePath) {
    return map((uri) {
      if (uri.path.startsWith("/")) {
        return uri;
      }

      if (currentPagePath.endsWith("/")) {
        return Uri.parse("$currentPagePath${uri.path}");
      } else {
        return Uri.parse("$currentPagePath/${uri.path}");
      }
    });
  }

  Iterable<Uri> whereRemote(Uri? thisSiteBaseUri) {
    return where(_selectRemoteUrls(thisSiteBaseUri));
  }

  bool Function(Uri) _selectRemoteUrls(Uri? thisSiteBaseUri) {
    return (link) {
      if (thisSiteBaseUri == null) {
        // We don't know the base URL, so we can't find URLs pointing to this
        // site. However, all paths implicitly point to this site. Select based
        // on path.

        if (link.host.isNotEmpty) {
          // This is a URL, we assume it's pointing somewhere else.
          return true;
        }

        if (_looksLikeDomain(link)) {
          final asUrl = Uri.tryParse("https://${link.path}");
          if (asUrl != null && asUrl.host.isNotEmpty) {
            // This is a URL without a scheme, e.g., "flutter.dev". We assume
            // it's pointing somewhere else.
            return true;
          }
        }

        // This is a path - no scheme, no host - it points somewhere within
        // this website.
        return false;
      }

      // At this point, we know the site base URI is non-null.
      //
      // Ensure the base URI is encoded as a URL so that we can correctly compare
      // URL components.
      final thisSiteBaseUrl = thisSiteBaseUri.host.isNotEmpty ? thisSiteBaseUri : Uri.parse("https://$thisSiteBaseUri");

      if (link.host.isNotEmpty && !_hasSameHost(link, thisSiteBaseUrl)) {
        // This link is a URL with a scheme and it points to some other website.
        return true;
      }

      if (_looksLikeDomain(link)) {
        final asUrl = Uri.tryParse("https://${link.path}");
        if (asUrl != null && asUrl.host.isNotEmpty && !_hasSameHost(asUrl, thisSiteBaseUrl)) {
          // This link is a URL without a scheme, e.g., "flutter.dev", and it points
          // to another website.
          return true;
        }
      }

      // This link is either a URL that points to this website, or an internal
      // page path.
      return false;
    };
  }

  bool _hasSameHost(Uri a, Uri b) {
    if (a.host.toLowerCase() == b.host.toLowerCase()) {
      return true;
    }

    // Handle case where one has "www" but the other doesn't.
    final findWWW = RegExp(r"www\.", caseSensitive: false);
    if (a.host.startsWith(findWWW)) {
      return a.host.substring(4) == b.host;
    } else if (b.host.startsWith(findWWW)) {
      return b.host.substring(4) == a.host;
    }

    return false;
  }

  bool _looksLikeDomain(Uri uri) {
    // No scheme or host, and path resembles a domain (e.g. www.flutter.dev)
    final path = uri.path;
    return !uri.hasScheme && //
        uri.host.isEmpty &&
        !path.startsWith('/') &&
        RegExp(r'^[^/\s]+\.[^/\s]+$').hasMatch(path);
  }
}
