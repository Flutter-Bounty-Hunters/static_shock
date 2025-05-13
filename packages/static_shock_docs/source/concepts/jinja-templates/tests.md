---
title: Tests
---
A test is a function that runs against some value or variable and returns
`true` and `false`.

Example of a test called `divisibleby`:
```
{% if myNumber is divisibleby 3 %}
{% if myNumber is divisibleby(3) %}
```

As shown in the example, the keyword `is` is used to evaluate a test (or
any other boolean expression).

### Syntax Examples
The following example shows a variety of boolean conditions, including some
tests, which may help to understand Jinja syntax related to boolean expressions.

```
{% if category == 'news' %}
  <p>Displaying news articles...</p>
{% elif items is sequence and items|length > 5 %}
  <p>Displaying a long list of items...</p>
{% elif user.is_logged_in %}
  <p>Welcome back, user!</p>
{% else %}
  <p>Please log in.</p>
{% endif %}
```

Jinja also includes explicit syntax for negating boolean conditions.

```
{% if not items is empty %}
  <p>The list of items is not empty.</p>
{% endif %}

{% if value is not none %}
  <p>The value is not None.</p>
{% endif %}
```

### Available Tests
The official distribution of Jinja includes a number of [built-in tests](https://jinja.palletsprojects.com/en/stable/templates/#tests).

Static Shock uses a [Pub package for Jinja](https://pub.dev/packages/jinja) support, which may or may not support all standard tests.

Static Shock currently doesn't add any custom tests, but may in the future.