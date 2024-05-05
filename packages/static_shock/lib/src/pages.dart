import 'dart:async';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'files.dart';
import 'pipeline.dart';

abstract class PageLoader {
  bool canLoad(FileRelativePath path);

  FutureOr<Page> loadPage(FileRelativePath path, String content);
}

abstract class PageTransformer {
  FutureOr<void> transformPage(StaticShockPipelineContext context, Page page);
}

abstract class PageGenerator {
  FutureOr<void> generatePages(StaticShockPipelineContext context);
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

  /// Searches all pages using the given [rawQuery] and returns a list of pages that satisfy the
  /// search.
  List<Page> search(String rawQuery) {
    final query = SearchQuery.parse(rawQuery);
    return query.find(_pages);
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
        "search": (String query) => search(query).map((page) => _serializePage(page)),
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

@visibleForTesting
class SearchQuery {
  static final _equalConditionPattern = RegExp(r'''([^\s]+[^\^\?*<>]=([^\s'"]+|'.+'|".+"))''');
  static final _notEqualConditionPattern = RegExp(r'''([^\s]+\^=([^\s'"]+|'.+'|".+"))''');
  static final _containsConditionPattern = RegExp(r'''([^\s]+\*=([^\s'"]+|'.+'|".+"))''');
  static final _lessThanEqualConditionPattern = RegExp(r'''([^\s]+<=([^\s'"]+|'.+'|".+"))''');
  static final _lessThanConditionPattern = RegExp(r'''([^\s]+<([^=\s'"]+|'.+'|".+"))''');
  static final _greaterThanEqualConditionPattern = RegExp(r'''([^\s]+>=([^\s'"]+|'.+'|".+"))''');
  static final _greaterThanConditionPattern = RegExp(r'''([^\s]+>([^=\s'"]+|'.+'|".+"))''');
  static final _tokenConditionPattern = RegExp(r'''^[^\s\^\?\*<>='"]+$''');
  static final _whitespace = RegExp(r"\s+");

  factory SearchQuery.parse(String query) {
    final parsedConditions = <PropertySearchCondition>[];
    parsedConditions.addAll(
      _equalConditionPattern.allMatches(query).map(
            (match) => PropertySearchCondition.parse(query.substring(match.start, match.end))!,
          ),
    );
    parsedConditions.addAll(
      _notEqualConditionPattern.allMatches(query).map(
            (match) => PropertySearchCondition.parse(query.substring(match.start, match.end))!,
          ),
    );
    parsedConditions.addAll(
      _containsConditionPattern.allMatches(query).map(
            (match) => PropertySearchCondition.parse(query.substring(match.start, match.end))!,
          ),
    );
    parsedConditions.addAll(
      _lessThanConditionPattern.allMatches(query).map(
            (match) => PropertySearchCondition.parse(query.substring(match.start, match.end))!,
          ),
    );
    parsedConditions.addAll(
      _lessThanEqualConditionPattern.allMatches(query).map(
            (match) => PropertySearchCondition.parse(query.substring(match.start, match.end))!,
          ),
    );
    parsedConditions.addAll(
      _greaterThanConditionPattern.allMatches(query).map(
            (match) => PropertySearchCondition.parse(query.substring(match.start, match.end))!,
          ),
    );
    parsedConditions.addAll(
      _greaterThanEqualConditionPattern.allMatches(query).map(
            (match) => PropertySearchCondition.parse(query.substring(match.start, match.end))!,
          ),
    );

    final tokens = query.split(_whitespace);
    for (final token in tokens) {
      if (_tokenConditionPattern.hasMatch(token)) {
        parsedConditions.add(PropertySearchCondition.parse(token)!);
      }
    }

    return SearchQuery(parsedConditions);
  }

  const SearchQuery(this.conditions);

  final List<PropertySearchCondition> conditions;

  List<Page> find(List<Page> allPages) {
    return allPages
        .where(
          (page) => conditions.every((condition) => condition.isSatisfied(page.data[condition.propertyName])),
        )
        .toList();
  }

  @override
  String toString() => "[SearchQuery] - ${conditions.join(", ")}";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchQuery &&
          runtimeType == other.runtimeType &&
          const DeepCollectionEquality().equals(conditions, other.conditions);

  @override
  int get hashCode => conditions.hashCode;
}

@visibleForTesting
class PropertySearchCondition {
  static PropertySearchCondition? parse(String condition) {
    for (final operator in SearchOperator.values) {
      if (condition.contains(operator.syntax)) {
        final pieces = condition.split(operator.syntax);
        return PropertySearchCondition(pieces.first, operator, _parseDiscriminator(pieces.last));
      }
    }

    // We didn't find any operator in the given condition. In that case, we assume that
    // the condition represents a desired tag. This grammar is a UX consideration. Tag
    // searching is so common that we don't want to require explicit reference to the
    // tag property.
    return PropertySearchCondition("tags", SearchOperator.contains, condition);
  }

  static Object? _parseDiscriminator(String discriminator) {
    if (discriminator.toLowerCase() == "null") {
      return null;
    }

    final integer = int.tryParse(discriminator);
    if (integer != null) {
      return integer;
    }

    final float = double.tryParse(discriminator);
    if (float != null) {
      return float;
    }

    // The discriminator is actually a string.
    if ((discriminator.startsWith("'") && discriminator.endsWith("'")) ||
        (discriminator.startsWith('"') && discriminator.endsWith('"'))) {
      // The string value is surrounded by quotes. Remove those quotes because
      // they're only relevant to the query encoding, not the value, itself.
      return discriminator.substring(1, discriminator.length - 1);
    }
    return discriminator;
  }

  const PropertySearchCondition(this.propertyName, this.operator, this.discriminator);

  /// The name of a property, e.g., "title", "url", "tags".
  final String propertyName;

  /// The condition operator, which applies to the [discriminator], e.g., "=", "*=", ">=", etc.
  final SearchOperator operator;

  /// The discriminator, which determines whether this condition is met, e.g., "Guides" for
  /// a title, "/archive" for a URL, "flutter" as a tag.
  final Object? discriminator;

  bool isSatisfied(Object? propertyValue) {
    switch (operator) {
      case SearchOperator.equals:
        return propertyValue == discriminator;
      case SearchOperator.startsWith:
        if (propertyValue is! String || discriminator is! String) {
          return false;
        }
        return propertyValue.startsWith(discriminator as String);
      case SearchOperator.endsWith:
        if (propertyValue is! String || discriminator is! String) {
          return false;
        }
        return propertyValue.endsWith(discriminator as String);
      case SearchOperator.contains:
        if (propertyValue is List) {
          return propertyValue.contains(discriminator);
        }
        if (propertyValue is String && discriminator is String) {
          return propertyValue.contains(discriminator as String);
        }
        return false;
      case SearchOperator.lessThanEqualTo:
        if (propertyValue is! num || discriminator is! num) {
          return false;
        }
        return propertyValue <= (discriminator as num);
      case SearchOperator.lessThan:
        if (propertyValue is! num || discriminator is! num) {
          return false;
        }
        return propertyValue < (discriminator as num);
      case SearchOperator.greaterThanEqualTo:
        if (propertyValue is! num || discriminator is! num) {
          return false;
        }
        return propertyValue >= (discriminator as num);
      case SearchOperator.greaterThan:
        if (propertyValue is! num || discriminator is! num) {
          return false;
        }
        return propertyValue > (discriminator as num);
    }
  }

  @override
  String toString() => "$propertyName${operator.syntax}$discriminator";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PropertySearchCondition &&
          runtimeType == other.runtimeType &&
          propertyName == other.propertyName &&
          operator == other.operator &&
          discriminator == other.discriminator;

  @override
  int get hashCode => propertyName.hashCode ^ operator.hashCode ^ discriminator.hashCode;
}

@visibleForTesting
enum SearchOperator {
  // Order of the following is important because we greedily try to match
  // each syntax in a condition. Notice that "<=" and "<" both contain a
  // "<". If we try to parse "value<=3" by first looking for a "<" then we'll
  // incorrectly treat the condition as "less than" instead of "less than or equal to".
  startsWith("^="),
  endsWith("\$="),
  contains("*="),
  lessThanEqualTo("<="),
  lessThan("<"),
  greaterThanEqualTo(">="),
  greaterThan(">"),
  equals("=");

  static SearchOperator? parse(String syntax) {
    for (final operator in SearchOperator.values) {
      if (operator.syntax == syntax) {
        return operator;
      }
    }

    return null;
  }

  const SearchOperator(this.syntax);

  final String syntax;
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
  Page({
    this.sourcePath,
    this.sourceContent,
    Map<String, dynamic>? data,
    this.destinationPath,
    this.destinationContent,
  }) : data = data ?? {};

  /// The path the source file that declares this page's initial structure, if this page is based on
  /// a source file.
  ///
  /// A dynamically generated page doesn't have a [sourcePath].
  final FileRelativePath? sourcePath;

  /// The page content that came from the source file that declares this page's initial structure, if
  /// this page is based on a source file.
  ///
  /// A dynamically generated page doesn't have [sourceContent].
  final String? sourceContent;

  /// The relative file path where this page will be written in the final build directory for the website.
  ///
  /// The final file will be filled with [destinationContent].
  FileRelativePath? destinationPath;

  /// The full content of this page, which will be written to the file at [destinationPath].
  String? destinationContent;

  /// Data that's specific to the rendering of this page.
  ///
  /// The [data] of this page is combined with inherited data from the [DataIndex], and is made available
  /// to the rendering engine when this page is rendered.
  final Map<String, dynamic> data;

  /// The title of this page.
  String? get title => data["title"];

  /// The relative path URL for this page, which determines the [destinationPath].
  String? get url => data["url"];
  set url(String? url) => data["url"] = url;

  /// A priority list of renderers, through which the page's content should move.
  ///
  /// Typically, a page only uses a single content renderer, such as a Markdown renderer to
  /// convert from Markdown to HTML. However, the Markdown content might include Jinja template
  /// values, in which case that page first needs to render with Jinja, and then render with Markdown.
  /// To do so, this list would be ["jinja", "markdown"].
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

  /// Returns `true` if this page contains the given [tag], or `false` otherwise.
  bool hasTag(String tag) => tags.contains(tag);

  /// Returns all tags in the [data] for this page.
  List<String> get tags =>
      data["tags"] != null ? List.from(data["tags"] is List ? data["tags"] : [data["tags"] as String]) : [];

  String describe() {
    return '''Page:
Source: "${sourcePath ?? "None"}"
Destination: "$destinationPath"

Data: 
$data

Source Content:
${sourceContent ?? "None"}

Destination Content:
$destinationContent
''';
  }

  /// Returns a copy of this [Page].
  ///
  /// The [data] is shallow-copied from the original [Page].
  Page copy() {
    return Page(
      sourcePath: sourcePath,
      sourceContent: sourceContent,
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
