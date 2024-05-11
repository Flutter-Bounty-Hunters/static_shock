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
