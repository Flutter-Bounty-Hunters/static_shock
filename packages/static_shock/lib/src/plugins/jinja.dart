import 'dart:async';
import 'dart:io';

import 'package:jinja/jinja.dart';
import 'package:markdown/markdown.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:static_shock/src/files.dart';
import 'package:static_shock/src/pages.dart';
import 'package:static_shock/src/pipeline.dart';
import 'package:static_shock/src/static_shock.dart';
import 'package:yaml/yaml.dart';

class JinjaPlugin implements StaticShockPlugin {
  const JinjaPlugin();

  @override
  FutureOr<void> configure(StaticShockPipeline pipeline, StaticShockPipelineContext context) {
    pipeline.pick(const ExtensionPicker("jinja"));
    pipeline.loadPages(JinjaPageLoader(context.log));
    pipeline.renderPages(JinjaPageRenderer(context.log));
  }
}

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
  const JinjaPageRenderer(this._log);

  final Logger _log;

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
    // Generate the layout, filled with content and data.
    final template = Template(templateSource);

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

        final template = Template(entry.value.content);
        String component = template.render(vars?.cast() ?? {});
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

    final hydratedLayout = template.render(pageData);

    // Set the page's final content to the newly hydrated layout, and set the extension to HTML.
    page.destinationContent = hydratedLayout;
  }
}
