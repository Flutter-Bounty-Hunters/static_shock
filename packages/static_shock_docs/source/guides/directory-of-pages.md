---
title: Directory of Pages
---
# Directory of Pages
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

You can also defin tags in the front matter for Jinja pages.

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
