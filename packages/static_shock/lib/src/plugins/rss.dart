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
    this.title,
    this.description,
    this.homePageUrl,
    this.language = "en-us",
    this.pageToRssItemMapper = defaultPageToRssItemMapper,
  });

  final String? title;
  final String? description;
  final String? homePageUrl;
  final String? language;
  final PageToRssItemMapper pageToRssItemMapper;

  @override
  FutureOr<void> configure(StaticShockPipeline pipeline, StaticShockPipelineContext context) {
    pipeline.finish(_RssFinisher(
      title: title,
      description: description,
      homePageUrl: homePageUrl,
      language: language,
      pageToRssItemMapper: pageToRssItemMapper,
    ));
  }
}

RssItem defaultPageToRssItemMapper(Page page) {
  return RssItem(
    guid: page.url,
    link: page.url,
    title: page.title,
    description: page.data["description"],
    pubDate: page.data["publishDate"],
    author: page.data["author"],
  );
}

typedef PageToRssItemMapper = RssItem Function(Page page);

class _RssFinisher implements Finisher {
  static final _rssDateFormat = DateFormat("dd MMM yyyy");

  const _RssFinisher({
    this.title,
    this.description,
    this.homePageUrl,
    this.language = "en-us",
    required this.pageToRssItemMapper,
  });

  final String? title;
  final String? description;
  final String? homePageUrl;
  final String? language;
  final PageToRssItemMapper pageToRssItemMapper;

  @override
  FutureOr<void> execute(StaticShockPipelineContext context) {
    final feed = RssFeed(
      title: title,
      description: description,
      link: homePageUrl,
      language: language,
      // Note: Technically, the pubDate should reflect the date of the latest content
      // change. We don't have a good way to know when that was, so we assume the user
      // is generating this file because content was changed.
      pubDate: _rssDateFormat.format(DateTime.now()),
      lastBuildDate: _rssDateFormat.format(DateTime.now()),
      docs: "http://blogs.law.harvard.edu/tech/rss",
      items: [
        for (final page in context.pagesIndex.pages) //
          pageToRssItemMapper(page),
      ],
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
}
