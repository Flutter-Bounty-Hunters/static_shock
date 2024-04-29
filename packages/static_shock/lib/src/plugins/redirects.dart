import 'dart:async';

import 'package:path/path.dart' as path;
import 'package:static_shock/src/files.dart';
import 'package:static_shock/src/finishers.dart';
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
  FutureOr<void> configure(StaticShockPipeline pipeline, StaticShockPipelineContext context) {
    pipeline.finish(
      RedirectsFinisher(),
    );
  }
}

/// [Finisher] that copies pages with redirects and adds appropriate HTML for the redirect.
///
/// To setup redirects without a server, each page with 1+ listed redirect is copied. The copy
/// has its URL set to the `redirectFrom` value
class RedirectsFinisher implements Finisher {
  static final _urlRegExp = RegExp(r'^((?:https?://)?[^./]+(?:\.[^./]+)+(?:/.*)?)$');

  @override
  void execute(StaticShockPipelineContext context) {
    final pagesWithRedirects = context.pagesIndex.pages.where(
      (page) => page.data['redirectFrom'] != null,
    );
    if (pagesWithRedirects.isEmpty) {
      return;
    }

    for (final page in pagesWithRedirects) {
      // Parse the 1+ redirects from YAML front-matter.
      final redirects = <String>{};
      final redirectsValue = page.data['redirectFrom'];
      if (redirectsValue is YamlList) {
        redirects.addAll(redirectsValue.value.cast());
      } else if (redirectsValue is String) {
        if (redirectsValue.isEmpty) {
          // The user added a redirect key, but didn't include a value.
          context.log.warn(
            "Page ${page.url} has a 'redirectsValue' field, but no corresponding value. To setup a redirect, please add a redirect URL.",
          );
          continue;
        }

        if (_urlRegExp.hasMatch(redirectsValue)) {
          // The user specified a full URL, which isn't appropriate for a redirect value.
          // For example, if the user entered "mysite.com/old/dir" the redirect URL can't be
          // honored because Static Shock only has control over the path within a site, not
          // the domain where the site lives.
          continue;
        }

        redirects.add(redirectsValue);
      }

      context.log.detail("Setting up redirects for page: ${page.url}");
      context.log.detail("Redirecting from:");
      for (final redirect in redirects) {
        context.log.detail(" - $redirect");
        final redirectDestinationFilePath = _mapRedirectUrlToBuildFilePath(context, redirect);
        if (redirectDestinationFilePath == null) {
          context.log.warn("Failed to convert a 'redirectFrom' URL path to a file path. URL path: '$redirect'");
          continue;
        }
        if (page.url == null) {
          context.log.warn(
              "Tried to setup a direct for page '${page.title}' - but the page has no URL so we don't know where to redirect TO.");
          continue;
        }
        if (page.destinationContent == null) {
          context.log.warn(
              "Tried to setup a redirect for page at URL '${page.url}' - but the page has no content. Therefore, no redirect will be created.");
          continue;
        }

        // Add a redirect tag to the original HTML.
        final originalHtml = page.destinationContent!;
        final redirectTags =
            '    <!-- Page redirect tags -->\n    <meta http-equiv="refresh" content="0; url=/${page.url}" />\n    <link rel="canonical" href="/${page.url}" />';
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
          ..url = redirect
          ..destinationPath = redirectDestinationFilePath
          ..destinationContent = redirectPageHtml;

        context.pagesIndex.addPage(redirectPage);
      }
    }
  }

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
