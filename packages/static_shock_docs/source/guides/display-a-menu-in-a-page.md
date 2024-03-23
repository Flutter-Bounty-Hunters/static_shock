---
title: Display a Menu in a Page
tags: drafting
---
# Display a Menu in a Page
A page might display a menu of links, and it might appear as if the content changes within that
one page when you select different menu items. For example, the page you're viewing right now
contains a menu with links to different guides. However, you're not looking at one single page,
but instead a series of pages, each of which look almost identical, except the content is different.

To create a series of pages that appear to show the same menu, you need to share a menu definition
among those pages.

Create a directory to hold your related pages.

    /guides

Create a data file in your new directory, where you can define a menu structure, and share that
menu structure among all the pages in that directory.

    /guides/_data.yaml

Define a menu in the `_data.yaml` file.

```yaml
my_menu:
  - title: Guide 1
    id: guide-1
  - title: Guide 2
    id: guide-2
  - title: Guide 3
    id: guide-3
```

Create a shared layout file for each of the pages in your group.

    /_includes/layouts/guide.jinja

Configure the layout file to display a menu, based on the menu data in `_data.yaml`.

```html
<html lang="en">
  <body>
    <div class="container">
      <!-- This is where we generate all the menu items -->
      <nav class="guides-menu">
        {% for menuItem in my_menu %}
          <a class="btn btn-primary btn-sm" href="/guides/{{ menuItem.id }}" role="button">{{ menuItem.title }}</a>
        {% endfor %}
      </nav>
        
      <!-- This is where the main content goes for this page -->
      <section>
        {{ content }}
      </section>
    </div>
  </body>
</html>
```

To easily apply the new layout file to every page in your group, add the `layout` property to your
existing `_data.yaml` file.

```yaml
layout: /layouts/guides.jinja
my_menu:
  - title: Guide 1
    id: guide-1
  - title: Guide 2
    id: guide-2
  - title: Guide 3
    id: guide-3
```

The `guides.jinja` layout will now be applied to every page in the `/guides` directory, because the
data in `_data.yaml` is inherited by all pages in that directory.

Next, you need to define each of the pages in the menu.

Create a Markdown file for each page in your group.

    /guides
      /guide-1.md
      /guide-2.md
      /guide-3.md

In each Markdown file, write the content for that page.

```markdown
# Guide 1
This is the content for Guide 1.
```

Now, if you visit any of your guide pages, you'll see the menu that you defined. When you select
a menu item for navigation, it will appear as if only the page's primary content changes.