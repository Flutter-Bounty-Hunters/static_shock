import 'dart:async';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:static_shock/static_shock.dart';
import 'package:path/path.dart' as path;
import 'package:sass/sass.dart' as sass;

final _log = Logger(level: Level.verbose);

class StaticShockSass implements StaticShockPlugin {
  const StaticShockSass();

  @override
  FutureOr<void> applyTo(StaticShock shock) async {
    _log.info("⚡ Compiling Sass to CSS");

    final sassDirectory = shock.sourceFiles.directory.subDir(["_styles"]);
    if (!sassDirectory.existsSync()) {
      _log.warn("Sass directory doesn't exist");
      return;
    }

    final cssDirectory = shock.destinationDir.subDir(["styles"]);
    for (final entity in sassDirectory.listSync()) {
      final sassFile = entity as File;
      final cssCompilation = sass.compileToResult(sassFile.path);

      final sassFileName = path.basenameWithoutExtension(sassFile.path);
      final cssFile = cssDirectory.descFile(["$sassFileName.css"]);
      cssFile.createSync(recursive: true);
      cssFile.writeAsStringSync(cssCompilation.css);

      _log.detail("Compiled '${sassFile.path}' -> '${cssFile.path}'");
    }
  }
}
