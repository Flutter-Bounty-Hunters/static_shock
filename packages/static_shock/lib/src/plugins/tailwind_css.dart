import 'dart:io';

import 'package:static_shock/src/finishers.dart';
import 'package:static_shock/src/pipeline.dart';
import 'package:static_shock/src/static_shock.dart';

/// [StaticShockPlugin] that runs Tailwind CSS against the project's source files.
///
/// This plugin depends on the presence of the Tailwind binary tool. By default,
/// that tool is expected to be named `tailwindcss` and to sit at the root of the
/// website project directory.
///
/// Learn more about the standalone Tailwind tool: https://tailwindcss.com/blog/standalone-cli
class TailwindPlugin implements StaticShockPlugin {
  const TailwindPlugin({
    this.tailwindPath = "./tailwindcss",
    required this.input,
    required this.output,
  });

  /// Path and name of the Tailwind executable.
  final String tailwindPath;

  /// File path to the Tailwind input file, which contains Tailwind code.
  ///
  /// Unlike typical CSS, there only needs to be a single input file for
  /// Tailwind, and that file is mostly (or entirely) a configuration of
  /// Tailwind, itself. For example, the following might be used as the
  /// content of a file at `/styles/tailwind.css`.
  ///
  /// ```
  /// @tailwind base;
  /// @tailwind components;
  /// @tailwind utilities;
  /// ```
  final String input;

  /// File path to the desired Tailwind output file, where Tailwind
  /// should write the compiled CSS.
  ///
  /// In general, this output file holds all styles for your website.
  /// You might choose to place it at `/styles/styles.css` in the
  /// build output directory. Any HTML file that wants to use these
  /// styles need to reference this output stylesheet file location.
  ///
  /// ```
  ///<link href="styles/styles.css" rel="stylesheet">
  /// ```
  final String output;

  @override
  void configure(StaticShockPipeline pipeline, StaticShockPipelineContext context) {
    pipeline.finish(_TailwindGenerator(
      tailwindPath: tailwindPath,
      input: input,
      output: output,
    ));
  }
}

class _TailwindGenerator implements Finisher {
  const _TailwindGenerator({
    required this.tailwindPath,
    required this.input,
    required this.output,
  });

  /// Path and name of the Tailwind executable.
  final String tailwindPath;

  /// File path to the input file, which contains Tailwind code.
  final String input;

  /// File path to the output file, where Tailwind should write the compiled CSS.
  final String output;

  @override
  Future<void> execute(StaticShockPipelineContext context) async {
    try {
      context.log.info("Generating Tailwind CSS");
      context.log.detail("Tailwind executable path: $tailwindPath");
      context.log.detail("Tailwind input file: $input");
      final result = await Process.run(
        tailwindPath,
        ["-i", input, "-o", output],
      );
      if (result.exitCode != 0) {
        context.log.warn("Failed to run Tailwind CSS compilation - exist code: ${result.exitCode}");
        return;
      }

      context.log.detail("Successfully generated Tailwind CSS: $output");
    } catch (exception, stacktrace) {
      context.log.warn("Failed to run Tailwind CSS compilation!");
      context.log.err("$exception");
      context.log.err("$stacktrace");
    }
  }
}
