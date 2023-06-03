import 'package:static_shock/static_shock.dart';

Future<void> main(List<String> arguments) async {
  // Configure the static website generator.
  final staticShock = _createSite();

  // Generate the static website.
  await staticShock.generateSite();
}

StaticShock _createSite() {
  return StaticShock(
    // Relative path to source files, which are copied or transformed.
    // This is where you place your Markdown, templates, images, Sass, etc.
    sourceDirectoryRelativePath: "website_source",

    // Relative path to where all the final files are copied or created.
    // This is what you deploy to your webserver.
    destinationDirectoryRelativePath: "website_build",

    // Plugins that add specialized behavior to the static website build process.
    plugins: {
      // Static Shock comes with a Sass plugin out-of-the-box.
      const StaticShockSass(),
    },
  );
}
