---
title: Add a Page
---
# Add a Page
A page is a URL-addressable web page.

A page can be configured with a Markdown file, which is the most common approach for repeated content, such as blog posts. A page can also be configured with a Jinja template, which is the most common approach for one-off pages, such as a landing page, or a contact page. 

## A Page from Markdown
To create a new page, first select a desired URL path.

```
/posts/my-blog-post
```

Page URL paths are based on directory structure. Create directories that match your desired path, along with a Markdown file whose name matches your final path segment.

```
/posts
  my-blog-post.md
```

Inside the Markdown file, add Front Matter configuration, to tell Static Shock how to generate the final page. Also, add Markdown content, which will be used as the primary content for the generated page.

```markdown
---
title: My Blog Post
layout: layouts/blog-post.jinja
---
# My Blog Post
This is where the main content goes.
```

With this configuration, you can run a Static Shock build.

```shell
dart bin/my_project.dart
```

When running the build, Static Shock takes the following steps:

 1. Finds the Markdown file in the source set
 2. Looks up the layout template referenced by the Markdown file
 3. Fills the template with the data and content form the Markdown file
 4. Places a copy of the filled template HTML file in the correct directory in the build set

Continuing with our example, after running a Static Shock build, an HTML file is generated in the build set.

```
/build/posts/my-blog-post/index.html
```

You now have a static HTML page that you can serve to users, and it's available at your desired URL path.

## A Page from a Jinja Template
To create a new page, first select a desired URL path.

```
/help/contact-us
```

Page URL paths are based on directory structure. Create directories that match your desired path, along with a Jinja file whose name matches your final path segment.

```
/help
  contact-us.jinja
```

Inside the Jinja file, add Front Matter configuration, to tell Static Shock how to generate the final page. Also, add HTML and Jinja template content, which will directly translate into the final HTML for the page.

```html
<!--
title: Contact Us
-->
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>{{ title }}</title>

    <!-- Fill with whatever header configurations you'd like -->
  </head>

  <body>
    <!-- Fill with whatever HTML and Jinja blocks that you'd like -->
  </body>
</html>
```

With this configuration, you can run a Static Shock build.

```shell
dart bin/my_project.dart
```

When running the build, Static Shock takes the following steps:

1. Finds the Jinja file in the source set
3. Fills the Jinja blocks with incoming data
4. Places a copy of the filled template HTML file in the correct directory in the build set

Continuing with our example, after running a Static Shock build, an HTML file is generated in the build set.

```
/build/help/contact-us/index.html
```

You now have a static HTML page that you can serve to users, and it's available at your desired URL path.