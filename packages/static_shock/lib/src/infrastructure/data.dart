import 'package:yaml/yaml.dart';

/// Merges the given [newData] into [destination], replacing any [YamlMap]s along the way with
/// standard [Map]s so that we can retain map typing as `Map<String, dynamic>`.
Map deepMergeMap(Map destination, Map? newData) {
  if (newData == null) {
    return destination;
  }

  for (final entry in newData.entries) {
    final k = entry.key;
    final v = entry.value;

    if (!destination.containsKey(k)) {
      if (v is YamlMap || v is Map) {
        // We don't want to store any YamlMaps because their Map interface isn't typed. Therefore,
        // if we treat our maps as Map<String, dynamic> it will throw exception due to YamlMap's
        // implied type of Map<dynamic, dynamic>.
        //
        // We also don't want to copy Maps because we don't want other branches of
        // the data tree altering this one.
        destination[k] = <String, dynamic>{};
        deepMergeMap(destination[k], Map.fromEntries(v.entries));
        continue;
      }

      if (v is YamlList || v is List) {
        // We don't want to store any YamlLists because they're unmodifiable.
        //
        // We also don't want to copy Lists because we don't want other branches of
        // the data tree altering this one.
        //
        // We need to cascade this copying of Maps and Lists for every item in the list.
        destination[k] = deepMergeList([], v);
        continue;
      }

      // Direct copy from new data to destination.
      destination[k] = v;
      continue;
    }

    if (destination[k] is Map) {
      // Continue merging maps deeper.
      deepMergeMap(destination[k], Map.of(newData[k]));
      continue;
    }

    if (destination[k] is List && newData[k] is List) {
      // Append the new list to the existing list.
      deepMergeList(destination[k], newData[k] as List);
      continue;
    }

    // Overwrite existing value.
    destination[k] = newData[k];
  }

  return destination;
}

List deepMergeList(List destination, List source) {
  return destination
    ..addAll(
      source.map((listItem) {
        if (listItem is Map) {
          return deepMergeMap({}, listItem);
        } else if (listItem is List) {
          return deepMergeList([], listItem);
        } else {
          return listItem;
        }
      }),
    );
}
