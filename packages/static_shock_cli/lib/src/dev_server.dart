import 'dart:async';
import 'dart:io';

import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:watcher/watcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'website_builder.dart';

/// Web server for local Static Shock development.
///
/// This web server serves static assets, as expected, but also injects developer
/// tools, such as injecting JavaScript to automatically refresh a page when its
/// source changes on the server.
class StaticShockDevServer {
  StaticShockDevServer(
    this._log,
    this._buildWebsiteDelegate, {
    List<String> appArguments = const [],
  }) : _appArguments = appArguments;

  final Logger _log;

  /// Delegate that (re)builds the website by running the Static Shock pipeline.
  final WebsiteBuilder _buildWebsiteDelegate;

  final List<String> _appArguments;

  /// Whether this server is active.
  bool _isServing = false;
  HttpServer? _server;

  /// The port that this dev server is listening to.
  late int _port;

  /// Websocket connections to every active webpage that's been served, used to
  /// send refresh signals when the site rebuilds.
  final _connectedWebpages = <WebSocketChannel>{};

  /// Whether a website build is actively in-progress.
  bool isBuilding = false;

  /// Whether another website build is desired after the one that's currently in-progress.
  bool isAnotherBuildQueued = false;

  /// Starts a development mode web server.
  ///
  /// The dev server serves static assets, as expected. It also intercepts all HTML webpages
  /// and injects JavaScript that causes a page refresh whenever the site is rebuilt.
  ///
  /// To stop the dev server, call [stop].
  Future<void> run({
    required int port,
    bool findAnOpenPort = false,
    String? basePath,
  }) async {
    if (_isServing) {
      _log.err("Tried to start a dev server, but it's already running!");
      return;
    }
    _isServing = true;

    _log.info("Serving a static site!");
    int chosenPort = port;
    const maxPortTryCount = 50;
    final serverHandler = _createServerHandler(basePath: basePath);
    do {
      try {
        _server = await serve(serverHandler, 'localhost', chosenPort);
      } on SocketException {
        if (!findAnOpenPort) {
          rethrow;
        }
        if ((chosenPort - port) > maxPortTryCount) {
          _log.err("Couldn't find open port on localhost. Tried ports from $port to $chosenPort.");
          return;
        }

        chosenPort = chosenPort + 1;
      }
    } while (_server == null);

    // Track the actual port that was chosen.
    _port = chosenPort;

    // Enable content compression
    _server!.autoCompress = true;

    _log.success('Serving at http://${_server!.address.host}:${_server!.port}');
    _log.detail(" - port: ${_server!.port}");
    _log.detail(" - base path: $basePath");

    // Rebuild the website whenever a source file changes.
    DirectoryWatcher("${Directory.current.absolute.path}${Platform.pathSeparator}bin") //
        .events
        .listen(_onSourceFileChange);
    DirectoryWatcher("${Directory.current.absolute.path}${Platform.pathSeparator}source") //
        .events
        .listen(_onSourceFileChange);
  }

  /// Stops a dev server that was started with [run].
  Future<void> stop() async {
    if (!_isServing) {
      return;
    }

    try {
      await _server!.close();
    } finally {
      _server = null;
      _connectedWebpages.clear();
      _isServing = false;
    }
  }

  FutureOr<Response> Function(Request) _createServerHandler({
    String? basePath,
  }) {
    return (Request request) {
      _log.detail("Received request: ${request.url}");
      if (request.url.path == 'ws') {
        _log.detail("Sending request to websocket handler");
        return _createDevServerSocketHandler()(request);
      } else {
        _log.detail("Sending request to standard handler");
        return _createStaticSiteServerHandler(basePath: basePath)(request);
      }
    };
  }

  /// Creates the static web server handler for the dev server.
  ///
  /// This handler serves HTML pages, CSS stylesheets, JS scripts, images, and other
  /// static assets.
  FutureOr<Response> Function(Request) _createStaticSiteServerHandler({
    String? basePath,
  }) {
    return const Pipeline() //
        .addMiddleware(logRequests()) //
        .addMiddleware(_injectDevServerWebSocket(() => _port))
        .addMiddleware(_removeBasePath(_log, basePath))
        .addHandler(
          createStaticHandler(
            'build',
            defaultDocument: 'index.html',
          ),
        );
  }

  /// Creates a Shelf websocket handler, which we expect each webpage to connect to for
  /// refresh signals.
  ///
  /// This dev server adds a snippet of JavaScript to every HTML page that it serves. That
  /// JavaScript snippet connects a websocket to this handler. Whenever this server sends
  /// a refresh message through the websocket, each connected webpage requests a refresh,
  /// thereby receiving the latest version of itself from the server.
  FutureOr<Response> Function(Request) _createDevServerSocketHandler() {
    return webSocketHandler((WebSocketChannel webSocket) {
      _log.detail("Adding new websocket: $webSocket - ID: ${webSocket.hashCode}");
      _connectedWebpages.add(webSocket);

      webSocket.stream.listen((message) {
        _log.detail("Page websocket received message: '$message'");
        webSocket.sink.add("echo $message");
      });

      webSocket.sink.done.then((webSocketImpl) {
        // Note: The "web socket" we're given in this callback is of type WebSocketImpl, which is
        // different from the WebSocketChannel type that we receive in the main callback above.
        _log.detail("WebSocket is done! Removing it: $webSocket - ID: ${webSocket.hashCode}");
        _connectedWebpages.remove(webSocket);
      });
    });
  }

  Future<void> _onSourceFileChange(WatchEvent event) async {
    if (event.path.contains(".shock")) {
      // Don't track changes to the Static Shock cache so that `shock serve`
      // doesn't get stuck in an endless build loop.
      return;
    }

    // WARNING: Don't log anything with mason_logger if we're already running a
    // build. Something is causing the logger to blow up. https://github.com/felangel/mason/issues/1280
    if (isBuilding) {
      // A website build is already on-going. We don't want to risk conflicting file outputs
      // on the file system. Queue another build when the current build is done.
      isAnotherBuildQueued = true;
      // ignore: avoid_print
      print(
          "File system change (${event.type}): ${event.path} - server is already running a build. We'll queue a followup build to run after that.");
      return;
    }

    _log.detail("File system change (${event.type}): ${event.path}.");

    // Run a website build, and then keep rebuilding as long as more changes come in while
    // we're running a build.
    do {
      _log.detail("Rebuilding the website.");
      isBuilding = true;
      isAnotherBuildQueued = false;

      final stopwatch = Stopwatch()..start();
      try {
        final exitCode = await _buildWebsiteDelegate(appArguments: _appArguments);
        isBuilding = false;
        stopwatch.stop();

        if (exitCode == null) {
          // A build pre-flight check failed, so the build never even started. Fizzle.
          _log.err("Website build failed pre-flight checks. Build failed. Not refreshing pages.");
          return;
        }

        if (exitCode != 0) {
          // Something went wrong during the build. Don't refresh the pages because the
          // pages probably won't exist. Fizzle.
          _log.err("Website build encountered an error during the build ($exitCode). Not refreshing pages.");
          return;
        }
      } catch (exception) {
        // Something went wrong during the build. Don't refresh the pages because the
        // pages probably won't exist. Fizzle.
        _log.err("Website build encountered an error during the build ($exception). Not refreshing pages.");
        stopwatch.stop();
        isBuilding = false;
        return;
      }

      _log.detail("Rebuilt website in ${stopwatch.elapsed.inMilliseconds}ms");

      if (!isAnotherBuildQueued) {
        // We're done running all the queued builds, so now we can have the connected
        // websites refresh their files without running into a race condition with the
        // build system. Notify the websites to update themselves.
        //
        // Previously, we were refreshing the webpages after every build, while immediately
        // starting a followup build. I think this created a file system race condition, and
        // lead to crashes similar to this: https://github.com/Flutter-Bounty-Hunters/static_shock/issues/76
        _log.detail("Notifying ${_connectedWebpages.length} connected webpages to refresh.");
        for (final page in _connectedWebpages) {
          page.sink.add("refresh");
        }
      }
    } while (isAnotherBuildQueued);
  }
}

/// Middleware, which adds a JavaScript snippet to every HTML page in which the JavaScript
/// establishes a websocket with this server to receive a refresh signal from the server.
///
/// When this JavaScript snippet receives a refresh signal from the dev server, it requests
/// a full page refresh so that the page is running the latest version from the server. This
/// is kind of a like an automatic "hot restart" for every HTML page that this dev server
/// serves.
// ignore: unused_element, unused_element_parameter
Middleware _injectDevServerWebSocket(int Function() getPort, {void Function(String message, bool isError)? logger}) =>
    (innerHandler) {
      return (request) async {
        final response = await innerHandler(request);

        if (response.mimeType != "text/html") {
          return response;
        }

        // This is an HTML page. Inject dev server websocket to enable auto-refresh.
        final html = await response.readAsString();
        final dom = parse(html);
        dom.body!.append(DocumentFragment.html('''
        <script>
          // Create a WebSocket connection
          var socket = new WebSocket('ws://localhost:${getPort()}/ws');
          
          socket.onopen = function() {
            console.log('Opening auto-refresh signal websocket with dev server.');
            // Tell the dev server our HTML page page so the dev server can
            // invalidate us when that page changes.
            console.log('Our page path of interest is: ', location.pathname);
            socket.send(location.pathname);
          };
          
          socket.onmessage = function(event) {
            if (event.data == "refresh") {
              console.log('The dev server sent us a refresh signal. Refreshing the page.');
              location.reload();
            }
          };
          
          socket.onclose = function() {
            console.log('The dev server auto-refresh websocket has been closed.');
          };
        </script>
        '''));

        // Update the HTML that we're serving to include the refresh JavaScript snippet.
        return response.change(
          body: dom.outerHtml,
        );
      };
    };

/// Middleware that removes a given [basePath] from all incoming requests.
///
/// This middleware simulates a deployment server that adds a base path. For
/// example, GitHub pages adds a base path to all URLs, whose value is the same
/// as the repository name.
Middleware _removeBasePath(Logger log, String? basePath) => (innerHandler) {
      return (request) async {
        if (basePath == null) {
          // No base path desired for the dev server. Process request without alteration.
          return await innerHandler(request);
        }

        final requestedPath = "/${request.url}";
        if (request.url.pathSegments.isEmpty || !requestedPath.startsWith(requestedPath)) {
          // There's no base path configured, or the requested URL doesn't start
          // with the given base path. Execute without intervention.
          log.warn(
              "The dev server is configured with a base path ($basePath), but server received a request for a URL without the base path: '$requestedPath'");
          return await innerHandler(request);
        }

        // There's a base path. Strip it from the request path.
        var newPath = requestedPath.substring(basePath.length);
        if (newPath.isEmpty) {
          newPath = "/";
        }
        final newRequest = Request(
          request.method,
          request.requestedUri.replace(path: newPath),
          headers: request.headers,
        );
        log.detail("Rewrote incoming path to: '$newPath'");
        return await innerHandler(newRequest);
      };
    };
