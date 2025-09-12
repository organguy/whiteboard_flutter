import 'package:flutter/material.dart';

class WebViewFocusWrapper extends StatefulWidget {
  final Widget child;
  const WebViewFocusWrapper({Key? key, required this.child}) : super(key: key);

  @override
  State<WebViewFocusWrapper> createState() => _WebViewFocusWrapperState();
}

class _WebViewFocusWrapperState extends State<WebViewFocusWrapper> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'webview_focus');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      canRequestFocus: true,
      child: Listener(
        behavior: HitTestBehavior.deferToChild,
        onPointerDown: (_) {
          // 탭 시 Flutter 포커스 경합을 빠르게 이겨서
          // 하위 네이티브 뷰(WebView) 포커스 흐름을 방해하지 않게 함
          if (!_focusNode.hasFocus) {
            _focusNode.requestFocus();
          }
        },
        child: widget.child,
      ),
    );
  }
}