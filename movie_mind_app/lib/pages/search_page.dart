import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/tmdb_service.dart';
import '../services/award_service.dart';
import '../models/movie.dart';
import 'movie_detail_page.dart';
import 'person_detail_page.dart';
import 'movie_list_page.dart';
import 'person_list_page.dart';
import 'award_year_list_page.dart';

enum SortOption { relevance, rating, date }
enum SearchType { movie, person, awards, quote }

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final TMDbService _tmdbService = TMDbService();
  final AwardService _awardService = AwardService();
  
  List<Movie> _movies = [];
  List<Person> _people = [];
  List<Person> _popularPeople = []; // 热门影人
  List<Genre> _genres = [];
  Set<int> _winnerIds = {}; // Store IDs of award winning movies
  
  bool _isLoading = false;
  SearchType _searchType = SearchType.movie;
  SortOption _sortOption = SortOption.relevance;

  // ... (regions remain same)
  final List<Map<String, String>> _regions = [
    {'name': '华语', 'code': 'CN', 'flag': 'https://flagcdn.com/w640/cn.png'},
    {'name': '美国', 'code': 'US', 'flag': 'https://flagcdn.com/w640/us.png'},
    {'name': '韩国', 'code': 'KR', 'flag': 'https://flagcdn.com/w640/kr.png'},
    {'name': '日本', 'code': 'JP', 'flag': 'https://flagcdn.com/w640/jp.png'},
    {'name': '英国', 'code': 'GB', 'flag': 'https://flagcdn.com/w640/gb.png'},
    {'name': '法国', 'code': 'FR', 'flag': 'https://flagcdn.com/w640/fr.png'},
  ];

  @override
  void initState() {
    super.initState();
    _loadGenres();
    _loadPopularPeople();
  }

  void _loadGenres() async {
    final genres = await _tmdbService.getGenres();
    if (mounted) setState(() => _genres = genres);
  }

  void _loadPopularPeople() async {
    final people = await _tmdbService.getPopularPeople();
    if (mounted) setState(() => _popularPeople = people);
  }


  Future<void> _performSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() { _isLoading = true; _movies.clear(); _people.clear(); });
    FocusScope.of(context).unfocus();

    try {
      if (_searchType == SearchType.person) {
        final results = await _tmdbService.searchPeople(query);
        if (mounted) setState(() => _people = results);
      } else if (_searchType == SearchType.awards) {
        // 1. Try local award search
        final awards = await _awardService.searchAwards(query);
        
        if (awards.isNotEmpty) {
           // Found local award data
           final List<int> idsToFetch = [];
           _winnerIds.clear();

           // Flatten movies from all matching awards
           for (var award in awards) {
             for (var movie in award.movies) {
               if (movie.tmdbId > 0) {
                 idsToFetch.add(movie.tmdbId);
                 if (movie.isWinner) {
                   _winnerIds.add(movie.tmdbId);
                 }
               }
             }
           }
           
           // Limit to 30 movies to prevent API overload if query is too broad
           final limitedIds = idsToFetch.length > 30 ? idsToFetch.sublist(idsToFetch.length - 30) : idsToFetch;

           // Fetch details (parallel)
           final futures = limitedIds.map((id) => _tmdbService.getMovieDetail(id));
           final details = await Future.wait(futures);
           
           final validMovies = details.whereType<Movie>().toList();
           
           // Sort: Winners first
           validMovies.sort((a, b) {
             final aWin = _winnerIds.contains(a.id);
             final bWin = _winnerIds.contains(b.id);
             if (aWin && !bWin) return -1;
             if (!aWin && bWin) return 1;
             return 0;
           });
           
           if (mounted) setState(() => _movies = validMovies);
        } else {
           // 2. Fallback to regular movie search (remote)
           final results = await _tmdbService.searchMovies(query); 
           if (mounted) setState(() => _movies = results);
        }
      } else if (_searchType == SearchType.quote) {
         // 模拟台词搜索
         final results = await _tmdbService.searchMovies(query);
         if (mounted) setState(() => _movies = results);
      } else {
        final results = await _tmdbService.searchMovies(query);
        if (mounted) setState(() => _movies = results);
      }
      
      if (_sortOption != SortOption.relevance && _searchType == SearchType.movie) {
        _applySort();
      }

    } catch (e) {
      print(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applySort() {
    if (_searchType != SearchType.movie) return;

    if (_sortOption == SortOption.relevance) {
       _performSearch();
       return;
    }

    setState(() {
      switch (_sortOption) {
        case SortOption.rating:
          _movies.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
          break;
        case SortOption.date:
          _movies.sort((a, b) {
            if (a.releaseDate.isEmpty) return 1;
            if (b.releaseDate.isEmpty) return -1;
            return b.releaseDate.compareTo(a.releaseDate);
          });
          break;
        case SortOption.relevance:
          break;
      }
    });
  }

  Future<void> _navigateToCategory(String title, {int? genreId, String? region}) async {
     setState(() => _isLoading = true);
     final regionCode = (region != null && region.isNotEmpty) ? region : null;
     final results = await _tmdbService.discoverMovies(genreId: genreId, region: regionCode);
     if (mounted) {
       setState(() => _isLoading = false);
       Navigator.push(context, MaterialPageRoute(builder: (_) => MovieListPage(title: title, movies: results)));
     }
  }

  void _navigateToPersonList(String title, {int? gender, String? department}) async {
    List<Person> listToShow;
    if (department == 'Directing') {
      // 如果是导演，优先尝试加载热门导演列表
      setState(() => _isLoading = true);
      final directors = await _tmdbService.getPopularDirectors();
      setState(() => _isLoading = false);
      listToShow = directors;
    } else {
      final filtered = _popularPeople.where((p) {
        if (gender != null && p.gender != gender) return false;
        return true;
      }).toList();
      listToShow = filtered.isNotEmpty ? filtered : _popularPeople;
    }
    
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PersonListPage(title: title, people: listToShow)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 当没有搜索内容且未加载时，显示各类型的默认页面
    bool showDefaultPage = _controller.text.isEmpty && _movies.isEmpty && _people.isEmpty && !_isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F7),
        elevation: 0,
        toolbarHeight: 120,
        title: Column(
          children: [
            Container(
              height: 46,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: _getHintText(),
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  suffixIcon: _controller.text.isNotEmpty 
                      ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { _controller.clear(); setState(() { _movies.clear(); _people.clear(); }); })
                      : null,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _performSearch(),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSearchTypeChip('搜电影', SearchType.movie),
                  const SizedBox(width: 8),
                  _buildSearchTypeChip('搜影人', SearchType.person),
                  const SizedBox(width: 8),
                  _buildSearchTypeChip('搜奖项', SearchType.awards),
                  const SizedBox(width: 8),
                  _buildSearchTypeChip('搜台词', SearchType.quote),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : showDefaultPage ? _buildDefaultView() : _buildResultView(),
    );
  }
  
  String _getHintText() {
    switch (_searchType) {
      case SearchType.person: return '输入演员/导演姓名...';
      case SearchType.awards: return '输入电影节/奖项名称 (如 Oscar)...';
      case SearchType.quote: return '输入经典台词...';
      default: return '输入电影名称...';
    }
  }

  Widget _buildSearchTypeChip(String label, SearchType type) {
    final isSelected = _searchType == type;
    return GestureDetector(
      onTap: () => setState(() { 
        _searchType = type; 
        // 切换 Tab 时清空之前的结果，显示该 Tab 的默认页面
        _movies.clear();
        _people.clear();
        _controller.clear();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.black : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildDefaultView() {
    switch (_searchType) {
      case SearchType.person: return _buildPersonCategoryView();
      case SearchType.awards: return _buildAwardsCategoryView();
      case SearchType.quote: return _buildQuoteCategoryView();
      case SearchType.movie: return _buildMovieCategoryView();
    }
  }

  // 1. 搜电影默认页
  Widget _buildMovieCategoryView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('按类型浏览', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.6, crossAxisSpacing: 12, mainAxisSpacing: 12),
            itemCount: _genres.length,
            itemBuilder: (context, index) {
              final genre = _genres[index];
              return _buildCategoryCard(genre.name, 'assets/images/genres/${genre.name}.jpg', () => _navigateToCategory(genre.name, genreId: genre.id));
            },
          ),
          const SizedBox(height: 30),
          const Text('按地区浏览', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // 地区也用卡片展示，带国旗模糊
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.6, crossAxisSpacing: 12, mainAxisSpacing: 12),
            itemCount: _regions.length,
            itemBuilder: (context, index) {
              final region = _regions[index];
              return _buildRegionCard(region['name']!, region['flag']!, () => _navigateToCategory('${region['name']}地区电影', region: region['code']));
            },
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  // 2. 搜影人默认页
  Widget _buildPersonCategoryView() {
    return GridView.count(
      padding: const EdgeInsets.all(20),
      crossAxisCount: 2, // 两列
      childAspectRatio: 1.4, // 宽高比，类似电影分类
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildPersonCategoryCard('男演员', const AssetImage('assets/images/actors/男演员.jpg'), () => _navigateToPersonList('男演员', gender: 2)),
        _buildPersonCategoryCard('女演员', const AssetImage('assets/images/actors/女演员.jpg'), () => _navigateToPersonList('女演员', gender: 1)),
        _buildPersonCategoryCard('导演', const AssetImage('assets/images/actors/导演.jpg'), () => _navigateToPersonList('导演', department: 'Directing')),
      ],
    );
  }

  // 3. 搜奖项默认页
  Widget _buildAwardsCategoryView() {
    final awards = ['奥斯卡', '柏林电影节', '戛纳电影节', '金鸡奖', '上海金爵奖', '香港金像奖'];
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.2, crossAxisSpacing: 16, mainAxisSpacing: 16),
      itemCount: awards.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => AwardYearListPage(awardName: awards[index])));
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events, size: 40, color: Colors.amber), // 奖杯
                const SizedBox(height: 12),
                Text(awards[index], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }

  // 4. 搜台词默认页
  Widget _buildQuoteCategoryView() {
    final List<String> quotes = [
      'I Love You', '我爱你', '愛してる', 'Je t\'aime', 'Te quiero',
      'Hello', '你好', 'Bonjour', 'Hola', 'こんにちは', '안녕하세요',
      'Goodbye', '再见', 'Au revoir', 'Adiós', 'さようなら', '안녕',
      'Destiny', '命中注定', '運命', 'Destin', 'Destino', '인연',
      'Sorry', '对不起', 'ごめんなさい', 'Désolé', 'Lo siento', '미안해',
    ];

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 60),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.volume_up, size: 40, color: Colors.black54), // 喇叭
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceEvenly,
                children: quotes.map((q) => _buildBubble(q)).toList(),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.hearing, size: 40, color: Colors.black54), // 耳朵
          ],
        ),
      ),
    );
  }
  
  Widget _buildBubble(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _buildCategoryCard(String title, String imagePath, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(imagePath, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.blueGrey)),
            ),
            Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.black.withOpacity(0.3))),
            Center(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2))),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRegionCard(String title, String flagUrl, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 模糊国旗
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: CachedNetworkImage(imageUrl: flagUrl, fit: BoxFit.cover),
              ),
              Container(color: Colors.black.withOpacity(0.2)),
              Center(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2, shadows: [Shadow(color: Colors.black, blurRadius: 5)]))),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPersonCategoryCard(String title, ImageProvider imageProvider, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: imageProvider, 
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken) 
          ),
        ),
        child: Center(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2))),
      ),
    );
  }

  Widget _buildResultView() {
    if (_searchType == SearchType.person) {
      if (_people.isEmpty) return _buildEmpty('未找到相关影人');
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _people.length,
        itemBuilder: (context, index) {
          final person = _people[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: CircleAvatar(radius: 30, backgroundImage: NetworkImage(person.fullProfileUrl)),
              title: Text(person.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PersonDetailPage(personId: person.id, personName: person.name, profilePath: person.profilePath))),
            ),
          );
        },
      );
    } else {
      if (_movies.isEmpty) return _buildEmpty('未找到相关内容');
      return Column(
        children: [
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween, 
               children: [
                 Text('${_movies.length} 个结果', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                 if (_searchType == SearchType.movie)
                   DropdownButton<SortOption>(
                     value: _sortOption,
                     underline: const SizedBox(),
                     icon: const Icon(Icons.sort, size: 18),
                     style: const TextStyle(color: Colors.black87, fontSize: 13),
                     onChanged: (SortOption? newValue) {
                       if (newValue != null) {
                         setState(() => _sortOption = newValue);
                         _applySort();
                       }
                     },
                     items: const [
                       DropdownMenuItem(value: SortOption.relevance, child: Text('推荐排序')),
                       DropdownMenuItem(value: SortOption.rating, child: Text('评分最高')),
                       DropdownMenuItem(value: SortOption.date, child: Text('上映时间')),
                     ],
                   )
               ],
             ),
           ),
           Expanded(
             child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.6, crossAxisSpacing: 12, mainAxisSpacing: 12),
              itemCount: _movies.length,
              itemBuilder: (context, index) {
                final movie = _movies[index];
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie))),
                  child: Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))]),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedNetworkImage(imageUrl: movie.fullPosterUrl, fit: BoxFit.cover)),
                        if (_winnerIds.contains(movie.id))
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]
                              ),
                              child: const Icon(Icons.emoji_events, size: 16, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }
  }
  
  Widget _buildEmpty(String text) => Center(child: Text(text, style: TextStyle(color: Colors.grey[500])));
}
