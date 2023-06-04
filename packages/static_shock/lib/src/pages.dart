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

  Map<String, dynamic> buildPageIndexDataForTemplates() {
    return {
      "pages": {
        "byTag": (String tag) {
          return _pages.where((page) => page.hasTag(tag)).map(
                (page) => {
                  "data": page.data,
                },
              );
        },
      },
    };
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
