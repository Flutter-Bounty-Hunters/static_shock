---
title: Functions
---
Jinja supports calling out to standalone Dart functions.

Jinja functions can use position parameters.

```
{{ cycle("odd", "even") }}
```

Jinja functions also support named parameters.

```
{{ print("Hello, world!", level="verbose") }}
```

### Available Functions
The official distribution of Jinja includes a number of [built-in functions](https://jinja.palletsprojects.com/en/stable/templates/#list-of-global-functions).

Static Shock uses a [Pub package for Jinja](https://pub.dev/packages/jinja) support, which may or may not support all standard functions.

Static Shock currently doesn't add any custom functions, but may in the future.
