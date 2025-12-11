import 'package:dio/dio.dart';

class YouTubeService {
  static const String apiKey = 'AIzaSyDyVAa7bYJJQvKO-pox-BcJE_DRt8aN6Qw';
  static const String baseUrl = 'https://www.googleapis.com/youtube/v3';

  final Dio _dio = Dio();

  /// Searches for a video on YouTube.
  /// Returns the video ID of the first result.
  Future<String?> searchVideo(String query) async {
    try {
      final response = await _dio.get(
        '$baseUrl/search',
        queryParameters: {
          'part': 'snippet',
          'q': query,
          'type': 'video',
          'maxResults': 1,
          'key': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final items = response.data['items'] as List;
        if (items.isNotEmpty) {
          return items[0]['id']['videoId'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

