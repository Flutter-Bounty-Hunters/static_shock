import 'dart:io';

import 'package:static_shock/src/files.dart';
import 'package:static_shock/src/templates/components.dart';
import 'package:static_shock/src/templates/layouts.dart';

import 'assets.dart';
import 'pages.dart';

abstract class StaticShockPipeline {
  void pick(Picker picker);

  void exclude(Excluder excluder);

  void transformAssets(AssetTransformer transformer);

  void loadPages(PageLoader loader);

  void transformPages(PageTransformer transformer);

  void renderPages(PageRenderer renderer);
}

class StaticShockPipelineContext {
  StaticShockPipelineContext(this._sourceDirectory);

  final Directory _sourceDirectory;

  Directory resolveSourceDirectory(DirectoryRelativePath relativePath) {
    return _sourceDirectory.subDir([relativePath.value]);
  }

  File resolveSourceFile(FileRelativePath relativePath) {
    return _sourceDirectory.descFile([relativePath.value]);
  }

  final pagesIndex = PagesIndex();

  Layout? getLayout(FileRelativePath path) => _layouts[path];
  final _layouts = <FileRelativePath, Layout>{};

  void putLayout(Layout layout) {
    _layouts[layout.path] = layout;
  }

  Component? getComponent(String name) => _components[name];

  Map<String, Component> get components => Map<String, Component>.from(_components);
  final _components = <String, Component>{};

  void putComponent(String name, Component component) {
    _components[name] = component;
  }
}
