import 'dart:async';

import 'package:collection/collection.dart';

import 'files.dart';
import 'pipeline.dart';

abstract class PageLoader {
  bool canLoad(FileRelativePath path);

  FutureOr<Page> loadPage(FileRelativePath path, String content);
}

abstract class PageTransformer {
  FutureOr<void> transformPage(StaticShockPipelineContext context, Page page);
}

abstract class PageFilter {
  bool shouldInclude(StaticShockPipelineContext context, Page page);
}

abstract class PageRenderer {
  /// Globally unique ID for this renderer, which is used to identify which pages
  /// should be rendered by this renderer.
  ///
  /// A single page might be rendered by multiple renderers. The page selects the
  /// order of rendering by specifying a list of renderer IDs.
  String get id;

  /// Renders source content by applying some kind of transcoding or template replacements
  /// to [page.sourceContent].
  ///
  /// Examples:
  ///  - Markdown is rendered to HTML
  ///  - Jinja templates are executed, such as value substitution.
  ///
  /// When this method renders content, the content is stored in [page.destinationContent].
  FutureOr<void> renderContent(StaticShockPipelineContext context, Page page);

  /// Applies a layout template to the [page], if desired.
  ///
  /// Some pages have content that's separate from layout. For example, a Markdown page specifies
  /// its content as Markdown, but expects that content to be placed within a broader layout
  /// template, such as a full-page Jinja template. This method does that.
  ///
  /// However, not all pages separate content from layout. For example, a page might consist of
  /// a combination of HTML and Jinja templating. For such a page, the content is the layout.
  /// In that case, the relevant rendering takes place in [renderContent], and this method does
  /// nothing.
  FutureOr<void> renderLayout(StaticShockPipelineContext context, Page page);
}

class PagesIndex {
  PagesIndex();

  Iterable<Page> get pages => List.from(_pages);
  final List<Page> _pages = [];

  void addPages(Iterable<Page> pages) {
    for (final page in pages) {
      addPage(page);
    }
  }

  void addPage(Page page) {
    _pages.add(page);
  }

  void removePage(Page page) {
    _pages.remove(page);
  }

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
  Map<String, dynamic> buildPageIndexDataForTemplates() {
    return {
      "pages": {
        "hasPageWithUrl": _hasPageWithUrl,
        "hasPagesAtPath": _hasPagesAtPath,
        "all": _all,
        "byTag": _byTag,
      },
    };
  }

  /// Returns `true` if a page exists with a destination path that's the same as the given
  /// [path].
  bool _hasPageWithUrl(String path) {
    return _pages.firstWhereOrNull(
            (page) => page.destinationPath?.value == path || page.destinationPath?.value == "${path}index.html") !=
        null;
  }

  /// Returns `true` if at least one page has a destination path that begins with [path].
  bool _hasPagesAtPath(String path) {
    return _pages.firstWhereOrNull((page) => page.destinationPath?.value.startsWith(path) == true) != null;
  }

  /// Return an `Iterable` of page data for all pages, optionally ordered by [sortBy].
  ///
  /// {@macro sortBy}
  Iterable<Map<String, dynamic>> _all({
    String? sortBy,
  }) {
    final pages = _pages.where((page) => page.data["shouldIndex"] != false).toList();

    final pageSorter = _PageSorter.parseSortBy(sortBy);
    pages.sort(pageSorter.compare);

    return pages.map(_serializePage);
  }

  /// Return an `Iterable` of page data for all pages with the given [tag], optionally
  /// ordered by [sortBy].
  ///
  /// {@macro sortBy}
  Iterable<Map<String, dynamic>> _byTag(
    String tag, {
    String? sortBy,
  }) {
    final pages = _pages.where((page) => page.hasTag(tag) && page.data["shouldIndex"] != false).toList();

    final pageSorter = _PageSorter.parseSortBy(sortBy);
    pages.sort(pageSorter.compare);

    return pages.map(_serializePage);
  }

  Map<String, dynamic> _serializePage(Page page) => {
        "data": page.data,
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

class Page {
  Page(
    this.sourcePath,
    this.sourceContent, {
    Map<String, dynamic>? data,
    this.destinationPath,
    this.destinationContent,
  }) : data = data ?? {} {
    if (this.data["tags"] is String) {
      this.data["tags"] = [(this.data["tags"] as String)];
    }
  }

  final FileRelativePath sourcePath;
  final String sourceContent;
  final Map<String, dynamic> data;

  FileRelativePath? destinationPath;
  String? destinationContent;

  // TODO: decide if these properties should exist on Page, or if we should have a PageData sub-object
  String? get title => data["title"];

  String? get url => data["url"];
  set url(String? url) => data["url"] = url;

  List<String> get contentRenderers {
    final renderers = data["contentRenderers"];
    if (renderers == null) {
      return [];
    }

    if (renderers is String) {
      // There's exactly one renderer. Return it.
      return [renderers];
    }

    // A list of renderers was requested.
    return List.from(
      // Note: We map the value and cast each renderer ID because the data might be a YamlList,
      // which isn't a typed list. We'll get an exception if we try to return `List<String>`.
      data["contentRenderers"].map((rendererId) => rendererId as String),
    );
  }

  bool hasTag(String tag) => tags.contains(tag);
  List<String> get tags =>
      data["tags"] != null ? List.from(data["tags"] is List ? data["tags"] : [data["tags"] as String]) : [];

  String describe() {
    return '''Page:
Source: "$sourcePath"
Destination: "$destinationPath"

Data: 
$data

Source Content:
$sourceContent

Destination Content:
$destinationContent
''';
  }

  /// Returns a copy of this [Page].
  ///
  /// The [data] is shallow-copied from the original [Page].
  Page copy() {
    return Page(
      sourcePath,
      sourceContent,
      destinationPath: destinationPath,
      destinationContent: destinationContent,
      data: Map.from(data),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Page && runtimeType == other.runtimeType && sourcePath == other.sourcePath;

  @override
  int get hashCode => sourcePath.hashCode;

  @override
  String toString() => "[Page] - source: $sourcePath, destination: $destinationPath";
}
