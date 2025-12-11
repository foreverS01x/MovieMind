import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../models/movie.dart';
import '../services/storage_service.dart';
import '../services/tmdb_service.dart';
import '../services/youtube_service.dart';
import 'person_detail_page.dart';
import 'video_player_page.dart';
import '../widgets/expandable_text.dart'; 

class MovieDetailPage extends StatefulWidget {
  final Movie movie;

  const MovieDetailPage({super.key, required this.movie});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  final StorageService _storageService = StorageService();
  final TMDbService _tmdbService = TMDbService();
  final YouTubeService _youTubeService = YouTubeService();
  
  late Movie _movie; // Use local state for movie to allow updates
  bool _isFavorite = false;
  WatchStatus _watchStatus = WatchStatus.none;
  double _progress = 0.0;
  String? _userNote;
  String? _videoKey;
  
  List<Cast> _cast = [];
  List<Movie> _recommendations = [];
  List<String> _images = [];
  List<Review> _reviews = []; 

  final ScrollController _scrollController = ScrollController();
  double _appBarOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _movie = widget.movie; // Initialize with passed movie
    _checkStatus();
    _loadExtraData();
    _scrollController.addListener(() {
      double offset = _scrollController.offset;
      double opacity = (offset / 200).clamp(0.0, 1.0);
      if (opacity != _appBarOpacity) {
        setState(() {
          _appBarOpacity = opacity;
        });
      }
    });
  }

  void _checkStatus() async {
    final isFav = await _storageService.isFavorite(_movie.id);
    final status = await _storageService.getWatchStatus(_movie.id);
    final progress = await _storageService.getProgress(_movie.id);
    final note = await _storageService.getNote(_movie.id);
    
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
        _watchStatus = status;
        _progress = progress;
        _userNote = note;
      });
    }
  }

  void _loadExtraData() async {
    // Fetch full movie details to get genres and other missing info
    final fullMovie = await _tmdbService.getMovieDetail(_movie.id);
    
    final cast = await _tmdbService.getMovieCredits(_movie.id);
    final recommendations = await _tmdbService.getMovieRecommendations(_movie.id);
    final images = await _tmdbService.getMovieImages(_movie.id);
    final reviews = await _tmdbService.getMovieReviews(_movie.id);
    
    // 获取视频 Key：直接搜索 YouTube
    String? videoKey = await _youTubeService.searchVideo(_movie.title);
    
    if (mounted) {
      setState(() {
        if (fullMovie != null) {
          _movie = fullMovie; // Update movie with full details
        }
        _cast = cast;
        _recommendations = recommendations;
        _images = images;
        _reviews = reviews;
        _videoKey = videoKey;
      });
    }
  }

  void _toggleFavorite() async {
    final newStatus = await _storageService.toggleFavorite(_movie);
    if (mounted) setState(() => _isFavorite = newStatus);
  }

  void _changeWatchStatus(WatchStatus status) async {
    await _storageService.setWatchStatus(_movie, status);
    if (mounted) setState(() => _watchStatus = status);
  }
  
  void _updateProgress(double value) async {
    setState(() => _progress = value);
    await _storageService.setProgress(_movie.id, value);
  }

  void _showNoteDialog() {
    final TextEditingController noteController = TextEditingController(text: _userNote);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('我的观影笔记'),
        content: TextField(
          controller: noteController, 
          maxLines: 5, 
          decoration: InputDecoration(
            hintText: '记录下这一刻的感受...', 
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              if (noteController.text.isNotEmpty) {
                await _storageService.saveNote(_movie, noteController.text);
                if (mounted) setState(() => _userNote = noteController.text);
              }
              if (context.mounted) Navigator.pop(context);
            }, 
            child: const Text('保存', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddToListDialog() async {
    final lists = await _storageService.getCustomListNames();
    final textController = TextEditingController();
    final descController = TextEditingController();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true, // 允许键盘弹出
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: 500,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('添加到片单', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: lists.isEmpty 
                      ? const Center(child: Text('暂无片单，请创建', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: lists.length,
                          itemBuilder: (context, index) {
                            final listName = lists[index];
                            return ListTile(
                              leading: const Icon(Icons.list_alt),
                              title: Text(listName),
                              trailing: const Icon(Icons.add_circle_outline),
                              onTap: () async {
                                await _storageService.addMovieToCustomList(listName, _movie);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已添加到 $listName')));
                                }
                              },
                            );
                          },
                        ),
                  ),
                  const Divider(),
                  const Text('新建片单', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(controller: textController, decoration: const InputDecoration(hintText: '片单名称', isDense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: descController, decoration: const InputDecoration(hintText: '一句话简介', isDense: true)),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      child: const Text('创建'),
                      onPressed: () async {
                        if (textController.text.isNotEmpty) {
                          await _storageService.createCustomList(textController.text, description: descController.text);
                          final newLists = await _storageService.getCustomListNames();
                          setModalState(() {
                            lists.clear();
                            lists.addAll(newLists);
                            textController.clear();
                            descController.clear();
                          });
                        }
                      },
                    ),
                  )
                ],
              ),
            );
          }
        ),
      ),
    );
  }

  // 优化：使用 PageView 的全屏相册
  void _showFullImage(BuildContext context, int initialIndex) {
    PageController pageController = PageController(initialPage: initialIndex);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero, // 全屏
        child: Stack(
          alignment: Alignment.center,
          children: [
             PageView.builder(
               controller: pageController,
               itemCount: _images.length,
               itemBuilder: (context, index) {
                 return InteractiveViewer(
                   child: CachedNetworkImage(imageUrl: _images[index], fit: BoxFit.contain),
                 );
               },
             ),
             Positioned(top: 40, right: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context))),
             Positioned(
               bottom: 40,
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                 decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                 child: SmoothPageIndicator(
                   controller: pageController, 
                   count: _images.length,
                   effect: const ScrollingDotsEffect(activeDotColor: Colors.white, dotColor: Colors.grey, dotHeight: 8, dotWidth: 8),
                 ), 
               ), 
             ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final movie = _movie;
    // Genres list string
    final genresText = movie.genres.isNotEmpty ? movie.genres.join(' / ') : '暂无类型';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(_appBarOpacity * 0.8),
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(backgroundColor: Colors.black.withOpacity(0.3), child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))),
        ),
        title: _appBarOpacity > 0.8 ? Text(movie.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)) : null,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(backgroundColor: Colors.black.withOpacity(0.3), child: IconButton(icon: const Icon(Icons.playlist_add, color: Colors.white), onPressed: _showAddToListDialog)),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(backgroundColor: Colors.black.withOpacity(0.3), child: IconButton(icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border, color: _isFavorite ? Colors.red : Colors.white), onPressed: _toggleFavorite)),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: CachedNetworkImage(imageUrl: movie.fullPosterUrl, fit: BoxFit.cover)),
          Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), child: Container(color: Colors.black.withOpacity(0.3)))),
          
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                const SizedBox(height: 100),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'detail_poster_${movie.id}',
                        child: Container(
                          width: 140,
                          height: 210,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))], image: DecorationImage(image: CachedNetworkImageProvider(movie.fullPosterUrl), fit: BoxFit.cover)),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            Text(movie.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black54, blurRadius: 10)])),
                            const SizedBox(height: 10),
                            Row(children: [RatingBarIndicator(rating: movie.voteAverage / 2, itemBuilder: (context, index) => const Icon(Icons.star, color: Colors.amber), itemCount: 5, itemSize: 16.0), const SizedBox(width: 8), Text('${movie.voteAverage}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))]),
                            const SizedBox(height: 10),
                            Text('上映: ${movie.releaseDate}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(genresText, style: const TextStyle(color: Colors.white60, fontSize: 12)), // 新增类型显示
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                if (_videoKey != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => VideoPlayerPage(
                                        videoId: _videoKey!,
                                        title: movie.title,
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('暂无预告片资源')),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _videoKey != null 
                                    ? const Color(0xFFFF5252) 
                                    : Colors.grey, 
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 4,
                                shadowColor: Colors.redAccent.withOpacity(0.4),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: Text(_videoKey != null ? '相关视频' : '暂无资源', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatusButton(WatchStatus.wantToWatch, '想看', Icons.bookmark_border, Icons.bookmark),
                      _buildStatusButton(WatchStatus.watching, '正在看', Icons.play_circle_outline, Icons.play_circle_fill),
                      _buildStatusButton(WatchStatus.watched, '看过', Icons.check_circle_outline, Icons.check_circle),
                    ],
                  ),
                ),

                if (_watchStatus == WatchStatus.watching) 
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('观看进度', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text('${(_progress * 100).toInt()}%', style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: Colors.amber,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.white,
                            overlayColor: Colors.amber.withOpacity(0.2),
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          ),
                          child: Slider(
                            value: _progress,
                            onChanged: _updateProgress,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 30),
                
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.6),
                  decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 50),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('剧情简介', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ExpandableText(
                        text: movie.overview, 
                        maxLines: 4,
                        style: TextStyle(fontSize: 16, height: 1.6, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 30),
                      
                      if (_cast.isNotEmpty) ...[
                        const Text('演职人员', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _cast.length,
                            itemBuilder: (context, index) {
                              final actor = _cast[index];
                              return GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PersonDetailPage(
                                  personId: actor.id, 
                                  personName: actor.name,
                                  profilePath: actor.profilePath,
                                ))),
                                child: Container(
                                  width: 80,
                                  margin: const EdgeInsets.only(right: 16),
                                  child: Column(
                                    children: [
                                      CircleAvatar(radius: 35, backgroundImage: NetworkImage(actor.fullProfileUrl), backgroundColor: Colors.grey[200]),
                                      const SizedBox(height: 8),
                                      Text(actor.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                      
                      if (_images.isNotEmpty) ...[
                        const Text('剧照 / 相册', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _images.length,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () => _showFullImage(context, index), // 传递 index
                                child: Container(margin: const EdgeInsets.only(right: 12), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedNetworkImage(imageUrl: _images[index], fit: BoxFit.cover, width: 180))),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],

                      if (_recommendations.isNotEmpty) ...[
                        const Text('类似推荐', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 180,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _recommendations.length,
                            itemBuilder: (context, index) {
                              final sm = _recommendations[index];
                              return GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: sm))),
                                child: Container(
                                  width: 110,
                                  margin: const EdgeInsets.only(right: 12),
                                  child: Column(
                                    children: [
                                      ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedNetworkImage(imageUrl: sm.fullPosterUrl, height: 150, width: 110, fit: BoxFit.cover)),
                                      const SizedBox(height: 6),
                                      Text(sm.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                      
                      if (_userNote != null && _userNote!.isNotEmpty) ...[
                        const Divider(height: 40),
                        const Text('我的笔记', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFFECB3)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: const [Icon(Icons.format_quote_rounded, color: Colors.amber, size: 20), SizedBox(width: 8), Text('Review', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12))]),
                              const SizedBox(height: 8),
                              Text(_userNote!, style: TextStyle(fontSize: 15, height: 1.6, color: Colors.brown[800], fontStyle: FontStyle.italic)),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(onPressed: _showNoteDialog, icon: const Icon(Icons.edit, size: 14, color: Colors.brown), label: const Text('编辑', style: TextStyle(color: Colors.brown))),
                              )
                            ],
                          ),
                        ),
                      ],
                      
                      if (_userNote == null || _userNote!.isEmpty)
                         Padding(
                           padding: const EdgeInsets.only(top: 20),
                           child: SizedBox(
                             width: double.infinity,
                             child: OutlinedButton.icon(
                               onPressed: _showNoteDialog,
                               icon: const Icon(Icons.edit_note),
                               label: const Text('写影评'),
                               style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                             ),
                           ),
                         ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(WatchStatus status, String label, IconData icon, IconData activeIcon) {
    final isActive = _watchStatus == status;
    return GestureDetector(
      onTap: () => _changeWatchStatus(isActive ? WatchStatus.none : status),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive ? Colors.amber : Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(isActive ? activeIcon : icon, color: isActive ? Colors.black : Colors.white),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isActive ? Colors.amber : Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))
        ],
      ),
    );
  }
}

// 简单的指示器，避免引入 smooth_page_indicator 库的依赖问题，或者如果已添加依赖可以使用。
// 这里手写一个简单的。
class SmoothPageIndicator extends StatelessWidget {
  final PageController controller;
  final int count;
  final dynamic effect; // 占位

  const SmoothPageIndicator({super.key, required this.controller, required this.count, this.effect});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        int currentPage = controller.page?.round() ?? 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(count, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: currentPage == index ? Colors.white : Colors.grey,
              ),
            );
          }),
        );
      }
    );
  }
}
class ScrollingDotsEffect {
  final Color activeDotColor;
  final Color dotColor;
  final double dotHeight;
  final double dotWidth;
  const ScrollingDotsEffect({this.activeDotColor = Colors.white, this.dotColor = Colors.grey, this.dotHeight = 8, this.dotWidth = 8});
}
