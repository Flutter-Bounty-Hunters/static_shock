---
title: Basic Syntax
---
Jinja includes a variety of syntax options, which are fully documented on the
[Jinja website](https://jinja.palletsprojects.com/en/stable/).

Static Shock uses the [Jinja package from Pub](https://pub.dev/packages/jinja),
which may not support all Jinja syntax features.

You should refer to the above references for complete Jinja documentation.

To aid with Static Shock development, some key syntax examples are documented here.

## Statement Bounds
Generally speaking, anything that appears between a `{{` and a `}}` will be
interpreted by Jinja as a Jinja statement.

## Variables
Variable replacement occurs by naming the variable in a Jinja statement.

```
The following variable will be replaced: {{ someVar }}.
```

## Comments
Comments are often useful when writing obtuse template code. In Jinja, comments
are encoded as blocks (not lines). A comment block begins with `{#` and ends with
`#}`.

```
{# This is an explanation of something #}
Hello, {{ someVar }}!
```

Comments don't just hide Jinja code. They hide whatever content appears between
them, even if that code happens to be HTML.

```
{# None of the content here will appear in the output file
  <section>
    <nav>
    </nav>
  </section>
}#
```

## Escape Block
It's common for Jinja syntax to appear in regular content. For example, every code
sample on this page obviously includes Jinja syntax. Therefore, it's important to
remember how to avoid parsing Jinja.

Tell Jinja to ignore a block of text by surrounding it with `{% raw %}` and
`{% endraw %}`.

```
{% raw %}
<p>None of the Jinja synax in this code sample will be processed by Jinja.</p>
<pre><code>
  <nav>
    <ul>
    {% for item in menuItem.items %}
      <li><a href="{{ item.url }}" title="{{ item.title }}">{{ item.title }}</a></li>
    {% endfor %}
    </ul>
  </nav>
</code></pre>
{% endraw %}
```

## Conditionals

## Loops

## Filters

## Tests
