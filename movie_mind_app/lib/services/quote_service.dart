import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui'; // For RootIsolateToken
import '../models/movie.dart';

class QuoteMatch {
  final Movie movie;
  final String matchedContent; // Combined content for legacy support or script snippets
  final String contentEn;
  final String contentZh;
  final String startTime;
  final String endTime;
  final String keyword;
  final String source; // 'subtitle' or 'script'

  QuoteMatch({
    required this.movie,
    required this.matchedContent,
    this.contentEn = '',
    this.contentZh = '',
    this.startTime = '',
    this.endTime = '',
    required this.keyword,
    required this.source,
  });
}

class QuoteService {
  static final QuoteService _instance = QuoteService._internal();
  factory QuoteService() => _instance;
  QuoteService._internal();

  Map<String, List<dynamic>>? _subtitleData;

  Future<void> init() async {
    if (_subtitleData != null) return;
    
    try {
      // 1. Load subtitles (small file, ~3.6MB)
      final String subtitleJson = await rootBundle.loadString('assets/scripts/33_subtitles_data_with_tmdb.json');
      final Map<String, dynamic> parsed = jsonDecode(subtitleJson);
      if (parsed['data'] != null) {
        _subtitleData = Map<String, List<dynamic>>.from(parsed['data']);
      }
    } catch (e) {
      debugPrint('Error loading subtitles: $e');
      _subtitleData = {};
    }
  }

  // Search logic
  Future<List<QuoteMatch>> searchQuotes(String query) async {
    if (_subtitleData == null) await init();
    
    List<QuoteMatch> results = [];
    final lowerQuery = query.toLowerCase().trim();

    // 1. Search in subtitles (curated data)
    if (_subtitleData != null) {
      _subtitleData!.forEach((keyword, matches) {
        bool keywordMatches = keyword.toLowerCase().contains(lowerQuery);
        
        for (var item in matches) {
           String content = item['subtitle_content'] ?? '';
           String contentZh = item['subtitle_content_zh'] ?? '';
           
           if (keywordMatches || 
               content.toLowerCase().contains(lowerQuery) || 
               contentZh.contains(lowerQuery)) {
             
             if (item['tmdb'] != null) {
               final movie = Movie.fromLocalJson(item['tmdb']);
               
               results.add(QuoteMatch(
                 movie: movie,
                 matchedContent: '', // Not used for subtitle results in new UI
                 contentEn: content,
                 contentZh: contentZh,
                 startTime: item['start_time'] ?? '',
                 endTime: item['end_time'] ?? '',
                 keyword: keyword,
                 source: 'subtitle',
               ));
             }
           }
        }
      });
    }

    // 2. Search in scripts (large file, ~300MB)
    // Only search scripts if the query is not matching any keyword exactly?
    // User requirement specifically mentioned the subtitle dataset features.
    // We will keep script search as fallback or supplementary.
    if (query.length >= 2) {
       try {
         final scriptResults = await _searchScriptsInIsolate(query);
         results.addAll(scriptResults);
       } catch (e) {
         debugPrint('Error searching scripts: $e');
       }
    }

    return results;
  }

  Future<List<QuoteMatch>> _searchScriptsInIsolate(String query) async {
    final token = RootIsolateToken.instance;
    return await compute(_parseAndSearchScripts, {'query': query, 'token': token});
  }

  static Future<List<QuoteMatch>> _parseAndSearchScripts(Map<String, dynamic> params) async {
    final query = params['query'] as String;
    final token = params['token'] as RootIsolateToken?;
    
    if (token != null) {
      BackgroundIsolateBinaryMessenger.ensureInitialized(token);
    }

    try {
      final String jsonString = await rootBundle.loadString('assets/scripts/movie_scripts_with_tmdb.json');
      final List<dynamic> data = jsonDecode(jsonString);
      final List<QuoteMatch> results = [];
      final lowerQuery = query.toLowerCase();

      for (var item in data) {
        final script = (item['script'] as String? ?? '').toLowerCase();
        if (script.contains(lowerQuery)) {
           final originalScript = item['script'] as String;
           final index = script.indexOf(lowerQuery);
           
           int start = (index - 50).clamp(0, script.length);
           int end = (index + lowerQuery.length + 50).clamp(0, script.length);
           String snippet = '...' + originalScript.substring(start, end).replaceAll('\n', ' ') + '...';
           
           if (item['tmdb'] != null) {
              final movie = Movie.fromLocalJson(item['tmdb']);
              results.add(QuoteMatch(
                movie: movie,
                matchedContent: snippet,
                keyword: query,
                source: 'script'
              ));
           }
        }
      }
      return results;
    } catch (e) {
      debugPrint('Isolate search error: $e');
      return [];
    }
  }
}
