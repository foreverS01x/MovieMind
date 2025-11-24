import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';
import 'movie_detail_page.dart';
import '../widgets/expandable_text.dart';

class PersonDetailPage extends StatefulWidget {
  final int personId;
  final String personName;
  final String profilePath;

  const PersonDetailPage({
    super.key, 
    required this.personId, 
    required this.personName,
    required this.profilePath,
  });

  @override
  State<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends State<PersonDetailPage> {
  final TMDbService _tmdbService = TMDbService();
  PersonDetail? _detail;
  List<Movie> _credits = [];
  List<String> _images = []; // 这里改为存剧照
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final detail = await _tmdbService.getPersonDetail(widget.personId);
    final credits = await _tmdbService.getPersonMovieCredits(widget.personId);
    final images = await _tmdbService.getPersonTaggedImages(widget.personId); // 使用 Tagged Images
    
    if (mounted) {
      setState(() {
        _detail = detail;
        _credits = credits;
        _images = images;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(widget.personName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 头部信息
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: _detail?.fullProfileUrl ?? 'https://image.tmdb.org/t/p/w500${widget.profilePath}',
                          width: 100,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _detail?.name ?? widget.personName,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            if (_detail != null) ...[
                              Text('出生: ${_detail!.birthday}', style: const TextStyle(color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text('出生地: ${_detail!.placeOfBirth}', style: const TextStyle(color: Colors.grey)),
                            ]
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 2. 简介
                  if (_detail?.biography.isNotEmpty == true) ...[
                    const Text('影人简介', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ExpandableText(
                      text: _detail!.biography,
                      maxLines: 5,
                      style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 3. 剧照相册
                  if (_images.isNotEmpty) ...[
                    const Text('剧照 / 花絮', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _images.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: GestureDetector(
                              // 点击可以看大图 (这里简化处理)
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(imageUrl: _images[index], fit: BoxFit.cover, width: 180),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 4. 代表作品
                  const Text('代表作品', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.6,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: _credits.take(12).length, // 限制展示数量
                    itemBuilder: (context, index) {
                      final movie = _credits[index];
                      return GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie))),
                        child: Column(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: movie.fullPosterUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(color: Colors.grey[200]),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              movie.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
