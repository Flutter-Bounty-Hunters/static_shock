import 'dart:async';
import 'dart:io';

import 'package:jinja/jinja.dart';
import 'package:mason_logger/mason_logger.dart';
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

  final List<StaticShockJinjaFunctionBuilder> filters;
  final List<StaticShockJinjaFunctionBuilder> tests;

  @override
  FutureOr<void> configure(StaticShockPipeline pipeline, StaticShockPipelineContext context) {
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
        if (entry.key is! String) {
          continue;
        }
        frontMatter[entry.key] = entry.value;
      }
    }

    return Page(
      path,
      trimmedContent,
      data: {...frontMatter},
      destinationPath: path.copyWith(extension: "html"),
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
  FutureOr<void> renderPage(StaticShockPipelineContext context, Page page) async {
    if (page.sourcePath.extension.toLowerCase() == "jinja") {
      _renderJinjaContent(context, page);
    } else {
      _renderJinjaLayout(context, page);
    }
  }

  void _renderJinjaContent(StaticShockPipelineContext context, Page page) {
    _log.detail("Rendering Jinja layout page (${page.sourcePath})");
    _renderJinjaToContent(context, page, page.sourceContent);
  }

  void _renderJinjaLayout(StaticShockPipelineContext context, Page page) {
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
    _renderJinjaToContent(context, page, layout.value);
  }

  void _renderJinjaToContent(StaticShockPipelineContext context, Page page, String templateSource) {
    final jinjaFilters = Map.fromEntries([
      MapEntry("startsWith", (String? candidate, String? prefix) {
        print("startsWith - candidate: '$candidate', prefix: '$prefix'");
        if (candidate == null || prefix == null) {
          return false;
        }
        return candidate.startsWith(prefix);
      }),
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

    // Generate the layout, filled with content and data.
    final template = Template(
      templateSource,
      filters: jinjaFilters,
      tests: jinjaTests,
    );

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
          if (vars != null) ...vars.cast(),
        };

        print("Components data:");
        print("$componentData");

        final template = Template(
          entry.value.content,
          filters: jinjaFilters,
          tests: jinjaTests,
        );
        String component = template.render(componentData);
        return component;
      };
    }

    final pageData = {
      ...page.data,
      "content": page.destinationContent ?? page.sourceContent,
      ...context.templateFunctions,
      ...context.pagesIndex.buildPageIndexDataForTemplates(),
      "components": {
        // Maps component name to a factory method: "footer": () -> "<div>...</div>"
        ...componentsLookup,
      },
    };

    print("Page data");
    print(" - incoming page.data[url]: ${page.data['url']}");
    print(" - outgoing pageData[url]: ${pageData['url']}");
    print("");

    final hydratedLayout = template.render(pageData);

    // Set the page's final content to the newly hydrated layout, and set the extension to HTML.
    page.destinationContent = hydratedLayout;
  }
}
