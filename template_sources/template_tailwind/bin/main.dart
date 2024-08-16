import 'dart:io';

import 'package:static_shock/static_shock.dart';

Future<void> main(List<String> arguments) async {
  var operatingSystem = Platform.operatingSystem;
  String tailwindPath = switch (operatingSystem) {
    "macos" => "./bin/macos/tailwindcss",
    "linux" => "./bin/linux/tailwindcss",
    "windows" => "./bin/windows/tailwindcss.exe",
    _ => throw UnsupportedError(
        "Unsupported operating system: $operatingSystem",
      ),
  };

  // Configure the static website generator.
  final staticShock = StaticShock()
    // Here, you can directly hook into the StaticShock pipeline. For example,
    // you can copy an "images" directory from the source set to build set:
    ..pick(ExtensionPicker("html"))
    ..pick(DirectoryPicker.parse("images"))
    // All 3rd party behavior is added through plugins, even the behavior
    // shipped with Static Shock.
    ..plugin(const MarkdownPlugin())
    ..plugin(const JinjaPlugin())
    ..plugin(const PrettyUrlsPlugin())
    ..plugin(const RedirectsPlugin())
    ..plugin(const SassPlugin())
    ..plugin(DraftingPlugin(
      showDrafts: arguments.contains("preview"),
    ))
    ..plugin(TailwindPlugin(
      input: "source/styles/tailwind.css",
      output: "build/styles/tailwind.css",
      tailwindPath: tailwindPath,
    ));

  // Generate the static website.
  await staticShock.generateSite();
}
