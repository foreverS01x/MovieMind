import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/tmdb_service.dart';
import '../services/award_service.dart';
import '../services/quote_service.dart';
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
  final QuoteService _quoteService = QuoteService();
  
  List<Movie> _movies = [];
  List<Person> _people = [];
  List<QuoteMatch> _quoteMatches = []; // Store quote search results
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

  // Genre ID to English Filename mapping
  final Map<int, String> _genreIdToEnglishName = {
    28: 'Action',
    12: 'Adventure',
    16: 'Animation',
    35: 'Comedy',
    80: 'Crime',
    99: 'Documentary',
    18: 'Drama',
    10751: 'Family',
    14: 'Fantasy',
    36: 'History',
    27: 'Horror',
    10402: 'Music',
    9648: 'Mystery',
    10749: 'Romance',
    878: 'Sci-Fi',
    10770: 'TV Movie',
    53: 'Thriller',
    10752: 'War',
    37: 'Western',
  };

  // Genre ID to Google Font mapping
  Map<int, TextStyle> get _genreFonts => {
    28: GoogleFonts.blackOpsOne(), // Action
    12: GoogleFonts.hennyPenny(), // Adventure
    16: GoogleFonts.loveYaLikeASister(), // Animation
    35: GoogleFonts.limelight(), // Comedy
    80: GoogleFonts.rubikWetPaint(), // Crime
    99: GoogleFonts.merriweather(), // Documentary
    18: GoogleFonts.ubuntu(fontWeight: FontWeight.bold), // Drama
    10751: GoogleFonts.slackey(), // Family
    14: GoogleFonts.amarante(fontWeight: FontWeight.bold), // Fantasy
    36: GoogleFonts.medievalSharp(), // History
    27: GoogleFonts.rubikGlitch(), // Horror
    10402: GoogleFonts.trainOne(), // Music
    9648: GoogleFonts.mysteryQuest(), // Mystery
    10749: GoogleFonts.greatVibes(), // Romance
    878: GoogleFonts.orbitron(fontWeight: FontWeight.bold), // Sci-Fi
    10770: GoogleFonts.pacifico(), // TV Movie
    53: GoogleFonts.rubikBurned(), // Thriller
    10752: GoogleFonts.wallpoet(), // War
    37: GoogleFonts.rye(), // Western
  };

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

    setState(() { 
      _isLoading = true; 
      _movies.clear(); 
      _people.clear(); 
      _quoteMatches.clear();
    });
    FocusScope.of(context).unfocus();

    try {
      if (_searchType == SearchType.person) {
        final results = await _tmdbService.searchPeople(query);
        if (mounted) setState(() => _people = results);
      } else if (_searchType == SearchType.awards) {
        // ... (existing awards logic) ...
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
         // 台词搜索
         final results = await _quoteService.searchQuotes(query);
         if (mounted) setState(() => _quoteMatches = results);
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
    bool showDefaultPage = _controller.text.isEmpty && _movies.isEmpty && _people.isEmpty && _quoteMatches.isEmpty && !_isLoading;

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
          _quoteMatches.clear();
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
              final englishName = _genreIdToEnglishName[genre.id] ?? 'Drama'; // Default backup
              final fontStyle = _genreFonts[genre.id] ?? GoogleFonts.roboto();
              
              return _buildCategoryCard(
                englishName, 
                'assets/images/genres/$englishName.jpg', 
                () => _navigateToCategory(genre.name, genreId: genre.id),
                fontStyle: fontStyle,
              );
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
    // Define consistent font styles for each language
    final englishStyle = GoogleFonts.playfairDisplay(fontSize: 18, fontStyle: FontStyle.italic);
    final chineseStyle = GoogleFonts.zhiMangXing(fontSize: 20);
    final japaneseStyle = GoogleFonts.shipporiMincho(fontSize: 16);
    final frenchStyle = GoogleFonts.parisienne(fontSize: 19);
    final spanishStyle = GoogleFonts.kaushanScript(fontSize: 18);
    final koreanStyle = GoogleFonts.nanumPenScript(fontSize: 20);

    final List<Map<String, dynamic>> quotes = [
      {'text': 'I Love You', 'style': englishStyle},
      {'text': '我爱你', 'style': chineseStyle},
      {'text': '愛してる', 'style': japaneseStyle},
      {'text': 'Je t\'aime', 'style': frenchStyle},
      {'text': 'Te quiero', 'style': spanishStyle},
      {'text': '사랑해', 'style': koreanStyle},
      
      {'text': 'Hello', 'style': englishStyle},
      {'text': '你好', 'style': chineseStyle},
      {'text': 'Bonjour', 'style': frenchStyle},
      {'text': 'Hola', 'style': spanishStyle},
      {'text': 'こんにちは', 'style': japaneseStyle},
      {'text': '안녕하세요', 'style': koreanStyle},
      
      {'text': 'Goodbye', 'style': englishStyle},
      {'text': '再见', 'style': chineseStyle},
      {'text': 'Au revoir', 'style': frenchStyle},
      {'text': 'Adiós', 'style': spanishStyle},
      {'text': 'さようなら', 'style': japaneseStyle},
      {'text': '안녕', 'style': koreanStyle},
      
      {'text': 'Destiny', 'style': englishStyle},
      {'text': '命中注定', 'style': chineseStyle},
      {'text': '運命', 'style': japaneseStyle},
      {'text': 'Destin', 'style': frenchStyle},
      {'text': 'Destino', 'style': spanishStyle},
      {'text': '인연', 'style': koreanStyle},
      
      {'text': 'Sorry', 'style': englishStyle},
      {'text': '对不起', 'style': chineseStyle},
      {'text': 'ごめんなさい', 'style': japaneseStyle},
      {'text': 'Désolé', 'style': frenchStyle},
      {'text': 'Lo siento', 'style': spanishStyle},
      {'text': '미안해', 'style': koreanStyle},
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
                children: quotes.map((q) => _buildBubble(q['text'], q['style'])).toList(),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.hearing, size: 40, color: Colors.black54), // 耳朵
          ],
        ),
      ),
    );
  }
  
  Widget _buildBubble(String text, TextStyle style) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Text(text, style: style.copyWith(color: Colors.black87)),
    );
  }

  Widget _buildCategoryCard(String title, String imagePath, VoidCallback onTap, {TextStyle? fontStyle}) {
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
            Center(
              child: Text(
                title, 
                style: (fontStyle ?? const TextStyle()).copyWith(
                  fontSize: 20, // Slightly larger for better visibility with custom fonts
                  fontWeight: FontWeight.bold, 
                  color: Colors.white, 
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(
                      blurRadius: 4.0,
                      color: Colors.black.withOpacity(0.8),
                      offset: const Offset(1.0, 1.0),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              )
            ),
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

  Widget _buildHighlightText(String text, String query, TextStyle style) {
    if (query.isEmpty) return Text(text, style: style);

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    if (!lowerText.contains(lowerQuery)) return Text(text, style: style);

    final List<TextSpan> spans = [];
    int start = 0;
    int indexOfHighlight;

    while ((indexOfHighlight = lowerText.indexOf(lowerQuery, start)) != -1) {
      if (indexOfHighlight > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfHighlight), style: style));
      }
      spans.add(TextSpan(
        text: text.substring(indexOfHighlight, indexOfHighlight + query.length),
        style: style.copyWith(color: Colors.redAccent, fontWeight: FontWeight.bold),
      ));
      start = indexOfHighlight + query.length;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }

    return RichText(text: TextSpan(children: spans));
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
    } else if (_searchType == SearchType.quote) {
      if (_quoteMatches.isEmpty) return _buildEmpty('未找到相关台词');
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _quoteMatches.length,
        itemBuilder: (context, index) {
          final match = _quoteMatches[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: match.movie))),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: match.movie.fullPosterUrl,
                            width: 60,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(match.movie.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              if (match.movie.originalTitle.isNotEmpty && match.movie.originalTitle != match.movie.title)
                                Text(match.movie.originalTitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: match.source == 'subtitle' ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  match.source == 'subtitle' ? '精选台词' : '剧本搜索',
                                  style: TextStyle(
                                    fontSize: 10, 
                                    color: match.source == 'subtitle' ? Colors.blue[800] : Colors.orange[800],
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    if (match.source == 'subtitle') ...[
                      if (match.contentEn.isNotEmpty)
                        _buildHighlightText(match.contentEn, _controller.text.trim(), GoogleFonts.notoSerif(fontSize: 15, fontStyle: FontStyle.italic, color: Colors.black87)),
                      if (match.contentEn.isNotEmpty && match.contentZh.isNotEmpty)
                        const SizedBox(height: 8),
                      if (match.contentZh.isNotEmpty)
                        _buildHighlightText(match.contentZh, _controller.text.trim(), const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                           const Icon(Icons.access_time_filled, size: 14, color: Colors.grey),
                           const SizedBox(width: 4),
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                             decoration: BoxDecoration(
                               color: Colors.grey[200],
                               borderRadius: BorderRadius.circular(4),
                             ),
                             child: Text('${match.startTime}  —  ${match.endTime}', style: TextStyle(color: Colors.grey[700], fontSize: 11, fontFamily: 'monospace')),
                           ),
                        ],
                      )
                    ] else ...[
                      _buildHighlightText(
                        match.matchedContent, 
                        _controller.text.trim(),
                        GoogleFonts.notoSerif(fontSize: 15, height: 1.6, color: Colors.black87),
                      ),
                    ]
                  ],
                ),
              ),
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
