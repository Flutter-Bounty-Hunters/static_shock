import 'dart:async';

import 'package:dart_rss/dart_rss.dart';
import 'package:intl/intl.dart';
import 'package:static_shock/src/assets.dart';
import 'package:static_shock/src/files.dart';
import 'package:static_shock/src/finishers.dart';
import 'package:static_shock/src/pages.dart';
import 'package:static_shock/src/pipeline.dart';
import 'package:static_shock/src/static_shock.dart';

class RssPlugin implements StaticShockPlugin {
  const RssPlugin({
    required this.site,
    this.pageToRssItemMapper = defaultPageToRssItemMapper,
  });

  final RssSiteConfiguration site;
  final PageToRssItemMapper pageToRssItemMapper;

  @override
  FutureOr<void> configure(StaticShockPipeline pipeline, StaticShockPipelineContext context) {
    pipeline.finish(_RssFinisher(
      site: site,
      pageToRssItemMapper: pageToRssItemMapper,
    ));
  }
}

class RssSiteConfiguration {
  const RssSiteConfiguration({
    this.title,
    this.description,
    required this.homePageUrl,
    this.language = "en-us",
    this.includePagesByDefault = true,
  });

  final String? title;
  final String? description;
  final String homePageUrl;
  final String? language;

  /// Is `true` if all [Page]s should be included in the RSS feed, except the
  /// pages that explicitly opt out, or `false` if all [Page]s should be
  /// excluded from the RSS feed, except the pages that explicitly opt in.
  final bool includePagesByDefault;

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
    description: page.data["description"],
    pubDate: page.data["publishDate"],
    author: page.data["author"],
  );
}

/// Maps a Static Shock [page] to an [RssItem], to be placed in an RSS feed.
typedef PageToRssItemMapper = RssItem? Function(RssSiteConfiguration config, Page page);

/// The standard date format for dates within an RSS feed.
final rssDateFormat = DateFormat("dd MMM yyyy");

class _RssFinisher implements Finisher {
  const _RssFinisher({
    required this.site,
    required this.pageToRssItemMapper,
  });

  final RssSiteConfiguration site;
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
        destinationPath: FileRelativePath("", "feed", "rss"),
        destinationContent: AssetContent.text(
          feed.toXmlDocument().toXmlString(pretty: true, indent: "  "),
        ),
      ),
    );
  }

  bool _selectPagesToPublish(Page page) {
    if (site.includePagesByDefault && page.data['rss'] == false) {
      // This page opted out of RSS inclusion. Ignore it.
      return false;
    }
    if (!site.includePagesByDefault && page.data['rss'] != true) {
      // This page didn't opt in to RSS inclusion. Ignore it.
      return false;
    }

    // Add this page to the RSS feed.
    return true;
  }
}
