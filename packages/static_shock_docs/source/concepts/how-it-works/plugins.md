---
title: Plugins
---
Plugins are a major part of Static Shock. Static Shock is designed to be as
pluggable as possible, with the express purpose of empowering plugins.

Static Shock ships with support for the following:
 * Markdown parsing
 * Jinja templating
 * Sass compilation
 * Tailwind compilation
 * Pretty URLs
 * Redirect generation
 * RSS feeds
 * Website screenshotting
 * Pub package metadata scraping
 * GitHub repository metadata scraping
 * and more...

Despite the fact that Static Shock ships these tools, each of these tools is
implemented as it's own plugin. Each behavior is accomplished by registering
these plugins with Static Shock.

For example, the Dart file for this very website looks like the following.

```dart
final staticShock = StaticShock(
    site: SiteMetadata(
        rootUrl: 'https://staticshock.io',
        basePath: '/',
      ),
    )
    ..pick(DirectoryPicker.parse("images"))
    ..plugin(const MarkdownPlugin())
    ..plugin(JinjaPlugin(
      filters: [
        menuItemsWherePageExistsFilterBuilder,
      ],
    ))
    ..plugin(const PrettyUrlsPlugin())
    ..plugin(const RedirectsPlugin())
    ..plugin(const SassPlugin())
    ..plugin(DraftingPlugin(
      showDrafts: arguments.contains("preview"),
    ))
    ..plugin(const PubPackagePlugin())
    ..plugin(WebsiteScreenshotsPlugin(
      selector: (context) {
        // Implementation elided...
      },
      outputWidth: 256,
    ))
    ..plugin(const RssPlugin(
      site: RssSiteConfiguration(
        title: "Static Shock Docs",
        description: "Documentation website for the static_shock package.",
        homePageUrl: "https://staticshock.io",
      ),
    ))
    ..plugin(
      GitHubContributorsPlugin(
        authToken: Platform.environment["GHUB_DOC_WEBSITE_TOKEN"],
      ),
    )
    ..loadData(/*...*/);
```

Notice that nearly all of the Static Shock website's configuration is the
selection and configuration of plugins.

By shipping behaviors as plugins, Static Shock ensures that 3rd party developers
will be able to access what they need to write their own plugins.

Also, by shipping behaviors as plugins, developers enjoy the freedom to activate
only the behaviors they need.

## How do plugins work?
Fundamentally, plugins are extremely simple. A plugin is essentially a function
that's called by Static Shock. Inside that function, the plugin can register
whatever pieces it wants.

The interface for a plugin is as follows.

```dart
abstract class StaticShockPlugin {
  const StaticShockPlugin();

  /// ID that uniquely differentiates this plugin from all other plugins.
  ///
  /// The plugin ID is used, for example, to segregate caches for each plugin.
  ///
  /// One strategy to help avoid ID conflicts is to use a domain name that
  /// you own, e.g., "com.mydomain.myplugin".
  String get id;

  /// Configures the [pipeline] to add new features that are associated with
  /// this plugin.
  FutureOr<void> configure(
    StaticShockPipeline pipeline,
    StaticShockPipelineContext context,
    StaticShockCache pluginCache,
  ) {}
}
```

A plugin is defined entirely by what it chooses to register within its `configure()` method.

The following is the implementation for the drafting plugin, which removes any pages
that are in draft mode.

```dart
@override
FutureOr<void> configure(
  StaticShockPipeline pipeline,
  StaticShockPipelineContext context,
  StaticShockCache pluginCache,
) {
  pipeline.filterPages(
    _DraftPageFilter(showDrafts: showDrafts),
  );
}
```

The following is the implementation of the Sass plugin, which compiles Sass files
to CSS.

```dart
@override
  FutureOr<void> configure(
    StaticShockPipeline pipeline,
    StaticShockPipelineContext context,
    StaticShockCache pluginCache,
  ) {
  final sassEnvironment = SassEnvironment(context.log);

  pipeline
    // Load all local Sass files as assets.
    ..pick(ExtensionPicker("sass"))
    ..pick(ExtensionPicker("scss"))
    // Index all the loaded Sass files so they can import each other.
    ..transformAssets(
      SassIndexTransformer(context.log, sassEnvironment),
    )
    // Compile all Sass files to CSS.
    ..transformAssets(
      SassAssetTransformer(context.log, sassEnvironment),
    );
}
```

The objects that plugins register with Static Shock are the various hooks
supported by the `StaticShockPipeline`. See [the pipeline](concepts/how-it-works/the-pipeline)
documentation to learn more about pipeline steps and hooks.