import 'package:dio/dio.dart';
import '../models/movie.dart';

class TMDbService {
  static const String apiKey = '9d5a5768705c19907badb63abbb20821'; 
  static const String baseUrl = 'https://api.themoviedb.org/3';

  late final Dio _dio;

  TMDbService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      queryParameters: {
        'api_key': apiKey,
        'language': 'zh-CN',
      },
    ));
    _dio.interceptors.add(LogInterceptor(request: true, responseBody: false, error: true)); 
  }

  Future<List<Movie>> getNowPlaying() => _getMovies('/movie/now_playing');
  Future<List<Movie>> getUpcoming() => _getMovies('/movie/upcoming');
  Future<List<Movie>> getPopular() => _getMovies('/movie/popular');
  Future<List<Movie>> getTopRated() => _getMovies('/movie/top_rated');

  Future<Movie?> getMovieDetail(int movieId) async {
    try {
      final response = await _dio.get('/movie/$movieId');
      if (response.statusCode == 200) {
        return Movie.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error getting movie detail: $e');
      // If it's one of our mock IDs, return the mock object back so Daily Pick works
      if (movieId <= 3) {
         return _getMockMovies('').firstWhere((m) => m.id == movieId);
      }
      return null;
    }
  }

  // --- 搜索 & 发现 ---
  
  Future<List<Movie>> searchMovies(String query) async {
    if (query.isEmpty) return [];
    return _getMovies('/search/movie', params: {'query': query});
  }

  Future<List<Person>> searchPeople(String query) async {
    if (query.isEmpty) return [];
    try {
      final response = await _dio.get('/search/person', queryParameters: {'query': query});
      if (response.statusCode == 200) {
        final results = response.data['results'] as List;
        return results.map((e) => Person.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 新增：获取热门影人 (支持分页以获取更多导演)
  Future<List<Person>> getPopularPeople({int page = 1}) async {
    try {
      final response = await _dio.get('/person/popular', queryParameters: {'page': page});
      if (response.statusCode == 200) {
        final results = response.data['results'] as List;
        return results.map((e) => Person.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 新增：获取热门导演 (扫描多页)
  Future<List<Person>> getPopularDirectors() async {
    List<Person> directors = [];
    // 扫描前5页
    for (int i = 1; i <= 5; i++) {
      final people = await getPopularPeople(page: i);
      directors.addAll(people.where((p) => p.knownForDepartment == 'Directing'));
      if (directors.length >= 20) break;
    }
    return directors;
  }

  // --- 分类 & 地区 ---

  Future<List<Genre>> getGenres() async {
    try {
      final response = await _dio.get('/genre/movie/list');
      if (response.statusCode == 200) {
        final results = response.data['genres'] as List;
        return results.map((e) => Genre.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 综合发现接口：支持分类、地区
  Future<List<Movie>> discoverMovies({int? genreId, String? region}) async {
    final Map<String, dynamic> params = {};
    if (genreId != null) params['with_genres'] = genreId;
    if (region != null) params['with_origin_country'] = region; // 使用 with_origin_country 更准确筛选产地
    
    return _getMovies('/discover/movie', params: params);
  }

  // --- 详情增强 ---

  Future<List<Cast>> getMovieCredits(int movieId) async {
    try {
      final response = await _dio.get('/movie/$movieId/credits');
      if (response.statusCode == 200) {
        final cast = response.data['cast'] as List;
        return cast.map((e) => Cast.fromJson(e)).take(10).toList(); 
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Movie>> getMovieRecommendations(int movieId) async {
    return _getMovies('/movie/$movieId/recommendations');
  }
  
  Future<List<String>> getMovieImages(int movieId) async {
    try {
      final response = await _dio.get(
        '/movie/$movieId/images', 
        queryParameters: {'language': 'null', 'include_image_language': 'en,null'}
      );
      if (response.statusCode == 200) {
        final backdrops = response.data['backdrops'] as List;
        return backdrops.map((e) => 'https://image.tmdb.org/t/p/w500${e['file_path']}').take(6).toList().cast<String>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 新增：获取电影评论
  Future<List<Review>> getMovieReviews(int movieId) async {
    try {
      // 评论可能没有中文，所以不强制 zh-CN，或者尝试不传 language 获取所有
      final response = await _dio.get('/movie/$movieId/reviews', queryParameters: {'language': 'en-US'}); 
      // 这里为了演示内容丰富，暂时请求英文评论，因为 TMDb 中文评论较少。实际项目可根据需求调整。
      if (response.statusCode == 200) {
        final results = response.data['results'] as List;
        return results.map((e) => Review.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 新增：获取电影视频 (Trailers, Teasers)
  Future<String?> getMovieVideoKey(int movieId) async {
    try {
      final response = await _dio.get('/movie/$movieId/videos');
      if (response.statusCode == 200) {
        final results = response.data['results'] as List;
        if (results.isNotEmpty) {
          // 优先查找 Trailer，其次 Teaser
          final trailer = results.firstWhere(
            (v) => v['site'] == 'YouTube' && v['type'] == 'Trailer',
            orElse: () => null,
          );
          if (trailer != null) return trailer['key'];

          final teaser = results.firstWhere(
            (v) => v['site'] == 'YouTube' && v['type'] == 'Teaser',
            orElse: () => null,
          );
          if (teaser != null) return teaser['key'];
          
          // 如果都没有，返回第一个 YouTube 视频
          final anyYoutube = results.firstWhere(
            (v) => v['site'] == 'YouTube',
            orElse: () => null,
          );
          if (anyYoutube != null) return anyYoutube['key'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- 影人详情 ---

  Future<PersonDetail?> getPersonDetail(int personId) async {
    try {
      final response = await _dio.get('/person/$personId');
      if (response.statusCode == 200) {
        return PersonDetail.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Movie>> getPersonMovieCredits(int personId) async {
    try {
      final response = await _dio.get('/person/$personId/movie_credits');
      if (response.statusCode == 200) {
        final cast = response.data['cast'] as List;
        cast.sort((a, b) => (b['popularity'] ?? 0).compareTo(a['popularity'] ?? 0));
        return cast.map((e) => Movie.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  
  // 修改：获取影人剧照 (Tagged Images) 而不是 Profiles
  Future<List<String>> getPersonTaggedImages(int personId) async {
     try {
      final response = await _dio.get('/person/$personId/tagged_images');
      if (response.statusCode == 200) {
        final results = response.data['results'] as List;
        // tagged_images 返回的是 media 对象，我们需要提取图片路径
        return results
            .where((e) => e['media_type'] == 'movie') // 只看电影剧照
            .map((e) => 'https://image.tmdb.org/t/p/w500${e['file_path']}')
            .take(10)
            .toList()
            .cast<String>();
      }
      return [];
    } catch (e) {
      return [];
    } 
  }

  Future<List<Movie>> _getMovies(String path, {Map<String, dynamic>? params}) async {
    try {
      final response = await _dio.get(path, queryParameters: params);
      if (response.statusCode == 200) {
        final results = response.data['results'] as List;
        return results.map((e) => Movie.fromJson(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      print('Network Error: ${e.message}');
      return _getMockMovies(path); // Fallback to mock data
    } catch (e) {
      print('Unknown Error: $e');
      return _getMockMovies(path); // Fallback to mock data
    }
  }

  // --- Mock Data for Demo / Offline Mode ---
  List<Movie> _getMockMovies(String path) {
    print('Returning mock data for: $path');
    return [
      Movie(
        id: 1,
        title: 'Inception (Demo)',
        originalTitle: 'Inception',
        posterPath: '', // Will use placeholder
        backdropPath: '',
        voteAverage: 8.8,
        releaseDate: '2010-07-15',
        overview: '盗梦空间：这是因为网络无法连接 TMDb API 而显示的演示数据。请检查模拟器网络或代理设置。',
        genreIds: [28, 878, 12],
        tagline: 'Your mind is the scene of the crime.',
      ),
      Movie(
        id: 2,
        title: 'Interstellar (Demo)',
        originalTitle: 'Interstellar',
        posterPath: '',
        backdropPath: '',
        voteAverage: 8.6,
        releaseDate: '2014-11-05',
        overview: '星际穿越：演示数据。当您看到此内容时，说明 App 处于离线演示模式。',
        genreIds: [12, 18, 878],
        tagline: 'Mankind was born on Earth. It was never meant to die here.',
      ),
      Movie(
        id: 3,
        title: 'The Dark Knight (Demo)',
        originalTitle: 'The Dark Knight',
        posterPath: '',
        backdropPath: '',
        voteAverage: 9.0,
        releaseDate: '2008-07-16',
        overview: '蝙蝠侠：黑暗骑士。演示数据。',
        genreIds: [28, 80, 18],
        tagline: 'Why so serious?',
      ),
    ];
  }
}
