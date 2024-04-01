import 'dart:io';

import 'package:static_shock/src/files.dart';
import 'package:static_shock/src/source_files.dart';
import 'package:yaml/yaml.dart';

/// Loads data that might be needed by one or more pages.
///
/// All [DataLoader]s run before any assets or pages are loaded.
abstract class DataLoader {
  /// Loads data from any desired data source and returns it.
  ///
  /// The returned data will be made available to all pages.
  Future<Map<String, Object>> loadData();
}

/// Inspects all [sourceFiles] for files called `_data.yaml`, accumulates the content of those
/// files into a [DataIndex], and returns that [DataIndex].
Future<DataIndex> indexSourceData(SourceFiles sourceFiles) async {
  final dataIndex = DataIndex();
  for (final directory in sourceFiles.sourceDirectories()) {
    final dataFile = File("${directory.directory.path}${Platform.pathSeparator}_data.yaml");
    if (!dataFile.existsSync()) {
      continue;
    }

    final data = loadYaml(dataFile.readAsStringSync());

    dataIndex.mergeAtPath(DirectoryRelativePath(directory.subPath), Map<String, Object>.from(data));
  }

  return dataIndex;
}

/// A hierarchical index of data.
class DataIndex {
  DataIndex() : _data = _DataNode("/");

  final _DataNode _data;

  Map<String, Object> getForPath(RelativePath path) {
    final data = Map<String, Object>.from(_data.data);

    var node = _data;
    final directories = path.directories;
    while (directories.isNotEmpty && node.children[directories.first] != null) {
      node = node.children[directories.first]!;
      data.addEntries(node.data.entries);
    }

    return data;
  }

  void mergeAtPath(RelativePath path, Map<String, Object> data) {
    // TODO: how do we handle root-level data?
    _DataNode node = _data;
    final directories = path.directories;
    for (final directory in directories) {
      var childNode = node.children[directory];
      if (childNode == null) {
        childNode = _DataNode(directory);
        node.children[directory] = childNode;
      }
      node = childNode;
    }

    node.data.addEntries(data.entries);
  }
}

class _DataNode {
  _DataNode(
    this.directory, [
    Map<String, Object>? data,
    Map<String, _DataNode>? children,
  ])  : data = data ?? {},
        children = children ?? {};

  final String directory;
  final Map<String, Object> data;
  final Map<String, _DataNode> children;
}
