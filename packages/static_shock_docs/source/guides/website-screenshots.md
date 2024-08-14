---
title: Website Screenshots
tags: drafting
---
## The website screenshot plugin
With the `WebsiteScreenshotPlugin` you can take screenshots of websites, save those
screenshots as images, and then display those screenshots in your website.

An ideal use-case for this plugin is to create a "showcase" of your other websites,
such as on a portfolio website.

## Configure the plugin
Add the `WebsiteScreenshotPlugin` to your `StaticShock` pipeline and configure the
size of the final output image.

```dart
Future<void> main(List<String> arguments) async {
  // Configure the static website generator.
  final staticShock = StaticShock()
    // ...existing configuration here...
    ..plugin(const WebsiteScreenshotsPlugin(
      outputWidth: 256,
    ));

  // Generate the static website.
  await staticShock.generateSite();
}
```

When building your website, a headless browser is launched to take screenshots of
the websites you requested. The `WebsiteScreenshotsPlugin` has a default browser 
viewport size, but if you'd like a different viewport size, you can provide that 
as a plugin argument.

```dart
  ..plugin(const WebsiteScreenshotsPlugin(
    viewportSize: const ViewportSize(width: 720, height: 1280)
    outputWidth: 256,
  ));
```

## Request screenshots directly
If you know what screenshots you want to take within your Dart code, you can
specify those screenshots directly, during plugin configuration.

```dart
Future<void> main(List<String> arguments) async {
  // Configure the static website generator.
  final staticShock = StaticShock()
    // ...existing configuration here...
    ..plugin(const WebsiteScreenshotsPlugin(
      screenshots: {
        WebsiteScreenshot(
          id: "static_shock",
          url: Uri.parse("https://staticshock.io"),
          output: FileRelativePath("images/screenshots", "staticshock", "png"),
        ),
        WebsiteScreenshot(
          id: "flutter_bounty_hunters",
          url: Uri.parse("https://flutterbountyhunters.com"),
          output: FileRelativePath("images/screenshots", "fbh", "png"),
        ),
      },
      outputWidth: 256,
    ));

  // Generate the static website.
  await staticShock.generateSite();
}
```

The "id" of each screenshot is used to cache the screenshots between builds. Using the
same "id" multiple times will result in later screenshots overwriting earlier screenshots
in your request set.

## Requesting screenshots from data files
It's often more convenient to request screenshots from `_data.yaml` files than it is
from Dart code. Your website probably includes template code that wants to display
your screenshots. Your template code uses the data index to access information.
Therefore, declaring your screenshots in the data index gives you a direct connection
to your template code.

You can define screenshots anywhere in your data that you choose. You're in charge
of where it goes, how it's formatted, and how you load it into the website screenshot
plugin.

The following is one example for how you might request screenshots from your data.

**/_data.yaml**
```yaml
showcase:
  screenshots:
    -
      id: "staticshock_io"
      title: "Static Shock"
      url: "https://staticshock.io"
      output: "/images/screenshots/staticshock_io.png"
    -
      id: "superdeclarative_com"
      title: "SuperDeclarative!"
      url: "https://superdeclarative.com"
      output: "/images/screenshots/superdeclarative_com.png"
    -
      id: "flutterbountyhunters_com"
      title: "Flutter Bounty Hunters"
      url: "https://flutterbountyhunters.com"
      output: "/images/screenshots/flutterbountyhunters_com.png"
```

Given the aforementioned `_data.yaml` definition, configure the plugin so that it
loads this data.

**/bin/main.dart:**
```dart
Future<void> main(List<String> arguments) async {
  // Configure the static website generator.
  final staticShock = StaticShock()
    // ...existing configuration here...
    ..plugin(const WebsiteScreenshotsPlugin(
      selector: (context) {
        final rootData = context.dataIndex.inheritDataForPath(DirectoryRelativePath("/"));
        final showcase = rootData['showcase'];
        if (showcase == null) {
          return {};
        }
        if (showcase is! Map<String, dynamic>) {
          return {};
        }

        final screenshots = <WebsiteScreenshot>{};
        final screenshotsYaml = showcase['screenshots'] as List<dynamic>;

        for (final screenshotYaml in screenshotsYaml) {
          screenshots.add(
            WebsiteScreenshot(
              id: screenshotYaml['id'],
              url: Uri.parse(screenshotYaml['url']),
              output: FileRelativePath.parse(screenshotYaml['output']),
            ),
          );
        }

        return screenshots;
      },
      outputWidth: 256,
    ));

  // Generate the static website.
  await staticShock.generateSite();
}
```

The plugin `selector` finds the screenshot requests in the data index and feeds them
to the screenshot plugin. At this point, those screenshots will be generated and saved
when the website is built.

However, the webpage template still needs to read this data and display the screenshots.
Assume that a showcase is built on the index page.

**/index.jinja:**
```html
<section style="max-width: 1200px; margin: auto; margin-bottom: 200px;">
  <h2 style="text-align: center; text-transform: uppercase;">Showcase</h2>
  <p style="text-align: center; color: rgba(255, 255, 255, 0.5);">My awesome websites.</p>
  <ul style="list-style-type: none; margin: 0; padding: 0; text-align: center;">
    {% for screenshot in showcase.screenshots %}
    <li style="display: inline-block; margin: 0; padding: 0;">
      <a href="{{ screenshot.url }}" target="_blank" title="{{ screenshot.title }}">
        <img src="{{ screenshot.output }}" style="display: inline-block; border-radius: 4px; margin: 16px;">
      </a>
    </li>
    {% endfor %}
  </ul>
</section>
```

With the template code above, the webpage now displays the screenshots that were taken
by the plugin, and were declared in `_data.yaml`.

To see this approach in action, visit the [Static Shock homepage](/)