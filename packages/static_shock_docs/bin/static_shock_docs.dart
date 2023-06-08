import 'package:static_shock/static_shock.dart';

Future<void> main(List<String> arguments) async {
  // Configure the static website generator.
  final staticShock = StaticShock(
    sourceDirectoryRelativePath: "website_source",
    destinationDirectoryRelativePath: "website_build",
  )
    // ..pick(DirectoryPicker.parse("fonts"))
    ..pick(DirectoryPicker.parse("images"))
    ..pick(DirectoryPicker.parse("_styles"))
    ..plugin(const StaticShockSass());

  // Generate the static website.
  await staticShock.generateSite();
}
