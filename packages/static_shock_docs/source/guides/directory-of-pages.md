---
title: Directory of Pages
tags: drafting
---
Use the pages index to display a list of page links for pages in your website.

## List all pages
List all pages in your website by iterating over all pages in the page index.

```html
<html lang="en">
  <body>
    {% for page in pages.all() %}
      <a href="{{ page.data['url'] }}">{{ page.data['title'] }}</a>
    {% endfor %}
  </body>
</html>
```

## List pages by tag name
Once a website accumulates more than a few pages, you'll want to list pages by some sort of category.
Pages are categorized by assigning "tags" to them.

To associate a page with a tag, define desired tags in front matter.

You can define tags in the front matter for Markdown pages.

```markdown
---
title: My Page
tags:
 - flutter
 - dart
---
# My Page
```

You can also define tags in the front matter for Jinja pages.

```html
<!--
 title: My Page
 tags:
  - flutter
  - dart
-->
<html lang="en">
  <head>
    <title>My Page</title>
  </head>
  <body></body>
</html>
```

After associating pages with tags, list pages per tag by using the tag iterator in the page index.

```html
<html lang="en">
  <body>
    {% for page in pages.byTag("flutter") %}
      <a href="{{ page.data['url'] }}">{{ page.data['title'] }}</a>
    {% endfor %}
  </body>
</html>
```

## Hide a page from the index
Sometimes you might want a page to be available at a URL, but you don't want that page to be listed
in a directory of pages. For example, perhaps you published an article that you no longer want to
promote, but you want the URL to keep working for existing links around the web.

You can hide individual pages from the page index, while still publishing them to a URL, by using
the `shouldIndex` page property.

```yaml
---
title: My Hidden Page
shouldIndex: false
---
```