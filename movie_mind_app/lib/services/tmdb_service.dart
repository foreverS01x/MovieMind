import 'package:dio/dio.dart';
import '../models/movie.dart';

class TMDbService {
  // 这是一个有效的测试 Key，如果失效请替换为你自己的
  static const String apiKey = '9d5a5768705c19907badb63abbb20821'; 
  static const String baseUrl = 'https://api.themoviedb.org/3';

  late final Dio _dio;

  TMDbService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15), // 增加到15秒超时
      receiveTimeout: const Duration(seconds: 15), // 接收超时
      queryParameters: {
        'api_key': apiKey,
        'language': 'zh-CN',
      },
    ));

    // 添加日志拦截器，方便调试
    _dio.interceptors.add(LogInterceptor(
      request: false,
      requestHeader: false,
      responseHeader: false, 
      responseBody: false,
      error: true // 只打印错误日志
    ));
  }

  Future<List<Movie>> getNowPlaying() async {
    return _getMovies('/movie/now_playing');
  }

  Future<List<Movie>> getUpcoming() async {
    return _getMovies('/movie/upcoming');
  }
  
  Future<List<Movie>> getPopular() async {
    return _getMovies('/movie/popular');
  }

  // 统一封装请求逻辑
  Future<List<Movie>> _getMovies(String path) async {
    try {
      final response = await _dio.get(path);
      if (response.statusCode == 200) {
        final results = response.data['results'] as List;
        return results.map((e) => Movie.fromJson(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      print('🔴 TMDb API Error [$path]: ${e.type} - ${e.message}');
      return [];
    } catch (e) {
      print('🔴 Unknown Error: $e');
      return [];
    }
  }
}
