import 'dart:io';

import 'package:static_shock/static_shock.dart';

Future<void> main(List<String> arguments) async {
  // Configure the static website generator.
  final staticShock = StaticShock()
    ..pick(DirectoryPicker.parse("images"))
    ..plugin(const MarkdownPlugin())
    ..plugin(JinjaPlugin(
      filters: [
        menuItemsWherePageExistsFilterBuilder,
      ],
    ))
    ..plugin(const PrettyUrlsPlugin())
    ..plugin(const RedirectsPlugin())
    ..plugin(const SassPlugin())
    ..plugin(DraftingPlugin(
      showDrafts: arguments.contains("preview"),
    ))
    ..plugin(const PubPackagePlugin())
    ..plugin(WebsiteScreenshotsPlugin({
      WebsiteScreenshot(
        "staticshock_io",
        Uri.parse("https://staticshock.io"),
        FileRelativePath("images/screenshots/", "staticshock_io", "png"),
      ),
      WebsiteScreenshot(
        "superdeclarative_com",
        Uri.parse("https://superdeclarative.com"),
        FileRelativePath("images/screenshots/", "superdeclarative_com", "png"),
      ),
      WebsiteScreenshot(
        "flutterbountyhunters_com",
        Uri.parse("https://flutterbountyhunters.com"),
        FileRelativePath("images/screenshots/", "flutterbountyhunters_com", "png"),
      ),
      WebsiteScreenshot(
        "blog_flutterbountyhunters_com",
        Uri.parse("https://blog.flutterbountyhunters.com"),
        FileRelativePath("images/screenshots/", "blog_flutterbountyhunters_com", "png"),
      ),
      WebsiteScreenshot(
        "flutterarbiter_com",
        Uri.parse("https://flutterarbiter.com"),
        FileRelativePath("images/screenshots/", "flutterarbiter_com", "png"),
      ),
      WebsiteScreenshot(
        "flutterspaces_com",
        Uri.parse("https://flutterspaces.com"),
        FileRelativePath("images/screenshots/", "flutterspaces_com", "png"),
      ),
      WebsiteScreenshot(
        "fluttershaders_com",
        Uri.parse("https://fluttershaders.com"),
        FileRelativePath("images/screenshots/", "fluttershaders_com", "png"),
      ),
      WebsiteScreenshot(
        "flutter_test_robots",
        Uri.parse("https://flutter-bounty-hunters.github.io/flutter_test_robots/"),
        FileRelativePath("images/screenshots/", "docs_flutter_test_robots", "png"),
      ),
      WebsiteScreenshot(
        "ffmpeg_cli",
        Uri.parse("https://flutter-bounty-hunters.github.io/ffmpeg_cli/"),
        FileRelativePath("images/screenshots/", "docs_ffmpeg_cli", "png"),
      ),
    }))
    ..plugin(const RssPlugin(
      site: RssSiteConfiguration(
        title: "Static Shock Docs",
        description: "Documentation website for the static_shock package.",
        homePageUrl: "https://staticshock.io",
      ),
    ))
    ..plugin(
      GitHubContributorsPlugin(
        authToken: Platform.environment["GHUB_DOC_WEBSITE_TOKEN"],
      ),
    )
    ..loadData(DataLoader.fromFunction((context) async {
      return {
        "algolia_app_id": Platform.environment["STATIC_SHOCK_ALGOLIA_APP_ID"] ?? "",
        "algolia_api_key": Platform.environment["STATIC_SHOCK_ALGOLIA_API_KEY"] ?? "",
      };
    }));

  // Generate the static website.
  await staticShock.generateSite();
}
