---
title: Pages Index
---
As `Page`s are loaded into the pipeline, they're added to a data structure called
the `PagesIndex`.

As the name implies, the `PagesIndex` is a queryable index of `Page`s in the
website. `Page`s might be queried for a number of reasons.

 * The Jinja plugin uses the `PagesIndex` so that page templates can render
   HTML for groups of pages, such as the navigation menu on the documentation
   page that you're reading now.
 * The RSS plugin inspects every `Page` in the `PagesIndex` to assemble the
   RSS feed for the website.
 * The redirects plugin inspects every `Page` to find the ones that want to
   setup HTTP redirects.

The `PagesIndex` can be accessed through the `StaticShockPipelineContext`.
