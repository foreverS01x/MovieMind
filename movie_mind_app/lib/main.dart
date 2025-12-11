import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/tmdb_service.dart';
import 'services/storage_service.dart';
import 'models/movie.dart';
import 'pages/movie_detail_page.dart';
import 'pages/search_page.dart';
import 'pages/profile_page.dart';
import 'pages/movie_list_page.dart';

void main() {
  runApp(const MovieMindApp());
}

class MovieMindApp extends StatelessWidget {
  const MovieMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MovieMind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
        primaryColor: Colors.black,
        useMaterial3: true,
        fontFamily: 'San Francisco',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          iconTheme: IconThemeData(color: Colors.black),
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, background: const Color(0xFFF5F5F7)),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _pages = [const HomePage(), const SearchPage(), const ProfilePage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, spreadRadius: 5)]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: BottomNavigationBar(
              backgroundColor: Colors.white.withOpacity(0.8),
              elevation: 0,
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              selectedItemColor: Colors.black,
              unselectedItemColor: Colors.grey.shade500,
              showUnselectedLabels: false,
              showSelectedLabels: false,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home_outlined, size: 28), activeIcon: Icon(Icons.home_filled, size: 28), label: '首页'),
                BottomNavigationBarItem(icon: Icon(Icons.explore_outlined, size: 28), activeIcon: Icon(Icons.explore, size: 28), label: '找片'),
                BottomNavigationBarItem(icon: Icon(Icons.person_outline, size: 28), activeIcon: Icon(Icons.person, size: 28), label: '我的'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TMDbService _tmdbService = TMDbService();
  final StorageService _storageService = StorageService();
  List<Movie> _popularMovies = []; 
  List<Movie> _nowPlayingMovies = [];
  List<Movie> _upcomingMovies = [];
  List<Movie> _topRatedMovies = [];
  List<Movie> _recommendedMovies = [];
  Movie? _dailyMovie;
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    print('Loading data started...');
    try {
      final user = await _storageService.getCurrentUser();
      print('User loaded');
      
      final results = await Future.wait([
        _tmdbService.getPopular(),
        _tmdbService.getNowPlaying(),
        _tmdbService.getUpcoming(),
        _tmdbService.getTopRated(),
      ]);
      print('TMDB basic lists loaded');

      final popular = results[0];
      final nowPlaying = results[1];
      final upcoming = results[2];
      final topRated = results[3];

      Movie? daily;
      if (topRated.isNotEmpty) {
         final random = Random();
         final candidate = topRated[random.nextInt(topRated.length)];
         daily = await _tmdbService.getMovieDetail(candidate.id);
         print('Daily movie loaded');
      }
      
      // 个性化推荐逻辑
      List<Movie> recommended = [];
      if (user != null && user.preferredGenres.isNotEmpty) {
        // 如果用户有偏好，抓取相关类型的电影
        // 这里简单起见，随机选一个偏好类型抓取 discovery
        final randomGenre = user.preferredGenres[Random().nextInt(user.preferredGenres.length)];
        final genreMovies = await _tmdbService.discoverMovies(genreId: randomGenre);
        
        // 过滤掉已看的 (这里暂不实现完全过滤，只做简单逻辑)
        // 优先选评分高的
        genreMovies.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
        recommended = genreMovies;
        print('Recommendations loaded');
      }

      if (mounted) {
        setState(() {
          _popularMovies = popular.take(5).toList();
          _nowPlayingMovies = nowPlaying;
          _upcomingMovies = upcoming;
          _topRatedMovies = topRated;
          _recommendedMovies = recommended;
          _dailyMovie = daily;
          _isLoading = false;
        });
        print('State updated, loading finished');
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  floating: true,
                  pinned: false,
                  expandedHeight: 60,
                  backgroundColor: const Color(0xFFF5F5F7),
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(left: 20, bottom: 9),
                    // 混合字体 Logo：极简主义 + 衬线/无衬线混搭
                    title: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Movie',
                            style: GoogleFonts.fascinate(
                              color: const Color.fromARGB(146, 0, 0, 0), 
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          TextSpan(
                            text: 'Mind',
                            style: GoogleFonts.peralta(
                              color: const Color.fromARGB(110, 11, 0, 37), 
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [Padding(padding: const EdgeInsets.only(right: 16.0), child: CircleAvatar(radius: 18, backgroundColor: Colors.grey[200], child: const Icon(Icons.notifications_none, color: Colors.black)))],
                ),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      if (_popularMovies.isNotEmpty) _buildBanner(),
                      
                      const SizedBox(height: 30),
                      
                      if (_dailyMovie != null) _buildDailyRecommendation(),

                      if (_recommendedMovies.isNotEmpty) ...[
                        const SizedBox(height: 30),
                        _buildSectionHeader('猜你喜欢', '根据偏好推荐', _recommendedMovies),
                        _buildHorizontalMovieList(_recommendedMovies),
                      ],

                      const SizedBox(height: 30),
                      
                      _buildSectionHeader('Top 250 高分榜', '查看全部', _topRatedMovies),
                      _buildHorizontalMovieList(_topRatedMovies),

                      const SizedBox(height: 30),
                      
                      _buildSectionHeader('正在热映', '查看全部', _nowPlayingMovies),
                      _buildHorizontalMovieList(_nowPlayingMovies),

                      const SizedBox(height: 30),

                      _buildSectionHeader('即将上映', '查看全部', _upcomingMovies),
                      _buildHorizontalMovieList(_upcomingMovies),
                      
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildDailyRecommendation() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('每日推荐', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: _dailyMovie!))),
            child: Container(
              height: 360,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: DecorationImage(image: CachedNetworkImageProvider(_dailyMovie!.fullPosterUrl), fit: BoxFit.cover), 
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Stack(
                children: [
                  Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.8)]))),
                  Positioned(
                    left: 24, right: 24, bottom: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DAILY PICK', style: GoogleFonts.shrikhand(color: Colors.white.withOpacity(0.7), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        const SizedBox(height: 8),
                        Text(
                          _dailyMovie!.tagline.isNotEmpty ? "“${_dailyMovie!.tagline}”" : _dailyMovie!.title,
                          style: TextStyle(color: Colors.white, fontSize: _dailyMovie!.tagline.isNotEmpty ? 24 : 32, fontWeight: FontWeight.bold, fontFamily: 'Georgia', fontStyle: _dailyMovie!.tagline.isNotEmpty ? FontStyle.italic : FontStyle.normal),
                        ),
                        if (_dailyMovie!.tagline.isNotEmpty) ...[
                           const SizedBox(height: 12),
                           Text(_dailyMovie!.title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        ]
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return CarouselSlider(
      options: CarouselOptions(height: 220.0, autoPlay: true, enlargeCenterPage: true, viewportFraction: 0.85, aspectRatio: 16/9, autoPlayCurve: Curves.fastOutSlowIn),
      items: _popularMovies.map((movie) {
        return Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MovieDetailPage(movie: movie))),
              child: Hero(
                tag: 'banner_${movie.id}',
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5.0),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20.0), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))], image: DecorationImage(image: CachedNetworkImageProvider(movie.fullBackdropUrl), fit: BoxFit.cover)),
                  child: Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20.0), gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.6), Colors.transparent])),
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.bottomLeft,
                    child: Text(movie.title, style: const TextStyle(color: Colors.white, fontSize: 18.0, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(String title, String action, List<Movie> movies) { 
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          GestureDetector(
            child: InkWell(
              onTap: () {
                 Navigator.push(
                   context, 
                   MaterialPageRoute(
                     builder: (_) => MovieListPage(title: title, movies: movies)
                   )
                 );
              },
              child: Text(action, style: const TextStyle(color: Colors.blueAccent, fontSize: 14, fontWeight: FontWeight.w600))
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalMovieList(List<Movie> movies) {
    return SizedBox(
      height: 260,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 24),
        itemCount: movies.length,
        itemBuilder: (context, index) {
          final movie = movies[index];
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MovieDetailPage(movie: movie))),
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(imageUrl: movie.fullPosterUrl, fit: BoxFit.cover, placeholder: (context, url) => Container(color: Colors.grey[200]), errorWidget: (context, url, error) => Container(color: Colors.grey[300])),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(movie.voteAverage.toStringAsFixed(1), style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold))
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
