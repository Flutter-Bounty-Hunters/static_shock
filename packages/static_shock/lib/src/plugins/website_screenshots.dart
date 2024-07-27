import 'dart:async';
import 'dart:io';

import 'package:image/image.dart';
import 'package:puppeteer/puppeteer.dart';
import 'package:static_shock/src/assets.dart';
import 'package:static_shock/src/data.dart';
import 'package:static_shock/src/files.dart';
import 'package:static_shock/src/pipeline.dart';
import 'package:static_shock/src/static_shock.dart';

class WebsiteScreenshotsPlugin extends StaticShockPlugin {
  const WebsiteScreenshotsPlugin(this.screenshots);

  final Set<WebsiteScreenshot> screenshots;

  @override
  void configure(StaticShockPipeline pipeline, StaticShockPipelineContext context) {
    pipeline.loadData(
      WebsiteScreenshotsDataLoader(screenshots),
    );
  }
}

class WebsiteScreenshotsDataLoader implements DataLoader {
  const WebsiteScreenshotsDataLoader(this.screenshots);

  final Set<WebsiteScreenshot> screenshots;

  @override
  Future<Map<String, Object>> loadData(StaticShockPipelineContext context) async {
    final stopwatch = Stopwatch()..start();

    final screenshotFutures = <Future>[];

    print("Launching browser...");
    final viewportSize = ViewportSize(width: 1280, height: 1024);
    final browser = await puppeteer.launch(
      headless: true,
      defaultViewport: DeviceViewport(width: viewportSize.width, height: viewportSize.height),
    );
    print("Browser is launched.");
    for (final screenshot in screenshots) {
      print("Taking screenshot of: ${screenshot.url}");
      screenshotFutures.add(_takeScreenshot(context, browser, viewportSize, screenshot));
    }
    await Future.wait(screenshotFutures);
    browser.close();

    stopwatch.stop();
    print("Total screenshot time: ${stopwatch.elapsedMilliseconds.toDouble() / 1000}s");

    return {};
  }

  Future<void> _takeScreenshot(
    StaticShockPipelineContext context,
    Browser browser,
    ViewportSize viewport,
    WebsiteScreenshot screenshot,
  ) async {
    final page = await browser.newPage();
    await page.goto(screenshot.url.toString(), wait: Until.networkIdle);
    final bitmap = await page.screenshot(
      format: ScreenshotFormat.png,
      fullPage: false,
      clip: Rectangle(0, 0, viewport.width, viewport.height),
    );
    page.close();

    final image = decodePng(bitmap)!;
    final smallImage = copyResize(image, width: 256, interpolation: Interpolation.average);

    context.addAsset(
      Asset(
        destinationPath: screenshot.output,
        destinationContent: AssetContent.binary(
          encodePng(smallImage),
        ),
      ),
    );
  }
}

class ViewportSize {
  ViewportSize({
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
  const WebsiteScreenshot(this.id, this.url, this.output);

  final String id;
  final Uri url;
  final FileRelativePath output;
}
