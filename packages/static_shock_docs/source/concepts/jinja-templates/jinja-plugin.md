---
title: Jinja Plugin
---
Jinja template support is added to a Static Shock website by applying the
`JinjaPlugin`.

```dart
final site = StaticShock()
  ..plugin(JinjaPlugin());
```

Once the Jinja plugin is applied, the plugin finds and picks every Jinja
file in the source directory, as determined by the extension. Jinja is
typically used to create layout and component files. It can also be used
to create a traditional HTML page, with templating.

```
/source
  /_includes
    /components
      navbar.jinja
    /layouts
      guide.jinja
  /guides
    welcome.md
  contact.jinja
  index.jinja
```

The value of Jinja templates within HTML is that a single HTML file can be
used to render an infinite number of pages, because the template values
change for every page.
