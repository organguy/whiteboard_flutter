import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
// #docregion platform_imports
// Import for Android features.
import 'package:webview_flutter_android/webview_flutter_android.dart';
// Import for iOS features.
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
// #enddocregion platform_imports

import 'bridge.dart';

class DsBridgeWebView extends StatefulWidget {
  final BridgeCreatedCallback onDSBridgeCreated;

  DsBridgeWebView({
    Key? key,
    required this.onDSBridgeCreated,
  }) : super(key: key);

  @override
  DsBridgeWebViewState createState() => DsBridgeWebViewState();
}

class DsBridgeWebViewState extends State<DsBridgeWebView> {
  DsBridgeBasic dsBridge = DsBridgeBasic();

  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    // #docregion platform_features
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);
    // #enddocregion platform_features

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 DsBridge/1.0.0")
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('WebView is loading (progress : $progress%)');
          },
          onPageStarted: (String url) {
            _onPageStarted(url);
          },
          onPageFinished: (String url) {
            _onPageFinished(url);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Page resource error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('allowing navigation to ${request.url}');
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        DsBridge.BRIDGE_NAME,
        onMessageReceived: (JavaScriptMessage message) {
          var res = jsonDecode(message.message);
          dsBridge.javascriptInterface.call(res["method"], res["args"]);
        },
      )
      ..loadFlutterAsset(
          "packages/whiteboard_sdk_flutter/assets/whiteboardBridge/index.html");

    // #docregion platform_features
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
    // #enddocregion platform_features

    _controller = controller;
    dsBridge.initController(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (_) {
      return WebViewWidget(controller: _controller);
    });
  }

  void _onPageStarted(String url) {
    debugPrint('WebView Page started loading: $url');
    if (url.endsWith("whiteboardBridge/index.html")) {}
  }

  void _onPageFinished(String url) {
    debugPrint('WebView Page finished loading: $url');
    if (url.endsWith("whiteboardBridge/index.html")) {
      dsBridge.runCompatScript().then((_) {
        widget.onDSBridgeCreated(dsBridge);
      });
    }
  }
}

class DsBridgeBasic extends DsBridge {
  static const _compatDsScript = """
      if (window.__dsbridge) {
          window._dsbridge = {}
          window._dsbridge.call = function (method, arg) {
              console.log(`call flutter webview \${method} \${arg}`);
              window.__dsbridge.postMessage(JSON.stringify({ "method": method, "args": arg }))
              return '{}';
          }
          console.log("wrapper flutter webview success");
      } else {
          console.log("window.__dsbridge undefine");
      }
  """;

  late WebViewController _controller;

  Future<void> initController(WebViewController controller) async {
    _controller = controller;
  }

  Future<void> runCompatScript() async {
    try {
      await _controller.runJavaScript(_compatDsScript);
    } catch (e) {
      print("WebView bridge run compat script error $e");
    }
  }

  @override
  FutureOr<String?> evaluateJavascript(String javascript) async {
    try {
      final result = await _controller.runJavaScriptReturningResult(javascript);
      return result.toString();
    } catch (e) {
      print("WebView bridge evaluateJavascript cause $e");
      return null;
    }
  }
}
