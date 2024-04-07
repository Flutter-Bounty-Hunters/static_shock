---
title: Create RSS Feed
tags: publishing
---
RSS feeds are a way for visitors to get notified of new posts, articles, or guides that you add
to your website.

An RSS feed is an XML document, which describes your website, and lists individual content items
that are available on your website. For example, here's part of the RSS feed for the 
[Flutter Bounty Hunters blog](https://blog.flutterbountyhunters.com).

```xml
<rss version="2.0">
  <channel>
    <title>Blog | Flutter Bounty Hunters</title>
    <description>The Flutter Bounty Hunters blog.</description>
    <link>https://blog.flutterbountyhunters.com</link>
    <language>en-us</language>
    <pubDate>07 Apr 2024</pubDate>
    <lastBuildDate>07 Apr 2024</lastBuildDate>
    <docs>http://blogs.law.harvard.edu/tech/rss</docs>
    <item>
      <title>How to make money building open source Flutter and Dart packages</title>
      <link>https://blog.flutterbountyhunters.com/how-to-make-money-building-open-source-flutter-and-dart-packages/</link>
      <description>You can make money writing open source code, but you need to run it like a business.</description>
      <pubDate>2023-06-17</pubDate>
      <guid>/how-to-make-money-building-open-source-flutter-and-dart-packages/</guid>
      <author>Matt Carroll</author>
    </item>
  </channel>
</rss>
```

## The RSS Plugin
To generate an RSS feed for your Static Shock website, use the `RssPlugin`.

```dart
Future<void> main(List<String> arguments) async {
  // Configure the static website generator.
  final staticShock = StaticShock()
    // ...
    ..plugin(RssPlugin(
      site: RssSiteConfiguration(
        title: "Blog | Flutter Bounty Hunters",
        description: "The Flutter Bounty Hunters blog.",
        homePageUrl: "https://blog.flutterbountyhunters.com",
      ),
    ));

  // Generate the static website.
  await staticShock.generateSite();
}
```

The `RssSiteConfiguration` provides top-level website information for the `<channel>` description
in the RSS feed.

By default, every `Page` in a Static Shock website is encoded as an `RssItem` in the generated RSS
feed. The default mapping from `page` to `RssItem` is as follows:

 * Page "title" -> RssItem "title".
 * Page "description" -> RssItem "description".
 * Page "publicationDate" -> RssItem "pubDate".
 * RssSiteConfiguration "homePageUrl" + Page "url" -> RssItem "link".
 * Page "url" -> RssItem "guid".
 * Page "author" -> RssItem "author".

This mapping can be changed by further configuring the `RssPlugin`.

### Change the output location and file name
By default, the `RssPlugin` writes the RSS feed to `/rss_feed.xml`. You can specify a different
output location by configuring the `RssPlugin`:

```dart
RssPlugin(
  site: RssSiteConfiguration(
    // ...
    // Write to "/feed.xml" instead of "/rss_feed.xml".
    rssFeedPath: FileRelativePath("", "feed", "xml"),
  ),
);
```

### Change the Page to RssItem mapping
Different websites use `Page` metadata in different ways. A website might choose to use a property
called "summary" instead of "description", or might choose to encode an entire data structure
under "author" instead of just a `String`. In these cases, the `RssPlugin` must be instructed how
to map `Page`s to `RssItem`s.

The Flutter Bounty Hunters blog includes multiple pieces of info under "author":

```yaml
author:
  name: Matt Carroll
  role: Chief
  avatarUrl: https://secure.gravatar.com/avatar/2b519036dc508c11b0db3463fffbd8ff
```

Given this structure for "author", the default author mapping in the `RssPlugin` will fail because
the `RssPlugin` expects a `String`, not a YAML data structure. To work around this, the Flutter
Bounty Hunters blog provides a custom mapper function, which uses the default mapper function, and
then alters the "author" property.

```dart
RssPlugin(
  site: RssSiteConfiguration(
    // ...
  ),
  pageToRssItemMapper: (RssSiteConfiguration config, Page page) {
    // Run the default mapper, then update the "author" property of the RssItem
    // to use the author's name from the page data.
    return defaultPageToRssItemMapper(config, page)?.copyWith(
      author: page.data["author"]?["name"],
    );
  },
);
```

### Opt-in and opt-out
By default all `Page`s are included in the RSS feed. There are two ways to opt in and opt out.

First, decide whether you want all `Page`s **included** by default, or whether you want all `Page`s
**excluded** by default.

```dart
RssPlugin(
  site: RssSiteConfiguration(
    // ...
    // Include all pages by default...
    includePagesByDefault: true,
    // or exclude all pages by default.
    includePagesByDefault: false,
  ),
);
```

Once you've decided whether to include or exclude all `Page`s by default, you can then include or
exclude specific `Page`s, as needed. The `RssPlugin` looks for a `Page` property called `rss`, which
can be set to `true` to include the page, `false` to exclude the page, or not included at all to
use the default action.

```markdown
---
title: My Post
rss: false
---
# This post won't be included in the RSS feed
```

```html
<!--
rss: false
-->
<html>
  <!-- This HTML page won't be included in the RSS feed -->
</html>
```