class Award {
  final String name;
  final int session;
  final int year;
  final String winner;
  final List<AwardMovie> movies;

  Award({
    required this.name,
    required this.session,
    required this.year,
    required this.winner,
    required this.movies,
  });

  factory Award.fromJson(String awardName, Map<String, dynamic> json) {
    var moviesList = (json['all_movies_data'] as List?)
        ?.map((e) => AwardMovie.fromJson(e))
        .toList() ?? [];

    return Award(
      name: awardName,
      session: json['session'] ?? 0,
      year: json['year'] ?? 0,
      winner: json['winner'] ?? '',
      movies: moviesList,
    );
  }
}

class AwardMovie {
  final String title;
  final String link;
  final bool isWinner;
  final int tmdbId;
  final String tmdbTitle;
  final String tmdbReleaseDate;

  AwardMovie({
    required this.title,
    required this.link,
    required this.isWinner,
    required this.tmdbId,
    required this.tmdbTitle,
    required this.tmdbReleaseDate,
  });

  factory AwardMovie.fromJson(Map<String, dynamic> json) {
    return AwardMovie(
      title: json['title'] ?? '',
      link: json['link'] ?? '',
      isWinner: json['is_winner'] ?? false,
      tmdbId: json['tmdb_id'] ?? 0,
      tmdbTitle: json['tmdb_title'] ?? '',
      tmdbReleaseDate: json['tmdb_release_date'] ?? '',
    );
  }
}

