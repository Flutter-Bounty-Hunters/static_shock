import 'package:static_shock/static_shock.dart';

Future<void> main(List<String> arguments) async {
  // Configure the static website generator.
  final staticShock = StaticShock()
    // Here, you can directly hook into the StaticShock pipeline. For example,
    // you can copy an "images" directory from the source set to build set:
    ..pick(ExtensionPicker("html"))
    ..pick(ExtensionPicker("jpeg"))
    ..pick(DirectoryPicker.parse("images"))
    // All 3rd party behavior is added through plugins, even the behavior
    // shipped with Static Shock.
    ..plugin(const MarkdownPlugin())
    ..plugin(const JinjaPlugin())
    ..plugin(const PrettyUrlsPlugin())
    ..plugin(const LinksPlugin())
    ..plugin(const SassPlugin())
    ..plugin(DraftingPlugin(
      showDrafts: arguments.contains("preview"),
    ))
    ..plugin(RssPlugin(
      site: RssSiteConfiguration(
        title: "Better Living",
        description: "Articles about living a better life",
        homePageUrl: "",
      ),
      pageToRssItemMapper: (RssSiteConfiguration config, Page page) {
        return defaultPageToRssItemMapper(config, page)?.copyWith(
          author: page.data["author"],
        );
      },
    ));

  // Generate the static website.
  await staticShock.generateSite();
}
