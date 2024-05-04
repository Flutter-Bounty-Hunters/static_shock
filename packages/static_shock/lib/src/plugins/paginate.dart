import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:static_shock/src/data.dart';
import 'package:static_shock/src/files.dart';
import 'package:static_shock/src/pages.dart';
import 'package:static_shock/src/pipeline.dart';
import 'package:static_shock/src/static_shock.dart';

/// A [StaticShockPlugin] that generates multiple pages of search results for
/// given page queries.
///
/// For example, this plugin might be used to query "tag=article", retrieve 25
/// such pages, and then generate 3 pages of search results, totalling 10, 10, and
/// 5 results per page to cover the 25 total results.
///
/// Pagination requests can be provided directly to this plugin through [requests],
/// and/or requests can be declared in data.
///
/// Data request example:
///
/// ```yaml
/// paginate:
///   query: tag=articles
///   baseUrl: /articles
///   pageTitle: archive
///   itemsPerPage: 10
///   layout: article-archive.jinja
/// ```
///
/// The generated pages would be:
///
///   /articles/archive-0/index.html
///   /articles/archive-1/index.html
///   /articles/archive-2/index.html
///
class PaginatePlugin implements StaticShockPlugin {
  const PaginatePlugin({
    this.requests = const [],
  });

  final List<PaginationRequest> requests;

  @override
  FutureOr<void> configure(StaticShockPipeline pipeline, StaticShockPipelineContext context) {
    pipeline.generatePages(
      PaginatePageGenerator(requests),
    );
  }
}

class PaginatePageGenerator implements PageGenerator {
  const PaginatePageGenerator(this.requests);

  final List<PaginationRequest> requests;

  @override
  Future<void> generatePages(StaticShockPipelineContext context) async {
    final requests = _collectAllRequests(context.dataIndex);

    for (final request in requests) {
      await _paginate(context, request);
    }
  }

  Set<PaginationRequest> _collectAllRequests(DataIndex dataIndex) {
    return {
      ...requests,
      ..._findRequestsInData(dataIndex),
    };
  }

  Set<PaginationRequest> _findRequestsInData(DataIndex dataIndex) {
    final requests = <PaginationRequest>{};
    dataIndex.visitBreadthFirst((path, data) {
      if (data["paginate"] == null) {
        return;
      }

      final request = PaginationRequest.parseData(data["paginate"]);
      if (request == null) {
        print("ERROR: Bad paginate data configuration:");
        print(const JsonEncoder.withIndent("  ").convert(data["paginate"]));
        // TODO: warn the user with logger
        return;
      }

      requests.add(request);
    });

    return requests;
  }

  Future<void> _paginate(StaticShockPipelineContext context, PaginationRequest request) async {
    final List<Page> contentPages = context.pagesIndex.search(request.query);
    if (contentPages.isEmpty) {
      return;
    }

    final paginatedContentPages = contentPages.splitEvery(request.itemsPerPage);

    final searchResultPages = <Page>[];
    for (int i = 0; i < paginatedContentPages.length; i += 1) {
      // Create the search results page, and fill it with pagination data.
      searchResultPages.add(
        Page(
          data: {
            // Generic page data.
            "title": request.pageTitle,
            "url": _createSearchResultPageUrl(request.baseUrl, i),

            // Pagination data.
            "paginate": {
              "currentIndex": i,
              "pageCount": searchResultPages.length,
              "urlFor": _createUrlForFunction(request, searchResultPages),
              if (i > 0) //
                "previousPageUrl": _createSearchResultPageUrl(request.baseUrl, i - 1),
              if (i < paginatedContentPages.length - 1) //
                "nextPageUrl": _createSearchResultPageUrl(request.baseUrl, i + 1),
            }
          },
        ),
      );
    }
  }

  /// A function that creates and returns another function, which assembles the URL path for
  /// a search result page at any given index.
  Function _createUrlForFunction(PaginationRequest request, List<Page> searchResultPages) => (int pageIndex) {
        if (pageIndex < 0) {
          throw Exception(
            "Can't create a paginated URL for a page index < 0. Index $pageIndex was requested for paginated results for query '${request.query}'",
          );
        }
        if (pageIndex >= searchResultPages.length) {
          throw Exception(
            "Can't create a paginated URL for a page index that exceeds the number of pages. Index $pageIndex was requested for paginated results for query '${request.query}', but there are only ${searchResultPages.length} result pages.",
          );
        }

        return _createSearchResultPageUrl(request.baseUrl, pageIndex);
      };
}

FileRelativePath _createSearchResultPageUrl(DirectoryRelativePath baseUrl, int pageIndex) {
  // Note: +1 on pageIndex so that page "0" becomes page "1".
  return FileRelativePath(baseUrl.value, "${pageIndex + 1}", "html");
}

extension<T> on List<T> {
  List<List<T>> splitEvery(int count) {
    final groupList = <List<T>>[];
    int index = 0;
    while (index < length - 1) {
      groupList.add(sublist(index, min(index + count, length)));
    }

    return groupList;
  }
}

/// A request to paginate results for a given [query].
///
/// Each page of search results are then rendered to a generated page based on the given
/// [baseUrl], with [itemsPerPage], displaying search results within the given [layout].
class PaginationRequest {
  static PaginationRequest? parseData(Map<String, dynamic> data) {
    try {
      return PaginationRequest(
        query: data["query"],
        baseUrl: data["baseUrl"],
        pageTitle: data["pageTitle"],
        itemsPerPage: data["itemsPerPage"] ?? 10,
        layout: data["layout"],
      );
    } catch (exception) {
      return null;
    }
  }

  const PaginationRequest({
    required this.query,
    required this.baseUrl,
    required this.pageTitle,
    required this.itemsPerPage,
    required this.layout,
  });

  final String query;
  final DirectoryRelativePath baseUrl;
  final String pageTitle;
  final int itemsPerPage;
  final String layout;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginationRequest &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          baseUrl == other.baseUrl &&
          pageTitle == other.pageTitle &&
          itemsPerPage == other.itemsPerPage &&
          layout == other.layout;

  @override
  int get hashCode => query.hashCode ^ baseUrl.hashCode ^ pageTitle.hashCode ^ itemsPerPage.hashCode ^ layout.hashCode;
}
