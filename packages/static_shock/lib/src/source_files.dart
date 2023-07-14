import 'dart:io';
import 'package:path/path.dart' as dart_path;
import 'package:static_shock/static_shock.dart';

class SourceFiles {
  SourceFiles({
    required this.directory,
    required Set<String> excludedPaths,
  }) : _excludedPaths = excludedPaths;

  final Directory directory;
  // TODO: get rid of this explicit set of excluded paths in favor of filters passed to the iterators
  final Set<String> _excludedPaths;

  /// Returns all file system entities in the source directory.
  Iterable<SourceEntity> sourceEntities([SourceFilter? filter]) {
    return directory
        .listSync(recursive: true) //
        .map(
          (entity) => entity is Directory
              ? SourceDirectory(
                  entity,
                  entity.path.substring(directory.path.length),
                )
              : SourceFile(
                  entity as File,
                  entity.path.substring(directory.path.length),
                ),
        )
        .where((sourceEntity) => !_isExcluded(sourceEntity.subPath))
        .where((file) => filter?.passesFilter(file) ?? true);
  }

  /// Returns all directories in the source directory, except excluded paths.
  Iterable<SourceDirectory> sourceDirectories([SourceFilter? filter]) {
    final rootDirectory = SourceDirectory(directory, "/");

    return directory
        .listSync(recursive: true) //
        .whereType<Directory>()
        .map((subDirectory) => SourceDirectory(
              subDirectory,
              subDirectory.path.substring(directory.path.length),
            ))
        .where((directory) => !_isExcluded(directory.subPath))
        .where((file) => filter?.passesFilter(file) ?? true)
        .toList()
      ..insert(0, rootDirectory);
  }

  /// Returns all files in the source directory, except excluded paths.
  Iterable<SourceFile> sourceFiles([SourceFilter? filter]) {
    return directory
        .listSync(recursive: true) //
        .whereType<File>() //
        .map((file) => SourceFile(
              file,
              file.path.substring(directory.path.length),
            )) //
        .where((file) => !_isExcluded(file.subPath))
        .where((file) => filter?.passesFilter(file) ?? true);
  }

  Iterable<SourceFile> layouts() {
    final layoutsDirectory = directory.subDir(["_includes", "layouts"]);
    if (!layoutsDirectory.existsSync()) {
      return [];
    }

    return layoutsDirectory //
        .listSync(recursive: true)
        .whereType<File>()
        .map((file) => SourceFile(
              file,
              file.path.substring(directory.path.length),
            ));
  }

  Iterable<SourceFile> components() {
    final componentsDirectory = directory.subDir(["_includes", "components"]);
    if (!componentsDirectory.existsSync()) {
      return [];
    }

    return componentsDirectory //
        .listSync(recursive: true)
        .whereType<File>()
        .map((file) => SourceFile(
              file,
              file.path.substring(directory.path.length),
            ));
  }

  bool _isExcluded(String subPath) {
    for (final excludedPath in _excludedPaths) {
      if (subPath.startsWith(excludedPath)) {
        return true;
      }
    }
    return false;
  }
}

abstract class SourceEntity {
  const SourceEntity(this.entity, this.subPath);

  /// The generic file system entity referenced by this [SourceEntity].
  ///
  /// If you know that you're working with a [SourceDirectory], or a [SourceFile], consider
  /// accessing their `directory` and `file` properties, respectively, instead of
  /// accessing this [entity], so that you gain the maximum possible information about
  /// the entity.
  final FileSystemEntity entity;

  /// A partial source directory path, which begins at the root source directory.
  ///
  /// "/Users/admin/documents/my_project/source/my_dir/" becomes
  /// "/my_dir".
  final String subPath;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceDirectory && runtimeType == other.runtimeType && subPath == other.subPath;

  @override
  int get hashCode => subPath.hashCode;
}

class SourceDirectory extends SourceEntity {
  const SourceDirectory(this.directory, String subPath) : super(directory, subPath);

  /// The [Directory] for the given source file.
  final Directory directory;

  String get path => directory.path;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && other is SourceDirectory && runtimeType == other.runtimeType && directory == other.directory;

  @override
  int get hashCode => super.hashCode ^ directory.hashCode;
}

class SourceFile extends SourceEntity {
  const SourceFile(this.file, String subPath) : super(file, subPath);

  /// The [File] for the given source file.
  final File file;

  String get path => file.path;

  String get extension => dart_path.extension(path);

  @override
  String toString() => "[SourceFile] - '$subPath' - $file";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && other is SourceFile && runtimeType == other.runtimeType && file == other.file;

  @override
  int get hashCode => super.hashCode ^ file.hashCode;
}

/// A filter that prevents visiting files that fail some condition.
abstract class SourceFilter {
  /// Returns `true` to let a visitor receive the [sourceEntity], or `false` to
  /// prevent a visitor from receiving the [sourceEntity].
  bool passesFilter(SourceEntity sourceEntity);
}

class CombineFilters implements SourceFilter {
  const CombineFilters(this._filters);

  final Set<SourceFilter> _filters;

  @override
  bool passesFilter(SourceEntity sourceEntity) {
    for (final filter in _filters) {
      if (!filter.passesFilter(sourceEntity)) {
        return false;
      }
    }
    return true;
  }
}

/// Excludes any path which contains a directory or file name that begins with
/// the given prefixes.
///
/// Example exclusions (assuming a "_" prefix):
///  * /_a/b/c.md
///  * /a/_b/c.md
///  * /a/b/_c.md
class ExcludePrefixes implements SourceFilter {
  const ExcludePrefixes(
    this._prefixes,
  );

  final Set<String> _prefixes;

  @override
  bool passesFilter(SourceEntity sourceEntity) {
    for (final prefix in _prefixes) {
      if (sourceEntity.subPath.split(Platform.pathSeparator).any((element) => element.startsWith(prefix))) {
        return false;
      }
    }

    return true;
  }
}

/// A [SourceFilter] that filters out all files that don't have one of the
/// given [extensions], i.e., only files with the given [extensions] are pushed
/// through the filter.
///
/// All directories are excluded by this filter.
class IncludeExtensions implements SourceFilter {
  const IncludeExtensions(
    this._extensions,
  );

  final Set<String> _extensions;

  @override
  bool passesFilter(SourceEntity sourceEntity) {
    if (sourceEntity is! SourceFile) {
      // Only files have extensions. Reject this entity.
      return false;
    }

    for (final extension in _extensions) {
      if (sourceEntity.extension == extension) {
        return true;
      }
    }

    return false;
  }
}

/// A [SourceFilter] that filters out all files that have one of the given [extensions].
///
/// Example: If this filter is given `["md"]` as an extension list, then `my_post.md`
/// would be excluded by this filter.
///
/// No directories are excluded by this filter.
class ExcludeExtensions implements SourceFilter {
  const ExcludeExtensions(
    this._extensions,
  );

  final Set<String> _extensions;

  @override
  bool passesFilter(SourceEntity sourceEntity) {
    if (sourceEntity is! SourceFile) {
      // Only files have extensions. Let directories through.
      return true;
    }

    for (final extension in _extensions) {
      if (sourceEntity.extension == extension) {
        return false;
      }
    }

    return true;
  }
}
