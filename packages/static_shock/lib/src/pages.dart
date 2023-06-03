import 'destination_files.dart';
import 'source_files.dart';

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

  Map<String, dynamic> buildDataForPage(Map<String, dynamic> globalData, String subPath, String contentHtml) {
    Page? targetPage;
    for (final page in _pages) {
      if (page.sourceFile.subPath == subPath) {
        targetPage = page;
        break;
      }
    }

    return {
      ...globalData,
      "pages": {
        "byTag": (String tag) {
          print("Running tag search: $tag");

          return _pages.where((page) => page.data.hasTag(tag)).map((page) => {
                "data": {
                  "title": page.data.title,
                  "url": page.data.url,
                },
              });
        },
      },
      if (targetPage != null) //
        ...targetPage.data.toMap(),
      "content": contentHtml,
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
  const Page({
    required this.sourceFile,
    required this.data,
    this.destinationFile,
  });

  final SourceFile sourceFile;
  String get extension => sourceFile.extension;

  final PageData data;

  final DestinationFile? destinationFile;

  @override
  String toString() => "[Page] - source: ${sourceFile.subPath}";

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Page && runtimeType == other.runtimeType && sourceFile == other.sourceFile;

  @override
  int get hashCode => sourceFile.hashCode;
}

class PageData {
  final _data = <String, dynamic>{
    "tags": <String>[],
  };

  String? get title => _data["title"];
  set title(String? title) => _data["title"] = title;

  // TODO: is this a full URL? or sub-path? add appropriate comment, and maybe rename
  String? get url => _data["url"];
  set url(String? url) => _data["url"];

  // TODO: is this the layout file path, or the layout content? add appropriate comment
  String? get layout => _data["layout"];
  set layout(String? layout) => _data["layout"] = layout;

  bool hasTag(String tag) => tags.contains(tag);
  bool hasTags(Set<String> tags) => tags.containsAll(tags);
  Set<String> get tags => _data["tags"];
  set tags(Set<String> tags) => _data["tags"] = tags;
  void addTag(String tag) => tags.add(tag);
  void removeTag(String tag) => tags.remove(tag);

  DateTime? get createdAt => _data["createdAt"];
  set createdAt(DateTime? createdAt) => _data["createdAt"] = createdAt;

  DateTime? get updatedAt => _data["updatedAt"];
  set updatedAt(DateTime? updatedAt) => _data["updatedAt"] = updatedAt;

  String? get content => _data["content"];
  set content(String? content) => _data["content"] = content;

  // TODO: components
  //  - need to be accessible via ["components"] for template, and that needs to return a render function
  //  - probably also want people to be able to add components to this set?

  Object? operator [](String key) => _data[key];

  Map<String, dynamic> toMap() => Map.from(_data);
}
