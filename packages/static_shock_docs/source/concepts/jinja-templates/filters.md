---
title: Filters
---
Filters are functions that take an input value and then return an output value.

The syntax for a typical filter is `{{ someVariable | my_filter }}`. Some filters
require additional information to do their job. In that case, the filter can receive
arguments like a typical function call, `{{ someVariable | my_filter(arg1, arg2) }}`.

For example, the following illustrate string manipulation with filters.

```
<h1>{{ title | upper }}</h1>
<p>{{ summary | capitalize }}</p>
<p>{{ "hello world" | title }}</p>
<p>{{ name | lower }}</p>
<p>{{ text | truncate(20) }}</p>
<p>{{ filename | replace('.txt', '.csv') }}</p>
```

### Available Filters
The official distribution of Jinja includes a number of [built-in filters](https://jinja.palletsprojects.com/en/stable/templates/#builtin-filters).

Static Shock uses a [Pub package for Jinja](https://pub.dev/packages/jinja) support, which may or may not support all standard filters.

Static Shock adds some of its own filters, making them available to every `Page` template.
 * `local_link`, which creates an absolute URL path for the given local path. E.g., "guides/welcome/" might become "/static_shock/guides/welcome/". Example: `{{ "guides/welcome/" | local_link }}`.
 * `formatDateTime`, which parses the incoming date, and then returns it in another date format. Example: `{{ "2022-12-28" | formatDateTime(to = "MMMM dd, yyyy") }}`.
 * `take`, which takes and returns up to the given number of items from a given iterable variable. Example: `{{ for contribute in contributors | take(4) }}`.
 * `pathRelativeToPage`, which returns a new path built from the current `Page`'s path, and the given sub-path. Example: `{{ "images/header.png" | pathRelativeToPath }}`.
