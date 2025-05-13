---
title: Overview
contentRenderers:
  - jinja
  - markdown
---
Markdown is a [popular document markup format](https://www.markdownguide.org/basic-syntax/), 
which is easy to read and write.

Markdown is used in popular apps, including GitHub issues and PRs, Obsidian,
Bear, Linear, and more. It's a great tradeoff between control over styling,
ease of writing, and ease of reading.

Static Shock supports Markdown as its primary content writing format.

## Add the Plugin
To use Markdown in your static site, add the `MarkdownPlugin` to your
`StaticShock`.

{% raw %}
```dart
final site = StaticShock()
  ..plugin(const MarkdownPlugin());
```
{% endraw %}

The Markdown plugin finds and picks every Markdown file it can find in the
source directory. Markdown files are identified by a `.md` extension.

{% raw %}
```
/source
  /guides
    welcome.md
  index.md
```
{% endraw %}

## Frontmatter
Markdown isn't enough on its own. Authors need to be able to specify the title
for a given page, as well as select a layout. It's also common to add a publish
date and other metadata, too.

Static Shock supports a syntax called "Frontmatter", which appears before the actual
Markdown content. Frontmatter begins with "---" and ends with "---". In between, authors
can write YAML to specify page metadata.

{% raw %}
```
---
title: Welcome
publishDate: 2025-05-12
layout: layouts/guide.jinja
---
# Welcome
This is a welcome guide. This content below the "---" is Markdown.
The content between the "---"'s is YAML metadata.

The YAML metadata is provided to the templating system when this
page is rendered, such as provided to a Jinja template.
```
{% endraw %}

To render a Markdown page, see the [Jinja references]({{ "concepts/jinja-templates/what-is-jinja" | local_link }}).
