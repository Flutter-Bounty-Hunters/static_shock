import 'package:static_shock/static_shock.dart';

Future<void> main(List<String> arguments) async {
  // Configure the static website generator.
  final staticShock = StaticShock(
    // Relative path to source files, which are copied or transformed.
    // This is where you place your Markdown, templates, images, Sass, etc.
    sourceDirectoryRelativePath: "source",

    // Relative path to where all the final files are copied or created.
    // This is what you deploy to your webserver.
    destinationDirectoryRelativePath: "build",
  )
    // Plugins that add specialized behavior to the static website build process.
    // Static Shock comes with a Sass plugin out-of-the-box.
    ..plugin(const StaticShockSass());

  // Generate the static website.
  await staticShock.generateSite();
}
