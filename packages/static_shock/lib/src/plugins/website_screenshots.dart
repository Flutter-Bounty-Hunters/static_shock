import 'dart:async';

import 'package:image/image.dart';
import 'package:puppeteer/puppeteer.dart';
import 'package:static_shock/static_shock.dart';

/// A [StaticShockPlugin] that takes screenshots of webpages and places those
/// screenshots in the final website build at desired locations.
class WebsiteScreenshotsPlugin extends StaticShockPlugin {
  const WebsiteScreenshotsPlugin({
    this.screenshots = const <WebsiteScreenshot>{},
    this.selector,
    this.viewportSize = const ViewportSize(width: 1280, height: 720),
    this.outputWidth,
    this.outputHeight,
    this.useCache = true,
    this.forceCacheRefresh = false,
  }) : assert(!forceCacheRefresh || useCache, "To use forceCacheRefresh, useCache must be `true`.");

  @override
  final id = "io.staticshock.websitescreenshots";

  /// The webpages that should be screenshotted, and their final image
  /// locations.
  final Set<WebsiteScreenshot> screenshots;

  /// A user-provided delegate that finds desired [WebsiteScreenshot]s by reading
  /// the global data index.
  ///
  /// This can be used, for example, to define desired screenshots in a local
  /// YAML file and then read that YAML data to request [WebsiteScreenshot]s.
  final WebsiteScreenshotSelector? selector;

  /// The dimensions of the browser, which determines the dimensions of the screenshot.
  final ViewportSize viewportSize;

  /// The final width of the screenshot image, or `null` to keep the screenshot
  /// at its original width.
  final int? outputWidth;

  /// The final height of the screenshot image, or `null` to keep the screenshot
  /// at its original height.
  final int? outputHeight;

  /// `true` to place screenshots in a cache directory so that they can be re-used
  /// across builds, or `false` to take fresh screenshots on every build.
  final bool useCache;

  /// `true` to take fresh screenshots and overwrite any existing screenshots in the
  /// cache.
  final bool forceCacheRefresh;

  @override
  void configure(
    StaticShockPipeline pipeline,
    StaticShockPipelineContext context,
    StaticShockCache pluginCache,
  ) {
    pipeline.loadAssets(
      WebsiteScreenshotsAssetLoader(
        pluginCache,
        screenshots: screenshots,
        selector: selector,
        viewportSize: viewportSize,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
        useCache: useCache,
        forceCacheRefresh: forceCacheRefresh,
      ),
    );
  }
}

typedef WebsiteScreenshotSelector = Set<WebsiteScreenshot> Function(StaticShockPipelineContext context);

class WebsiteScreenshotsAssetLoader implements AssetLoader {
  const WebsiteScreenshotsAssetLoader(
    this.cache, {
    this.screenshots = const <WebsiteScreenshot>{},
    this.selector,
    this.viewportSize = const ViewportSize(width: 1280, height: 720),
    this.outputWidth,
    this.outputHeight,
    this.useCache = true,
    this.forceCacheRefresh = false,
  });

  final Set<WebsiteScreenshot> screenshots;

  /// A user-provided delegate that finds desired [WebsiteScreenshot]s by reading
  /// the global data index.
  ///
  /// This can be used, for example, to define desired screenshots in a local
  /// YAML file and then read that YAML data to request [WebsiteScreenshot]s.
  final WebsiteScreenshotSelector? selector;

  final StaticShockCache cache;

  /// The dimensions of the browser, which determines the dimensions of the screenshot.
  final ViewportSize viewportSize;

  /// The final width of the screenshot image, or `null` to keep the screenshot
  /// at its original width.
  final int? outputWidth;

  /// The final height of the screenshot image, or `null` to keep the screenshot
  /// at its original height.
  final int? outputHeight;

  /// `true` to place screenshots in a cache directory so that they can be re-used
  /// across builds, or `false` to take fresh screenshots on every build.
  final bool useCache;

  /// `true` to take fresh screenshots and overwrite any existing screenshots in the
  /// cache.
  final bool forceCacheRefresh;

  @override
  Future<void> loadAssets(StaticShockPipelineContext context) async {
    final screenshots = Set.from(this.screenshots);
    if (selector != null) {
      screenshots.addAll(selector!(context));
    }

    if (screenshots.isEmpty) {
      return;
    }

    context.log.detail("Taking screenshots of webpages...");
    final stopwatch = Stopwatch()..start();
    final screenshotsToTake = List<WebsiteScreenshot>.from(screenshots);

    // Find all cached screenshots and load them as assets.
    if (useCache && !forceCacheRefresh) {
      await _loadCachedScreenshots(context, screenshotsToTake);
    }
    if (screenshotsToTake.isEmpty) {
      // All screenshots were cached. No need to start a browser to take screenshots.
      return;
    }

    // Take fresh screenshots for items not in the cache.
    await _takeScreenshots(context, screenshotsToTake);

    stopwatch.stop();
    context.log.detail(
        "Done screenshotting webpages - Total screenshot time: ${stopwatch.elapsedMilliseconds.toDouble() / 1000}s");

    return;
  }

  Future<void> _loadCachedScreenshots(
    StaticShockPipelineContext context,
    List<WebsiteScreenshot> screenshotsToTake,
  ) async {
    context.log.detail("Checking for cached screenshots...");
    final screenshots = Set.from(screenshotsToTake);
    for (final screenshot in screenshots) {
      final screenshotCacheName = "${screenshot.id}.png";
      if (await cache.contains(screenshotCacheName)) {
        context.log.detail("Loading cached screenshot for: $screenshotCacheName");
        final cachedScreenshot = await cache.loadBinary(screenshotCacheName);
        if (cachedScreenshot == null) {
          // For some reason the cached file was empty. Ignore this cache value.
          context.log.detail("Screenshot ${screenshot.id}.png isn't in the cache");
          continue;
        }
        context.log.detail("Loading ${screenshot.id}.png from the cache");

        // Add the cached image to the assets collection.
        context.addAsset(
          Asset(
            destinationPath: screenshot.output,
            destinationContent: AssetContent.binary(cachedScreenshot),
          ),
        );

        // Remove this screenshot from the list of new screenshots that
        // need to be taken.
        screenshotsToTake.remove(screenshot);
      }
    }
    context.log.detail("Done loading cached screenshots.");
  }

  Future<void> _takeScreenshots(StaticShockPipelineContext context, List<WebsiteScreenshot> screenshotsToTake) async {
    final screenshotFutures = <Future>[];

    context.log.detail("Launching headless browser...");
    final browser = await puppeteer.launch(
      headless: true,
      defaultViewport: DeviceViewport(width: viewportSize.width, height: viewportSize.height),
    );
    context.log.detail("Browser is launched.");
    for (final screenshot in screenshotsToTake) {
      context.log.detail("Taking screenshot of: ${screenshot.url}");
      screenshotFutures.add(_takeScreenshot(context, browser, screenshot));
    }
    await Future.wait(screenshotFutures);
    browser.close();
  }

  Future<void> _takeScreenshot(
    StaticShockPipelineContext context,
    Browser browser,
    WebsiteScreenshot screenshot,
  ) async {
    final page = await browser.newPage();
    await page.goto(screenshot.url.toString(), wait: Until.networkIdle);
    final bitmap = await page.screenshot(
      format: ScreenshotFormat.png,
      fullPage: false,
      clip: Rectangle(0, 0, viewportSize.width, viewportSize.height),
    );
    page.close();

    var image = decodePng(bitmap)!;
    if (outputWidth != null || outputHeight != null) {
      // Resize the screenshot as desired.
      image = copyResize(
        image,
        width: outputWidth,
        height: outputHeight,
        interpolation: Interpolation.average,
      );
    }
    final pngBinary = encodePng(image);

    context.addAsset(
      Asset(
        destinationPath: screenshot.output,
        destinationContent: AssetContent.binary(pngBinary),
      ),
    );

    if (useCache) {
      cache.putBinary("${screenshot.id}.png", pngBinary);
    }
  }
}

class ViewportSize {
  const ViewportSize({
    required this.width,
    required this.height,
  });

  final int width;
  final int height;

  double get aspectRatio => width / height;

  ViewportSize scaleToWidth(int newWidth) => ViewportSize(width: newWidth, height: (newWidth / aspectRatio).round());

  ViewportSize scaleToHeight(int newHeight) =>
      ViewportSize(width: (newHeight * aspectRatio).round(), height: newHeight);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewportSize && runtimeType == other.runtimeType && width == other.width && height == other.height;

  @override
  int get hashCode => width.hashCode ^ height.hashCode;
}

class WebsiteScreenshot {
  const WebsiteScreenshot({
    required this.id,
    required this.url,
    required this.output,
  });

  /// ID that uniquely identifies this screenshot from all other
  /// screenshots.
  ///
  /// The [id] is used to cache the screenshot between builds. Therefore,
  /// two or more screenshots with the sam [id] will overwrite each other.
  final String id;

  /// The URL of the webpage to screenshot.
  final Uri url;

  /// The file path and name within the final build directory where this screenshot
  /// image should be placed.
  final FileRelativePath output;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WebsiteScreenshot && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
