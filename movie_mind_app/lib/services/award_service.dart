import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/award.dart';

class AwardService {
  // Mapping from display name to filename prefix
  static const Map<String, String> awardFileMap = {
    '奥斯卡': '奥斯卡_output_winner_nominees.json',
    '柏林电影节': '柏林_output_winner_nominees.json',
    '戛纳电影节': '戛纳_output_winner_nominees.json',
    '金鸡奖': '金鸡奖_output_winner_nominees.json',
    '上海金爵奖': '金爵奖_output_winner_nominees.json',
    '香港金像奖': '金像奖_output_winner_nominees.json',
  };

  Future<List<Award>> getAwards(String awardName) async {
    final fileName = awardFileMap[awardName];
    if (fileName == null) return [];

    try {
      final String jsonString = await rootBundle.loadString('assets/awards/$fileName');
      final List<dynamic> jsonList = json.decode(jsonString);
      
      return jsonList.map((json) => Award.fromJson(awardName, json)).toList();
    } catch (e) {
      print('Error loading award data: $e');
      return [];
    }
  }

  Future<List<Award>> searchAwards(String query) async {
    List<Award> results = [];
    
    // Regex patterns for flexible parsing
    // Matches "第77届奥斯卡", "77届奥斯卡", "奥斯卡第77届"
    final sessionPattern = RegExp(r'(?:第)?(\d+)(?:届)?\s*([^\d\s]+)|([^\d\s]+)\s*(?:第)?(\d+)(?:届)?');
    // Matches "2024年柏林", "2024柏林", "柏林2024"
    final yearPattern = RegExp(r'(\d{4})(?:年)?\s*([^\d\s]+)|([^\d\s]+)\s*(\d{4})(?:年)?');

    String? awardName;
    int? session;
    int? year;

    final sessionMatch = sessionPattern.firstMatch(query);
    final yearMatch = yearPattern.firstMatch(query);

    if (sessionMatch != null) {
      // Extract session number and award name
      // Group 1/2 or 3/4 depending on order
      String numStr = sessionMatch.group(1) ?? sessionMatch.group(4) ?? '';
      String nameStr = sessionMatch.group(2) ?? sessionMatch.group(3) ?? '';
      
      if (numStr.isNotEmpty) session = int.tryParse(numStr);
      if (nameStr.isNotEmpty) awardName = _normalizeAwardName(nameStr);
    } else if (yearMatch != null) {
      // Extract year and award name
      String numStr = yearMatch.group(1) ?? yearMatch.group(4) ?? '';
      String nameStr = yearMatch.group(2) ?? yearMatch.group(3) ?? '';

      if (numStr.isNotEmpty) year = int.tryParse(numStr);
      if (nameStr.isNotEmpty) awardName = _normalizeAwardName(nameStr);
    } else {
      // Try simple name match if no numbers found
      awardName = _normalizeAwardName(query);
    }

    // If we identified an award name, search specifically in that file
    if (awardName != null) {
        // Load just that award's data
        final allYears = await getAwards(awardName);
        
        if (session != null) {
           results.addAll(allYears.where((a) => a.session == session));
        } else if (year != null) {
           results.addAll(allYears.where((a) => a.year == year));
        } else {
           // Just name match? Return all years? Or maybe just recent ones? 
           // User query likely implies "Show me this award's stuff".
           // But searchAwards usually expects specific items.
           // If generic name search, we might just return everything or let UI handle category click.
           // For now let's return empty for generic name to fallback to default UI, 
           // OR return everything if you want search results list.
           // Let's return everything for now.
           results.addAll(allYears);
        }
    } else {
      // If no specific award name identified, maybe search ALL files (expensive but comprehensive)
      // Or just return empty
    }

    return results;
  }

  String? _normalizeAwardName(String input) {
    // Simple fuzzy matching or alias handling
    if (input.contains('奥斯卡')) return '奥斯卡';
    if (input.contains('柏林')) return '柏林电影节';
    if (input.contains('戛纳') || input.contains('康城')) return '戛纳电影节';
    if (input.contains('金鸡')) return '金鸡奖';
    if (input.contains('金爵')) return '上海金爵奖';
    if (input.contains('金像')) return '香港金像奖';
    return null;
  }
}

