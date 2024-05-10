import 'dart:convert';
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
Future<void> indexSourceData(StaticShockPipelineContext context, SourceFiles sourceFiles) async {
  context.log.info("⚡ Indexing local data files into the global data index");

  final dataIndex = context.dataIndex;
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

    context.log.detail("Indexing data from: ${dataFile.path}");
    final yamlData = loadYaml(text) as YamlMap;

    final data = _deepMergeMap(<String, dynamic>{}, yamlData);
    if (data["tags"] is String) {
      data["tags"] = [(data["tags"] as String)];
    }

    dataIndex.mergeAtPath(DirectoryRelativePath(directory.subPath), data.cast());
  }
}

/// A hierarchical index of data.
///
/// A [DataIndex] stores arbitrary blobs of data, indexed by a hierarchical path.
///
/// For example, a [DataIndex] might contain the following structure:
///
/// "/": {
///   "siteName": "My Site",
///   "domain": "www.mysite.com",
/// }
///
/// "/articles": {
///   "tags": ["article"],
///   "authors": [{
///     "name": "John",
///     "avatarUrl": "mysite.com/avatars/john.png",
///   },{
///     "name": "Jane",
///     "avatarUrl": "mysite.com/avatars/jane.png",
///   }],
/// }
///
/// "/articles/news": {
///   "lastUpdated": "June 13, 2019",
/// }
///
/// The overall structure of the index is a tree, where the tree is defined by paths, e.g.,
/// "/", "/articles", "/articles/news". In that tree, each path (or node) then contains an entire
/// map of data, which itself might have multiple levels of data.
///
/// The purpose of this hierarchical structure is to make it easy for a page to inherit data blobs
/// from higher level directories. For example, every article page can inherit the data that's
/// defined at "/articles".
class DataIndex {
  DataIndex() : _data = _DataNode("/");

  final _DataNode _data;

  // FIXME: The implementation returns data that sits outside the given path, e.g., will return "github/users" data even if "github/repositories" is requested.
  /// Returns all data from the global index that should be available to a page at the given [path].
  ///
  /// The global data index is a tree. The data that's made available to a given [path] includes all
  /// data higher in the tree along that path, as well as the data at the exact path. Data further down
  /// the [path] branch is not included, nor is data that's stored on different branches higher up in
  /// the tree.
  ///
  /// For example, assume the path "/articles/news"...
  ///
  /// Included data:
  ///  - "/articles"
  ///  - "/articles/news"
  ///
  /// Excluded data:
  ///  - "/about-us"
  ///  - "/forum"
  ///  - "/articles/news/today"
  Map<String, Object> inheritDataForPath(RelativePath path) {
    print("Inheriting data at path: $path");
    final data = Map<String, Object>.from(_data.data);

    var node = _data;
    final directories = List.from(path.directories);
    print("Path segments: $directories");
    while (directories.isNotEmpty && node.children[directories.first] != null) {
      final directory = directories.removeAt(0);
      node = node.children[directory]!;

      print("Indexed data at '$directory':");
      print(const JsonEncoder.withIndent("  ").convert(node.data));
      print("");

      // data.addEntries(node.data.entries);
      _deepMergeMap(data, node.data);

      print("Available children within the data tree: ${node.children}");
      print("");
    }

    print("Full merged data:");
    print(const JsonEncoder.withIndent("  ").convert(data));

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
    // Create any missing nodes from the root to the given `path`.
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

    // Now that we've found (or created) the desired node, merge the given data with
    // whatever data already exists at that node.
    print("Merging new data at path: $path");
    print("");
    print("Existing data:");
    print(const JsonEncoder.withIndent("  ").convert(node.data));
    print("");
    print("New data:");
    print(const JsonEncoder.withIndent("  ").convert(data));
    print("");

    _deepMergeMap(node.data, data);
  }
}

/// Merges the given [newData] into [destination], replacing any [YamlMap]s along the way with
/// standard [Map]s so that we can retain map typing as `Map<String, dynamic>`.
Map _deepMergeMap(Map destination, Map? newData) {
  if (newData == null) {
    return destination;
  }

  newData.forEach((k, v) {
    if (!destination.containsKey(k)) {
      if (v is YamlMap) {
        // We don't want to store any YamlMaps because their Map interface isn't typed. Therefore,
        // if we treat our maps as Map<String, dynamic> it will throw exception due to YamlMap's
        // implied type of Map<dynamic, dynamic>.
        destination[k] = <String, dynamic>{};
        _deepMergeMap(destination[k], Map.fromEntries(v.entries));
        return;
      }

      // Direct copy from new data to destination.
      destination[k] = v;
      return;
    }

    if (destination[k] is Map) {
      // Continue merging maps deeper.
      _deepMergeMap(destination[k], newData[k]);
      return;
    }

    if (destination[k] is List && newData[k] is List) {
      // Append the new list to the existing list.
      (destination[k] as List).addAll(newData[k] as List);
      return;
    }

    // Overwrite existing value.
    destination[k] = newData[k];
  });

  return destination;
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
