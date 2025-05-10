---
title: Base URL
contentRenderers:
  - jinja
  - markdown
---
Each webpage URL is comprised of three pieces: the root URL, the base path, and the
page path. 

For example the following are the URL pieces for this page:
 - Root URL: `{{ rootUrl }}`
 - Base Path: `{{ basePath }}`
 - Page Path: `{{ pagePath }}`

## Configure a website root URL and base path
The root URL and base path for a Static Shock website can be set in the `StaticShock`
constructor in the main Dart file.

```dart
StaticShock(
  site: SiteMetadata(
    rootUrl: 'https://staticshock.io',
    basePath: '/',
  ),
);
```

By default, `rootUrl` is `null`, and `basePath` is `/`.

The root URL and base path can also be set in the top-level `_data.yaml` file.

```yaml
rootUrl: https://staticshock.io
basePath: /
```

<p class="callout warning">
<span class="title">🚧 Warning</span>
WARNING: Because the <code>rootUrl</code> and <code>basePath</code> exist in the site data index, it's
possible to override these in any <code>_data.yaml</code> file, and any page file. Doing so
will almost certainly break the website, because these values are supposed to be
consistent across all pages in a website.
</p>

## Run locally with a base path
Running and testing your Static Shock website locally is critical. The Static Shock dev server
supports simulating a custom base path.

Run the dev server with the `--base-path` flag.

```
shock serve --base-path=/static_shock/
```

With the above `--base-path` value, a local browser request could be sent, for example, to
`localhost:4000/static_shock/guides/base-url` and the dev server would serve the content
at `guides/base-url`.

## Why base paths matter
Typically, a website serves pages with `/` as the base path. For example, the main index page
is served from `/index.html`. A base path of `/` works in Static Shock by default.

However, some web servers serve files from a sub-path. For example, GitHub Pages serves files
from a path whose name matches the project name. The following is an example of a GitHub Pages
URL for a project called "lucid":

    https://flutter-bounty-hunters.github.io/lucid/index.html

Serving files from a sub-path creates a problem for absolute paths. Imagine that the Lucid
website contains an `images` directory with an `icon.png`:

    /images/icon.png

The typical absolute URL for this image would be `/images/icon.png` - but when served
from GitHub Pages, the actual URL is `/lucid/images/icon.png`.

As a result, with a deployment like GitHub Pages, all absolute paths to CSS files, JS files,
images, and links to other pages will point to the wrong place. In other words, the entire
website would be completely broken. Therefore, in such cases, it's critical to set the
`basePath` property for the Static Shock website.

## Create links with the base path
It's critical to ensure that all links that point to local files include the
website base path. To help with this, Static Shock provides a Jinja filter
called `local_link`.

[Read the docs]({{ "guides/page-links" | local_link }}) on the `local_link` filter.

If needed, a local link can be assembled manually within a Jinja template or component
by using the base path variable.

{% raw %}
```
<a href="{{ basePath }}my/actual/path">Some Link</a>
```
{% endraw %}

## Using the root URL and base path variables
Static Shock provides access to the root URL and base path within every page.

Within a page's Jinja template or component, reference `rootUrl` and `basePath`, respectively.

{% raw %}
```
The root URL is: {{ rootUrl }}
The base path is: {{ basePath }}
```
{% endraw %}

Note, the `rootUrl` is `null` by default, and the `basePath` is `/` by default.
