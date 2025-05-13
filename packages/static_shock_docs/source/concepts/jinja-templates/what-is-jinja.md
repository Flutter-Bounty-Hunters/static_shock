---
title: What is Jinja?
contentRenderers:
  - jinja
  - markdown
---
Jinja is a templating system which is included with Static Shock.

Jinja is similar in purpose to may other templating systems such as Mustache,
Handlebars, Nunjuck, and Vento. Static Shock avoided Mustache and Handlebars
because those systems seemed too simplistic. Static Shock chose Jinja over
Nunjuck and Vento because there were no good Pub packages that implemented
those syntaxes.

Jinja was originally developed as a [Python library](https://jinja.palletsprojects.com/en/stable/).

A port of Jinja is [available on Pub](https://pub.dev/packages/jinja).

## What are templates?
Technically, a template is any text file that includes templating syntax.

For example, the following snippet would replace "location" with some value,
such as "world".

{% raw %}
```
Hellow, {{ location }}!
```
{% endraw %}

In practice, when we talk about templates in Static Shock, we're referring to
HTML files where we want to insert values, execute loops, and run other template
behaviors.

For example, in an HTML file, a developer might want the title to be configurable
so that it's easy to change.

{% raw %}
```
<html>
  <head>
    <title>{{ title }}</title>
  </head>
</html
```
{% endraw %}

Similarly, a developer might want to generate a navigation menu from data that's
provided by a static site generator.

{% raw %}
```
<nav>
  <ul>
  {% for item in menuItem.items %}
    <li><a href="{{ item.url }}" title="{{ item.title }}">{{ item.title }}</a></li>
  {% endfor %}
  </ul>
</nav>
```
{% endraw %}

## What can Jinja do?
Jinja supports a variety of templating behaviors.

The most basic behavior is replacement. When a template refers to a variable that's
defined in the template environment, Jinja replaces the variable with the actual value.

Jinja provides a few execution controls including loops and conditionals.

Jinja can call out to Dart functions using what Jinja calls "filters". Learn more about
the [filters that ship with Static Shock]({{ "concepts/jinja-templates/filters" | local_link }}).

Jinja can call out to Dart boolean checks with what Jinja calls "tests". Learn more about
the [tests that ship with Static Shock]({{ "concepts/jinja-templates/tests" | local_link }}).