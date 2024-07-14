import 'dart:async';
import 'dart:io';

import 'package:fbh_front_matter/fbh_front_matter.dart' as front_matter;
import 'package:http/http.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:static_shock/src/data.dart';
import 'package:static_shock/src/finishers.dart';
import 'package:static_shock/src/infrastructure/data.dart';
import 'package:static_shock/src/infrastructure/timer.dart';
import 'package:static_shock/src/templates/components.dart';
import 'package:static_shock/src/templates/layouts.dart';
import 'package:yaml/yaml.dart';

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
    Set<RemoteInclude>? remoteLayoutPickers,
    Set<RemoteInclude>? remoteComponentPickers,
    Set<RemoteFile>? remoteDataPickers,
    Set<RemoteFile>? remoteAssetPickers,
    Set<RemoteFile>? remotePagePickers,
    Set<DataLoader>? dataLoaders,
    Set<AssetTransformer>? assetTransformers,
    Set<PageLoader>? pageLoaders,
    Set<PageTransformer>? pageTransformers,
    Set<PageFilter>? pageFilters,
    Set<PageRenderer>? pageRenderers,
    Set<Finisher>? finishers,
    Set<StaticShockPlugin>? plugins,
  })  : _pickers = pickers ?? {},
        _remoteLayouts = remoteLayoutPickers ?? {},
        _remoteComponents = remoteComponentPickers ?? {},
        _remoteData = remoteDataPickers ?? {},
        _remoteAssets = remoteAssetPickers ?? {},
        _remotePages = remotePagePickers ?? {},
        _excluders = excluders ??
            {
              const FilePrefixExcluder("."),
            },
        _dataLoaders = dataLoaders ?? {},
        _assetTransformers = assetTransformers ?? {},
        _pageLoaders = pageLoaders ?? {},
        _pageTransformers = pageTransformers ?? {},
        _pageFilters = pageFilters ?? {},
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

  @override
  void pickRemote({
    Set<RemoteIncludeSource>? layouts,
    Set<RemoteIncludeSource>? components,
    Set<RemoteFileSource>? data,
    Set<RemoteFileSource>? assets,
    Set<RemoteFileSource>? pages,
  }) {
    _remoteLayouts.addAll(layouts ?? {});
    _remoteComponents.addAll(components ?? {});
    _remoteData.addAll(data ?? {});
    _remoteAssets.addAll(assets ?? {});
    _remotePages.addAll(pages ?? {});
  }

  late final Set<RemoteIncludeSource> _remoteLayouts;
  late final Set<RemoteIncludeSource> _remoteComponents;
  late final Set<RemoteFileSource> _remoteData;
  late final Set<RemoteFileSource> _remoteAssets;
  late final Set<RemoteFileSource> _remotePages;

  /// Adds the given [DataLoader] to the pipeline, which loads external data before
  /// any assets or pages are loaded.
  @override
  void loadData(DataLoader dataLoader) => _dataLoaders.add(dataLoader);
  late final Set<DataLoader> _dataLoaders;

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

  @override
  void filterPages(PageFilter filter) => _pageFilters.add(filter);
  late final Set<PageFilter> _pageFilters;

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
  @override
  void addTemplateFunction(String name, Function templateFunction) =>
      _context.putTemplateFunction(name, templateFunction);

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

  late CheckpointTimer _timer;
  late StaticShockPipelineContext _context;
  final _files = <FileRelativePath>[];

  /// Generates a static site from content and assets.
  ///
  /// The site begins with a source set of files, and generates final static web files
  /// in a build set.
  ///
  /// The default source set location is "/source", and the default build set location
  /// is "/build".
  Future<void> generateSite() async {
    _timer = CheckpointTimer(_log)..start();

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
    _context = StaticShockPipelineContext(_log, _sourceDirectory);
    _files.clear();

    // Run plugin configuration - we do this first so that plugins can contribute pickers.
    _applyPlugins();

    // Load layouts and components
    await _loadLayoutsAndComponents();

    // Collect all data in _data.yaml files in the source set.
    await _loadData(_context, _sourceFiles);

    // Pick the files.
    _pickAllSourceFiles();

    // Load all external data that will be injected into all pages.
    await _loadExternalData();

    // Load pages and assets.
    await _loadPagesAndAssets();

    // Transform pages.
    await _transformPages();

    // Transform assets.
    await _transformAssets();

    // Filter out unwanted pages.
    _filterPages();

    // Render pages.
    await _renderPages();

    // Run Finishers, which take arbitrary actions in response to the pages and
    // assets generated by the pipeline.
    await _runFinishers();

    // Write pages and assets to their destinations.
    await _writePagesAndAssetsToFiles();

    // Stop tracking build time and report it.
    _timer
      ..totalTime("Total build")
      ..stop();
  }

  void _clearDestination() {
    _log.info("⚡ Clearing destination directory");

    _destinationDir = Directory.current.subDir([destinationDirectoryRelativePath]);
    if (_destinationDir.existsSync()) {
      _destinationDir.deleteSync(recursive: true);
    }
    _destinationDir.createSync(recursive: true);

    _timer.checkpoint("Clear build directory", "Deletes all pre-existing files in the project build directory");
    _log.info("");
  }

  void _applyPlugins() {
    _log.info("⚡ Applying plugins");

    for (final plugin in _plugins) {
      plugin.configure(this, _context);
    }

    _timer.checkpoint("Apply plugins", "Every plugin configures the pipeline as desired");
    _log.info("");
  }

  Future<void> _loadLayoutsAndComponents() async {
    _log.info("⚡ Loading layouts and components");

    // Load remote layouts and components. We do this before local layouts and components
    // so that local layouts and components can overwrite remove values.
    final client = Client();
    final remoteLoadFutures = <Future>[];

    // Load remote layouts.
    for (final remoteLayout in _remoteLayouts) {
      switch (remoteLayout) {
        case HttpIncludeGroup includes:
          for (final include in includes) {
            remoteLoadFutures.add(
              _loadRemoteLayout(client, include),
            );
          }
        case RemoteInclude include:
          remoteLoadFutures.add(
            _loadRemoteLayout(client, include),
          );
      }
    }

    // Load remote components.
    for (final remoteComponent in _remoteComponents) {
      switch (remoteComponent) {
        case HttpIncludeGroup includes:
          for (final include in includes) {
            remoteLoadFutures.add(
              _loadRemoteComponent(client, include),
            );
          }
        case RemoteInclude include:
          remoteLoadFutures.add(
            _loadRemoteComponent(client, include),
          );
      }
    }
    await Future.wait(remoteLoadFutures);

    // Load local layouts and components. We do this after loading remove values so
    // that local values can overwrite remote values.
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

    _timer.checkpoint("Load layouts & components", "Finds all layout and component files and loads them into memory");
    _log.info("");
  }

  Future<void> _loadRemoteLayout(Client client, RemoteInclude remoteLayout) async {
    _log.detail("Loading remote layout: ${remoteLayout.url}");
    late final Uri url;
    try {
      url = Uri.parse(remoteLayout.url);
    } catch (exception) {
      _log.err("Couldn't parse the URL for the remote layout (ignoring it): ${remoteLayout.url}.");
      return;
    }
    final response = await client.get(url);
    final content = response.body;

    _context.putLayout(
      Layout(
        remoteLayout.simulatedLayoutPath,
        content,
      ),
    );
  }

  Future<void> _loadRemoteComponent(Client client, RemoteInclude remoteComponent) async {
    _log.detail("Loading remote component: ${remoteComponent.url}");
    late final Uri url;
    try {
      url = Uri.parse(remoteComponent.url);
    } catch (exception) {
      _log.err("Couldn't parse the URL for the remote component (ignoring it): ${remoteComponent.url}.");
      return;
    }
    final response = await client.get(url);
    final content = response.body;
    final componentContent = front_matter.parse(content);

    _context.putComponent(
      remoteComponent.name,
      Component(
        remoteComponent.simulatedComponentPath,
        Map.from(componentContent.data),
        content,
      ),
    );
  }

  /// Inspects all [sourceFiles] for files called `_data.yaml`, accumulates the content of those
  /// files into a [DataIndex], and returns that [DataIndex].
  Future<void> _loadData(StaticShockPipelineContext context, SourceFiles sourceFiles) async {
    _log.info("⚡ Indexing local data files into the global data index");
    final dataIndex = context.dataIndex;

    // Load remote data. We do this before local data so that remote data can be
    // overwritten by remote data.
    final client = Client();
    final remoteLoadFutures = <Future>[];
    for (final remoteData in _remoteData) {
      switch (remoteData) {
        case HttpFileGroup remoteDataGroup:
          for (final remoteData in remoteDataGroup) {
            remoteLoadFutures.add(
              _loadRemoteData(client, remoteData),
            );
          }
        case RemoteFile remoteData:
          remoteLoadFutures.add(
            _loadRemoteData(client, remoteData),
          );
      }
    }
    await Future.wait(remoteLoadFutures);

    // Load local data. We do this after the remote data so that local data overwrites
    // duplicated remote paths.
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

      final data = deepMergeMap(<String, dynamic>{}, yamlData);

      // Special support for tags. We want user to be able to write a single tag value
      // under "tags", but we also need tags to be mergeable as a list. Therefore, we
      // explicitly turn a single tag into a single-item tag list.
      //
      // This same conversion is done in pages.dart
      // TODO: generalize this auto-conversion so that plugins can do the same thing.
      if (data["tags"] is String) {
        data["tags"] = [(data["tags"] as String)];
      }

      dataIndex.mergeAtPath(DirectoryRelativePath(directory.subPath), data.cast());
    }

    _timer.checkpoint(
      "Index local data",
      "Finds all local data files and loads that data into the global pipeline index",
    );
    _log.info("");
  }

  Future<void> _loadRemoteData(Client client, RemoteFile remoteData) async {
    _log.detail("Loading remote data: ${remoteData.url}");
    late final Uri url;
    try {
      url = Uri.parse(remoteData.url);
    } catch (exception) {
      _log.err("Couldn't parse the URL for the remote data (ignoring it): ${remoteData.url}.");
      return;
    }
    final response = await client.get(url);
    final text = response.body;
    if (text.trim().isEmpty) {
      // The file is empty. Ignore it.
      return;
    }

    final yamlData = loadYaml(text) as YamlMap;

    final data = deepMergeMap(<String, dynamic>{}, yamlData);

    // Special support for tags. We want user to be able to write a single tag value
    // under "tags", but we also need tags to be mergeable as a list. Therefore, we
    // explicitly turn a single tag into a single-item tag list.
    //
    // This same conversion is done in pages.dart
    // TODO: generalize this auto-conversion so that plugins can do the same thing.
    if (data["tags"] is String) {
      data["tags"] = [(data["tags"] as String)];
    }

    _context.dataIndex.mergeAtPath(remoteData.buildPath.containingDirectory, data.cast());
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

    _timer.checkpoint("Pick source files", "Loads every desired source file into memory");
    _log.info("");
  }

  Future<void> _loadExternalData() async {
    _log.info("⚡ Loading external data");

    final loadingFutures = <Future<Map<String, Object>>>[];
    for (final loader in _dataLoaders) {
      loadingFutures.add(loader.loadData(_context));
    }

    List<Map<String, Object>> loadedData = await Future.wait(loadingFutures);
    for (final data in loadedData) {
      _context.dataIndex.mergeAtPath(DirectoryRelativePath("/"), data);
    }

    _timer.checkpoint("Load external data", "Loads all data from non-local sources, such as APIs");
    _log.info("");
  }

  Future<void> _loadPagesAndAssets() async {
    _log.info("⚡ Loading pages and assets");

    // Load remote pages and assets. We do this before local page and assets so
    // that local files can overwrite remote files.
    final client = Client();
    final remoteLoadFutures = <Future>[];

    // Load remote pages.
    for (final remotePage in _remotePages) {
      switch (remotePage) {
        case HttpFileGroup remotePageGroup:
          for (final remotePage in remotePageGroup) {
            remoteLoadFutures.add(
              _loadRemotePage(client, remotePage),
            );
          }
        case RemoteFile remotePage:
          remoteLoadFutures.add(_loadRemotePage(client, remotePage));
      }
    }

    // Load remote assets.
    for (final remoteAsset in _remoteAssets) {
      switch (remoteAsset) {
        case HttpFileGroup remoteAssetGroup:
          for (final remoteAsset in remoteAssetGroup) {
            remoteLoadFutures.add(_loadRemoteAsset(client, remoteAsset));
          }
        case RemoteFile remoteAsset:
          remoteLoadFutures.add(_loadRemoteAsset(client, remoteAsset));
      }
    }
    await Future.wait(remoteLoadFutures);

    // Load local pages and assets. We do this 2nd so that they override any remote
    // pages and assets.
    pickerLoop:
    for (final pickedFile in _files) {
      late AssetContent content;

      final file = _resolveSourceFile(pickedFile);
      try {
        // Try to read as plain text, first.
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

        final inheritedData = _context.dataIndex.inheritDataForPath(page.sourcePath);
        page.data.addEntries(inheritedData.entries);

        // Check for a desired base path override, and apply it.
        String? basePath = page.data['basePath'];
        if (basePath != null && basePath.isNotEmpty) {
          if (basePath.startsWith("/")) {
            // Chop off leading "/".
            //
            // A "/" is acceptable from a URL perspective, where it refers to the root
            // of the website. However, from a file system perspective, a "/" refers to
            // the root of the file system. We don't want to write files to the root of
            // the file system.
            basePath = basePath.substring(1);
          }

          _log.detail("Overriding default page URL:\nFrom: ${page.destinationPath?.value}\nTo: $basePath");
          page.destinationPath = page.destinationPath!.copyWith(directoryPath: basePath);
        }

        _context.pagesIndex.addPage(page);

        continue pickerLoop;
      }

      // The file isn't a page, therefore it must be an asset.
      _log.detail("Loading asset: $pickedFile");
      _context.addAsset(Asset(
        sourcePath: pickedFile,
        sourceContent: content,
        // By default, we assume a direct copy of each asset. Asset transformers
        // can change this decision later.
        destinationPath: pickedFile,
        destinationContent: content,
      ));
    }

    _timer.checkpoint("Load pages & assets", "Finds all local page and asset files and loads them into memory");
    _log.info("");
  }

  Future<void> _loadRemotePage(Client client, RemoteFile remotePage) async {
    _log.detail("Loading remote page: ${remotePage.url}");
    late final Uri url;
    try {
      url = Uri.parse(remotePage.url);
    } catch (exception) {
      _log.err("Couldn't parse the URL for the remote page (ignoring it): ${remotePage.url}.");
      return;
    }
    final response = await client.get(url);
    final content = response.body;

    final page = Page(remotePage.buildPath, content);

    final inheritedData = _context.dataIndex.inheritDataForPath(page.sourcePath);
    page.data.addEntries(inheritedData.entries);

    // Check for a desired base path override, and apply it.
    String? basePath = page.data['basePath'];
    if (basePath != null && basePath.isNotEmpty) {
      if (basePath.startsWith("/")) {
        // Chop off leading "/".
        //
        // A "/" is acceptable from a URL perspective, where it refers to the root
        // of the website. However, from a file system perspective, a "/" refers to
        // the root of the file system. We don't want to write files to the root of
        // the file system.
        basePath = basePath.substring(1);
      }

      _log.detail("Overriding default page URL:\nFrom: ${page.destinationPath?.value}\nTo: $basePath");
      page.destinationPath = page.destinationPath!.copyWith(directoryPath: basePath);
    }

    _context.pagesIndex.addPage(page);
  }

  Future<void> _loadRemoteAsset(Client client, RemoteFile remoteAsset) async {
    _log.detail("Loading remote asset: ${remoteAsset.url}");
    late final Uri url;
    try {
      url = Uri.parse(remoteAsset.url);
    } catch (exception) {
      _log.err("Couldn't parse the URL for the remote asset (ignoring it): ${remoteAsset.url}.");
      return;
    }
    final response = await client.get(url);

    late final AssetContent content;
    final contentType = response.headers["content-type"];
    if (contentType == null || contentType.isEmpty) {
      _log.err("Remote asset didn't report its content type. We don't know how to process it. Ignoring it.");
      return;
    }

    if (contentType.startsWith("text")) {
      try {
        // Try to read as plain text, first.
        final textContent = response.body;
        content = AssetContent.text(textContent);
      } catch (exception) {
        _log.err("The remote asset reported as a text asset, but we encountered an error when treating it as text.");
        _log.err("$exception");
        return;
      }
    } else {
      try {
        // The content wasn't plain text. Try to read as binary.
        final binary = response.bodyBytes;
        content = AssetContent.binary(binary);
      } catch (exception) {
        _log.err(
            "The remote asset reported as a binary asset, but we encountered an error when treating it as binary.");
        _log.err("$exception");
        return;
      }
    }

    _context.addAsset(Asset(
      sourcePath: remoteAsset.buildPath,
      sourceContent: content,
      // By default, we assume a direct copy of each asset. Asset transformers
      // can change this decision later.
      destinationPath: remoteAsset.buildPath,
      destinationContent: content,
    ));
  }

  Future<void> _transformPages() async {
    _log.info("⚡ Transforming pages");

    for (final page in _context.pagesIndex.pages) {
      for (final transformer in _pageTransformers) {
        await transformer.transformPage(_context, page);
      }
    }

    _timer.checkpoint("Transform pages", "Alters loaded pages in whatever way is desired by the app and plugins");
    _log.info("");
  }

  Future<void> _transformAssets() async {
    _log.info("⚡ Transforming assets");

    // Order is important: Each transformer should be given every asset before going
    // to the next transformer. This allows transformers to be added in phases, for
    // example, to first cache all the Sass stylsheets, and then second to compile them.
    for (final transformer in _assetTransformers) {
      for (final asset in _context.assets) {
        await transformer.transformAsset(_context, asset);
      }
    }

    _timer.checkpoint("Transform assets", "Alters loaded assets in whatever way is desired by the app and plugins");
    _log.info("");
  }

  void _filterPages() async {
    _log.info("⚡ Filtering pages");

    if (_pageFilters.isEmpty) {
      // If there aren't any filters, don't waste time looping through all the pages.
      _log.info("No page filters to apply - all pages will be rendered.");
      return;
    }

    for (final page in _context.pagesIndex.pages) {
      for (final filter in _pageFilters) {
        if (!filter.shouldInclude(_context, page)) {
          _log.detail("Removing page: ${page.title}");
          _context.pagesIndex.removePage(page);
          continue;
        }
      }
    }

    _timer.checkpoint("Filter pages", "Removes all pages that are no longer desired in the final build");
    _log.info("");
  }

  Future<void> _renderPages() async {
    _log.info("⚡ Rendering pages");

    // Render the content for every page.
    _log.info("\nRendering content for all pages...");
    for (final page in _context.pagesIndex.pages) {
      var didRender = false;
      for (final rendererId in page.contentRenderers) {
        for (final renderer in _pageRenderers) {
          if (renderer.id == rendererId) {
            _log.detail("Rendering page '${page.title}' content as '$rendererId'");
            didRender = true;
            await renderer.renderContent(_context, page);
          }
        }
      }

      if (!didRender) {
        _log.warn(
          "Couldn't find any content renderers for page '${page.title}' - requested renderers: ${page.contentRenderers}",
        );
      }
    }
    _timer.checkpoint(
      "Render page content",
      "Renders the content for all pages, e.g., Markdown to HTML",
    );
    _log.info("");

    // Render the layout for every page whose layout is separate from content.
    _log.info("\nRendering layouts for all pages...");
    for (final page in _context.pagesIndex.pages) {
      for (final renderer in _pageRenderers) {
        await renderer.renderLayout(_context, page);
      }
    }
    _timer.checkpoint(
      "Render final pages",
      "Injects content into page templates, generating the final content for all pages",
    );
    _log.info("");
  }

  Future<void> _runFinishers() async {
    _log.info("⚡ Running Finishers");

    for (final finisher in _finishers) {
      await finisher.execute(_context);
    }

    _timer.checkpoint("Run finishers", "Runs all finishers, which take final actions after a build is complete");
    _log.info("");
  }

  Future<void> _writePagesAndAssetsToFiles() async {
    _log.info("⚡ Writing pages and assets to their final destination");

    final writeFutures = <Future>[];

    for (final page in _context.pagesIndex.pages) {
      if (page.destinationPath == null) {
        throw Exception(
            "Tried to write a page to its destination, but it has no destination. Page source: ${page.sourcePath}");
      }
      if (page.destinationContent == null) {
        throw Exception(
            "Tried to write a page to its destination, but it has no content. Page source: ${page.sourcePath}");
      }

      _log.detail("Writing page to destination: ${page.destinationPath}");
      writeFutures.add(_writePage(page));
    }

    for (final asset in _context.assets) {
      if (asset.destinationPath == null) {
        throw Exception(
            "Tried to write an asset to its destination, but it has no destination. Asset source: ${asset.sourcePath}");
      }
      if (asset.destinationContent == null) {
        throw Exception(
            "Tried to write an asset to its destination, but it has no content. Asset source: ${asset.sourcePath}");
      }

      _log.detail("Writing asset to destination: ${asset.destinationPath}");
      writeFutures.add(_writeAsset(asset));
    }

    await Future.wait(writeFutures);

    _timer.checkpoint("Write to file system", "Writes all pages and assets to the final build directory");
    _log.info("");
  }

  Future<void> _writePage(Page page) async {
    // final stopwatch = Stopwatch()..start();

    final destinationFile = _resolveDestinationFile(page.destinationPath!);
    if (!destinationFile.existsSync()) {
      destinationFile.createSync(recursive: true);
    }
    destinationFile.writeAsStringSync(page.destinationContent!);

    // stopwatch.stop();
    // _log.detail("Wrote page in ${stopwatch.elapsedMilliseconds / 1000}s");
  }

  Future<void> _writeAsset(Asset asset) async {
    // final stopwatch = Stopwatch()..start();

    final destinationFile = _resolveDestinationFile(asset.destinationPath!);
    if (!destinationFile.existsSync()) {
      await destinationFile.create(recursive: true);
    }

    final content = asset.destinationContent!;
    if (content.isText) {
      await destinationFile.writeAsString(content.text!);
    } else {
      await destinationFile.writeAsBytes(content.binary!);
    }

    // stopwatch.stop();
    // _log.detail("Wrote asset in ${stopwatch.elapsedMilliseconds / 1000}s");
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
  const StaticShockPlugin();

  /// Configures the [pipeline] to add new features that are associated with
  /// this plugin.
  FutureOr<void> configure(StaticShockPipeline pipeline, StaticShockPipelineContext context) {}
}
