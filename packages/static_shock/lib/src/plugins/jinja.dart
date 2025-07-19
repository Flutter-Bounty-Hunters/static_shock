import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
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
        // Note: assign "pagePath" before including frontMatter so that the frontMatter can override it.
        PageKeys.pagePath: destinationPath.value,
        if (!frontMatter.containsKey(PageKeys.contentRenderers)) //
          PageKeys.contentRenderers: ["jinja"],
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
    if (page.data[PageKeys.layout] == null ||
        page.data[PageKeys.layout].trim().isEmpty ||
        page.data[PageKeys.layout].trim().toLowerCase() == "none") {
      return;
    }

    // Treat the page's source content as content to be injected in the specified layout.
    final layoutPathString = page.data[PageKeys.layout] as String?;
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
    final basePath = context.dataIndex.basePath;

    final jinjaFilters = Map.fromEntries([
      MapEntry(
        JinjaFilterKeys.localLink,
        _createLocalLinkFilter(basePath),
      ),
      MapEntry(JinjaFilterKeys.startsWith, _startsWith),
      MapEntry(JinjaFilterKeys.formatDateTime, _formatDateTime),
      MapEntry(JinjaFilterKeys.take, _take),
      MapEntry(JinjaFilterKeys.pathRelativeToPage, (String relativePath) => _pathRelativeToPage(page, relativePath)),
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
            if (varEntry.value is String) {
              String replaceBrackets = varEntry.value as String;
              replaceBrackets = replaceBrackets.replaceAll("<", "&lt;");
              replaceBrackets = replaceBrackets.replaceAll(">", "&gt;");
              vars[varEntry.key] = replaceBrackets;
            }
          }
        }

        final componentData = <String, Object?>{
          ...page.data,
          ...context.pagesIndex.buildPageIndexDataForTemplates(basePath: basePath),
          JinjaTemplateKeys.components: {
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
    final globalPageFunctions = <String, Function>{
      JinjaTestKeys.isCurrentPage: (String urlPath) => _isCurrentPage(page, urlPath),
    };

    final pageData = {
      ...page.data,
      JinjaTemplateKeys.url: page.makeUrl(basePath),
      if (content != null) //
        JinjaTemplateKeys.content: content,
      ...globalPageFunctions,
      ...context.templateFunctions,
      ...context.pagesIndex.buildPageIndexDataForTemplates(basePath: basePath),
      JinjaTemplateKeys.components: {
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

      _log.warn("Available filters:");
      for (final entry in jinjaFilters.entries) {
        _log.warn(" - ${entry.key}: ${entry.value}");
      }
      _log.warn("");

      _log.warn("Available tests:");
      for (final entry in jinjaTests.entries) {
        _log.warn(" - ${entry.key}: ${entry.value}");
      }
      _log.warn("");

      _log.warn("Available data:");
      for (final entry in pageData.entries) {
        _log.warn(" - ${entry.key}: ${entry.value}");
      }

      rethrow;
    }

    // Set the page's final content to the newly hydrated layout, and set the extension to HTML.
    page.destinationContent = hydratedLayout;
  }

  String Function(String pagePage) _createLocalLinkFilter(String websiteBasePath) {
    return (String pagePath) {
      final localPath = pagePath.startsWith("/") //
          ? pagePath.substring(1)
          : pagePath;

      return "$websiteBasePath$localPath";
    };
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
  ///  - Page URL: `posts/my-article/index.html`
  ///  - relativePath: `images/my-photo.png`
  ///  - return value: `posts/my-article/images/my-photo.png`
  String _pathRelativeToPage(Page page, String relativePath) {
    final pageUrl = Uri.parse(page.pagePath!);
    return pageUrl.resolve(relativePath).path;
  }

  /// A global function available to a page, which returns `true` if the
  /// given [urlPath] is the path of the current [page], or `false` otherwise.
  ///
  /// This is useful for activating menu items when viewing the page for that
  /// menu item.
  bool _isCurrentPage(Page page, String urlPath) {
    final pageUrlWithTrailingSlash = page.pagePath!;
    final pageUrlNoTrailingSlash = pageUrlWithTrailingSlash.substring(0, pageUrlWithTrailingSlash.length - 1);

    return pageUrlNoTrailingSlash == urlPath || pageUrlNoTrailingSlash == urlPath;
  }
}

abstract class JinjaTemplateKeys {
  static const url = "url";
  static const content = "content";
  static const components = "components";
}

abstract class JinjaFilterKeys {
  static const localLink = "local_link";
  static const pathRelativeToPage = "pathRelativeToPage";
  static const formatDateTime = "formatDateTime";
  static const take = "take";
  static const startsWith = "startsWith";
}

abstract class JinjaTestKeys {
  static const isCurrentPage = "isCurrentPage";
}

extension on PagesIndex {
  /// Returns a data structure which represents a "page index" within a Jinja template.
  ///
  /// For example, when the returned data structure is added to a Jinja context, a developer
  /// can list all pages with a "flutter" tag as follows:
  ///
  /// ```jinja
  /// <body>
  ///   <ul>
  ///     {% for page in pages.byTag("flutter") %}
  ///       <li>
  ///         <a href="{{ page.data['url'] }}">{{ page.data['title'] }}</a>
  ///       </li>
  ///     {% endfor %}
  ///   </ul>
  /// </body>
  /// ```
  ///
  Map<String, dynamic> buildPageIndexDataForTemplates({
    required String basePath,
  }) {
    return {
      "pages": {
        "hasPageWithUrl": _hasPageWithUrl,
        "hasPagesAtPath": _hasPagesAtPath,
        "all": ({
          String? sortBy,
        }) =>
            _all(basePath: basePath, sortBy: sortBy),
        "byTag": (
          String tag, {
          String? sortBy,
        }) =>
            _byTag(tag, basePath: basePath, sortBy: sortBy),
      },
    };
  }

  /// Returns `true` if a page exists with a destination path that's the same as the given
  /// [path].
  bool _hasPageWithUrl(String path) {
    return pages.firstWhereOrNull(
            (page) => page.destinationPath?.value == path || page.destinationPath?.value == "${path}index.html") !=
        null;
  }

  /// Returns `true` if at least one page has a destination path that begins with [path].
  bool _hasPagesAtPath(String path) {
    return pages.firstWhereOrNull((page) => page.destinationPath?.value.startsWith(path) == true) != null;
  }

  /// Return an `Iterable` of page data for all pages, optionally ordered by [sortBy].
  ///
  /// {@macro sortBy}
  Iterable<Map<String, dynamic>> _all({
    required String basePath,
    String? sortBy,
  }) {
    final indexedPages = pages.where((page) => page.data[PageKeys.shouldIndex] != false).toList();

    final pageSorter = _PageSorter.parseSortBy(sortBy);
    indexedPages.sort(pageSorter.compare);

    return indexedPages.map((page) => _serializePage(page, basePath));
  }

  /// Return an `Iterable` of page data for all pages with the given [tag], optionally
  /// ordered by [sortBy].
  ///
  /// {@macro sortBy}
  Iterable<Map<String, dynamic>> _byTag(
    String tag, {
    required String basePath,
    String? sortBy,
  }) {
    final taggedPages = pages.where((page) => page.hasTag(tag) && page.data[PageKeys.shouldIndex] != false).toList();

    final pageSorter = _PageSorter.parseSortBy(sortBy);
    taggedPages.sort(pageSorter.compare);

    return taggedPages.map((page) => _serializePage(page, basePath));
  }

  Map<String, dynamic> _serializePage(Page page, String basePath) => {
        "data": {
          ...page.data,
          JinjaTemplateKeys.url: page.makeUrl(basePath),
        },
      };
}

/// Sorts [Page]s based on a priority order of [_SortProperty]s.
///
/// Each property is applied, in order, until one of them reports that one page
/// is greater than or less than another page. Each [_SortProperty] also states
/// its desired sort order.
class _PageSorter {
  /// Parses and encoded [sortBy] string to a [_PageSorter].
  ///
  /// {@template sortBy}
  /// [sortBy] is an encoded value, which might contain multiple priority
  /// ordered sort properties, e.g., "date=desc title=asc".
  /// {@endtemplate}
  static _PageSorter parseSortBy(String? sortBy) {
    if (sortBy == null) {
      return _PageSorter([]);
    }

    final propertiesToSortBy = sortBy
        .split(RegExp(r"\s+")) //
        .map((encodedSortProperty) => _SortProperty.parse(encodedSortProperty))
        .toList();

    return _PageSorter(propertiesToSortBy);
  }

  const _PageSorter(this._sortProperties);

  final List<_SortProperty> _sortProperties;

  int compare(Page a, Page b) {
    for (final property in _sortProperties) {
      final aProperty = a.data[property.name];
      final bProperty = b.data[property.name];

      if (bProperty == null || bProperty is! Comparable) {
        // Page b doesn't have the property we're sorting by, or that
        // property can't be compared. Put it at the end.
        return -1;
      }

      if (aProperty == null || aProperty is! Comparable) {
        // Page a doesn't have the property we're sorting by, or that
        // property can't be compared. Put it at the end.
        return 1;
      }

      final comparison = aProperty.compareTo(bProperty);
      if (comparison == 0) {
        // The properties are equivalent. Continue to the next lower priority
        // property and look for a difference there.
        continue;
      }

      if (comparison < 0) {
        // Page a naturally comes before Page b. Return a comparator value
        // based on the desired sort order.
        if (property.sortOrder == _SortOrder.ascending) {
          // Return the natural order.
          return -1;
        } else {
          // Flip the order.
          return 1;
        }
      } else {
        // Page b naturally comes before Page a. Return a comparator value
        // based on the desired sort order.
        if (property.sortOrder == _SortOrder.ascending) {
          // Return the natural order.
          return 1;
        } else {
          // Flip the order.
          return -1;
        }
      }
    }

    // We didn't find any difference in sort order across any of the given
    // sort properties. Therefore, both of these items have an equivalent
    // sort order.
    return 0;
  }
}

/// A page property, combined with a sorting order for that property.
///
/// The user can request a specific page ordering by providing a priority
/// list of [_SortProperty]s.
class _SortProperty {
  /// Parses an encoded sort property to a `SortProperty`, e.g.,
  /// "date=desc".
  static _SortProperty parse(String encodedSortProperty) {
    if (!encodedSortProperty.contains("=")) {
      // This property is just the name, e.g., "date" - it doesn't have
      // an explicit sort order. Return the property with the given name
      // and default sort order.
      return _SortProperty(encodedSortProperty);
    }

    final pieces = encodedSortProperty.split("=");
    if (pieces.length > 2) {
      throw Exception(
        "Tried to sort by invalid property value '$encodedSortProperty' - only one '=' can appear in a sort property.",
      );
    }

    final sortOrder = _SortOrder.fromName(pieces.last);
    if (sortOrder == null) {
      throw Exception(
        "Tried to sort by invalid property value '$encodedSortProperty' - invalid sort order: '${pieces.last}'",
      );
    }

    return _SortProperty(pieces.first, sortOrder);
  }

  const _SortProperty(this.name, [this.sortOrder = _SortOrder.ascending]);

  final String name;
  final _SortOrder sortOrder;
}

enum _SortOrder {
  ascending,
  descending;

  /// Parses the given [name] and returns the corresponding [_SortOrder], or returns
  /// `null` if the [name] doesn't correspond to a sort order.
  static _SortOrder? fromName(String name) {
    name = name.toLowerCase();
    if (name == "asc" || name == "ascending") {
      return _SortOrder.ascending;
    }
    if (name == "desc" || name == "descending") {
      return _SortOrder.descending;
    }

    return null;
  }
}
