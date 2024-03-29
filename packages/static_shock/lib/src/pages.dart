import 'dart:async';

import 'package:collection/collection.dart';
import 'package:mason_logger/mason_logger.dart';

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
  FutureOr<void> renderPage(StaticShockPipelineContext context, Page page);
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
    print("Looking for path at path: '$path'");
    for (final page in _pages) {
      print(" - page path: '${page.destinationPath}'");
    }
    return _pages.firstWhereOrNull(
            (page) => page.destinationPath?.value == path || page.destinationPath?.value == "${path}index.html") !=
        null;
  }

  /// Returns `true` if at least one page has a destination path that begins with [path].
  bool _hasPagesAtPath(String path) {
    return _pages.firstWhereOrNull((page) => page.destinationPath?.value.startsWith(path) == true) != null;
  }

  /// Return an `Iterable` of page data for all pages, optionally ordered by [sortBy].
  Iterable<Map<String, dynamic>> _all({
    String? sortBy,
    String order = "asc",
  }) {
    final allPagesSorted = _pages.toList() //
      ..sort(_sortPages(sortBy, _parseSortOrder(order)));
    return allPagesSorted.map(_serializePage);
  }

  /// Return an `Iterable` of page data for all pages with the given [tag], optionally
  /// ordered by [sortBy].
  Iterable<Map<String, dynamic>> _byTag(
    String tag, {
    String? sortBy,
    String order = "asc",
  }) {
    final pages = _pages.where((page) => page.hasTag(tag)).toList() //
      ..sort(_sortPages(sortBy, _parseSortOrder(order)));
    return pages.map(_serializePage);
  }

  _SortOrder _parseSortOrder(String order) {
    final sortOrder = _SortOrder.fromName(order);
    if (sortOrder != null) {
      return sortOrder;
    }

    _log.warn("WARNING: Received unknown name for sort order: '$order'");
    return _SortOrder.ascending;
  }

  /// Returns a sorting function for [Page]s based on each [Page]'s [sortBy] property.
  ///
  /// For example, assume that every [Page] has a property called `index`. This method
  /// would be called as follows:
  ///
  ///     final sortFunction = _sortPages("index");
  ///
  /// The `sortFunction` would say that Page A < Page B when `index` A < `index` B.
  int Function(Page, Page) _sortPages(String? sortBy, _SortOrder sortOrder) {
    if (sortBy == null || sortBy.isEmpty) {
      return (Page a, Page b) => -1;
    }

    return (Page a, Page b) {
      switch (sortOrder) {
        case _SortOrder.ascending:
          if (a.data[sortBy] == null) {
            // The first item doesn't have the sorted property - show it last.
            return 1;
          }
          if (b.data[sortBy] == null) {
            // The second item doesn't have the sorted property - show it last.
            return -1;
          }

          return a.data[sortBy].compareTo(b.data[sortBy]);
        case _SortOrder.descending:
          if (a.data[sortBy] == null) {
            // The first item doesn't have the sorted property - show it first (because descending).
            return -1;
          }
          if (b.data[sortBy] == null) {
            // The second item doesn't have the sorted property - show it first (because descending).
            return 1;
          }

          return b.data[sortBy].compareTo(a.data[sortBy]);
      }
    };
  }

  Map<String, dynamic> _serializePage(Page page) => {
        "data": page.data,
      };
}

enum _SortOrder {
  ascending,
  descending;

  /// Parses the given [name] and returns the corresponding [_SortOrder], or returns
  /// `null` if the [name] doesn't correspond to a sort order.
  static _SortOrder? fromName(String name) {
    if (name == "asc" || name == "ascending") {
      return _SortOrder.ascending;
    }
    if (name == "desc" || name == "descending") {
      return _SortOrder.descending;
    }

    return null;
  }
}

class PageIndex {
  factory PageIndex.from(PagesIndex sourceData) {
    final pageIndex = PageIndex._();

    for (final page in sourceData.pages) {
      final tags = page.data["tags"];
      if (tags == null || tags is! List) {
        continue;
      }

      for (final tag in tags) {
        if (tag is! String) {
          continue;
        }

        pageIndex._tags[tag] ??= <Page>[];
        pageIndex._tags[tag]!.add(page);
      }
    }

    return pageIndex;
  }

  PageIndex._();

  final Map<String, List<Page>> _tags = {};

  List<Page> byTag(Set<String> tags) {
    final pages = <Page>{};
    for (final tag in tags) {
      pages.addAll(_tags[tag] ?? {});
    }
    return pages.toList();
  }
}

class Page {
  Page(
    this.sourcePath,
    this.sourceContent, {
    Map<String, dynamic>? data,
    this.destinationPath,
    this.destinationContent,
  }) : data = data ?? {};

  final FileRelativePath sourcePath;
  final String sourceContent;
  final Map<String, dynamic> data;

  FileRelativePath? destinationPath;
  String? destinationContent;

  // TODO: decide if these properties should exist on Page, or if we should have a PageData sub-object
  String? get title => data["title"];

  String? get url => data["url"];
  set url(String? url) => data["url"] = url;

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Page && runtimeType == other.runtimeType && sourcePath == other.sourcePath;

  @override
  int get hashCode => sourcePath.hashCode;

  @override
  String toString() => "[Page] - source: $sourcePath, destination: $destinationPath";
}

final _log = Logger(level: Level.verbose);
