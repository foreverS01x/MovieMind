import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie.dart';

enum WatchStatus { none, wantToWatch, watching, watched }

class User {
  final String id;
  final String username;
  final String password; 
  final String avatar;
  final List<int> preferredGenres; 

  User({
    required this.id, 
    required this.username, 
    required this.password, 
    required this.avatar,
    this.preferredGenres = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      avatar: json['avatar'] ?? 'https://i.pravatar.cc/150?img=12',
      preferredGenres: List<int>.from(json['preferred_genres'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'password': password,
    'avatar': avatar,
    'preferred_genres': preferredGenres,
  };
  
  User copyWith({List<int>? preferredGenres, String? avatar}) {
    return User(
      id: id,
      username: username,
      password: password,
      avatar: avatar ?? this.avatar,
      preferredGenres: preferredGenres ?? this.preferredGenres,
    );
  }
}

class StorageService {
  static const String _favoritesKey = 'favorite_movies';
  static const String _notesKey = 'movie_notes';
  static const String _statusKey = 'movie_status'; 
  static const String _progressKey = 'movie_progress'; 
  static const String _timeKey = 'movie_timestamp';
  static const String _movieCacheKey = 'movie_cache_pool';
  static const String _userKey = 'current_user';
  static const String _usersDbKey = 'all_users_db';
  static const String _customListsKey = 'custom_movie_lists';
  static const String _customListDescsKey = 'custom_movie_lists_desc'; // 新增：片单简介

  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();

  // --- 用户系统 ---
  
  Future<User?> getCurrentUser() async {
    final prefs = await _prefs;
    final jsonStr = prefs.getString(_userKey);
    if (jsonStr == null) return null;
    return User.fromJson(jsonDecode(jsonStr));
  }

  Future<void> login(String username, String password) async {
    final prefs = await _prefs;
    final dbJson = prefs.getString(_usersDbKey);
    Map<String, dynamic> db = dbJson != null ? jsonDecode(dbJson) : {};
    
    final userJson = db.values.firstWhere(
      (u) => u['username'] == username && u['password'] == password,
      orElse: () => null,
    );

    if (userJson != null) {
      await prefs.setString(_userKey, jsonEncode(userJson));
    } else {
      throw Exception('用户名或密码错误');
    }
  }

  Future<void> register(String username, String password) async {
    final prefs = await _prefs;
    final dbJson = prefs.getString(_usersDbKey);
    Map<String, dynamic> db = dbJson != null ? jsonDecode(dbJson) : {};

    if (db.values.any((u) => u['username'] == username)) {
      throw Exception('用户名已存在');
    }

    final newUser = User(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      username: username,
      password: password,
      avatar: 'https://i.pravatar.cc/150?img=${(username.length % 70)}',
    );

    db[newUser.id] = newUser.toJson();
    await prefs.setString(_usersDbKey, jsonEncode(db));
    await prefs.setString(_userKey, jsonEncode(newUser.toJson()));
  }

  Future<void> logout() async {
    final prefs = await _prefs;
    await prefs.remove(_userKey);
  }

  Future<void> updateUser(User user) async {
    final prefs = await _prefs;
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    
    final dbJson = prefs.getString(_usersDbKey);
    Map<String, dynamic> db = dbJson != null ? jsonDecode(dbJson) : {};
    db[user.id] = user.toJson();
    await prefs.setString(_usersDbKey, jsonEncode(db));
  }

  // --- 收藏逻辑 ---
  
  Future<List<Movie>> getFavorites() async {
    final prefs = await _prefs;
    final List<String> jsonList = prefs.getStringList(_favoritesKey) ?? [];
    return jsonList.map((jsonStr) => Movie.fromLocalJson(jsonDecode(jsonStr))).toList();
  }

  Future<bool> isFavorite(int movieId) async {
    final favorites = await getFavorites();
    return favorites.any((m) => m.id == movieId);
  }

  Future<bool> toggleFavorite(Movie movie) async {
    final prefs = await _prefs;
    final List<String> jsonList = prefs.getStringList(_favoritesKey) ?? [];
    List<Movie> favorites = jsonList.map((jsonStr) => Movie.fromLocalJson(jsonDecode(jsonStr))).toList();
    
    final isFav = favorites.any((m) => m.id == movie.id);

    if (isFav) {
      favorites.removeWhere((m) => m.id == movie.id);
    } else {
      favorites.add(movie);
      await _saveMovieToCache(movie);
    }
    
    await prefs.setStringList(_favoritesKey, favorites.map((m) => jsonEncode(m.toJson())).toList());
    return !isFav;
  }

  // --- 笔记/评论逻辑 ---
  
  Future<String?> getNote(int movieId) async {
    final prefs = await _prefs;
    final notesJson = prefs.getString(_notesKey);
    if (notesJson == null) return null;
    return jsonDecode(notesJson)[movieId.toString()];
  }

  Future<void> saveNote(Movie movie, String content) async {
    final prefs = await _prefs;
    final notesJson = prefs.getString(_notesKey);
    Map<String, dynamic> notesMap = notesJson != null ? jsonDecode(notesJson) : {};
    
    if (content.isEmpty) {
      notesMap.remove(movie.id.toString());
    } else {
      notesMap[movie.id.toString()] = content;
      await _saveMovieToCache(movie);
    }
    
    await prefs.setString(_notesKey, jsonEncode(notesMap));
  }

  Future<List<Movie>> getCommentedMovies() async {
    final prefs = await _prefs;
    final notesJson = prefs.getString(_notesKey);
    if (notesJson == null) return [];
    
    Map<String, dynamic> notesMap = jsonDecode(notesJson);
    List<String> movieIds = notesMap.keys.toList();
    
    final cacheJson = prefs.getString(_movieCacheKey);
    if (cacheJson == null) return [];
    Map<String, dynamic> cacheMap = jsonDecode(cacheJson);
    
    List<Movie> result = [];
    for (var id in movieIds) {
      if (cacheMap.containsKey(id)) {
        result.add(Movie.fromLocalJson(cacheMap[id]));
      }
    }
    return result;
  }

  // --- 自定义片单逻辑 ---

  Future<List<String>> getCustomListNames() async {
    final prefs = await _prefs;
    final jsonStr = prefs.getString(_customListsKey);
    if (jsonStr == null) return [];
    Map<String, dynamic> map = jsonDecode(jsonStr);
    return map.keys.toList();
  }
  
  // 获取片单简介
  Future<String?> getCustomListDescription(String listName) async {
    final prefs = await _prefs;
    final jsonStr = prefs.getString(_customListDescsKey);
    if (jsonStr == null) return null;
    Map<String, dynamic> map = jsonDecode(jsonStr);
    return map[listName];
  }

  Future<void> createCustomList(String listName, {String description = ''}) async {
    final prefs = await _prefs;
    // 列表
    final jsonStr = prefs.getString(_customListsKey);
    Map<String, dynamic> map = jsonStr != null ? jsonDecode(jsonStr) : {};
    if (!map.containsKey(listName)) {
      map[listName] = [];
      await prefs.setString(_customListsKey, jsonEncode(map));
    }
    
    // 简介
    final descJsonStr = prefs.getString(_customListDescsKey);
    Map<String, dynamic> descMap = descJsonStr != null ? jsonDecode(descJsonStr) : {};
    descMap[listName] = description;
    await prefs.setString(_customListDescsKey, jsonEncode(descMap));
  }

  Future<void> addMovieToCustomList(String listName, Movie movie) async {
    final prefs = await _prefs;
    final jsonStr = prefs.getString(_customListsKey);
    Map<String, dynamic> map = jsonStr != null ? jsonDecode(jsonStr) : {};
    
    if (map.containsKey(listName)) {
      List<dynamic> ids = map[listName];
      if (!ids.contains(movie.id)) {
        ids.add(movie.id);
        await _saveMovieToCache(movie);
        map[listName] = ids;
        await prefs.setString(_customListsKey, jsonEncode(map));
      }
    }
  }

  Future<List<Movie>> getMoviesFromCustomList(String listName) async {
    final prefs = await _prefs;
    final jsonStr = prefs.getString(_customListsKey);
    if (jsonStr == null) return [];
    Map<String, dynamic> map = jsonDecode(jsonStr);
    
    List<dynamic> ids = map[listName] ?? [];
    if (ids.isEmpty) return [];

    final cacheJson = prefs.getString(_movieCacheKey);
    if (cacheJson == null) return [];
    Map<String, dynamic> cacheMap = jsonDecode(cacheJson);

    List<Movie> result = [];
    for (var id in ids) {
      final idStr = id.toString();
      if (cacheMap.containsKey(idStr)) {
        result.add(Movie.fromLocalJson(cacheMap[idStr]));
      }
    }
    return result;
  }

  // --- 观影状态 ---
  
  Future<WatchStatus> getWatchStatus(int movieId) async {
    final prefs = await _prefs;
    final statusJson = prefs.getString(_statusKey);
    if (statusJson == null) return WatchStatus.none;
    final map = jsonDecode(statusJson);
    final statusIndex = map[movieId.toString()];
    if (statusIndex == null) return WatchStatus.none;
    return WatchStatus.values[statusIndex];
  }

  Future<void> setWatchStatus(Movie movie, WatchStatus status) async {
    final prefs = await _prefs;
    
    final statusJson = prefs.getString(_statusKey);
    Map<String, dynamic> statusMap = statusJson != null ? jsonDecode(statusJson) : {};
    
    final timeJson = prefs.getString(_timeKey);
    Map<String, dynamic> timeMap = timeJson != null ? jsonDecode(timeJson) : {};

    if (status == WatchStatus.none) {
      statusMap.remove(movie.id.toString());
      timeMap.remove(movie.id.toString());
    } else {
      statusMap[movie.id.toString()] = status.index;
      timeMap[movie.id.toString()] = DateTime.now().millisecondsSinceEpoch;
      await _saveMovieToCache(movie); 
    }
    
    await prefs.setString(_statusKey, jsonEncode(statusMap));
    await prefs.setString(_timeKey, jsonEncode(timeMap));
  }
  
  Future<int?> getStatusTime(int movieId) async {
    final prefs = await _prefs;
    final timeJson = prefs.getString(_timeKey);
    if (timeJson == null) return null;
    final map = jsonDecode(timeJson);
    return map[movieId.toString()];
  }

  Future<Map<String, int>> getAllTimestamps() async {
    final prefs = await _prefs;
    final timeJson = prefs.getString(_timeKey);
    if (timeJson == null) return {};
    return Map<String, int>.from(jsonDecode(timeJson));
  }

  Future<double> getProgress(int movieId) async {
    final prefs = await _prefs;
    final progressJson = prefs.getString(_progressKey);
    if (progressJson == null) return 0.0;
    final map = jsonDecode(progressJson);
    return (map[movieId.toString()] ?? 0.0).toDouble();
  }

  Future<void> setProgress(int movieId, double progress) async {
    final prefs = await _prefs;
    final progressJson = prefs.getString(_progressKey);
    Map<String, dynamic> progressMap = progressJson != null ? jsonDecode(progressJson) : {};
    progressMap[movieId.toString()] = progress;
    await prefs.setString(_progressKey, jsonEncode(progressMap));
  }

  Future<void> _saveMovieToCache(Movie movie) async {
    final prefs = await _prefs;
    final cacheJson = prefs.getString(_movieCacheKey);
    Map<String, dynamic> cacheMap = cacheJson != null ? jsonDecode(cacheJson) : {};
    cacheMap[movie.id.toString()] = movie.toJson();
    await prefs.setString(_movieCacheKey, jsonEncode(cacheMap));
  }
  
  Future<void> cacheMovie(Movie movie) async {
    await _saveMovieToCache(movie);
  }

  Future<List<Movie>> getMoviesByStatus(WatchStatus status) async {
    final prefs = await _prefs;
    final statusJson = prefs.getString(_statusKey);
    if (statusJson == null) return [];
    Map<String, dynamic> statusMap = jsonDecode(statusJson);
    
    final targetIds = statusMap.entries
      .where((e) => e.value == status.index)
      .map((e) => e.key)
      .toList();
      
    if (targetIds.isEmpty) return [];

    final cacheJson = prefs.getString(_movieCacheKey);
    if (cacheJson == null) return [];
    Map<String, dynamic> cacheMap = jsonDecode(cacheJson);
    
    List<Movie> result = [];
    for (var id in targetIds) {
      if (cacheMap.containsKey(id)) {
        result.add(Movie.fromLocalJson(cacheMap[id]));
      }
    }
    return result;
  }
}
