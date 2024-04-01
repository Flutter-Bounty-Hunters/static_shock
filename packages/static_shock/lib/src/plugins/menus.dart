import 'package:static_shock/src/pipeline.dart';
import 'package:yaml/yaml.dart';

/// Returns `true` if the [YamlList] of menu items is either empty, or it only contains items
/// for non-existent pages.
///
/// Returns `false` if the [YamlList] of menu items has at least one item for a page that exists.
(String testName, Function testFunction) isMenuEmpty(StaticShockPipelineContext context) {
  return (
    "menuEmpty",
    (YamlList menuItems, List<Object?> pathPrefixFragments) =>
        !_isMenuNonEmpty(context, menuItems, pathPrefixFragments),
  );
}

/// Returns `true` if the [YamlList] of menu items contains at least one item that corresponds to
/// a [Page] that exists.
///
/// Returns `false` if the [YamlList] of menu items is empty, or if the menu only contains items for
/// non-existent pages.
(String testName, Function testFunction) isMenuNonEmpty(StaticShockPipelineContext context) {
  return (
    "menuNonEmpty",
    (YamlList menuItems, List<Object?> pathPrefixFragments) => _isMenuNonEmpty(context, menuItems, pathPrefixFragments),
  );
}

bool _isMenuNonEmpty(
  StaticShockPipelineContext context,
  YamlList menuItems,
  List<Object?> prefixPathFragments,
) {
  if (menuItems.isEmpty) {
    return false;
  }

  return _pageExistsForMenuItem(context, menuItems, prefixPathFragments).isNotEmpty;
}

/// A [StaticShockJinjaFilterBuilder] whose filter takes a list of YAML menu items
/// and removes all the menu items for which no [Page] exists.
///
/// The following example adds a link for every menu item that has a corresponding page:
///
/// ```
/// {% for menuItem in docs_menu|itemsForExistingPages(["guides"]) %}
///   <a class="btn btn-primary btn-sm" href="/guides/{{ menuItem.id }}" role="button">{{ menuItem.title }}</a>
/// {% endfor %}
/// ```
(String filterName, Function filterFunction) menuItemsWherePageExistsFilterBuilder(StaticShockPipelineContext context) {
  return (
    "itemsForExistingPages",
    (YamlList menuItems, List<Object?> pathPrefixFragments) =>
        _pageExistsForMenuItem(context, menuItems, pathPrefixFragments),
  );
}

/// Filters out all menu items for which no [Page] currently exists.
///
/// This filter is especially useful when using draft mode because draft mode removes pages
/// that exist in the source set, but happen to be marked as being in draft mode.
///
/// Path fragments are used instead of a full path because it's not always possible for Jinja
/// template code to assemble interpolated strings. Therefore, fragments are used, for example:
/// Given the fragments ["guides", "getting-started"], this method searches for
/// a [Page] with the path "guides/getting-started/".
YamlList _pageExistsForMenuItem(
  StaticShockPipelineContext context,
  YamlList menuItems,
  List<Object?> prefixPathFragments,
) {
  final filteredMenuItems = <Object>[];
  for (final menuItem in menuItems) {
    final pathFragments = [...prefixPathFragments, menuItem['id']];
    final url = "${pathFragments.join("/")}/";
    for (final page in context.pagesIndex.pages) {
      if (page.url == url) {
        filteredMenuItems.add(menuItem);
        break;
      }
    }
  }

  return YamlList.wrap(filteredMenuItems);
}
