---
title: Page Links
tags: pages
---
Links can be encoded in Jinja and Markdown.

### Jinja
Absolute URLs can be encoded as standard HTML anchor tags in a Jinja template.

```
<a href="https://flutterbountyhunters.com">This is a link</a>
```

Local links require knowledge of the website base path. The base path
is usually `/`, but it could be anything. For example, GitHub pages adds
the repository name as a base path, e.g., `flutterbountyhunters.github.io/static_shock/**`.

Static Shock provides a Jinja filter to create local links, called `local_link`.

The `local_link` filter can be used in Jinja layouts and components.

```
<a href="{{ "posts/hello-world" | local_link }}">This is a link</a>

<img src="{{ "images/logos/fbh.png" | local_link }}">
```

The output from the above Jinja template might look like the following HTML.

```
<a href="/static_shock/posts/hello-world">This is a link</a>

<img src="/static_shock/images/logos/fbh.png">
```

### Markdown
In Markdown, absolute links are supported through standard Markdown syntax.

```markdown
Absolute link: [This is a link](https://flutterbountyhunters.com)
```

To create local links within a Markdown page, Jinja needs to be added to the
page's render pipeline, so that the `local_link` filter can be used there, too.

Render a page with Jinja and then Markdown:

```markdown
---
title: My Page
contentRenderers:
 - jinja
 - markdown
---
[This is a link]({{ "posts/hello-world" | local_link }})
```

When rendering with Jinja and then Markdown, the following replacements occur.

Jinja converts `[This is a link]({{ "posts/hello-world" | local_link }})` to
`[This is a link](/static_shock/posts/hello-world)` (Markdown).

Markdown converts `[This is a link](/static_shock/posts/hello-world)` to
`<a href="/static_shock/posts/hello-world">This is a link</a>` (HTML).
