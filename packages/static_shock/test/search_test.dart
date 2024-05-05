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

    test("conditions", () {
      expect(pageIndex.search("url^=/articles/news").length, 2);

      expect(pageIndex.search("title*=Page").length, 4);
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
      expect(
        SearchQuery.parse("title^='Hello, '"),
        SearchQuery([
          PropertySearchCondition("title", SearchOperator.startsWith, "Hello, "),
        ]),
      );
      expect(
        SearchQuery.parse("title\$=' world!'"),
        SearchQuery([
          PropertySearchCondition("title", SearchOperator.endsWith, " world!"),
        ]),
      );
      expect(
        SearchQuery.parse("tags*=article"),
        SearchQuery([
          PropertySearchCondition("tags", SearchOperator.contains, "article"),
        ]),
      );
      expect(
        SearchQuery.parse("value<5"),
        SearchQuery([
          PropertySearchCondition("value", SearchOperator.lessThan, 5),
        ]),
      );
      expect(
        SearchQuery.parse("value<=5"),
        SearchQuery([
          PropertySearchCondition("value", SearchOperator.lessThanEqualTo, 5),
        ]),
      );
      expect(
        SearchQuery.parse("value>5"),
        SearchQuery([
          PropertySearchCondition("value", SearchOperator.greaterThan, 5),
        ]),
      );
      expect(
        SearchQuery.parse("value>=5"),
        SearchQuery([
          PropertySearchCondition("value", SearchOperator.greaterThanEqualTo, 5),
        ]),
      );
    });
  });
}

final _fakePages = [
  Page(
    data: {
      "title": "Page one",
      "url": "/articles",
      "tags": ["alpha"],
    },
  ),
  Page(
    data: {
      "title": "Page two",
      "url": "/articles",
      "tags": ["beta"],
    },
  ),
  Page(
    data: {
      "title": "Page three",
      "url": "/articles/news",
      "tags": ["beta"],
    },
  ),
  Page(
    data: {
      "title": "Page four",
      "url": "/articles/news/today",
      "tags": ["alpha", "beta"],
    },
  ),
];
