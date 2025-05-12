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

  Iterable<Page> get pages => _pages;
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
}

class Page {
  Page(
    this.sourcePath,
    this.sourceContent, {
    Map<String, dynamic>? data,
    this.destinationPath,
    this.destinationContent,
  }) : data = data ?? {} {
    // Special support for tags. We want user to be able to write a single tag value
    // under "tags", but we also need tags to be mergeable as a list. Therefore, we
    // explicitly turn a single tag into a single-item tag list.
    //
    // This same conversion is done in data.dart
    // TODO: generalize this auto-conversion so that plugins can do the same thing.
    if (this.data[PageKeys.tags] is String) {
      this.data[PageKeys.tags] = [(this.data[PageKeys.tags] as String)];
    }
  }

  final FileRelativePath sourcePath;
  final String sourceContent;

  FileRelativePath? destinationPath;
  String? destinationContent;

  final Map<String, dynamic> data;

  String? get title => data[PageKeys.title];

  /// Creates an absolute URL path for this page, given a [basePath].
  ///
  /// The typical base path is `/`, but can be anything that a server
  /// wants it to be. Because the base path is out of our control, we
  /// can't report an absolute URL path per page, we can only construct
  /// one on demand, given the base path.
  String? makeUrl(String basePath) => pagePath != null ? "$basePath$pagePath" : null;

  /// The relative URL path to this page, from the website's base path.
  ///
  /// E.g., `getting-started/install/`. Notice no leading slash `/`.
  String? get pagePath => data[PageKeys.pagePath];
  set pagePath(String? pagePath) => data[PageKeys.pagePath] = pagePath;

  List<String> get contentRenderers {
    final renderers = data[PageKeys.contentRenderers];
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
      data[PageKeys.contentRenderers].map((rendererId) => rendererId as String),
    );
  }

  bool hasTag(String tag) => tags.contains(tag);
  List<String> get tags => data[PageKeys.tags] != null
      ? List.from(data[PageKeys.tags] is List ? data[PageKeys.tags] : [data[PageKeys.tags] as String])
      : [];

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

abstract class PageKeys {
  static const title = "title";
  static const layout = "layout";
  static const pagePath = "pagePath";
  static const content = "content";
  static const contentRenderers = "contentRenderers";
  static const tags = "tags";
  static const shouldIndex = "shouldIndex";
  static const redirectFrom = "redirectFrom";
}
