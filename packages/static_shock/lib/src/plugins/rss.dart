import 'dart:async';

import 'package:dart_rss/dart_rss.dart';
import 'package:intl/intl.dart';
import 'package:static_shock/src/assets.dart';
import 'package:static_shock/src/cache.dart';
import 'package:static_shock/src/files.dart';
import 'package:static_shock/src/finishers.dart';
import 'package:static_shock/src/pages.dart';
import 'package:static_shock/src/pipeline.dart';
import 'package:static_shock/src/static_shock.dart';

/// Plugin for generating RSS feeds.
///
/// An RSS feed is an XML file. By default, this plugin writes the RSS feeds to `/rss_feed.xml`.
///
/// An RSS feed includes information about both the overall website, as well as individual
/// content items within the website, e.g., articles.
///
/// The RSS feed's site-level information is pulled from the provided [site] data structure.
///
/// By default, all `Page`s are given an `item` entry in the RSS feed. You can globally
/// include or exclude all `Page`s with [includePagesByDefault]. You can include or
/// exclude individual `Page`s by setting the `rss` property to `true` or `false` for
/// specific `Page`s.
///
/// To change the name and/or location of the final RSS feed file, use [rssFeedPath].
class RssPlugin implements StaticShockPlugin {
  const RssPlugin({
    required this.site,
    this.rssFeedPath = const FileRelativePath("", "rss_feed", "xml"),
    this.includePagesByDefault = true,
    this.pageToRssItemMapper = defaultPageToRssItemMapper,
  });

  @override
  final id = "io.staticshock.rss";

  /// Top-level website information for the `<channel>` configuration.
  final RssSiteConfiguration site;

  /// The name and location of the generated RSS feed file.
  final FileRelativePath rssFeedPath;

  /// Set to `true` if all [Page]s should be included in the RSS feed, except the
  /// pages that explicitly opt out, or `false` if all [Page]s should be
  /// excluded from the RSS feed, except the pages that explicitly opt in.
  final bool includePagesByDefault;

  /// Maps individual [Page]s to RSS `<item>`s, which are placed within the `<channel>`.
  ///
  /// A default mapper is included, so this property only needs to be set if the default
  /// mapper isn't sufficient for your use-case.
  final PageToRssItemMapper pageToRssItemMapper;

  @override
  FutureOr<void> configure(
    StaticShockPipeline pipeline,
    StaticShockPipelineContext context,
    StaticShockCache pluginCache,
  ) {
    pipeline.finish(_RssFinisher(
      site: site,
      rssFeedPath: rssFeedPath,
      includePagesByDefault: includePagesByDefault,
      pageToRssItemMapper: pageToRssItemMapper,
    ));
  }
}

/// Configures top-level website info for the [RssPlugin].
class RssSiteConfiguration {
  const RssSiteConfiguration({
    this.title,
    this.description,
    required this.homePageUrl,
    this.language = "en-us",
  });

  final String? title;
  final String? description;
  final String homePageUrl;
  final String? language;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RssSiteConfiguration &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          description == other.description &&
          homePageUrl == other.homePageUrl &&
          language == other.language;

  @override
  int get hashCode => title.hashCode ^ description.hashCode ^ homePageUrl.hashCode ^ language.hashCode;
}

/// The default [PageToRssItemMapper] used by the [RssPlugin].
RssItem? defaultPageToRssItemMapper(RssSiteConfiguration config, Page page) {
  if (page.url == null) {
    // This page isn't going to be built because it has no destination. Ignore it.
    return null;
  }

  // Note: The `page.url` has no leading "/". We need to add that leading "/" so
  // that the url can be appended to the website base URL, and also to clarify in
  // the guid that this URL path is based on the site root.
  String urlPath = "/${page.url!}";
  if (urlPath.endsWith("index.html")) {
    // The name "index.html" is redundant. E.g., "/index.html" can be represented as
    // "/", which is shorter and probably more canonical among web development.
    urlPath = urlPath.substring(0, urlPath.length - "index.html".length);
  }

  return RssItem(
    guid: urlPath,
    link: "${config.homePageUrl}$urlPath",
    title: page.title,
    description: page.data["description"] is String ? page.data["description"] : null,
    pubDate: page.data["publishDate"] is String ? page.data["publishDate"] : null,
    author: page.data["author"] is String ? page.data["author"] : null,
  );
}

/// Maps a Static Shock [page] to an [RssItem], to be placed in an RSS feed.
typedef PageToRssItemMapper = RssItem? Function(RssSiteConfiguration config, Page page);

/// The standard date format for dates within an RSS feed.
final rssDateFormat = DateFormat("dd MMM yyyy");

class _RssFinisher implements Finisher {
  const _RssFinisher({
    required this.site,
    required this.rssFeedPath,
    required this.includePagesByDefault,
    required this.pageToRssItemMapper,
  });

  final RssSiteConfiguration site;

  final FileRelativePath rssFeedPath;

  /// Is `true` if all [Page]s should be included in the RSS feed, except the
  /// pages that explicitly opt out, or `false` if all [Page]s should be
  /// excluded from the RSS feed, except the pages that explicitly opt in.
  final bool includePagesByDefault;

  final PageToRssItemMapper pageToRssItemMapper;

  @override
  FutureOr<void> execute(StaticShockPipelineContext context) {
    final feed = RssFeed(
      title: site.title,
      description: site.description,
      link: site.homePageUrl,
      language: site.language,
      // Note: Technically, the pubDate should reflect the date of the latest content
      // change. We don't have a good way to know when that was, so we assume the user
      // is generating this file because content was changed.
      pubDate: rssDateFormat.format(DateTime.now()),
      lastBuildDate: rssDateFormat.format(DateTime.now()),
      docs: "http://blogs.law.harvard.edu/tech/rss",
      items: context.pagesIndex.pages //
          .where(_selectPagesToPublish)
          .map((page) => pageToRssItemMapper(site, page))
          .where((item) => item != null)
          .toList(growable: false)
          .cast(),
    );

    context.addAsset(
      Asset(
        destinationPath: rssFeedPath,
        destinationContent: AssetContent.text(
          feed.toXmlDocument().toXmlString(pretty: true, indent: "  "),
        ),
      ),
    );
  }

  bool _selectPagesToPublish(Page page) {
    if (includePagesByDefault && page.data['rss'] == false) {
      // This page opted out of RSS inclusion. Ignore it.
      return false;
    }
    if (!includePagesByDefault && page.data['rss'] != true) {
      // This page didn't opt in to RSS inclusion. Ignore it.
      return false;
    }

    // Add this page to the RSS feed.
    return true;
  }
}
