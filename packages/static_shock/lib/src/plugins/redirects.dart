import 'dart:async';

import 'package:path/path.dart' as path;
import 'package:static_shock/src/cache.dart';
import 'package:static_shock/src/files.dart';
import 'package:static_shock/src/finishers.dart';
import 'package:static_shock/src/pages.dart';
import 'package:static_shock/src/pipeline.dart';
import 'package:static_shock/src/static_shock.dart';
import 'package:yaml/yaml.dart';

/// A [StaticShockPlugin] that configures HTML redirects for pages that want redirects.
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
class RedirectsPlugin implements StaticShockPlugin {
  const RedirectsPlugin();

  @override
  final id = "io.staticshock.redirects";

  @override
  FutureOr<void> configure(
    StaticShockPipeline pipeline,
    StaticShockPipelineContext context,
    StaticShockCache pluginCache,
  ) {
    pipeline.finish(
      RedirectsFinisher(
        basePath: context.dataIndex.getAtPath(["basePath"]) as String,
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
