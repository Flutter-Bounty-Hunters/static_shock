import 'dart:async';
import 'dart:io';

import 'package:front_matter/front_matter.dart' as front_matter;
import 'package:jinja/jinja.dart';
import 'package:markdown/markdown.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:static_shock/src/destination_files.dart';
import 'package:static_shock/src/include_files.dart';

import 'assets.dart';
import 'files.dart';
import 'pages.dart';
import 'source_files.dart';

class StaticShock {
  StaticShock({
    required this.sourceDirectoryRelativePath,
    required this.destinationDirectoryRelativePath,
    Set<SourcePageLoader> pageLoaders = const {
      MarkdownSourcePageLoader(),
      JinjaSourcePageLoader(),
    },
    Set<SourceFilter> assetExclusions = const {
      ExcludePrefixes({"_", "."}),
    },
    Set<StaticShockPlugin> plugins = const {},
  })  : _assetExclusions = assetExclusions,
        _pageLoaders = pageLoaders,
        _plugins = plugins;

  final String sourceDirectoryRelativePath;
  final String destinationDirectoryRelativePath;

  late Directory _sourceDirectory;
  late SourceFiles sourceFiles;

  late Directory destinationDir;

  final _layouts = <Layout>{};
  final _components = <Component>{};

  final Set<SourcePageLoader> _pageLoaders;
  final _pages = <Page>[];
  PagesIndex? _pagesIndex;

  final Set<SourceFilter> _assetExclusions;
  final _assetFiles = <Asset>[];

  final Set<StaticShockPlugin> _plugins;

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

    //----- Load all mappings from source files to destination files -----
    await _loadIncludes();
    _log.info("");

    await _loadPages();
    _log.info("");

    _buildPageIndex();
    _log.info("");

    final globalData = _createDataForAllPages(sourceFiles);
    _log.info("");

    //----- Let plugins configure their desired mappings from source files to destination files ----
    _log.info(lightYellow.wrap("⚡ Running plugins\n"));
    for (final plugin in _plugins) {
      plugin.applyTo(this);
    }
    _log.info("");

    //----- Write the static site files -----
    await _copyAssets();
    _log.info("");

    await _writePagesToFiles(globalData);
    _log.info("");
  }

  void _clearDestination() {
    destinationDir = Directory.current.subDir([destinationDirectoryRelativePath]);
    if (destinationDir.existsSync()) {
      destinationDir.deleteSync(recursive: true);
    }
    destinationDir.createSync(recursive: true);
  }

  Future<void> _loadIncludes() async {
    _log.info("⚡ Loading all include files");

    _layouts.clear();
    _components.clear();

    final layoutsDirectory = sourceFiles.directory.subDir(["_includes", "layouts"]);
    if (layoutsDirectory.existsSync()) {
      final layoutFiles = layoutsDirectory.listSync(recursive: true).whereType<File>().toList();
      for (final file in layoutFiles) {
        _layouts.add(
          Layout(
            sourceFile: SourceFile(file, path.relative(file.path, from: _sourceDirectory.path)),
            code: file.readAsStringSync(),
          ),
        );

        _log.detail("${_layouts.last}");
      }
    }

    final componentsDirectory = sourceFiles.directory.subDir(["_includes", "components"]);
    if (componentsDirectory.existsSync()) {
      final componentFiles = componentsDirectory.listSync(recursive: true).whereType<File>().toList();
      for (final file in componentFiles) {
        _components.add(
          Component(
            sourceFile: SourceFile(file, path.relative(file.path, from: _sourceDirectory.path)),
            code: file.readAsStringSync(),
          ),
        );

        _log.detail("${_components.last}");
      }
    }
  }

  Future<void> _loadPages() async {
    _log.info("⚡ Loading all pages");

    _pages.clear();
    for (final sourceFile in sourceFiles.sourceFiles()) {
      for (final pageLoader in _pageLoaders) {
        final page = await pageLoader.load(sourceFile);
        if (page != null) {
          _log.detail("Page: ${page.sourceFile.subPath}");
          _pages.add(page);
          continue;
        }
      }
    }
  }

  void _buildPageIndex() {
    _log.info("⚡ Indexing pages");
    _pagesIndex = PagesIndex()..addPages(_pages);
    _log.detail("Indexed ${_pages.length} pages");
  }

  Map<String, Object?> _createDataForAllPages(SourceFiles sourceSet) {
    final globalData = <String, Object?>{
      "components": <String, Object?>{},
    };

    for (final component in _components) {
      final name = path.basenameWithoutExtension(component.name);
      print("Creating factory for component: '$name'");
      (globalData["components"]! as Map<String, Object?>)[name] = () => component.code;
    }

    return globalData;
  }

  Future<void> _writePagesToFiles(Map<String, Object?> globalData) async {
    _log.info("⚡ Generating content");

    for (final page in _pages) {
      final sourceFileOrDirectoryName = page.sourceFile.path.split(Platform.pathSeparator).last;
      final newPath = '${destinationDir.path}/${page.sourceFile.subPath}$sourceFileOrDirectoryName';

      final parentDirectoryPath = path.dirname(newPath);

      final destFilePath =
          "${path.basenameWithoutExtension(page.sourceFile.subPath)}${Platform.pathSeparator}index.html";
      final destFile = File(path.join(parentDirectoryPath, destFilePath));

      destFile.createSync(recursive: true);

      print("Page layout: ${page.data.layout}, for page at: ${page.sourceFile.subPath}");
      print(" - full path: ${sourceFiles.directory.descFile([page.data.layout!]).path}");
      final layoutTemplateSource = sourceFiles.directory.descFile([page.data.layout!]).readAsStringSync();
      final template = Template(layoutTemplateSource);
      destFile.writeAsStringSync(
        template.render({
          ...globalData,
          ...page.data.toMap(),
        }),
      );
    }

    print("Done generating content");
  }

  Future<void> _transformMarkdownFile(
      SourceFile sourceFile, Map<String, Object?> globalData, PagesIndex sourceData, Directory buildRoot) async {
    final sourceFileOrDirectoryName = sourceFile.path.split(Platform.pathSeparator).last;
    final newPath = '${buildRoot.path}/${sourceFile.subPath}$sourceFileOrDirectoryName';

    final extension = path.extension(sourceFile.path);
    if (extension != ".md") {
      return;
    }

    _log.detail("Copying markdown file '${sourceFile.path}'");
    late final front_matter.FrontMatterDocument article;
    try {
      article = front_matter.parse(
        sourceFile.file.readAsStringSync(),
      );
    } catch (exception) {
      print("Caught exception while parsing Front Matter: $exception");
      return;
    }
    if (article.data.isEmpty) {
      _log.detail("Skipping '${sourceFile.path}' because it has no YAML configuration");
      return;
    }

    final htmlFileContent = await _transformMarkdownContent(sourceFile, globalData, article, sourceData);
    if (htmlFileContent == null) {
      return;
    }

    final parentDirectoryPath = path.dirname(newPath);

    final destFilePath = "${path.basenameWithoutExtension(sourceFile.subPath)}${Platform.pathSeparator}index.html";
    final destFile = File(path.join(parentDirectoryPath, destFilePath));

    destFile.createSync(recursive: true);
    destFile.writeAsStringSync(htmlFileContent);
  }

  Future<String?> _transformMarkdownContent(
    SourceFile sourceFile,
    Map<String, Object?> globalData,
    front_matter.FrontMatterDocument article,
    PagesIndex sourceData,
  ) async {
    if (!article.data.containsKey("layout")) {
      _log.err("Article is missing a 'layout' front matter property.");
      return null;
    }

    final layoutTemplateFile = File(path.join("website_source", "_includes", "layouts", article.data["layout"]));
    if (!layoutTemplateFile.existsSync()) {
      _log.err("No such layout template '${layoutTemplateFile.path}'.");
    }
    final layoutTemplateFilePath = layoutTemplateFile.readAsStringSync();

    final contentHtml = markdownToHtml(article.content!);

    final pageData = sourceData.buildDataForPage(globalData, sourceFile.subPath, contentHtml);

    print("Global data components before hydrating layout:");
    print("$pageData");

    final layoutTemplateSource =
        sourceFiles.directory.descFile(["_includes", layoutTemplateFilePath]).readAsStringSync();
    final template = Template(layoutTemplateSource);
    final hydratedLayout = template.render(
      pageData,
    );

    return hydratedLayout;
  }

  Future<void> _transformTemplateSourceFile(Page page, Map<String, Object?> globalData, Directory buildRoot) async {
    late final front_matter.FrontMatterDocument templateContent;
    try {
      templateContent = front_matter.parse(page.sourceFile.file.readAsStringSync());
    } catch (exception) {
      print("Caught Front Matter exception while processing template source file: $exception");
      return;
    }

    if (!templateContent.data.containsKey("layout")) {
      _log.err("Template source file is missing a 'layout' front matter property.");
      return;
    }

    final layoutTemplateFile = File(path.join("website_source", "_includes", templateContent.data["layout"]));
    if (!layoutTemplateFile.existsSync()) {
      _log.err("No such layout template '${layoutTemplateFile.path}'.");
    }
    final layoutTemplate = layoutTemplateFile.readAsStringSync();

    final contentHtml = markdownToHtml(templateContent.content!);

    final template = Template(layoutTemplate);
    final hydratedLayout = template.render(
      {
        ...globalData,
        ...page.data.toMap(),
        "content": contentHtml,
      },
    );

    final sourceFileName = path.basename(page.sourceFile.path);
    final newPath = '${buildRoot.path}/${page.sourceFile.subPath}$sourceFileName';
    final parentDirectoryPath = path.dirname(newPath);

    late File destFile;
    if (sourceFileName.startsWith("index.")) {
      destFile = File(path.join(parentDirectoryPath, "index.html"));
    } else {
      final destFilePath =
          "${path.basenameWithoutExtension(page.sourceFile.subPath)}${Platform.pathSeparator}index.html";
      destFile = File(path.join(parentDirectoryPath, destFilePath));
    }

    destFile.createSync(recursive: true);
    destFile.writeAsStringSync(hydratedLayout);
  }

  Future<void> _copyAssets() async {
    _log.info("⚡ Copying assets");
    final futures = <Future>[];

    final assets = sourceFiles.sourceEntities(
      CombineFilters({
        ..._assetExclusions,
        const ExcludeExtensions({".md", ".jinja"}),
      }),
    );

    for (final sourceEntity in assets) {
      if (!sourceEntity.entity.existsSync()) {
        _log.err("Tried to copy non-existent file or directory: '${sourceEntity.subPath}'");
        exit(ExitCode.ioError.code);
      }

      if (sourceEntity is SourceDirectory) {
        final destDirectory = Directory(_destinationEntity(sourceEntity.subPath));
        if (!destDirectory.existsSync()) {
          destDirectory.createSync(recursive: true);
        }
      } else {
        _log.detail("Copying ${sourceEntity.subPath}");

        final destinationFile = File(_destinationEntity(sourceEntity.subPath));
        if (!destinationFile.existsSync()) {
          destinationFile.createSync(recursive: true);
        }

        (sourceEntity as SourceFile).file.copySync(destinationFile.path);
      }
    }

    await Future.wait(futures);
  }

  String _destinationEntity(String localPath) {
    return "$destinationDirectoryRelativePath${Platform.pathSeparator}$localPath";
  }
}

final _log = Logger(level: Level.verbose);

const defaultAssetExclusions = {
  ExcludePrefixes({"_", "."})
};

abstract class StaticShockPlugin {
  FutureOr<void> applyTo(StaticShock pipeline);
}

/// Converts source files into [Page]s.
abstract class SourcePageLoader {
  // TODO: pass some kind of context into this method so that page generators can access
  //       global data, like tag searches, and also locate layout and component includes
  Future<Page?> load(SourceFile sourceFile);
}

/// Base class for a [SourcePageLoader], which filters out any file whose extension isn't
/// in the list of extensions given to this class.
abstract class FileExtensionSourcePageLoader implements SourcePageLoader {
  const FileExtensionSourcePageLoader(this._extensions);

  final List<String> _extensions;

  @override
  Future<Page?> load(SourceFile sourceFile) async {
    final fileExtension = path.extension(sourceFile.path);

    final isDesiredFile = _extensions.contains(fileExtension);
    if (!isDesiredFile) {
      return null;
    }

    return await doLoadPage(sourceFile);
  }

  Future<Page?> doLoadPage(SourceFile sourceFile);
}

/// A [SourcePageLoader] that loads page data from Markdown files.
class MarkdownSourcePageLoader extends FileExtensionSourcePageLoader {
  const MarkdownSourcePageLoader() : super(const [".md"]);

  @override
  Future<Page?> doLoadPage(SourceFile sourceFile) async {
    late final front_matter.FrontMatterDocument markdown;
    try {
      markdown = front_matter.parse(sourceFile.file.readAsStringSync());
    } catch (exception) {
      _log.err("Caught Front Matter exception while processing markdown source file: $exception");
      return null;
    }

    if (!markdown.data.containsKey("layout")) {
      _log.err("Markdown source file is missing a 'layout' front matter property.");
      return null;
    }

    late final String contentHtml;
    try {
      contentHtml = markdownToHtml(markdown.content!);
    } catch (exception) {
      _log.err("Failed to convert Markdown to HTML for source file: ${sourceFile.subPath} - Exception:\n$exception");
      return null;
    }

    final pageData = PageData()
      ..title = markdown.data["title"] ?? "TODO"
      ..url = markdown.data["url"] ?? sourceFile.subPath.replaceFirst(path.extension(sourceFile.subPath), "")
      ..createdAt = markdown.data["createdAt"] ?? DateTime.now()
      ..layout = '_includes${Platform.pathSeparator}${markdown.data["layout"]}'
      ..content = contentHtml;

    return Page(
      sourceFile: sourceFile,
      data: pageData,
    );
  }
}

/// A [SourcePageLoader] that loads page data from Jinja files.
///
/// Jinja is an appropriate source page format when you want to define a page's HTML
/// content directly, rather than transform non-HTML content (like Markdown) into HTML.
///
/// For example: a home page, or contact page, might be good candidates for a Jinja
/// page definition.
class JinjaSourcePageLoader extends FileExtensionSourcePageLoader {
  const JinjaSourcePageLoader() : super(const [".jinja"]);

  @override
  Future<Page?> doLoadPage(SourceFile sourceFile) async {
    print("Loading Jinja page: ${sourceFile.subPath}");
    return Page(
      sourceFile: sourceFile,
      data: PageData() //
        ..layout = sourceFile.subPath.substring(1), // Remove leading "/" to ensure its handled as a local path
      // TODO: we need to be able to specify a destination file from here, but we don't have access to the StaticShock for the destination
      // destinationFile: DestinationFile(),
    );
  }
}
