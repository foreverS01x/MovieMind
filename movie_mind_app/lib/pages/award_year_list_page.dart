import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/award.dart';
import '../services/award_service.dart';
import '../services/tmdb_service.dart';
import '../models/movie.dart';
import 'movie_detail_page.dart';

class AwardYearListPage extends StatefulWidget {
  final String awardName;

  const AwardYearListPage({super.key, required this.awardName});

  @override
  State<AwardYearListPage> createState() => _AwardYearListPageState();
}

class _AwardYearListPageState extends State<AwardYearListPage> {
  final AwardService _awardService = AwardService();
  List<Award> _awards = [];
  bool _isAscending = false; // Default descending (newest first)
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAwards();
  }

  void _loadAwards() async {
    final awards = await _awardService.getAwards(widget.awardName);
    if (mounted) {
      setState(() {
        _awards = awards;
        _sortAwards();
        _isLoading = false;
      });
    }
  }

  void _sortAwards() {
    if (_isAscending) {
      _awards.sort((a, b) => a.year.compareTo(b.year));
    } else {
      _awards.sort((a, b) => b.year.compareTo(a.year));
    }
  }

  void _toggleSort() {
    setState(() {
      _isAscending = !_isAscending;
      _sortAwards();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.awardName),
        actions: [
          IconButton(
            icon: Icon(_isAscending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: _toggleSort,
            tooltip: _isAscending ? '时间正序' : '时间倒序',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _awards.length,
              itemBuilder: (context, index) {
                final award = _awards[index];
                return _buildYearSection(award);
              },
            ),
    );
  }

  Widget _buildYearSection(Award award) {
    // Sort movies: winner first
    final sortedMovies = List<AwardMovie>.from(award.movies)
      ..sort((a, b) {
        if (a.isWinner && !b.isWinner) return -1;
        if (!a.isWinner && b.isWinner) return 1;
        return 0;
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${award.year}年',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '第${award.session}届',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: sortedMovies.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              return _AwardMovieCard(movie: sortedMovies[index]);
            },
          ),
        ),
        const Divider(height: 40),
      ],
    );
  }
}

class _AwardMovieCard extends StatefulWidget {
  final AwardMovie movie;

  const _AwardMovieCard({required this.movie});

  @override
  State<_AwardMovieCard> createState() => _AwardMovieCardState();
}

class _AwardMovieCardState extends State<_AwardMovieCard> {
  final TMDbService _tmdbService = TMDbService();
  Movie? _movieDetail;

  @override
  void initState() {
    super.initState();
    _loadMovieDetail();
  }

  void _loadMovieDetail() async {
    if (widget.movie.tmdbId == 0) {
       return;
    }
    
    final detail = await _tmdbService.getMovieDetail(widget.movie.tmdbId);
    if (mounted) {
      setState(() {
        _movieDetail = detail;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_movieDetail != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MovieDetailPage(movie: _movieDetail!)),
          );
        }
      },
      child: SizedBox(
        width: 120,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[200],
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))
                      ]
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _movieDetail != null
                          ? CachedNetworkImage(
                              imageUrl: _movieDetail!.fullPosterUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : const Center(child: Icon(Icons.movie, color: Colors.grey)),
                    ),
                  ),
                  if (widget.movie.isWinner)
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
            const SizedBox(height: 8),
            Text(
              widget.movie.tmdbTitle.isNotEmpty ? widget.movie.tmdbTitle : widget.movie.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

