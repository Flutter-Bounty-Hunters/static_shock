import 'dart:io';

import 'package:collection/collection.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:static_shock/src/data.dart';
import 'package:static_shock/src/files.dart';
import 'package:static_shock/src/finishers.dart';
import 'package:static_shock/src/templates/components.dart';
import 'package:static_shock/src/templates/layouts.dart';

import 'assets.dart';
import 'pages.dart';

/// A pipeline that runs a series of steps to generate a static website.
abstract class StaticShockPipeline {
  /// Adds the given [picker] to the pipeline, which selects files that will
  /// be pushed through the pipeline.
  void pick(Picker picker);

  /// Adds the given [excluder] to the pipeline, which prevents files from entering
  /// the pipeline, even when they're picked by a [Picker].
  ///
  /// For example:
  ///
  ///     pipeline
  ///       .pick(DirectoryPicker.parse("images"))
  ///       .exclude(FilePicker.parse("**/.DS_Store");
  ///
  void exclude(Excluder excluder);

  /// Pick all given remote files, which are then pushed through the pipeline as
  /// the described type of artifact, e.g., component vs page vs asset.
  void pickRemote({
    Set<RemoteIncludeSource>? layouts,
    Set<RemoteIncludeSource>? components,
    Set<RemoteFileSource>? data,
    Set<RemoteFileSource>? assets,
    Set<RemoteFileSource>? pages,
  });

  /// Adds the given [DataLoader] to the pipeline, which loads external data before
  /// any assets or pages are loaded.
  void loadData(DataLoader dataLoader);

  /// Adds the given [AssetLoader] to the pipeline, which loads and adds assets that
  /// weren't [pick]'ed, e.g., loading an image from network, or generating an image
  /// during the build process.
  void loadAssets(AssetLoader loader);

  /// Adds the given [AssetTransformer] to the pipeline, which copies, alters, and
  /// saves assets from the source set to the build set.
  void transformAssets(AssetTransformer transformer);

  /// Adds the given [PageLoader] to the pipeline, which reads desired files into
  /// [Page] objects, which may then be processed by [PageTransformer]s and
  /// [PageRenderer]s.
  void loadPages(PageLoader loader);

  /// Adds the given [PageTransformer] to the pipeline, which alters [Page]s loaded
  /// by [PageLoader]s, before the [Page] is rendered by a [PageRenderer].
  void transformPages(PageTransformer transformer);

  /// Adds the given [PageFilter] to the pipeline, which can remove [Page]s before
  /// those [Page]s are rendered.
  ///
  /// For example, a plugin might implement a "draft mode" in which article drafts
  /// are excluded from the final build. While the draft mode could try to exclude
  /// pages at the file level, that would require the draft mode plugin to understand
  /// all possible file types so that it could parse the draft data. By filtering
  /// after the creation of [Page]s, the draft mode plugin only needs to know which
  /// property to check on the [Page] object.
  void filterPages(PageFilter filter);

  /// Adds the given [templateFunction] to the pipeline, making the function available
  /// during page template rendering via the given [name].
  ///
  /// Example - Register a function that converts Markdown to inline HTML:
  ///
  ///     pipeline.addTemplateFunction("md", (markdown) => markdownToHtml(markdown, inlineOnly: true));
  ///
  /// The registered function can then be used within a page template:
  ///
  ///     ---
  ///     some_property: This is **markdown** in a *Front Matter* property.
  ///     ---
  ///     <html>
  ///       <body>
  ///         <h1>Markdown from Front Matter</h2>
  ///         <!-- The following lines takes the value of some_property and passes it into the md() function -->
  ///         <p>{{ md(some_property) }}</p>
  ///       <body>
  ///     </html>
  ///
  void addTemplateFunction(String name, Function templateFunction);

  /// Adds the given [PageRenderer] to the pipeline, which takes a [Page] and serializes
  /// that [Page] to an HTML page in the build set.
  void renderPages(PageRenderer renderer);

  /// Adds the given [Finisher] to the pipeline, which runs after all [Page]s are
  /// loaded, indexed, transformed, and rendered.
  ///
  /// A [Finisher] might be used, for example, to generate an RSS feed, which requires
  /// knowledge of all pages in the static site.
  void finish(Finisher finisher);
}

/// Information and file system access that's provided to various pipeline actors
/// and also provided to plugins.
class StaticShockPipelineContext {
  StaticShockPipelineContext(this._sourceDirectory, [Logger? log]) : log = log ?? Logger(level: Level.quiet);

  /// The shared [Logger] for all CLI output.
  ///
  /// Plugins should log messages with this [Logger] so that verbosity output level
  /// can be centrally controlled.
  final Logger log;

  final Directory _sourceDirectory;

  /// Maps a given [relativePath] to a fully-resolved file system [Directory].
  Directory resolveSourceDirectory(DirectoryRelativePath relativePath) {
    return _sourceDirectory.subDir([relativePath.value]);
  }

  /// Maps a given [relativePath] to a fully-resolved file system [File].
  File resolveSourceFile(FileRelativePath relativePath) {
    return _sourceDirectory.descFile([relativePath.value]);
  }

  /// The global hierarchy of data, which is filled during data loading, and which is
  /// made available to every page during rendering.
  final dataIndex = DataIndex();

  List<Asset> get assets => List.unmodifiable(_assets);
  final _assets = <Asset>[];

  /// Returns `true` if an asset has been added whose source path matches [sourcePath].
  bool hasAssetFromSourcePath(FileRelativePath sourcePath) {
    return _assets.firstWhereOrNull((asset) => asset.sourcePath == sourcePath) != null;
  }

  /// Returns `true` if an asset has been added whose destination path matches [destinationPath].
  bool hasAssetForDestinationPath(FileRelativePath destinationPath) {
    return _assets.firstWhereOrNull((asset) => asset.destinationPath == destinationPath) != null;
  }

  /// Returns all assets whose destination file has the given extension.
  Iterable<Asset> findAssetsWithExtension(String extension) {
    return _assets.where((asset) => asset.destinationPath?.extension == extension);
  }

  /// Adds the given [asset] to those that will be included in the final website build.
  void addAsset(Asset asset) {
    _assets.add(asset);
  }

  /// Removes the asset whose source path matches the given [sourcePath].
  ///
  /// Once removed, the asset will not be included in the final website build.
  void removeAssetBySourcePath(FileRelativePath sourcePath) {
    _assets.removeWhere((asset) => asset.sourcePath == sourcePath);
  }

  /// Removes the asset whose destination path matches the given [destinationPath].
  ///
  /// Once removed, the asset will not be included in the final website build.
  void removeAssetByDestinationPath(FileRelativePath destinationPath) {
    _assets.removeWhere((asset) => asset.destinationPath == destinationPath);
  }

  /// An index of [Page]s loaded into the pipeline.
  final pagesIndex = PagesIndex();

  /// Returns the [Layout] template from the given file [path].
  Layout? getLayout(FileRelativePath path) => _layouts[path];
  final _layouts = <FileRelativePath, Layout>{};

  /// Adds the given [layout] to the pipeline.
  void putLayout(Layout layout) {
    _layouts[layout.path] = layout;
  }

  /// Functions that should be available during template rendering.
  Map<String, Function> get templateFunctions => Map<String, Function>.from(_templateFunctions);
  final _templateFunctions = <String, Function>{};

  /// Adds the given [templateFunction] to the pipeline, making the function available
  /// during page template rendering via the given [name].
  ///
  /// Example - Register a function that converts Markdown to inline HTML:
  ///
  ///     pipeline.addTemplateFunction("md", (markdown) => markdownToHtml(markdown, inlineOnly: true));
  ///
  /// The registered function can then be used within a page template:
  ///
  ///     ---
  ///     some_property: This is **markdown** in a *Front Matter* property.
  ///     ---
  ///     <html>
  ///       <body>
  ///         <h1>Markdown from Front Matter</h2>
  ///         <!-- The following lines takes the value of some_property and passes it into the md() function -->
  ///         <p>{{ md(some_property) }}</p>
  ///       <body>
  ///     </html>
  ///
  void putTemplateFunction(String name, Function templateFunction) => _templateFunctions[name] = templateFunction;

  /// All components loaded into the pipeline.
  Map<String, Component> get components => Map<String, Component>.from(_components);
  final _components = <String, Component>{};

  /// Returns the [Component] in the file with the given [name].
  Component? getComponent(String name) => _components[name];

  /// Adds the given [Component] to the pipeline.
  void putComponent(String name, Component component) {
    _components[name] = component;
  }
}
