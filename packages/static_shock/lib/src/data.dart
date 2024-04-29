import 'dart:io';

import 'package:static_shock/src/files.dart';
import 'package:static_shock/src/pipeline.dart';
import 'package:static_shock/src/source_files.dart';
import 'package:yaml/yaml.dart';

/// Loads data that might be needed by one or more pages.
///
/// All [DataLoader]s run before any assets or pages are loaded.
abstract class DataLoader {
  /// Loads data from any desired data source and returns it.
  ///
  /// The returned data will be made available to all pages.
  Future<Map<String, Object>> loadData(StaticShockPipelineContext context);
}

/// Inspects all [sourceFiles] for files called `_data.yaml`, accumulates the content of those
/// files into a [DataIndex], and returns that [DataIndex].
Future<void> indexSourceData(DataIndex dataIndex, SourceFiles sourceFiles) async {
  for (final directory in sourceFiles.sourceDirectories()) {
    final dataFile = File("${directory.directory.path}${Platform.pathSeparator}_data.yaml");
    if (!dataFile.existsSync()) {
      continue;
    }

    final text = dataFile.readAsStringSync();
    if (text.trim().isEmpty) {
      // The file is empty. Ignore it.
      continue;
    }

    final data = loadYaml(text);
    dataIndex.mergeAtPath(DirectoryRelativePath(directory.subPath), Map<String, Object>.from(data));
  }
}

/// A hierarchical index of data.
class DataIndex {
  DataIndex() : _data = _DataNode("/");

  final _DataNode _data;

  // FIXME: Document the exact intended purpose for this method. The implementation is unclear.
  // FIXME: The implementation seems to return data even when the full `path` can't be matched, is that intentional?
  // FIXME: The implementation returns data that sits outside the given path, e.g., will return "github/users" data even if "github/repositories" is requested.
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

  /// Returns the data subtree that begins at the given [path], or `null` if no data subtree
  /// exists at the given [path].
  Object? getAtPath(List<String> path) {
    Map<String, dynamic> dataSubtree = _data.data;
    final searchPath = List.from(path);

    while (searchPath.length > 1 && dataSubtree[searchPath.first] != null) {
      if (dataSubtree[searchPath.first] is Map<String, dynamic>) {
        dataSubtree = dataSubtree[searchPath.first] as Map<String, dynamic>;
      }
      if (dataSubtree[searchPath.first] is YamlMap) {
        dataSubtree = Map.fromEntries((dataSubtree[searchPath.first] as YamlMap)
            .entries
            .map((yamlEntry) => MapEntry<String, dynamic>(yamlEntry.key as String, yamlEntry.value)));
      }

      searchPath.removeAt(0);
    }

    if (searchPath.length > 1) {
      // We didn't match all the path segments to existing data. Return nothing.
      return null;
    }

    // We mapped every desired level of the path. The current node holds the
    // data we want to return.
    final finalSegment = searchPath.first;
    return dataSubtree[finalSegment];
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
