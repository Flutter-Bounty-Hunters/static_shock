import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:intl/intl.dart';
import 'package:jinja/jinja.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:static_shock/src/cache.dart';
import 'package:static_shock/src/files.dart';
import 'package:static_shock/src/pages.dart';
import 'package:static_shock/src/pipeline.dart';
import 'package:static_shock/src/static_shock.dart';
import 'package:yaml/yaml.dart';

class JinjaPlugin implements StaticShockPlugin {
  const JinjaPlugin({
    this.filters = const [],
    this.tests = const [],
  });

  @override
  final id = "io.staticshock.jinja";

  final List<StaticShockJinjaFunctionBuilder> filters;
  final List<StaticShockJinjaFunctionBuilder> tests;

  @override
  FutureOr<void> configure(
    StaticShockPipeline pipeline,
    StaticShockPipelineContext context,
    StaticShockCache pluginCache,
  ) {
    pipeline.pick(const ExtensionPicker("jinja"));
    pipeline.loadPages(JinjaPageLoader(context.log));
    pipeline.renderPages(JinjaPageRenderer(
      context.log,
      filters: filters,
      tests: tests,
    ));
  }
}

/// Constructs and returns a Jinja function (filter or test), along with the function name,
/// given the [StaticShockPipelineContext].
///
/// Some Jinja functions only care about the input value, such as a filter that capitalizes a word.
/// For those functions, a function builder is redundant. However, other functions need to inspect
/// the [StaticShockPipelineContext], such as a filter that checks for the existence of a
/// given page. Therefore, all Jinja functions are configured with a builder like this, instead
/// of directly passing a function to Jinja.
typedef StaticShockJinjaFunctionBuilder = (String functionName, Function function) Function(
  StaticShockPipelineContext context,
);

class JinjaPageLoader implements PageLoader {
  const JinjaPageLoader(this._log);

  // ignore: unused_field
  final Logger _log;

  @override
  bool canLoad(FileRelativePath path) {
    return path.extension.toLowerCase() == "jinja";
  }

  @override
  FutureOr<Page> loadPage(FileRelativePath path, String content) {
    final frontMatter = <String, Object>{};
    var trimmedContent = content.trim();
    if (trimmedContent.startsWith("<!--")) {
      // The very first piece of content is an HTML comment. It might be front matter.
      // Try to parse it as YAML front matter.
      final comment = trimmedContent.substring("<!--".length, trimmedContent.indexOf("-->")).trim();
      trimmedContent = trimmedContent.substring(trimmedContent.indexOf("-->") + 3).trim();

      final yaml = loadYaml(comment) as YamlMap;
      for (final entry in yaml.entries) {
        if (entry.key is! String || entry.value == null) {
          continue;
        }
        frontMatter[entry.key] = entry.value;
      }
    }

    final destinationPath = path.copyWith(extension: "html");

    return Page(
      path,
      trimmedContent,
      data: {
        // Note: assign "url" before including frontMatter so that the frontMatter can override it.
        "url": destinationPath.value,
        if (!frontMatter.containsKey("contentRenderers")) //
          "contentRenderers": ["jinja"],
        ...frontMatter
      },
      destinationPath: destinationPath,
    );
  }
}

class JinjaPageRenderer implements PageRenderer {
  const JinjaPageRenderer(
    this._log, {
    this.filters = const [],
    this.tests = const [],
  });

  final Logger _log;

  final List<StaticShockJinjaFunctionBuilder> filters;
  final List<StaticShockJinjaFunctionBuilder> tests;

  @override
  String get id => "jinja";

  @override
  FutureOr<void> renderContent(StaticShockPipelineContext context, Page page) {
    _renderJinjaTemplate(
      context,
      page,
      templateSource: page.destinationContent ?? page.sourceContent,
    );
  }

  @override
  FutureOr<void> renderLayout(StaticShockPipelineContext context, Page page) async {
    if (page.data["layout"] == null ||
        page.data["layout"].trim().isEmpty ||
        page.data["layout"].trim().toLowerCase() == "none") {
      return;
    }

    // Treat the page's source content as content to be injected in the specified layout.
    final layoutPathString = page.data["layout"] as String?;
    if (layoutPathString == null || layoutPathString.isEmpty) {
      return;
    }

    // Get the layout that we want to apply.
    final layoutPath = FileRelativePath.parse("_includes${Platform.pathSeparator}$layoutPathString");
    final layout = context.getLayout(layoutPath);
    if (layout == null) {
      _log.err(
          "Tried to apply a layout template to page (${page.sourcePath}) but couldn't find layout for \"$layoutPath\".");
      return;
    }

    if (layout.path.extension != "jinja") {
      // This isn't a Jinja layout. It's not our job to apply it. Return.
      return;
    }

    _log.detail("Applying Jinja layout template (${layout.path}) to page (${page.sourcePath})");
    _renderJinjaTemplate(
      context,
      page,
      templateSource: layout.value,
      content: page.destinationContent ?? page.sourceContent,
    );
  }

  void _renderJinjaTemplate(
    StaticShockPipelineContext context,
    Page page, {
    required String templateSource,
    String? content,
  }) {
    final jinjaFilters = Map.fromEntries([
      MapEntry("startsWith", _startsWith),
      MapEntry("formatDateTime", _formatDateTime),
      MapEntry("take", _take),
      MapEntry("pathRelativeToPage", (String relativePath) => _pathRelativeToPage(page, relativePath)),
      ...filters.map((filterBuilder) {
        final filter = filterBuilder(context);
        return MapEntry<String, Function>(filter.$1, filter.$2);
      }),
    ]);

    final jinjaTests = Map.fromEntries([
      ...tests.map((testBuilder) {
        final test = testBuilder(context);
        return MapEntry<String, Function>(test.$1, test.$2);
      }),
    ]);

    // Make components available to the template renderer.
    final componentsLookup = <String, String Function(Map<Object?, Object?>)>{};
    for (final entry in context.components.entries) {
      componentsLookup[entry.key] = ([Map<Object?, Object?>? vars]) {
        if (vars != null) {
          for (final varEntry in vars.entries) {
            String replaceBrackets = varEntry.value as String;
            replaceBrackets = replaceBrackets.replaceAll("<", "&lt;");
            replaceBrackets = replaceBrackets.replaceAll(">", "&gt;");
            vars[varEntry.key] = replaceBrackets;
          }
        }

        final componentData = <String, Object?>{
          ...page.data,
          ...context.pagesIndex.buildPageIndexDataForTemplates(),
          "components": {
            // Maps component name to a factory method: "footer": () -> "<div>...</div>"
            ...componentsLookup,
          },
          if (vars != null) ...vars.cast(),
        };

        final template = Template(
          entry.value.content,
          filters: jinjaFilters,
          tests: jinjaTests,
        );
        String component = template.render(componentData);
        return component;
      };
    }

    // Assemble all data that should be available to the page during template rendering.
    final pageData = {
      ...page.data,
      if (content != null) //
        "content": content,
      ...context.templateFunctions,
      ...context.pagesIndex.buildPageIndexDataForTemplates(),
      "components": {
        // Maps component name to a factory method: "footer": () -> "<div>...</div>"
        ...componentsLookup,
      },
    };

    // Render the template.
    final template = Template(
      templateSource,
      filters: jinjaFilters,
      tests: jinjaTests,
    );

    late final String hydratedLayout;
    try {
      hydratedLayout = template.render(pageData);
    } catch (exception) {
      _log.err("Failed to hydrate template for page: ${page.title}");
      _log.err("Error: $exception");
      _log.warn("Available data:");
      for (final entry in pageData.entries) {
        _log.warn(" - ${entry.key}: ${entry.value}");
      }

      rethrow;
    }

    // Set the page's final content to the newly hydrated layout, and set the extension to HTML.
    page.destinationContent = hydratedLayout;
  }

  bool _startsWith(String? candidate, String? prefix) {
    if (candidate == null || prefix == null) {
      return false;
    }
    return candidate.startsWith(prefix);
  }

  /// Jinja filter that formats an incoming date string.
  ///
  /// The incoming format defaults to "yyyy-MM-dd", but an alternative
  /// incoming format can be provided in [from].
  ///
  /// The returned date string follows the [to] format, which is required.
  ///
  /// This filter might be used, for example, to replace "2024-02-15" with
  /// "Feb 15, 2024".
  String _formatDateTime(
    String date, {
    String from = "yyyy-MM-dd",
    required String to,
  }) {
    final dateTime = DateFormat(from).parse(date);
    return DateFormat(to).format(dateTime);
  }

  /// A Jinja filter that returns the first [count] items from the given list.
  List _take(List incoming, int count) => incoming.sublist(0, min(count, incoming.length));

  /// A Jinja filter (with a [Page] for context), which treats [relativePath] as a path
  /// that's relative the [page], and returns the full URL path that combines the two.
  ///
  /// Example:
  ///  - Page URL: `/posts/my-article/index.html`
  ///  - relativePath: `images/my-photo.png`
  ///  - return value: `/posts/my-article/images/my-photo.png`
  String _pathRelativeToPage(Page page, String relativePath) {
    final pageUrl = Uri.parse(page.url!);
    return pageUrl.resolve(relativePath).path;
  }
}
