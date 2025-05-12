---
title: Pages
---
`Page`s are the most important data structure in Static Shock. A `Page` is a 
data structure, which eventually becomes a URL-addressable HTML page, in
the final static site build.

`Page` data structures are created by `PageLoader`s, which are responsible
for identifying files that should be turned into pages. For example, the
Markdown plugin locates files with a `.md` extension, and creates a `Page`
data structure for every such file.

Once a `Page` is created, that `Page` can be altered by other steps in
the Static Shock pipeline. Specifically, by the "transform pages" step.

Any plugin can register a `PageTransformer` to change any `Page` in the
pipeline.

## The Page Structure
A `Page` is a hierarchical store of arbitrary data. It's little more than 
a glorified `Map`, or JSON object.

A `Page` has a source, a destination, and an arbitrary collection
of data that will be used to render the final page.

The source is the file from which the `Page` was originally created, such
as a Markdown file.

The destination is where the `Page` should be written at the end of the
pipeline, and the content that should be written.

Few restrictions are placed on `Page` data because Static Shock doesn't know
how that data might be used. Users might choose different content formats, e.g.,
Markdown, XML, plain text, HTML. Users might choose different templating packages,
e.g., Jinja, Handlebars, Mustache. Instead of restricting how users build their
static site, Static Shock leaves the data open ended.

That said, Static Shock expects at least a few properties to be set for every
`Page` in the pipeline.

```
// The following accessors are defined on `Page`. They each access a
// value in the `Page`'s `data`. These are first-class properties that
// Static Shock reserves for its own use.
page.title
page.pagePath
page.contentRenderers
page.tags
```

## Edit a Page
All of a `Page`'s data is stored in a property called `data`. The `data`
property is a `Map`. To edit a `Page`'s data, set the desired property
within the `Page`s `data`.

```dart
page.data['myThing'] = something;
```

You may notice some properties on `Page`, such as `page.title`. These accessors
are just syntactic sugar on top of the `data` property.

```dart
String get title => data['title'];
```

The time in the pipeline to edit a `Page` is from within a `PageTransformer`.
By collecting all `Page` transformations, Static Shock is able to ensure certain
`Page` states before the transformations, and validate `Page`s after all
transformations are complete.
