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
        authToken: Platform.environment["ghub_doc_website_token"],
      ),
    )
    ..loadData(DataLoader.fromFunction((context) async {
      return {
        "algolia_app_id": Platform.environment["static_shock_algolia_app_id"] ?? "",
        "algolia_api_key": Platform.environment["static_shock_algolia_api_key"] ?? "",
      };
    }));

  // Generate the static website.
  await staticShock.generateSite();
}
