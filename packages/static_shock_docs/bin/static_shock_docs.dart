import 'package:static_shock/static_shock.dart';

Future<void> main(List<String> arguments) async {
  // Configure the static website generator.
  final staticShock = StaticShock()
    ..pick(DirectoryPicker.parse("images"))
    ..plugin(const MarkdownPlugin())
    ..plugin(const JinjaPlugin())
    ..plugin(const PrettyUrlsPlugin())
    ..plugin(const SassPlugin())
    ..plugin(const PubPackagePlugin({
      "static_shock",
      "static_shock_cli",
    }));

  // Generate the static website.
  await staticShock.generateSite();
}
