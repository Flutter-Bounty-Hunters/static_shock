import 'dart:async';

import 'files.dart';
import 'pipeline.dart';

abstract class PageLoader {
  bool canLoad(FileRelativePath path);

  FutureOr<Page> loadPage(FileRelativePath path, String content);
}

abstract class PageTransformer {
  FutureOr<void> transformPage(StaticShockPipelineContext context, Page page);
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
        "all": _all,
        "byTag": _byTag,
      },
    };
  }

  /// Return an `Iterable` of page data for all pages, optionally ordered by [sortBy].
  Iterable<Map<String, dynamic>> _all({
    String? sortBy,
  }) {
    if (sortBy != null && sortBy.isNotEmpty) {
      _ensurePagesHaveSortingProperty(sortBy);
    }

    final allPagesSorted = _pages.toList()..sort(_sortPages(sortBy));
    return allPagesSorted.map(_serializePage);
  }

  /// Return an `Iterable` of page data for all pages with the given [tag], optionally
  /// ordered by [sortBy].
  Iterable<Map<String, dynamic>> _byTag(
    String tag, {
    String? sortBy,
  }) {
    if (sortBy != null && sortBy.isNotEmpty) {
      _ensurePagesHaveSortingProperty(sortBy);
    }

    final pages = _pages.where((page) => page.hasTag(tag)).toList()..sort(_sortPages(sortBy));
    return pages.map(_serializePage);
  }

  void _ensurePagesHaveSortingProperty(String sortBy) {
    final allPagesHaveProperty =
        _pages.fold(true, (hasProperty, element) => hasProperty && element.data[sortBy] != null);
    if (!allPagesHaveProperty) {
      throw Exception("Tried to sort pages by '$sortBy' but not all pages have that property!");
    }
  }

  /// Returns a sorting function for [Page]s based on each [Page]'s [sortBy] property.
  ///
  /// For example, assume that every [Page] has a property called `index`. This method
  /// would be called as follows:
  ///
  ///     final sortFunction = _sortPages("index");
  ///
  /// The `sortFunction` would say that Page A < Page B when `index` A < `index` B.
  int Function(Page, Page) _sortPages(String? sortBy) {
    if (sortBy == null || sortBy.isEmpty) {
      return (Page a, Page b) => -1;
    }

    return (Page a, Page b) => a.data[sortBy] <= b.data[sortBy] ? -1 : 1;
  }

  Map<String, dynamic> _serializePage(Page page) => {
        "data": page.data,
      };
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
  List<String> get tags => data["tags"] != null ? List.from(data["tags"]) : [];

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
