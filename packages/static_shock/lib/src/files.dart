import 'dart:io';
import 'package:path/path.dart' as fs_path;

abstract class Picker {
  bool shouldPick(FileRelativePath path);
}

abstract class Excluder {
  bool shouldExclude(FileRelativePath path);
}

class DirectoryPicker implements Picker {
  DirectoryPicker.parse(String path) : _pathMatcher = DirectoryRelativePath(path);

  const DirectoryPicker(this._pathMatcher);

  final RelativePath _pathMatcher;

  @override
  bool shouldPick(FileRelativePath path) => path.value.startsWith(_pathMatcher.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DirectoryPicker && runtimeType == other.runtimeType && _pathMatcher == other._pathMatcher;

  @override
  int get hashCode => _pathMatcher.hashCode;
}

class FilePicker implements Picker {
  FilePicker.parse(String path) : _pathMatcher = FileRelativePath.parse(path);

  const FilePicker(this._pathMatcher);

  final RelativePath _pathMatcher;

  @override
  bool shouldPick(FileRelativePath path) => path.value.endsWith(_pathMatcher.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilePicker && runtimeType == other.runtimeType && _pathMatcher == other._pathMatcher;

  @override
  int get hashCode => _pathMatcher.hashCode;
}

class ExtensionPicker implements Picker {
  const ExtensionPicker(this._extension);

  final String _extension;

  @override
  bool shouldPick(FileRelativePath path) => path.extension == _extension;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtensionPicker && runtimeType == other.runtimeType && _extension == other._extension;

  @override
  int get hashCode => _extension.hashCode;
}

class FilePrefixExcluder implements Excluder {
  const FilePrefixExcluder(this._prefix);

  final String _prefix;

  @override
  bool shouldExclude(FileRelativePath path) => path.filename.startsWith(_prefix);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilePrefixExcluder && runtimeType == other.runtimeType && _prefix == other._prefix;

  @override
  int get hashCode => _prefix.hashCode;
}

class RemoteInclude {
  const RemoteInclude({
    required this.url,
    required this.name,
    this.extension = "jinja",
  });

  final String url;
  final String name;
  final String extension;

  FileRelativePath get simulatedLayoutPath => FileRelativePath("/_includes/layouts/", name, extension);

  FileRelativePath get simulatedComponentPath => FileRelativePath("/_includes/components/", name, extension);
}

class RemoteFile {
  const RemoteFile({
    required this.url,
    required this.simulatedFilePath,
  });

  final String url;
  final FileRelativePath simulatedFilePath;
}

abstract class RelativePath {
  const RelativePath(this.value);

  final String value;

  /// The list of directory names that comprise this path.
  List<String> get directories;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RelativePath && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

class DirectoryRelativePath extends RelativePath {
  const DirectoryRelativePath(super.value);

  @override
  List<String> get directories => value.split(Platform.pathSeparator).where((item) => item.isNotEmpty).toList();
}

class FileRelativePath implements RelativePath {
  factory FileRelativePath.parse(String path) {
    String directory = fs_path.dirname(path);
    if (directory.startsWith(Platform.pathSeparator)) {
      // Remove the leading "/" so that we don't interpret this directory
      // as the root.
      directory = directory.substring(1);
    }
    if (!directory.endsWith(Platform.pathSeparator) && directory.isNotEmpty) {
      // Add a trailing "/" so that we can easily combine the directory with the file name. Only
      // add the trailing "/" if the directory isn't empty. An empty directory refers to the root
      // of the source directory.
      directory = directory + Platform.pathSeparator;
    }

    String extension = fs_path.extension(path);
    if (extension.isNotEmpty) {
      // Remove the leading ".".
      extension = extension.substring(1);
    }

    return FileRelativePath(
      directory,
      fs_path.basenameWithoutExtension(path),
      extension,
    );
  }

  const FileRelativePath(
    this.directoryPath,
    this.filename,
    this.extension,
  );

  @override
  String get value => extension.isNotEmpty ? "$directoryPath$filename.$extension" : "$directoryPath$filename";

  final String directoryPath;
  final String filename;
  final String extension;

  DirectoryRelativePath get containingDirectory => DirectoryRelativePath(directoryPath);

  @override
  List<String> get directories => directoryPath.split(Platform.pathSeparator).where((item) => item.isNotEmpty).toList();

  FileRelativePath copyWith({
    String? directoryPath,
    String? filename,
    String? extension,
  }) {
    return FileRelativePath(
      directoryPath ?? this.directoryPath,
      filename ?? this.filename,
      extension ?? this.extension,
    );
  }

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileRelativePath &&
          runtimeType == other.runtimeType &&
          directoryPath == other.directoryPath &&
          filename == other.filename &&
          extension == other.extension;

  @override
  int get hashCode => directoryPath.hashCode ^ filename.hashCode ^ extension.hashCode;
}

extension SubPath on Directory {
  Directory subDir(List<String> segments) {
    return Directory(fs_path.joinAll([path, ...segments]));
  }

  File descFile(List<String> segments) {
    return File(fs_path.joinAll([path, ...segments]));
  }
}
