---
title: Configure Website Base URL
---
Typically, a website serves pages with `/` as the base path. For example, the main index page
is served from `/index.html`. A base path of `/` works in Static Shock by default.

However, some web servers serve files from a subpath. For example, GitHub Pages serves files
from a path whose name matches the project name. The following is an example of a GitHub Pages
URL for a project called "lucid":

    https://flutter-bounty-hunters.github.io/lucid/index.html

Serving files from a subpath creates a problem for absolute paths. Imagine that the Lucid
website contains an `images` directory with an `icon.png`:

    /images/icon.png

The typical absolute URL for this image would be "/images/icon.png" - but when served
from GitHub Pages, the actual URL is "/lucid/images/icon.png".

Static Shock provides a couple mechanisms to respect a website base path.

## The `websiteBasePath` global variable
Static Shock has a global variable called `websiteBasePath`, which holds the base
path for all local URLs. By default, the value is "/", which is the standard base path
for a typical web server.

<p class="callout warning">
<span class="title">🚧 Warning</span>
Don't confuse the <code>websiteBasePath</code> global variable with the <code>basePath</code> page
variable. The <code>websiteBasePath</code> is used to add a base path to all file and link URLs 
throughout the entire website, without altering any pre-existing paths. The 
<code>basePath</code> page property is used to <em>change</em> the URL path of a given page.
</p>

### Create links with the `websiteBasePath` variable

The `websiteBasePath` is available to all page, layout, and component templates.

When writing an absolute URL within a page, layout, or component, use the global
variable to ensure you assemble the correct url:

    <a href="{{ websiteBasePath }}/my/actual/path">Some Link</a>

### Change the website base path

To change the base path, declare the `websiteBasePath` variable in a `_data.yaml`
file at the root of your source directory:

    websiteBasePath: /lucid/

Static Shock internally uses the `websiteBasePath` when setting the `url` property
on pages and files.

It's your responsibility to use this global variable when declaring your own URLs, such
as within HTML templates.