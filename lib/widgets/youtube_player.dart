import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/youtube_html.dart';

class YouTubePlayer extends StatefulWidget {
  final String videoId;
  final VoidCallback? onReady;
  final void Function(Map<String, dynamic> msg)? onMessage;

  const YouTubePlayer({
    super.key,
    required this.videoId,
    this.onReady,
    this.onMessage,
  });

  @override
  State<YouTubePlayer> createState() => YouTubePlayerState();
}

class YouTubePlayerState extends State<YouTubePlayer> {
  WebViewController? _controller;
  Timer? _statusTimer;
  bool _ready = false;

  void skipForward() {
    _controller?.runJavaScript(seekScript(1));
  }

  void skipBackward() {
    _controller?.runJavaScript(seekScript(-1));
  }

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(YouTubePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.videoId != oldWidget.videoId) {
      _ready = false;
      _statusTimer?.cancel();
      _initController();
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _initController() {
    final url = buildEmbedUrl(widget.videoId);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'SkipButtons',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = jsonDecode(message.message) as Map<String, dynamic>;
            if (data['type'] == 'ready' && !_ready) {
              _ready = true;
              widget.onReady?.call();
              _startStatusPolling();
            }
            widget.onMessage?.call(data);
          } catch (_) {}
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _controller?.runJavaScript(readyDetector());
          },
          onWebResourceError: (_) {},
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  void _startStatusPolling() {
    _statusTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_ready && _controller != null) {
        _controller?.runJavaScript(statusQuery());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller!);
  }
}
