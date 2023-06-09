import 'dart:async';
import 'dart:io';

import 'package:fbh_front_matter/fbh_front_matter.dart' as front_matter;
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:static_shock/src/content/markdown.dart';
import 'package:static_shock/src/templates/components.dart';
import 'package:static_shock/src/templates/jinja.dart';
import 'package:static_shock/src/templates/layouts.dart';

import 'assets.dart';
import 'files.dart';
import 'pages.dart';
import 'pipeline.dart';
import 'pretty_urls.dart';
import 'source_files.dart';

final _log = Logger(level: Level.verbose);

class StaticShock implements StaticShockPipeline {
  StaticShock({
    required this.sourceDirectoryRelativePath,
    required this.destinationDirectoryRelativePath,
    Set<Picker>? pickers,
    Set<Excluder>? excluders,
    Set<AssetTransformer>? assetTransformers,
    Set<PageLoader>? pageLoaders,
    Set<PageTransformer>? pageTransformers,
    Set<PageRenderer>? pageRenderers,
    Set<StaticShockPlugin>? plugins,
  })  : _pickers = pickers ??
            {
              const ExtensionPicker("md"),
              const ExtensionPicker("jinja"),
            },
        _excluders = excluders ??
            {
              const FilePrefixExcluder("."),
            },
        _assetTransformers = assetTransformers ?? {},
        _pageLoaders = pageLoaders ??
            {
              const MarkdownPageLoader(),
              const JinjaPageLoader(),
            },
        _pageTransformers = pageTransformers ??
            {
              const PrettyPathPageTransformer(),
            },
        _pageRenderers = pageRenderers ??
            {
              const MarkdownPageRenderer(),
              const JinjaPageRenderer(),
            },
        _plugins = plugins ?? {};

  final String sourceDirectoryRelativePath;
  final String destinationDirectoryRelativePath;

  late Directory _sourceDirectory;
  late SourceFiles sourceFiles;

  late Directory destinationDir;

  @override
  void pick(Picker picker) => _pickers.add(picker);
  late final Set<Picker> _pickers;

  @override
  void exclude(Excluder excluder) => _excluders.add(excluder);
  late final Set<Excluder> _excluders;

  @override
  void transformAssets(AssetTransformer transformer) => _assetTransformers.add(transformer);
  late final Set<AssetTransformer> _assetTransformers;

  @override
  void loadPages(PageLoader loader) => _pageLoaders.add(loader);
  late final Set<PageLoader> _pageLoaders;

  @override
  void transformPages(PageTransformer transformer) => _pageTransformers.add(transformer);
  late final Set<PageTransformer> _pageTransformers;

  @override
  void renderPages(PageRenderer renderer) => _pageRenderers.add(renderer);
  late final Set<PageRenderer> _pageRenderers;

  void plugin(StaticShockPlugin plugin) => _plugins.add(plugin);
  final Set<StaticShockPlugin> _plugins;

  File _resolveSourceFile(FileRelativePath relativePath) => _sourceDirectory.descFile([relativePath.value]);

  File _resolveDestinationFile(FileRelativePath relativePath) => destinationDir.descFile([relativePath.value]);

  late StaticShockPipelineContext _context;
  final _files = <FileRelativePath>[];
  final _pages = <Page>[];
  final _assets = <Asset>[];

  /// Generates a static site from content and assets.
  Future<void> generateSite() async {
    _log.info(lightYellow.wrap("\n⚡ Generating a static site with Static Shock!\n"));

    _sourceDirectory = Directory.current.subDir([sourceDirectoryRelativePath]);

    sourceFiles = SourceFiles(
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
  }

  void _clearDestination() {
    destinationDir = Directory.current.subDir([destinationDirectoryRelativePath]);
    if (destinationDir.existsSync()) {
      destinationDir.deleteSync(recursive: true);
    }
    destinationDir.createSync(recursive: true);
  }

  void _applyPlugins() {
    for (final plugin in _plugins) {
      plugin.configure(this, _context);
    }
  }

  void _loadLayoutsAndComponents() {
    _log.info("⚡ Loading layouts and components");
    for (final sourceFile in sourceFiles.layouts()) {
      _log.detail("Layout: ${sourceFile.subPath}");
      _context.putLayout(
        Layout(
          FileRelativePath.parse(sourceFile.subPath),
          sourceFile.file.readAsStringSync(),
        ),
      );
    }
    for (final sourceFile in sourceFiles.components()) {
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
    for (final sourceFile in sourceFiles.sourceFiles()) {
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
}

abstract class StaticShockPlugin {
  FutureOr<void> configure(StaticShockPipeline pipeline, StaticShockPipelineContext context) {}
}
