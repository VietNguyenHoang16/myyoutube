import 'dart:convert';
import 'package:http/http.dart' as http;

class PodLogEpisode {
  final String id;
  final String channelId;
  final String title;
  final String? url;
  final String? image;
  final int? durationSeconds;
  final String status;
  final List<dynamic> tags;

  PodLogEpisode({
    required this.id,
    required this.channelId,
    required this.title,
    this.url,
    this.image,
    this.durationSeconds,
    required this.status,
    required this.tags,
  });

  factory PodLogEpisode.fromJson(Map<String, dynamic> json) {
    return PodLogEpisode(
      id: json['id'] ?? '',
      channelId: json['channel_id'] ?? '',
      title: json['title'] ?? '',
      url: json['url'],
      image: json['image'],
      durationSeconds: json['duration_seconds'],
      status: json['status'] ?? 'chua_nghe',
      tags: List<dynamic>.from(json['tags'] ?? []),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'chua_nghe':
        return 'Chưa nghe';
      case 'dang_nghe':
        return 'Đang nghe';
      case 'da_xong':
        return 'Đã xong';
      case 'on_lai':
        return 'Ôn lại';
      default:
        return status;
    }
  }

  String get durationLabel {
    if (durationSeconds == null || durationSeconds! <= 0) return '';
    final m = durationSeconds! ~/ 60;
    final s = durationSeconds! % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  bool get hasYoutubeUrl => url != null && url!.isNotEmpty;
}

class PodLogService {
  static const String _defaultBaseUrl = 'https://podlog-three.vercel.app';

  String _baseUrl;

  PodLogService({String? baseUrl}) : _baseUrl = baseUrl ?? _defaultBaseUrl;

  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  String get baseUrl => _baseUrl;

  Future<List<PodLogEpisode>> fetchYoutubeEpisodes({String? channelId}) async {
    final uri = Uri.parse('$_baseUrl/api/episodes-youtube')
        .replace(queryParameters: channelId != null ? {'channel_id': channelId} : null);

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => PodLogEpisode.fromJson(e)).toList();
      }
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] != null) {
        throw Exception(body['error']);
      }
      throw Exception('Server error ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }
}
