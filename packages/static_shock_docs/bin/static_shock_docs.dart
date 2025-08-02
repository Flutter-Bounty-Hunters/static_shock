import 'dart:io';

import 'package:static_shock/static_shock.dart';

Future<void> main(List<String> arguments) async {
  // Configure the static website generator.
  final staticShock = StaticShock(
    site: SiteMetadata(
      rootUrl: 'https://staticshock.io',
      basePath: '/',
    ),
    cliArguments: arguments,
  )
    ..loadTheme(
      Theme.fromGit(
        url: "https://github.com/flutter-bounty-hunters/fbh_docs_theme",
        path: "theme",
      ),
    )
    ..pick(DirectoryPicker.parse("images"))
    ..plugin(const MarkdownPlugin())
    ..plugin(JinjaPlugin(
      filters: [
        menuItemsWherePageExistsFilterBuilder,
      ],
    ))
    ..plugin(const PrettyUrlsPlugin())
    ..plugin(const LinksPlugin())
    ..plugin(const SassPlugin())
    ..plugin(const DraftingPlugin())
    ..plugin(const PubPackagePlugin())
    ..plugin(WebsiteScreenshotsPlugin(
      selector: (context) {
        final rootData = context.dataIndex.inheritDataForPath(DirectoryRelativePath("/"));
        final showcase = rootData['showcase'];
        if (showcase == null) {
          return {};
        }
        if (showcase is! Map<String, dynamic>) {
          return {};
        }

        final screenshots = <WebsiteScreenshot>{};
        final marketingScreenshotsYaml = showcase['screenshots']['marketing'] as List<dynamic>;
        final docsScreenshotsYaml = showcase['screenshots']['docs'] as List<dynamic>;
        final screenshotsYaml = List.from(marketingScreenshotsYaml)..addAll(docsScreenshotsYaml);

        for (final screenshotYaml in screenshotsYaml) {
          screenshots.add(
            WebsiteScreenshot(
              id: screenshotYaml['id'],
              url: Uri.parse(screenshotYaml['url']),
              output: FileRelativePath.parse(screenshotYaml['output']),
            ),
          );
        }

        return screenshots;
      },
      outputWidth: 256,
    ))
    ..plugin(const RssPlugin(
      site: RssSiteConfiguration(
        title: "Static Shock Docs",
        description: "Documentation website for the static_shock package.",
        homePageUrl: "https://staticshock.io",
      ),
    ))
    ..plugin(
      GitHubContributorsPlugin(
        // GitHub allows a certain number of API requests per hour. If you're below
        // that number, you don't need to worry about an API token. If you need to exceed
        // that request limit, you can provide your own GitHub API token as an environment
        // variable, as shown here.
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
