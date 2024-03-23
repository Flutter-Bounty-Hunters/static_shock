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
    ..plugin(const SassPlugin())
    ..plugin(const DraftingPlugin())
    ..plugin(const PubPackagePlugin({
      "static_shock",
      "static_shock_cli",
    }));

  // Generate the static website.
  await staticShock.generateSite();
}
