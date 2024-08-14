import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:yaml/yaml.dart' as yaml;

/// File-system cache, which retains data between builds so that expensive
/// tasks aren't repeated, unnecessarily.
///
/// During development, a rebuild runs after every source code change. This means
/// a rebuild every few seconds. At that build rate, it becomes impractical to
/// repeatedly run expensive tasks, such as the following:
///
///  * Load data from web services.
///  * Take screenshots of webpages.
///  * Generate artwork.
///
/// Each [StaticShockCache] points to a different directory to avoid cached file
/// collisions. For example, Static Shock might provide different [StaticShockCache]s
/// to each plugin, and yet another cache to the application, itself. As a result,
/// each plugin is prevented from accessing cached files from other plugins, and the
/// application is unable to access any plugin cached filed.
class StaticShockCache {
  const StaticShockCache(this._directory);

  final Directory _directory;

  /// Returns `true` if this cache contains content for the given [id].
  ///
  /// Clients are expected to know the type of the cached data, which
  /// can be accessed with [loadPlainText], [loadJsonObject], [loadJsonList],
  /// [loadYaml], or [loadBinary].
  Future<bool> contains(String id) async {
    _ensureInitialized();
    _ensureValidId(id);

    final cacheFile = _getFileForId(id);
    return await cacheFile.exists();
  }

  /// Stores the given [text] in this cache, mapped to the given [id].
  Future<void> putPlainText(String id, String text) async {
    _ensureInitialized();
    _ensureValidId(id);

    await _writeTextToFile(id, text);
  }

  /// Loads the data for the given [id] and interprets that data plain text.
  Future<String?> loadPlainText(String id) async {
    _ensureInitialized();
    _ensureValidId(id);

    return await _loadTextFromFile(id);
  }

  /// Stores the given [json] object in this cache, mapped to the given [id].
  Future<void> putJsonObject(String id, Map<String, dynamic> json) async {
    _ensureInitialized();
    _ensureValidId(id);

    final jsonText = JsonEncoder().convert(json);
    await _writeTextToFile(id, jsonText);
  }

  /// Loads the data for the given [id] and interprets that data as a JSON object.
  Future<Map<String, dynamic>?> loadJsonObject(String id) async {
    _ensureInitialized();
    _ensureValidId(id);

    final jsonText = await _loadTextFromFile(id);
    if (jsonText == null || jsonText.isEmpty) {
      return null;
    }

    return JsonDecoder().convert(jsonText) as Map<String, dynamic>?;
  }

  /// Stores the given [json] list in this cache, mapped to the given [id].
  Future<void> putJsonList(String id, List<dynamic> json) async {
    _ensureInitialized();
    _ensureValidId(id);

    final jsonText = JsonEncoder().convert(json);
    await _writeTextToFile(id, jsonText);
  }

  /// Loads the data for the given [id] and interprets that data as a JSON list.
  Future<List<dynamic>?> loadJsonList(String id) async {
    _ensureInitialized();
    _ensureValidId(id);

    final jsonText = await _loadTextFromFile(id);
    if (jsonText == null || jsonText.isEmpty) {
      return null;
    }

    return JsonDecoder().convert(jsonText) as List<dynamic>?;
  }

  /// Stores the given [yaml] in this cache, mapped to the given [id].
  Future<void> putYaml(String id, yaml.YamlDocument yaml) async {
    _ensureInitialized();
    _ensureValidId(id);

    await _writeTextToFile(id, yaml.toString());
  }

  /// Loads the data for the given [id] and interprets that data as YAML.
  ///
  /// The return type is `dynamic` because the `yaml` package also declares
  /// a return type of `dynamic` from `loadYaml`. The return type is expected
  /// to be either a [yaml.YamlNode], or a [yaml.YamlScalar], or `null` if
  /// no YAML data exists.
  Future<dynamic> loadYaml(String id) async {
    _ensureInitialized();
    _ensureValidId(id);

    final yamlText = await _loadTextFromFile(id);
    if (yamlText == null) {
      return null;
    }

    return yaml.loadYaml(yamlText);
  }

  /// Stores the given [binary] in this cache, mapped to the given [id].
  Future<void> putBinary(String id, Uint8List binary) async {
    _ensureInitialized();
    _ensureValidId(id);

    await _writeBinaryToFile(id, binary);
  }

  /// Loads the binary data for the given [id] and interprets that data as binary.
  Future<Uint8List?> loadBinary(String id) async {
    _ensureInitialized();
    _ensureValidId(id);

    return await _loadBinaryFromFile(id);
  }

  /// Deletes the file in this cache with the given [id].
  Future<void> delete(String id) async {
    _ensureInitialized();
    _ensureValidId(id);
    //
  }

  /// Deletes all files in this cache.
  Future<void> deleteAll() async {
    _ensureInitialized();
    //
  }

  void _ensureInitialized() {
    if (_directory.existsSync()) {
      return;
    }

    try {
      _directory.createSync(recursive: true);
    } catch (exception) {
      throw Exception("Failed to create a new cache directory at: ${_directory.absolute.path}");
    }
  }

  void _ensureValidId(String id) {
    if (id.isEmpty) {
      throw Exception("Invalid StaticShockCache ID - IDs can't be empty.");
    }
  }

  File _getFileForId(String id) {
    return File("${_directory.path}${Platform.pathSeparator}$id");
  }

  Future<String?> _loadTextFromFile(String id) async {
    final cacheFile = _getFileForId(id);
    final exists = await cacheFile.exists();
    if (!exists) {
      return null;
    }

    return await cacheFile.readAsString();
  }

  Future<void> _writeTextToFile(String id, String content) async {
    final cacheFile = _getFileForId(id);
    final exists = await cacheFile.exists();
    if (!exists) {
      await cacheFile.create();
    }

    await cacheFile.writeAsString(content);
  }

  Future<Uint8List?> _loadBinaryFromFile(String id) async {
    final cacheFile = _getFileForId(id);
    final exists = await cacheFile.exists();
    if (!exists) {
      return null;
    }

    return await cacheFile.readAsBytes();
  }

  Future<void> _writeBinaryToFile(String id, Uint8List content) async {
    final cacheFile = _getFileForId(id);
    final exists = await cacheFile.exists();
    if (!exists) {
      await cacheFile.create();
    }

    await cacheFile.writeAsBytes(content);
  }
}
