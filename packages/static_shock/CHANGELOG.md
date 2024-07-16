## 0.0.9 - July 13, 2024
 * Fix: Remote Sass files can import other remote Sass files that sit in the same directory 
   (still need to add support for relative and absolute paths)

## 0.0.8 - July 13, 2024
 * Fix: Path bug with remote includes in `v0.0.7`

## 0.0.7 - July 13, 2024
 * Added picking of remote files and remote layouts/components

## 0.0.6 - June 21, 2024
 * Added `TailwindPlugin` for TailwindCSS support
 * Add Markdown plugin APIs to control how it converts to HTML

## 0.0.5 - May 9, 2024
 * Created GitHub plugin
 * Created Redirects plugin
 * Global data index is now accessible to all plugins through the context
 * Jinja syntax can be placed within Markdown pages
 * Components can include other components

## 0.0.4 - Apr 9, 2024
 * Pages now have access to a computed table-of-contents when rendering the page.
 * Individual pages can be hidden from the page index, but still made available at their URL.
 * BREAKING - Page sorting API now takes a single encoded string, e.g., `sortBy="pubDate=desc title=asc"`.
 * Jinja plugin: You can add custom filters and tests.
 * Jinja plugin: Added a `formatDateTime` filter.
 * RSS plugin: Can now generate (partial) RSS feeds. More RSS properties to come later.

## 0.0.3 - Mar 23, 2024
 * Hide pages by adding `DraftingPlugin` and setting `draft` to `true` for each draft page.

## 0.0.2 - Mar 23, 2024
 * Jinja templates can query Pages by tag and choose ascending or descending order.
 * Custom template renderers can be registered and then used within Jinja templates.

## 0.0.1 - July 19, 2023
First non-preview release.

Pipeline pieces:
 * Pickers
 * Excluders
 * DataLoaders
 * AssetTransformer
 * PageLoaders
 * PageTransformers
 * PageRenderers
 * Finishers

Plugins:
 * Jinja Templates
 * Markdown
 * Pretty URLs
 * Sass
 * Pub Packages

## 0.0.1-dev.2 - June 12, 2023
Cleaned up project for alpha testing:

 * Moved all built-in behavior to plugins
 * Added public member Dart Docs to core behaviors

## 0.0.1-dev.1 - June 9, 2023
Initial release. Includes an experimental static site generator API that we're continuing to iterate.
