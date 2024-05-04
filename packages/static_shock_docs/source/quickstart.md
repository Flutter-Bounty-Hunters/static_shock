---
title: Quickstart
description: Start assembling a Static Shock website
layout: layouts/top-level-page.jinja
contentRenderers:
 - jinja
 - markdown
---

{{ pub.packages|join(", ") }}

## Activate the Static Shock CLI
The Static Shock CLI tool helps you quickly generate new projects, and locally serve your static site. You don't need to use this tool, but it's the fastest and easiest way to get started.

Testing Jinja in Markdown:

```sh
dart pub global activate static_shock_cli
```

Verify that Static Shock was activated

```sh
which shock
```

## Generate a new project
Use the Static Shock CLI tool to generate a new project. You can also create the files manually, if you'd like.

```sh
shock create
```

## Build your static site
Every Static Shock project is a regular Dart project. The script that builds your static site is in the `/bin` directory. Build your static site to ensure that everything is configured correctly.

```sh
dart run bin/my_project.dart
```

As a shortcut, you can run the following command instead of <code>dart run</code>.

```sh
shock build
```

## Serve your site locally
To verify your static site locally, you need to run a local web server. The Static Shock CLI can do this for you.

```sh
shock serve
```

The <code>shock serve</code> command runs a local server, which serves your built webpages. That local server also watches your project directory and automatically rebuilds your website whenever a file changes. The local server also automatically refreshes your browser window so that you automatically see what your changes look like.

The automatic rebuild and reload is in the early stages of development. If errors are reported to the console when you change files, press <code>CTRL+C</code> to kill the server and then re-launch it with <code>shock serve</code>.