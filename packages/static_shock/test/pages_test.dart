import 'package:test/test.dart';

void main() {
  group("Pages >", () {
    group("data >", () {
      test("inherited data is overridden by local data", () async {
        // TODO: implement this test when we're able to run the pipeline without file access
        // The goal of this test is to ensure that when a page has inherited data
        // and local data with the same property name, the page's version is used
        // instead of the inherited property.
      }, skip: true);
    });
  });
}
