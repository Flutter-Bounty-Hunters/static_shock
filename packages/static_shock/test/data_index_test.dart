import 'package:static_shock/src/data.dart';
import 'package:static_shock/src/files.dart';
import 'package:static_shock/static_shock.dart';
import 'package:test/scaffolding.dart';
import 'package:test/test.dart';

void main() {
  group("Data index >", () {
    test("inherits merged data", () {
      final dataIndex = DataIndex();
      dataIndex.mergeAtPath(DirectoryRelativePath("/"), {
        "navigation": {
          "items": [
            {
              "title": "top1",
              "url": "/top1",
            },
            {
              "title": "top2",
              "url": "/top2",
            }
          ],
        },
      });

      dataIndex.mergeAtPath(DirectoryRelativePath("/home"), {
        "navigation": {
          "items": [
            {
              "title": "home",
              "items": [
                {
                  "title": "home1",
                  "url": "/home/1",
                },
                {
                  "title": "home2",
                  "url": "/home/2",
                }
              ],
            },
          ],
        },
      });

      dataIndex.mergeAtPath(DirectoryRelativePath("/about"), {
        "navigation": {
          "items": [
            {
              "title": "about",
              "items": [
                {
                  "title": "about1",
                  "url": "/about/1",
                },
                {
                  "title": "about2",
                  "url": "/about/2",
                }
              ],
            },
          ],
        },
      });

      expect(
        dataIndex.inheritDataForPath(DirectoryRelativePath("/")),
        {
          "navigation": {
            "items": [
              {
                "title": "top1",
                "url": "/top1",
              },
              {
                "title": "top2",
                "url": "/top2",
              },
            ],
          },
        },
      );

      expect(
        dataIndex.inheritDataForPath(DirectoryRelativePath("/home")),
        {
          "navigation": {
            "items": [
              {
                "title": "top1",
                "url": "/top1",
              },
              {
                "title": "top2",
                "url": "/top2",
              },
              {
                "title": "home",
                "items": [
                  {
                    "title": "home1",
                    "url": "/home/1",
                  },
                  {
                    "title": "home2",
                    "url": "/home/2",
                  }
                ],
              },
            ],
          },
        },
      );

      expect(
        dataIndex.inheritDataForPath(DirectoryRelativePath("/about")),
        {
          "navigation": {
            "items": [
              {
                "title": "top1",
                "url": "/top1",
              },
              {
                "title": "top2",
                "url": "/top2",
              },
              {
                "title": "about",
                "items": [
                  {
                    "title": "about1",
                    "url": "/about/1",
                  },
                  {
                    "title": "about2",
                    "url": "/about/2",
                  }
                ],
              },
            ],
          },
        },
      );
    });
  });
}
