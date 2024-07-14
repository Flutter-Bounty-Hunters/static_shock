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

/// A group of remote includes (layouts and components), readable via HTTP, all of
/// which have the same base URL.
///
/// The URL of each of include is assembled by taking the [urlTemplate] and replacing
/// the [templatePattern] with every file name in [files].
///
/// Example:
///  * `urlTemplate`: `https://github.com/my-repo/main/some/path/_includes/layouts/$?raw=true`
///  * `templatePattern`: `$`
///  * `files`: `post.jinja`, `page.jinja`, `header.jinja`
class HttpIncludeGroup with Iterable<RemoteInclude> implements RemoteIncludeSource {
  factory HttpIncludeGroup.fromUrlTemplate(
    String urlTemplate, {
    String templatePattern = "\$",
    required Set<String> files,
  }) {
    final remoteIncludes = <RemoteInclude>{};

    for (final fileName in files) {
      final nameParts = fileName.split(".");
      if (nameParts.length != 2) {
        // TODO: write to log that we can't process this file name
        continue;
      }
      if (nameParts.first.isEmpty || nameParts.last.isEmpty) {
        // TODO: write to log that we can't process this file name
        continue;
      }

      final url = urlTemplate.replaceFirst(templatePattern, fileName);
      remoteIncludes.add(
        RemoteInclude(
          url: url,
          name: nameParts.first,
          extension: nameParts.last,
        ),
      );
    }

    return HttpIncludeGroup(remoteIncludes);
  }

  const HttpIncludeGroup(this._files);

  final Set<RemoteInclude> _files;

  @override
  Iterator<RemoteInclude> get iterator => _files.iterator;
}

/// A single remote file, available at the given [url], which is either a layout file
/// or a component file.
///
/// This class doesn't know whether the file is a layout or a component. It's the
/// caller's job to maintain this knowledge. The caller should access the
/// [simulatedLayoutPath] or [simulatedComponentPath] based on its knowledge of the
/// content in this file.
///
/// The given [name] and [extension] apply to the final file that's written to the
/// build directory. These properties have no impact on the [url]. The [url] should
/// resolve to the desired file without any further modifications to the URL.
class RemoteInclude implements RemoteIncludeSource {
  const RemoteInclude({
    required this.url,
    required this.name,
    this.extension = "jinja",
  });

  final String url;
  final String name;
  final String extension;

  /// A simulated file path that pretends this remote layout came from the
  /// source directory at the given relative path.
  ///
  /// This path allows the Static Shock pipeline to treat this remote layout as
  /// if it were a local layout.
  FileRelativePath get simulatedLayoutPath => FileRelativePath("/_includes/layouts/", name, extension);

  /// A simulated file path that pretends this remote component came from the
  /// source directory at the given relative path.
  ///
  /// This path allows the Static Shock pipeline to treat this remote component as
  /// if it were a local component.
  FileRelativePath get simulatedComponentPath => FileRelativePath("/_includes/components/", name, extension);
}

/// A source of one or more remote include files (e.g., layouts and components).
///
/// This is a marker interface, which allows completely unrelated remote include
/// data structures to be combined together into collections.
///
/// See also:
///  * [HttpIncludeGroup] - a group of includes at a similar URL that are all mapped to local build paths.
///  * [RemoteInclude] - a single remote include that's mapped to either a layout or component.
abstract interface class RemoteIncludeSource {
  // Marker interface.
}

/// A group of remote files, readable via HTTP, all which have the same base URL.
///
/// The URL of each of file is assembled by taking the [urlTemplate] and replacing
/// the [templatePattern] with every file name in [files].
///
/// Example:
///  * `urlTemplate`: `https://github.com/my-repo/main/some/path/favicon$?raw=true`
///  * `templatePattern`: `$`
///  * `buildDirectory`: `images/favicon/`
///  * `files`: `favicon.ico`, `favicon-16x16.png`, `favicon-32x32.png`
class HttpFileGroup with Iterable<RemoteFile> implements RemoteFileSource {
  factory HttpFileGroup.fromUrlTemplate(
    String urlTemplate, {
    String templatePattern = "\$",
    required String buildDirectory,
    required Set<String> files,
  }) {
    final remoteFiles = <RemoteFile>{};

    for (final fileName in files) {
      final nameParts = fileName.split(".");
      if (nameParts.length != 2) {
        // TODO: write to log that we can't process this file name
        continue;
      }
      if (nameParts.first.isEmpty || nameParts.last.isEmpty) {
        // TODO: write to log that we can't process this file name
        continue;
      }

      final url = urlTemplate.replaceFirst(templatePattern, fileName);
      remoteFiles.add(
        RemoteFile(
          url: url,
          buildPath: FileRelativePath(buildDirectory, nameParts.first, nameParts.last),
        ),
      );
    }

    return HttpFileGroup(remoteFiles);
  }

  const HttpFileGroup(this._files);

  final Set<RemoteFile> _files;

  @override
  Iterator<RemoteFile> get iterator => _files.iterator;
}

/// A single remote file, available at the [url], which will be written to the build
/// directory at the given [buildPath].
class RemoteFile implements RemoteFileSource {
  const RemoteFile({
    required this.url,
    required this.buildPath,
  });

  final String url;
  final FileRelativePath buildPath;
}

/// A source of one or more remote files.
///
/// This is a marker interface, which allows completely unrelated remote file
/// data structures to be combined together into collections.
///
/// See also:
///  * [HttpFileGroup] - a group of files at a similar URL that are all mapped to local build paths.
///  * [RemoteFile] - a single remote file that's mapped to a local build path.
abstract interface class RemoteFileSource {
  // Marker interface.
}
