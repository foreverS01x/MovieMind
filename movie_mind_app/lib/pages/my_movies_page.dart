import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/storage_service.dart';
import '../models/movie.dart';
import 'movie_detail_page.dart';

class MyMoviesPage extends StatefulWidget {
  final WatchStatus status;
  final bool isFavorite;
  final bool isComment;
  final String? customListName;

  const MyMoviesPage({
    super.key, 
    this.status = WatchStatus.none, 
    this.isFavorite = false,
    this.isComment = false,
    this.customListName,
  });

  @override
  State<MyMoviesPage> createState() => _MyMoviesPageState();
}

class _MyMoviesPageState extends State<MyMoviesPage> {
  final StorageService _storageService = StorageService();
  List<Movie> _movies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    List<Movie> movies = [];
    if (widget.customListName != null) {
      movies = await _storageService.getMoviesFromCustomList(widget.customListName!);
    } else if (widget.isFavorite) {
      movies = await _storageService.getFavorites();
    } else if (widget.isComment) {
      movies = await _storageService.getCommentedMovies();
    } else {
      movies = await _storageService.getMoviesByStatus(widget.status);
    }
    
    if (mounted) setState(() { _movies = movies; _isLoading = false; });
  }

  String get _title {
    if (widget.customListName != null) return widget.customListName!;
    if (widget.isFavorite) return '我的收藏';
    if (widget.isComment) return '我的评论';
    switch (widget.status) {
      case WatchStatus.watching: return '正在看';
      case WatchStatus.wantToWatch: return '待看清单';
      case WatchStatus.watched: return '观影记录';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: Text(_title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF5F5F7),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _movies.isEmpty
              ? const Center(child: Text('列表为空', style: TextStyle(color: Colors.grey)))
              : (widget.status == WatchStatus.watched || widget.isFavorite)
                  ? GridView.builder(
                      padding: widget.isFavorite 
                          ? const EdgeInsets.fromLTRB(20, 40, 20, 20) 
                          : const EdgeInsets.all(20),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: widget.isFavorite ? 1.05 : 0.55,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 40, // 增加间距防止板夹溢出遮挡上一排
                      ),
                      itemCount: _movies.length,
                      itemBuilder: (context, index) {
                        if (widget.isFavorite) return _buildClapperboard(_movies[index], index);
                        return _buildWatchedTicket(_movies[index]);
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _movies.length,
                      itemBuilder: (context, index) {
                        final movie = _movies[index];
                        if (widget.status == WatchStatus.wantToWatch) return _buildWantToWatchCard(movie);
                        if (widget.status == WatchStatus.watching) return _buildWatchingCard(movie);
                        // isFavorite moved to GridView
                        if (widget.isComment) return _buildCommentCard(movie);
                        return _buildNormalCard(movie);
                      },
                    ),
    );
  }

  // 收藏：场记板设计
  Widget _buildClapperboard(Movie movie, int index) {
    const clapperColor = Color(0xFF424242); // 浅一些的深灰色
    
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie))),
      child: Column(
        children: [
          // 上部：板夹 (Clapper)
          SizedBox(
            height: 24,
            child: Stack(
              alignment: Alignment.bottomLeft,
              children: [
                // 旋转的板夹
                Transform.rotate(
                  angle: -0.2, // 加大角度
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    height: 18,
                    decoration: const BoxDecoration(
                      color: clapperColor,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                    ),
                    child: Row(
                      children: List.generate(6, (i) => Expanded(child: Container(
                        transform: Matrix4.skewX(-0.2), // 倾斜条纹
                        color: i % 2 == 0 ? const Color(0xFFE0E0E0) : Colors.transparent
                      ))),
                    ),
                  ),
                ),
                // 连接处挡片 (三角形)
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: CustomPaint(
                    size: const Size(24, 24),
                    painter: HingePainter(color: clapperColor),
                  ),
                ),
                // 螺丝钉装饰
                Positioned(
                  left: 2,
                  bottom: 4,
                  child: _buildScrewHead(),
                ),
                Positioned(
                  left: 12,
                  bottom: 8,
                  child: _buildScrewHead(),
                ),
                Positioned(
                  left: 8,
                  bottom: 16,
                  child: _buildScrewHead(),
                ),
              ],
            ),
          ),
          // 下部：信息板
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: clapperColor,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 4))]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 顶部黑白条纹
                  Container(
                    height: 12,
                    decoration: const BoxDecoration(color: clapperColor),
                    child: Row(
                      children: List.generate(6, (i) => Expanded(child: Container(
                        transform: Matrix4.skewX(-0.2),
                        color: i % 2 == 0 ? const Color(0xFFE0E0E0) : Colors.transparent
                      ))),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TITLE.', style: TextStyle(color: Colors.white70, fontSize: 7, fontFamily: 'Courier', fontWeight: FontWeight.bold)),
                        Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Courier', fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        // 分割线
                        Container(height: 1, color: Colors.white30),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('SCENE.', style: TextStyle(color: Colors.white70, fontSize: 7, fontFamily: 'Courier', fontWeight: FontWeight.bold)),
                                  Text('No.${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Courier')),
                                ],
                              ),
                            ),
                            // 竖线
                            Container(width: 1, height: 20, color: Colors.white30),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('DATE.', style: TextStyle(color: Colors.white70, fontSize: 7, fontFamily: 'Courier', fontWeight: FontWeight.bold)),
                                  Text(movie.releaseDate.replaceAll('-', '.'), style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Shantell Sans', fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                                ],
                              ),
                            ),
                          ],
                        ),
                         const SizedBox(height: 4),
                        // 分割线
                        Container(height: 1, color: Colors.white30),
                      ],
                    ),
                  ),
                  // 底部海报/剧照 (带白边框效果)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: movie.fullBackdropUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrewHead() {
    return Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: Color(0xFFE0E0E0),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 1, offset: Offset(0.5, 0.5))]
      ),
    );
  }

  // 待看清单：去除打孔，纯净卡片
  Widget _buildWantToWatchCard(Movie movie) {
    final List<Color> pastelColors = [
      const Color.fromARGB(147, 255, 248, 225), const Color.fromARGB(133, 225, 245, 254), const Color.fromARGB(155, 243, 229, 245),
      const Color.fromARGB(152, 232, 245, 233), const Color.fromARGB(145, 255, 235, 238), const Color(0xFFFAFAFA),
    ];
    final randomColor = pastelColors[Random(movie.id).nextInt(pastelColors.length)];

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 160,
        decoration: BoxDecoration(
          color: randomColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: CachedNetworkImage(imageUrl: movie.fullPosterUrl, width: 110, height: 160, fit: BoxFit.cover),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(movie.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(movie.originalTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('Tomorrow', style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Icon(Icons.favorite_border, color: Colors.grey[400]),
                      ],
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
  
  // 我的评论：解决 RenderFlex overflow
  Widget _buildCommentCard(Movie movie) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        // 不设置固定高度，让内容撑开
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: CachedNetworkImage(imageUrl: movie.fullPosterUrl, width: 100, height: 150, fit: BoxFit.cover),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(movie.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: Colors.amber[700]),
                        Text(' ${movie.voteAverage.toStringAsFixed(1)}', style: TextStyle(fontSize: 12, color: Colors.amber[900])),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<String?>(
                      future: _storageService.getNote(movie.id),
                      builder: (context, snapshot) {
                        final note = snapshot.data ?? '';
                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            note.isEmpty ? '暂无评论' : note,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
                          ),
                        );
                      }
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 正在看：保持优化后的虚化+渐变
  Widget _buildWatchingCard(Movie movie) {
    return FutureBuilder<double>(
      future: _storageService.getProgress(movie.id),
      builder: (context, snapshot) {
        final progress = snapshot.data ?? 0.0;
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie))),
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken),
                        child: CachedNetworkImage(imageUrl: movie.fullBackdropUrl, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return ShaderMask(
                        shaderCallback: (rect) {
                          return LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: const [Colors.white, Colors.white, Colors.transparent],
                            stops: [0.0, (progress - 0.2).clamp(0.0, 1.0), (progress + 0.1).clamp(0.0, 1.0)], 
                          ).createShader(rect);
                        },
                        blendMode: BlendMode.dstIn,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: 1.0, 
                          child: CachedNetworkImage(imageUrl: movie.fullBackdropUrl, width: constraints.maxWidth, height: constraints.maxHeight, fit: BoxFit.cover),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    left: 24, right: 24, bottom: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(movie.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5, shadows: [Shadow(color: Colors.black, blurRadius: 10)])),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                             Text('${(progress * 100).toInt()}%', style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 5)])),
                             const SizedBox(width: 8),
                             Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Colors.amber), minHeight: 6))),
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  // 已看：重新设计票根 (底部打孔)
  Widget _buildWatchedTicket(Movie movie) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _storageService.getNote(movie.id),
        _storageService.getStatusTime(movie.id),
      ]),
      builder: (ctx, snapshot) {
        final note = (snapshot.data?[0] as String?) ?? '';
        String quote = note.isNotEmpty ? note : (movie.tagline.isNotEmpty ? movie.tagline : 'MovieMind Review');
        
        final timestamp = snapshot.data?[1] as int?;
        final date = timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : DateTime.now();
        
        final dateStr = "${date.year}/${date.month}/${date.day}";
        String timeStr = 'NIGHT';
        final hour = date.hour;
        if (hour >= 6 && hour < 12) timeStr = 'MORNING';
        else if (hour >= 12 && hour < 14) timeStr = 'NOON';
        else if (hour >= 14 && hour < 18) timeStr = 'AFTERNOON';
        else if (hour >= 18 && hour < 22) timeStr = 'EVENING';

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie))),
          child: ClipPath(
            clipper: TicketClipper(),
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // 上部分：海报 + 名字 + 年份
                  Expanded(
                    flex: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: CachedNetworkImage(
                            imageUrl: movie.fullPosterUrl, 
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'serif')),
                              const SizedBox(height: 4),
                              Text(movie.originalTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 12, fontFamily: 'serif')),
                              const SizedBox(height: 8),
                              // 虚线分割
                              SizedBox(
                                height: 1,
                                child: CustomPaint(
                                  size: const Size(double.infinity, 1),
                                  painter: DashedLinePainter(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start, // 改为 start 对齐
                                children: [
                                  _buildTicketInfo('DATE', dateStr),
                                  const SizedBox(width: 32), // 缩小间距 (之前是 spaceBetween)
                                  _buildTicketInfo('TIME', timeStr),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 虚线分割
                  SizedBox(
                    height: 20,
                    child: CustomPaint(
                      size: const Size(double.infinity, 20),
                      painter: DashedLinePainter(),
                    ),
                  ),
                  // 下部分：金句
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      alignment: Alignment.topLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('FEELINGS:', style: TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, fontFamily: 'serif')),
                          const SizedBox(height: 4),
                          Expanded(
                            child: Text(
                              quote, 
                              maxLines: 3, 
                              overflow: TextOverflow.ellipsis, 
                              style: const TextStyle(fontSize: 11, height: 1.5, color: Colors.black54, fontFamily: 'serif'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildTicketInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label:', style: const TextStyle(color: Colors.black, fontSize: 10, fontFamily: 'serif', fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(color: Colors.black87, fontSize: 10, fontFamily: 'serif')),
      ],
    );
  }

  Widget _buildNormalCard(Movie movie) {
    return _buildCommentCard(movie); 
  }
}

class HingePainter extends CustomPainter {
  final Color color;
  HingePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
      
    final path = Path();
    // 三角形挡片，模拟连接处的金属件
    path.moveTo(0, size.height);
    path.lineTo(18, size.height);
    path.lineTo(0, size.height - 18);
    path.close();
    
    canvas.drawPath(path, paint);

    // 边缘高光
    final borderPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 票根裁剪器
class TicketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    const r = 10.0; // 打孔半径
    // 虚线位置：(总高度 - 固定高度20) * 上部分比例(8/10) + 固定高度的一半(10)
    final splitY = (h - 20) * 0.8 + 10;

    path.moveTo(0, 0);
    path.lineTo(w, 0);
    
    // 右侧虚线缺口
    path.lineTo(w, splitY - r);
    path.arcToPoint(Offset(w, splitY + r), radius: const Radius.circular(r), clockwise: false);
    
    // 右下角 1/4 圆缺口
    path.lineTo(w, h - r);
    path.arcToPoint(Offset(w - r, h), radius: const Radius.circular(r), clockwise: false);

    // 底部半圆打孔
    final double holeDiameter = r * 2;
    // 计算可以放几个孔，保留一定间距
    final double bottomWidth = w - 2 * r; 
    // 假设间距等于孔径的一半
    final int count = (bottomWidth / (holeDiameter * 1.5)).floor();
    final double spacing = (bottomWidth - count * holeDiameter) / (count + 1);
    
    double currentX = w - r;
    for(int i=0; i<count; i++) {
      currentX -= spacing;
      path.lineTo(currentX, h);
      path.arcToPoint(Offset(currentX - holeDiameter, h), radius: const Radius.circular(r), clockwise: false);
      currentX -= holeDiameter;
    }

    // 左下角 1/4 圆缺口
    path.lineTo(r, h);
    path.arcToPoint(Offset(0, h - r), radius: const Radius.circular(r), clockwise: false);

    // 左侧虚线缺口
    path.lineTo(0, splitY + r);
    path.arcToPoint(Offset(0, splitY - r), radius: const Radius.circular(r), clockwise: false);
    
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// 虚线画笔
class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    final dashWidth = 5;
    final dashSpace = 5;
    double startX = 10;
    final y = size.height / 2;
    
    while (startX < size.width - 10) {
      canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
