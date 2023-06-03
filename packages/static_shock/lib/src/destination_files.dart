import 'dart:io';

/// A file in the final static website build set.
class DestinationFile {
  const DestinationFile(this.file, this.subPath);

  /// The [File] for the given destination file.
  final File file;

  String get path => file.path;

  /// A partial file path, which begins at the root destination directory.
  ///
  /// "/Users/admin/documents/my_project/website_build/my_file.html" becomes
  /// "/my_file.html".
  final String subPath;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DestinationFile && runtimeType == other.runtimeType && subPath == other.subPath;

  @override
  int get hashCode => subPath.hashCode;
}
