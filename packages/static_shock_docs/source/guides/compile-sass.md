---
title: Compile Sass
layout: layouts/guides.jinja
---
# Compile Sass
Sass (also known as SCSS) is a format for defining CSS in a more convenient and extensible way.

Sass is a CSS superset, which means you can write regular CSS in a Sass file. But, Sass adds a 
number of syntax options that don't exist in regular CSS. Browsers don't understand that syntax. 
Instead, Sass code needs to be compiled down into regular CSS. The regular CSS is  then served with 
the final webpage.

To use Sass in a Static Shock project, create a Sass file in your source set. You can place a Sass
file wherever you'd like.

```
/styles/homepage.scss
```

Activate the Sass plugin in the `StaticShock` configuration.

```dart
final staticShock = StaticShock()
  ..plugin(const SassPlugin());
```

The Sass plugin looks for Sass files in your source set, compiles those Sass files to CSS, and
creates corresponding CSS files in your build set.

To compile your Sass files, run Static Shock.

```shell
dart bin/my_project.dart
```

Static Shock outputs a CSS file with the compiled Sass code.

```
/styles/homepage.css
```
