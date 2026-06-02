import 'package:flutter/material.dart';

class VideoInput extends StatefulWidget {
  final void Function(String videoId) onLoad;

  const VideoInput({super.key, required this.onLoad});

  @override
  State<VideoInput> createState() => _VideoInputState();
}

class _VideoInputState extends State<VideoInput> {
  final _controller = TextEditingController();
  String? _error;

  String? _parseYouTubeId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final directId = RegExp(r'^[a-zA-Z0-9_-]{11}$');
    if (directId.hasMatch(trimmed)) return trimmed;

    final patterns = [
      RegExp(r'(?:youtube\.com/watch\?v=)([a-zA-Z0-9_-]{11})'),
      RegExp(r'(?:youtu\.be/)([a-zA-Z0-9_-]{11})'),
      RegExp(r'(?:youtube\.com/shorts/)([a-zA-Z0-9_-]{11})'),
      RegExp(r'(?:youtube\.com/embed/)([a-zA-Z0-9_-]{11})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(trimmed);
      if (match != null) return match.group(1);
    }

    try {
      final uri = Uri.parse(trimmed);
      final v = uri.queryParameters['v'];
      if (v != null && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(v)) return v;
    } catch (_) {}

    return null;
  }

  void _handleLoad() {
    final videoId = _parseYouTubeId(_controller.text);
    if (videoId == null) {
      setState(() => _error = 'URL YouTube hoặc video ID không hợp lệ');
      return;
    }
    setState(() => _error = null);
    FocusScope.of(context).unfocus();
    widget.onLoad(videoId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Dán link YouTube hoặc video ID...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF333333)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF333333)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onSubmitted: (_) => _handleLoad(),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _handleLoad,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Load',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
