import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myyoutube/services/podlog_service.dart';

const _defaultOrientations = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

const _fullscreenOrientations = [
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setPreferredOrientations(_defaultOrientations);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const YouTubeHome(),
    );
  }
}

class YouTubeHome extends StatefulWidget {
  const YouTubeHome({super.key});
  @override
  State<YouTubeHome> createState() => _YouTubeHomeState();
}

class _YouTubeHomeState extends State<YouTubeHome> {
  late final WebViewController _controller;
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  double _leftX = -1, _leftY = -1;
  double _rightX = -1, _rightY = -1;
  double _pauseX = -1, _pauseY = -1;
  bool _paused = false;

  bool _isFullscreen = false;
  double _videoCurrentTime = 0;
  double _videoDuration = 0;
  Timer? _fullscreenTimer;

  final PodLogService _podlogService = PodLogService();

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; CPH2797) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36',
      )
      ..loadRequest(Uri.parse('https://m.youtube.com'));
    _loadPositions();
    _loadPodLogUrl();
  }

  Future<void> _loadPositions() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      // Detect old pixel-based format (values > 1.0) and reset
      final vals = [
        prefs.getDouble('left_x') ?? -1,
        prefs.getDouble('left_y') ?? -1,
        prefs.getDouble('right_x') ?? -1,
        prefs.getDouble('right_y') ?? -1,
        prefs.getDouble('pause_x') ?? -1,
        prefs.getDouble('pause_y') ?? -1,
      ];
      final hasOldFormat = vals.any((v) => v > 1.0);
      if (hasOldFormat) {
        await prefs.remove('left_x');
        await prefs.remove('left_y');
        await prefs.remove('right_x');
        await prefs.remove('right_y');
        await prefs.remove('pause_x');
        await prefs.remove('pause_y');
      }
      setState(() {
        _leftX = hasOldFormat ? -1 : vals[0];
        _leftY = hasOldFormat ? -1 : vals[1];
        _rightX = hasOldFormat ? -1 : vals[2];
        _rightY = hasOldFormat ? -1 : vals[3];
        _pauseX = hasOldFormat ? -1 : vals[4];
        _pauseY = hasOldFormat ? -1 : vals[5];
      });
    }
  }

  Future<void> _loadPodLogUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('podlog_url');
    if (saved != null && saved.isNotEmpty) {
      _podlogService.setBaseUrl(saved);
    }
  }

  void _showPodLogSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _PodLogSheet(
          service: _podlogService,
          onOpenEpisode: (ep) {
            if (ep.url != null) {
              _controller.loadRequest(Uri.parse(ep.url!));
            }
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  Future<void> _savePositions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('left_x', _leftX);
    await prefs.setDouble('left_y', _leftY);
    await prefs.setDouble('right_x', _rightX);
    await prefs.setDouble('right_y', _rightY);
    await prefs.setDouble('pause_x', _pauseX);
    await prefs.setDouble('pause_y', _pauseY);
  }

  void _resetPositions() {
    setState(() {
      _leftX = -1;
      _leftY = -1;
      _rightX = -1;
      _rightY = -1;
      _pauseX = -1;
      _pauseY = -1;
    });
    _savePositions();
  }

  void _doSearch() {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    _controller.loadRequest(
      Uri.parse(
        'https://m.youtube.com/results?search_query=${Uri.encodeComponent(q)}',
      ),
    );
    _searchCtrl.clear();
    setState(() => _showSearch = false);
    _searchFocus.unfocus();
  }

  void _skip(int seconds) {
    _controller.runJavaScript('''
(function(){
var v=document.querySelector('video');
if(v){
  var t=v.currentTime + $seconds;
  if(t<0)t=0;
  if(t>v.duration)t=v.duration;
  v.currentTime=t;
}
})();
''');
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    _controller.runJavaScript('''
(function(){
var v=document.querySelector('video');
if(v){v.paused?v.play():v.pause();}
})();
''');
  }

  Future<void> _toggleFullscreen() async {
    if (_isFullscreen) {
      _fullscreenTimer?.cancel();
      _fullscreenTimer = null;
      setState(() => _isFullscreen = false);
      await _restoreDefaultChrome();
    } else {
      setState(() => _isFullscreen = true);
      try {
        await SystemChrome.setPreferredOrientations(_fullscreenOrientations);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        await _controller.runJavaScript('''
(function(){
  window.dispatchEvent(new Event('resize'));
  var v=document.querySelector('video');
  if(v){v.dispatchEvent(new Event('resize'));}
})();
''');
      } catch (_) {}
      _startFullscreenPolling();
    }
  }

  Future<void> _restoreDefaultChrome() async {
    try {
      await SystemChrome.setPreferredOrientations(_defaultOrientations);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}
  }

  void _startFullscreenPolling() {
    _fullscreenTimer?.cancel();
    _fullscreenTimer = Timer.periodic(const Duration(milliseconds: 500), (
      _,
    ) async {
      try {
        final result = await _controller.runJavaScriptReturningResult('''
(function(){
var v=document.querySelector('video');
if(v)return JSON.stringify({t:v.currentTime,d:v.duration,p:v.paused});
return JSON.stringify({t:0,d:0,p:true});
})();
''');
        if (!mounted || !_isFullscreen) return;
        final data = jsonDecode(result.toString()) as Map<String, dynamic>;
        setState(() {
          _videoCurrentTime = (data['t'] as num).toDouble();
          _videoDuration = (data['d'] as num).toDouble();
          _paused = data['p'] as bool;
        });
      } catch (_) {}
    });
  }

  String _formatTime(double seconds) {
    if (seconds.isNaN || seconds.isInfinite || seconds < 0) return '00:00';
    final totalSecs = seconds.floor();
    final m = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final s = (totalSecs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _fullscreenTimer?.cancel();
    unawaited(_restoreDefaultChrome());
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final leftPad = MediaQuery.of(context).padding.left;
    final rightPad = MediaQuery.of(context).padding.right;

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          const bs = 50.0;

          final availW = w - leftPad - rightPad;
          final availH = h - topPad - bottomPad;

          Offset percentToPixel(
            double px,
            double py,
            double defX,
            double defY,
          ) {
            final x = px >= 0 ? leftPad + px * availW : defX;
            final y = py >= 0 ? topPad + py * availH : defY;
            return Offset(
              x.clamp(leftPad, w - bs - rightPad),
              y.clamp(topPad, h - bs - bottomPad),
            );
          }

          final left = percentToPixel(_leftX, _leftY, 14, topPad + h * 0.78);
          final right = percentToPixel(
            _rightX,
            _rightY,
            w - 14 - bs,
            topPad + h * 0.78,
          );
          final pause = percentToPixel(
            _pauseX,
            _pauseY,
            w / 2 - bs / 2,
            topPad + h * 0.78,
          );

          return Stack(
            children: [
              Positioned.fill(child: WebViewWidget(controller: _controller)),
              Positioned(
                top: topPad + 6,
                left: 0,
                right: 0,
                child: _showSearch
                    ? _buildSearchField()
                    : _isFullscreen
                    ? _buildFullscreenBar()
                    : _buildTopNav(),
              ),
              _DraggableButton(
                pos: left,
                icon: Icons.replay_5,
                label: '◄ 1s',
                onTap: () => _skip(-1),
                onMoved: (p) {
                  _leftX = (p.dx - leftPad) / availW;
                  _leftY = (p.dy - topPad) / availH;
                },
                onRelease: _savePositions,
              ),
              _DraggableButton(
                pos: right,
                icon: Icons.forward_5,
                label: '1s ►',
                onTap: () => _skip(1),
                onMoved: (p) {
                  _rightX = (p.dx - leftPad) / availW;
                  _rightY = (p.dy - topPad) / availH;
                },
                onRelease: _savePositions,
              ),
              _DraggableButton(
                pos: pause,
                icon: _paused ? Icons.play_arrow : Icons.pause,
                label: _paused ? 'Play' : 'Pause',
                onTap: _togglePause,
                onMoved: (p) {
                  _pauseX = (p.dx - leftPad) / availW;
                  _pauseY = (p.dy - topPad) / availH;
                },
                onRelease: _savePositions,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopNav() {
    return Row(
      children: [
        GestureDetector(
          onTap: _toggleFullscreen,
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
          ),
        ),
        GestureDetector(
          onTap: () => _controller.goBack(),
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: _showPodLogSheet,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.playlist_play,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: _resetPositions,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.refresh, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () {
            setState(() => _showSearch = true);
            Future.delayed(const Duration(milliseconds: 100), () {
              _searchFocus.requestFocus();
            });
          },
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildFullscreenBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggleFullscreen,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.fullscreen_exit,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${_formatTime(_videoCurrentTime)} / ${_formatTime(_videoDuration)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const Spacer(),
          if (_paused)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pause, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'PAUSED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red, width: 1.5),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              setState(() => _showSearch = false);
              _searchFocus.unfocus();
            },
            child: const Padding(
              padding: EdgeInsets.only(left: 6, right: 2),
              child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Tim kiem tren YouTube',
                hintStyle: TextStyle(color: Colors.white54, fontSize: 15),
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(bottom: 2),
              ),
              onSubmitted: (_) => _doSearch(),
            ),
          ),
          GestureDetector(
            onTap: _doSearch,
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 2),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _PodLogSheet extends StatefulWidget {
  final PodLogService service;
  final void Function(PodLogEpisode) onOpenEpisode;

  const _PodLogSheet({required this.service, required this.onOpenEpisode});

  @override
  State<_PodLogSheet> createState() => _PodLogSheetState();
}

class _PodLogSheetState extends State<_PodLogSheet> {
  List<PodLogEpisode> _episodes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final episodes = await widget.service.fetchYoutubeEpisodes();
      if (mounted) {
        setState(() {
          _episodes = episodes;
          _loading = false;
          if (episodes.isEmpty) {
            _error = 'Không có bài học YouTube nào trong PodLog';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'Không kết nối được PodLog: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    }
  }

  void _showSettings() {
    Navigator.of(context).pop();
    final urlCtrl = TextEditingController(text: widget.service.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'PodLog Server URL',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: urlCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'https://podlog-three.vercel.app',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () async {
              final url = urlCtrl.text.trim();
              if (url.isNotEmpty) {
                widget.service.setBaseUrl(url);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('podlog_url', url);
              }
              Navigator.of(ctx).pop();
              _fetch();
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'chua_nghe':
        return Colors.orange;
      case 'dang_nghe':
        return Colors.blue;
      case 'da_xong':
        return Colors.green;
      case 'on_lai':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    var body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, color: Colors.white24, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _fetch,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Thử lại'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: _episodes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final ep = _episodes[i];
              return GestureDetector(
                onTap: () => widget.onOpenEpisode(ep),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF252525),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ep.image != null && ep.image!.isNotEmpty
                            ? Image.network(
                                ep.image!,
                                width: 80,
                                height: 45,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _thumbPlaceholder(),
                              )
                            : _thumbPlaceholder(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ep.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(
                                      ep.status,
                                    ).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    ep.statusLabel,
                                    style: TextStyle(
                                      color: _statusColor(ep.status),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (ep.durationLabel.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.timer,
                                    size: 12,
                                    color: Colors.white38,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    ep.durationLabel,
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.play_circle_fill,
                        color: Colors.red,
                        size: 28,
                      ),
                    ],
                  ),
                ),
              );
            },
          );

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(width: 16),
                  const Icon(Icons.playlist_play, color: Colors.blue, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'PodLog — Bài học',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.settings,
                      color: Colors.white54,
                      size: 20,
                    ),
                    onPressed: _showSettings,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: 80,
      height: 45,
      color: const Color(0xFF333333),
      child: const Center(
        child: Icon(Icons.videocam, color: Colors.white24, size: 20),
      ),
    );
  }
}

class _DraggableButton extends StatefulWidget {
  final Offset pos;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final void Function(Offset) onMoved;
  final VoidCallback onRelease;

  const _DraggableButton({
    required this.pos,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.onMoved,
    required this.onRelease,
  });

  @override
  State<_DraggableButton> createState() => _DraggableButtonState();
}

class _DraggableButtonState extends State<_DraggableButton> {
  bool _dragging = false;
  Offset _dragStart = Offset.zero;
  Offset _posAtDragStart = Offset.zero;
  static const _btnSize = 50.0;

  Offset _clamp(Offset p, Size s, EdgeInsets pad) {
    return Offset(
      p.dx.clamp(pad.left, s.width - _btnSize - pad.right),
      p.dy.clamp(pad.top, s.height - _btnSize - pad.bottom),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final pad = MediaQuery.of(context).padding;
    final clamped = _clamp(widget.pos, screen, pad);

    return Positioned(
      left: clamped.dx,
      top: clamped.dy,
      child: GestureDetector(
        onTap: _dragging ? null : widget.onTap,
        onLongPressStart: (d) {
          _dragStart = d.globalPosition;
          _posAtDragStart = widget.pos;
          setState(() => _dragging = true);
        },
        onLongPressEnd: (_) {
          setState(() => _dragging = false);
          widget.onRelease();
        },
        onLongPressMoveUpdate: (d) {
          final delta = d.globalPosition - _dragStart;
          final newPos = Offset(
            _posAtDragStart.dx + delta.dx,
            _posAtDragStart.dy + delta.dy,
          );
          widget.onMoved(_clamp(newPos, screen, pad));
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: _dragging ? 62 : _btnSize,
          height: _dragging ? 62 : _btnSize,
          decoration: BoxDecoration(
            color: _dragging
                ? Colors.white.withValues(alpha: 0.35)
                : Colors.black54,
            shape: BoxShape.circle,
            border: Border.all(
              color: _dragging ? Colors.white54 : Colors.white24,
              width: _dragging ? 2.5 : 1.5,
            ),
          ),
          child: Center(
            child: _dragging
                ? Icon(widget.icon, color: Colors.white, size: 28)
                : Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
