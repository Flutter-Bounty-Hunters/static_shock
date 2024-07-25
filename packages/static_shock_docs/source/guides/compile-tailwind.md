---
title: Compile Tailwind
tags: styling
---
Static Shock includes a plugin that you can use to compile Tailwind classes in your website.

Tailwind is a CSS compilation tool that focuses on writing styles within your HTML tags, instead
of separating your styles into CSS classes. Learn more about Tailwind in the 
[official docs](https://tailwindcss.com/docs/installation).

## Activate the Tailwind plugin
Tell Static Shock to run the Tailwind compilation process by adding the Tailwind plugin.

```dart
Future<void> main(List<String> arguments) async {
  // Configure the static website generator.
  final staticShock = StaticShock()
    // ...existing configuration here...
    ..plugin(const TailwindPlugin(
      input: "source/styles/tailwind.css",
      output: "build/styles/tailwind.css",
    ));

  // Generate the static website.
  await staticShock.generateSite();
}
```

You'll need to provide the path to your Tailwind source file, and a desired destination for
your compiled Tailwind output file. Those files, and other Tailwind setup steps, are discussed
below.

## Add Tailwind to your project
Tailwind is typically added to projects through NPM or some other JavaScript package manager.
Static Shock is written in Dart and relies on the Pub package ecosystem. Therefore, Static Shock
projects can't use the standard pathway to integrate Tailwind. However, there's still an easy
path to integrate Tailwind.

Tailwind distributes a binary tool for exactly situations like ours.

### Download the standalone CLI tool
[Download the Tailwind standalone CLI tool](https://tailwindcss.com/blog/standalone-cli) directly 
into your project. Place it at the top-level of your Static Shock project and call it `tailwind`.

For example, on a Mac computer, you might run the following:

```
curl -sLO https://github.com/tailwindlabs/tailwindcss/releases/latest/download/tailwindcss-macos-arm64
chmod +x tailwindcss-macos-arm64
mv tailwindcss-macos-arm64 tailwindcss
```

### Create a Tailwind configuration file
Tailwind inspects files looking for Tailwind CSS classes to compile. Therefore, you need to tell
Tailwind which files to look at.

First, create the Tailwind configuration file in the same directory where you placed the
`tailwind` tool. Call it `tailwind.config.js`.

Second, in the configuration file, tell Tailwind which files to inspect.

In this example we tell Tailwind to only look at our source files, and we further tell Tailwind
to only look at our Jinja template files, which is where we write our HTML.

```javascript
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './source/**/*.jinja',
  ],
}
```

### Create your base Tailwind CSS configuration
Create a CSS file to hold your baseline Tailwind CSS preferences.

A common place for this file is `/source/styles/tailwind.css`.

If you're familiar with Tailwind, you probably know what to place in this file. For those
new to Tailwind, place the following code in `tailwind.css`.

```
@tailwind base;
@tailwind components;
@tailwind utilities;
```

Your site is now ready to compile Tailwind classes. The final step is to actually use the
CSS that Tailwind generates.

### Include Tailwind CSS in your HTML
The final output from Tailwind is a single CSS file. That file will appear wherever you tell
the `TailwindPlugin` to put it. A common location is `/build/styles/tailwind.css`.

You need to import this CSS file in all HTML/Jinja files where you made use of Tailwind CSS
classes.

```html
<html>
  <head>
    <link href="/styles/tailwind.css" rel="stylesheet">
  </head>
  <body></body>
</html>
```

With the final output file added to your HTML, every time you build your static site, your
webpages will magically apply Tailwind CSS classes.

## How does Tailwind integrate with Static Shock?
When you apply the `TailwindPlugin` to your Static Shock website, Static Shock runs the Tailwind
tool whenever you build your site. During the standard Static Shock build phase, Static Shock
starts a separate process and runs the standard Tailwind compilation step.

The output from the Tailwind process is a single CSS file that includes all the CSS needed
by the Tailwind classes that you added to your HTML. That CSS file is then imported by your
HTML files when you view your HTML files in the browser.