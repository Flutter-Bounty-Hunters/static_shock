import 'package:static_shock/src/pages.dart';
import 'package:test/test.dart';

void main() {
  group("Page search >", () {
    final pageIndex = PagesIndex()..addPages(_fakePages);

    test("tags", () {
      expect(pageIndex.search("alpha").length, 2);
      expect(pageIndex.search("beta").length, 3);
      expect(pageIndex.search("alpha beta").length, 1);
    });
  });

  group("Search query parsing >", () {
    test("tags", () {
      expect(
        SearchQuery.parse("alpha"),
        SearchQuery([
          PropertySearchCondition("tags", SearchOperator.contains, "alpha"),
        ]),
      );

      expect(
        SearchQuery.parse("alpha beta"),
        SearchQuery([
          PropertySearchCondition("tags", SearchOperator.contains, "alpha"),
          PropertySearchCondition("tags", SearchOperator.contains, "beta"),
        ]),
      );

      expect(
        SearchQuery.parse("tags*=alpha"),
        SearchQuery([
          PropertySearchCondition("tags", SearchOperator.contains, "alpha"),
        ]),
      );
    });

    test("operators", () {
      expect(
        SearchQuery.parse("title='Hello, world!'"),
        SearchQuery([
          PropertySearchCondition("title", SearchOperator.equals, "Hello, world!"),
        ]),
      );
    });
  });
}

final _fakePages = [
  Page(
    data: {
      "title": "Page one",
      "url": "/posts",
      "tags": ["alpha"],
    },
  ),
  Page(
    data: {
      "title": "Page two",
      "url": "/posts",
      "tags": ["beta"],
    },
  ),
  Page(
    data: {
      "title": "Page three",
      "url": "/posts",
      "tags": ["beta"],
    },
  ),
  Page(
    data: {
      "title": "Page three",
      "url": "/posts",
      "tags": ["alpha", "beta"],
    },
  ),
];
