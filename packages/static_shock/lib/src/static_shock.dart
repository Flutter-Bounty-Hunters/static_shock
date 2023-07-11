import 'dart:async';
import 'dart:io';

import 'package:fbh_front_matter/fbh_front_matter.dart' as front_matter;
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:static_shock/src/finishers.dart';
import 'package:static_shock/src/templates/components.dart';
import 'package:static_shock/src/templates/layouts.dart';

import 'assets.dart';
import 'files.dart';
import 'pages.dart';
import 'pipeline.dart';
import 'source_files.dart';

final _log = Logger(level: Level.verbose);

/// The core of Static Shock.
///
/// The [StaticShock] object configures all static site generator features, and then
/// generates the static site.
///
/// Methods like [pick], [exclude], [transformAssets], [loadPages], [transformPages],
/// and [renderPages] can be used to configure website generation.
///
/// [plugin] can be used to configure website generation from 3rd party code.
///
/// [generateSite] generates the static site in the destination directory.
class StaticShock implements StaticShockPipeline {
  StaticShock({
    this.sourceDirectoryRelativePath = "source",
    this.destinationDirectoryRelativePath = "build",
    Set<Picker>? pickers,
    Set<Excluder>? excluders,
    Set<AssetTransformer>? assetTransformers,
    Set<PageLoader>? pageLoaders,
    Set<PageTransformer>? pageTransformers,
    Set<PageRenderer>? pageRenderers,
    Set<Finisher>? finishers,
    Set<StaticShockPlugin>? plugins,
  })  : _pickers = pickers ?? {},
        _excluders = excluders ??
            {
              const FilePrefixExcluder("."),
            },
        _assetTransformers = assetTransformers ?? {},
        _pageLoaders = pageLoaders ?? {},
        _pageTransformers = pageTransformers ?? {},
        _pageRenderers = pageRenderers ?? {},
        _finishers = finishers ?? {},
        _plugins = plugins ?? {};

  /// Path of the source directory, relative to the Static Shock project directory.
  final String sourceDirectoryRelativePath;

  /// Path of the destination directory, relative to the Static Shock project directory.
  final String destinationDirectoryRelativePath;

  late Directory _sourceDirectory;
  late SourceFiles _sourceFiles;

  late Directory _destinationDir;

  /// Adds the given [picker] to the pipeline, which selects files that will
  /// be pushed through the pipeline.
  @override
  void pick(Picker picker) => _pickers.add(picker);
  late final Set<Picker> _pickers;

  /// Adds the given [excluder] to the pipeline, which prevents files from entering
  /// the pipeline, even when they're picked by a [Picker].
  @override
  void exclude(Excluder excluder) => _excluders.add(excluder);
  late final Set<Excluder> _excluders;

  /// Adds the given [AssetTransformer] to the pipeline, which copies, alters, and
  /// saves assets from the source set to the build set.
  @override
  void transformAssets(AssetTransformer transformer) => _assetTransformers.add(transformer);
  late final Set<AssetTransformer> _assetTransformers;

  /// Adds the given [PageLoader] to the pipeline, which reads desired files into
  /// [Page] objects, which may then be processed by [PageTransformer]s and
  /// [PageRenderer]s.
  @override
  void loadPages(PageLoader loader) => _pageLoaders.add(loader);
  late final Set<PageLoader> _pageLoaders;

  /// Adds the given [PageTransformer] to the pipeline, which alters [Page]s loaded
  /// by [PageLoader]s, before the [Page] is rendered by a [PageRenderer].
  @override
  void transformPages(PageTransformer transformer) => _pageTransformers.add(transformer);
  late final Set<PageTransformer> _pageTransformers;

  /// Adds the given [PageRenderer] to the pipeline, which takes a [Page] and serializes
  /// that [Page] to an HTML page in the build set.
  @override
  void renderPages(PageRenderer renderer) => _pageRenderers.add(renderer);
  late final Set<PageRenderer> _pageRenderers;

  /// Adds the given [Finisher] to the pipeline, which runs after all [Page]s are
  /// loaded, indexed, transformed, and rendered.
  ///
  /// A [Finisher] might be used, for example, to generate an RSS feed, which requires
  /// knowledge of all pages in the static site.
  @override
  void finish(Finisher finisher) => _finishers.add(finisher);
  late final Set<Finisher> _finishers;

  /// Adds the given [StaticShockPlugin] to the pipeline, which is given the opportunity
  /// to configure the Static Shock pipeline however it wants.
  ///
  /// Direct usage of Static Shock can use methods like [pick], [exclude], [transformAssets],
  /// and [loadPages] to control website generation.
  ///
  /// Third party code, which is distributed in isolation, must implement a plugin to
  /// configure a Static Shock pipeline.
  void plugin(StaticShockPlugin plugin) => _plugins.add(plugin);
  final Set<StaticShockPlugin> _plugins;

  File _resolveSourceFile(FileRelativePath relativePath) => _sourceDirectory.descFile([relativePath.value]);

  File _resolveDestinationFile(FileRelativePath relativePath) => _destinationDir.descFile([relativePath.value]);

  late StaticShockPipelineContext _context;
  final _files = <FileRelativePath>[];
  final _pages = <Page>[];
  final _assets = <Asset>[];

  /// Generates a static site from content and assets.
  ///
  /// The site begins with a source set of files, and generates final static web files
  /// in a build set.
  ///
  /// The default source set location is "/source", and the default build set location
  /// is "/build".
  Future<void> generateSite() async {
    _log.info(lightYellow.wrap("\n⚡ Generating a static site with Static Shock!\n"));

    _sourceDirectory = Directory.current.subDir([sourceDirectoryRelativePath]);

    _sourceFiles = SourceFiles(
      directory: _sourceDirectory,
      excludedPaths: {
        "/_includes",
      },
    );

    _clearDestination();

    //---- Run new pipeline ----
    _context = StaticShockPipelineContext(_sourceDirectory);
    _files.clear();
    _pages.clear();
    _assets.clear();

    // Run plugin configuration - we do this first so that plugins can contribute pickers.
    _applyPlugins();

    // Load layouts and components
    _loadLayoutsAndComponents();

    // Pick the files.
    _pickAllSourceFiles();

    // Load pages and assets.
    await _loadPagesAndAssets();

    // Index all the pages so that they're available to the template system.
    _indexPages();

    // Transform pages.
    await _transformPages();

    // Transform assets.
    await _transformAssets();

    // Render pages.
    await _renderPages();

    // Write pages and assets to their destinations.
    await _writePagesAndAssetsToFiles();

    // Run Finishers, which take arbitrary actions in response to the pages and
    // assets generated by the pipeline.
    await _runFinishers();
  }

  void _clearDestination() {
    _destinationDir = Directory.current.subDir([destinationDirectoryRelativePath]);
    if (_destinationDir.existsSync()) {
      _destinationDir.deleteSync(recursive: true);
    }
    _destinationDir.createSync(recursive: true);
  }

  void _applyPlugins() {
    for (final plugin in _plugins) {
      plugin.configure(this, _context);
    }
  }

  void _loadLayoutsAndComponents() {
    _log.info("⚡ Loading layouts and components");
    for (final sourceFile in _sourceFiles.layouts()) {
      _log.detail("Layout: ${sourceFile.subPath}");
      _context.putLayout(
        Layout(
          FileRelativePath.parse(sourceFile.subPath),
          sourceFile.file.readAsStringSync(),
        ),
      );
    }
    for (final sourceFile in _sourceFiles.components()) {
      _log.detail("Component: ${sourceFile.subPath}");

      final componentContent = front_matter.parse(sourceFile.file.readAsStringSync());

      // TODO: process the component data, e.g., pull out CSS imports
      _context.putComponent(
        path.basenameWithoutExtension(sourceFile.subPath),
        Component(
          FileRelativePath.parse(sourceFile.subPath),
          Map.from(componentContent.data),
          // If there's no Front Matter, then `content` will be `null`. In that case, assume
          // everything is a Jinja template, and pass the full `value`.
          componentContent.content ?? componentContent.value,
        ),
      );
    }
    _log.info("");
  }

  void _pickAllSourceFiles() {
    _log.info("⚡ Picking files");
    for (final sourceFile in _sourceFiles.sourceFiles()) {
      final relativePath = FileRelativePath.parse(sourceFile.subPath);

      pickerLoop:
      for (final picker in _pickers) {
        if (picker.shouldPick(relativePath)) {
          for (final excluder in _excluders) {
            if (excluder.shouldExclude(relativePath)) {
              break pickerLoop;
            }
          }

          _log.detail("Picked: $relativePath");
          _files.add(relativePath);

          // We picked the file. No need to check more pickers.
          break;
        }
      }
    }
    _log.info("");
  }

  Future<void> _loadPagesAndAssets() async {
    _log.info("⚡ Loading pages and assets");

    pickerLoop:
    for (final pickedFile in _files) {
      late AssetContent content;

      final file = _resolveSourceFile(pickedFile);
      // Try to read as plain text, first.
      try {
        final textContent = file.readAsStringSync();
        content = AssetContent.text(textContent);
      } catch (exception) {
        try {
          // The content wasn't plain text. Try to read as binary.
          final binary = file.readAsBytesSync();
          content = AssetContent.binary(binary);
        } catch (exception) {
          _log.err("Tried to load asset content but failed: \n$exception");
          continue;
        }
      }

      // Try to interpret the file as a page. If it is a page, load the page.
      for (final pageLoader in _pageLoaders) {
        if (!pageLoader.canLoad(pickedFile)) {
          continue;
        }

        _log.detail("Loading page: $pickedFile");
        final page = await pageLoader.loadPage(pickedFile, content.text!);
        _pages.add(page);

        continue pickerLoop;
      }

      // The file isn't a page, therefore it must be an asset.
      _log.detail("Loading asset: $pickedFile");
      _assets.add(Asset(
        pickedFile,
        content,
        // By default, we assume a direct copy of each asset. Asset transformers
        // can change this decision later.
        destinationPath: pickedFile,
        destinationContent: content,
      ));
    }
    _log.info("");
  }

  void _indexPages() {
    _log.info("⚡ Indexing all loaded pages");
    _context.pagesIndex.addPages(_pages);
    _log.info("");
  }

  Future<void> _transformPages() async {
    _log.info("⚡ Transforming pages");
    for (final page in _pages) {
      for (final transformer in _pageTransformers) {
        await transformer.transformPage(_context, page);
      }
    }
    _log.info("");
  }

  Future<void> _transformAssets() async {
    _log.info("⚡ Transforming assets");
    for (final asset in _assets) {
      for (final transformer in _assetTransformers) {
        await transformer.transformAsset(_context, asset);
      }
    }
    _log.info("");
  }

  Future<void> _renderPages() async {
    _log.info("⚡ Rendering pages");
    for (final page in _pages) {
      for (final renderer in _pageRenderers) {
        await renderer.renderPage(_context, page);
      }
    }
    _log.info("");
  }

  Future<void> _writePagesAndAssetsToFiles() async {
    _log.info("⚡ Writing pages and assets to their final destination");
    for (final page in _pages) {
      if (page.destinationPath == null) {
        throw Exception(
            "Tried to write a page to its destination, but it has no destination. Page source: ${page.sourcePath}");
      }
      if (page.destinationContent == null) {
        throw Exception(
            "Tried to write a page to its destination, but it has no content. Page source: ${page.sourcePath}");
      }

      _log.detail("Writing page to destination: ${page.destinationPath}");
      final destinationFile = _resolveDestinationFile(page.destinationPath!);
      if (!destinationFile.existsSync()) {
        destinationFile.createSync(recursive: true);
      }
      destinationFile.writeAsStringSync(page.destinationContent!);
    }

    for (final asset in _assets) {
      if (asset.destinationPath == null) {
        throw Exception(
            "Tried to write an asset to its destination, but it has no destination. Asset source: ${asset.sourcePath}");
      }
      if (asset.destinationContent == null) {
        throw Exception(
            "Tried to write an asset to its destination, but it has no content. Asset source: ${asset.sourcePath}");
      }

      _log.detail("Writing asset to destination: ${asset.destinationPath}");
      final destinationFile = _resolveDestinationFile(asset.destinationPath!);
      if (!destinationFile.existsSync()) {
        destinationFile.createSync(recursive: true);
      }

      final content = asset.destinationContent!;
      if (content.isText) {
        destinationFile.writeAsStringSync(content.text!);
      } else {
        destinationFile.writeAsBytesSync(content.binary!);
      }
    }
    _log.info("");
  }

  Future<void> _runFinishers() async {
    _log.info("⚡ Running Finishers");
    for (final finisher in _finishers) {
      await finisher.execute(_context);
    }
  }
}

/// A Static Shock plugin.
///
/// A plugin is a mechanism that allows Static Shock configuration to be shared
/// independently from Static Shock. A [StaticShockPlugin] receives the same
/// configuration opportunities as a Static Shock app, but in a self-contained
/// structure. Namely, Static Shock calls [configure] on every plugin that's
/// registered with the [StaticShock] object.
///
/// A plugin can add [Picker]s, [Excluder]s, [AssetTransformer]s, [PageLoader]s,
/// [PageTransformer]s, [PageRenderer]s, etc.
///
/// To promote the robustness of the plugin API, Static Shock implements its own
/// default generation behavior through plugins that are shipped with Static Shock.
/// These plugins include markdown page generation, jinja pages and templates, and
/// pretty URLs.
abstract class StaticShockPlugin {
  /// Configures the [pipeline] to add new features that are associated with
  /// this plugin.
  FutureOr<void> configure(StaticShockPipeline pipeline, StaticShockPipelineContext context) {}
}
