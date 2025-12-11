class Movie {
  final int id;
  final String title;
  final String originalTitle;
  final String posterPath;
  final String backdropPath;
  final double voteAverage;
  final String releaseDate;
  final String overview;
  final List<int> genreIds;
  final String tagline; 
  final List<String> genres; // String List for display
  final List<String> countries; // Production Countries
  final String director; // Director Name
  final int runtime;

  Movie({
    required this.id,
    required this.title,
    this.originalTitle = '',
    required this.posterPath,
    required this.backdropPath,
    required this.voteAverage,
    required this.releaseDate,
    required this.overview,
    this.genreIds = const [],
    this.tagline = '',
    this.genres = const [],
    this.countries = const [],
    this.director = '',
    this.runtime = 0,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    // Extract genres
    List<String> genreList = [];
    if (json['genres'] != null) {
      genreList = (json['genres'] as List).map((g) => g['name'].toString()).toList();
    }

    // Extract countries
    List<String> countryList = [];
    if (json['production_countries'] != null) {
      countryList = (json['production_countries'] as List).map((c) => c['iso_3166_1'].toString()).toList();
    }

    // Extract director (needs credits to be passed in json or handled separately, usually TMDb returns credits in a separate call or 'append_to_response')
    String directorName = '';
    if (json['credits'] != null && json['credits']['crew'] != null) {
      final crew = json['credits']['crew'] as List;
      final directorEntry = crew.firstWhere(
        (member) => member['job'] == 'Director',
        orElse: () => null,
      );
      if (directorEntry != null) {
        directorName = directorEntry['name'];
      }
    }

    return Movie(
      id: json['id'] ?? 0,
      title: json['title'] ?? json['original_title'] ?? '',
      originalTitle: json['original_title'] ?? '',
      posterPath: json['poster_path'] ?? '',
      backdropPath: json['backdrop_path'] ?? '',
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
      releaseDate: json['release_date'] ?? json['first_air_date'] ?? '',
      overview: json['overview'] ?? '暂无简介',
      genreIds: List<int>.from(json['genre_ids'] ?? []),
      tagline: json['tagline'] ?? '',
      genres: genreList,
      countries: countryList,
      director: directorName,
      runtime: json['runtime'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'original_title': originalTitle,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'vote_average': voteAverage,
      'release_date': releaseDate,
      'overview': overview,
      'genre_ids': genreIds,
      'tagline': tagline,
      'genres': genres.map((g) => {'name': g}).toList(), // Re-structure for consistency or just store list
      'production_countries': countries.map((c) => {'iso_3166_1': c}).toList(),
      'runtime': runtime,
      'director': director, // Custom field storage
      // NOTE: We store 'director' flat here, but fromJson expects it in credits structure if raw API. 
      // We should adjust fromJson to look for flat field too.
    };
  }
  
  // Helper to handle both API structure and Local Storage structure
  factory Movie.fromLocalJson(Map<String, dynamic> json) {
      return Movie(
      id: json['id'] ?? json['tmdb_id'] ?? 0, // Handle both 'id' and 'tmdb_id'
      title: json['title'] ?? '',
      originalTitle: json['original_title'] ?? '',
      posterPath: json['poster_path'] ?? '',
      backdropPath: json['backdrop_path'] ?? '',
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
      releaseDate: json['release_date'] ?? '',
      overview: json['overview'] ?? '',
      genreIds: List<int>.from(json['genre_ids'] ?? []),
      tagline: json['tagline'] ?? '',
      genres: (json['genres'] as List?)?.map((e) => e is String ? e : e['name'].toString()).toList() ?? [],
      countries: (json['production_countries'] as List?)?.map((e) => e is String ? e : e['iso_3166_1'].toString()).toList() ?? [],
      director: json['director'] ?? '',
      runtime: json['runtime'] ?? 0,
    );
  }

  String get fullPosterUrl => posterPath.isNotEmpty 
      ? 'https://image.tmdb.org/t/p/w500$posterPath' 
      : 'https://via.placeholder.com/500x750?text=No+Image';
      
  String get fullBackdropUrl => backdropPath.isNotEmpty 
      ? 'https://image.tmdb.org/t/p/w780$backdropPath' 
      : 'https://via.placeholder.com/780x440?text=No+Image';
}

class Cast {
  final int id;
  final String name;
  final String character;
  final String profilePath;

  Cast({required this.id, required this.name, required this.character, required this.profilePath});

  factory Cast.fromJson(Map<String, dynamic> json) {
    return Cast(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      character: json['character'] ?? '',
      profilePath: json['profile_path'] ?? '',
    );
  }

  String get fullProfileUrl => profilePath.isNotEmpty
      ? 'https://image.tmdb.org/t/p/w185$profilePath'
      : 'https://via.placeholder.com/185x275?text=No+Image';
}

class Genre {
  final int id;
  final String name;

  Genre({required this.id, required this.name});

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(id: json['id'] ?? 0, name: json['name'] ?? '');
  }
}

class Person {
  final int id;
  final String name;
  final String profilePath;
  final List<Movie> knownFor;
  final int gender; // 1: Female, 2: Male
  final String knownForDepartment;

  Person({
    required this.id, 
    required this.name, 
    required this.profilePath, 
    required this.knownFor,
    this.gender = 0,
    this.knownForDepartment = '',
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    var knownForList = (json['known_for'] as List?)
        ?.map((e) => Movie.fromJson(e))
        .where((m) => m.title.isNotEmpty)
        .toList() ?? [];

    return Person(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      profilePath: json['profile_path'] ?? '',
      knownFor: knownForList,
      gender: json['gender'] ?? 0,
      knownForDepartment: json['known_for_department'] ?? '',
    );
  }
  
  String get fullProfileUrl => profilePath.isNotEmpty
      ? 'https://image.tmdb.org/t/p/w185$profilePath'
      : 'https://via.placeholder.com/185x275?text=No+Image';
}

class PersonDetail {
  final int id;
  final String name;
  final String biography;
  final String birthday;
  final String placeOfBirth;
  final String profilePath;

  PersonDetail({
    required this.id,
    required this.name,
    required this.biography,
    required this.birthday,
    required this.placeOfBirth,
    required this.profilePath,
  });

  factory PersonDetail.fromJson(Map<String, dynamic> json) {
    return PersonDetail(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      biography: json['biography'] ?? '暂无介绍',
      birthday: json['birthday'] ?? '',
      placeOfBirth: json['place_of_birth'] ?? '',
      profilePath: json['profile_path'] ?? '',
    );
  }
  
  String get fullProfileUrl => profilePath.isNotEmpty
      ? 'https://image.tmdb.org/t/p/h632$profilePath'
      : 'https://via.placeholder.com/300x450?text=No+Image';
}

class Review {
  final String id;
  final String author;
  final String content;
  final String? avatarPath;
  final double? rating;
  final String createdAt;

  Review({
    required this.id,
    required this.author,
    required this.content,
    this.avatarPath,
    this.rating,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    final authorDetails = json['author_details'] ?? {};
    String? avatar = authorDetails['avatar_path'];
    if (avatar != null && !avatar.startsWith('http')) {
      avatar = 'https://image.tmdb.org/t/p/w185$avatar';
    } else if (avatar != null && avatar.startsWith('/http')) {
       avatar = avatar.substring(1); 
    }

    return Review(
      id: json['id'] ?? '',
      author: json['author'] ?? 'Anonymous',
      content: json['content'] ?? '',
      avatarPath: avatar,
      rating: (authorDetails['rating'] as num?)?.toDouble(),
      createdAt: json['created_at'] ?? '',
    );
  }
}
