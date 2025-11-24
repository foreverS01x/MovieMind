import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import 'movie_detail_page.dart';

class MovieListPage extends StatelessWidget {
  final String title;
  final List<Movie> movies;

  const MovieListPage({super.key, required this.title, required this.movies});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF5F5F7),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.6,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: movies.length,
        itemBuilder: (context, index) {
          final movie = movies[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MovieDetailPage(movie: movie),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: movie.fullPosterUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey[200]),
                        errorWidget: (context, url, error) => Container(color: Colors.grey[300]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  movie.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    const Icon(Icons.star, size: 12, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      movie.voteAverage.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

