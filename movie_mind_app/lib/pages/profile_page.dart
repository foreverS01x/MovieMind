import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';
import '../widgets/heatmap_grid.dart';
import 'my_movies_page.dart';
import 'custom_lists_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final StorageService _storageService = StorageService();
  final TMDbService _tmdbService = TMDbService();
  final ImagePicker _picker = ImagePicker();
  
  Map<DateTime, int> _heatmapData = {};
  User? _currentUser;
  
  int _watchedCount = 0;
  int _wantCount = 0;
  int _watchingCount = 0;
  int _favoriteCount = 0;
  int _commentCount = 0;
  int _listCount = 0;
  
  List<Genre> _allGenres = [];

  @override
  void initState() {
    super.initState();
    _loadGenres();
    _checkLoginStatus();
  }
  
  void _loadGenres() async {
    final genres = await _tmdbService.getGenres();
    if (mounted) setState(() => _allGenres = genres);
  }

  void _checkLoginStatus() async {
    final user = await _storageService.getCurrentUser();
    if (user != null) {
      setState(() => _currentUser = user);
      _loadData();
    }
  }

  void _loadData() async {
    if (_currentUser == null) return;

    final timestamps = await _storageService.getAllTimestamps();
    final watched = await _storageService.getMoviesByStatus(WatchStatus.watched);
    final want = await _storageService.getMoviesByStatus(WatchStatus.wantToWatch);
    final watching = await _storageService.getMoviesByStatus(WatchStatus.watching);
    final favorites = await _storageService.getFavorites();
    final commented = await _storageService.getCommentedMovies();
    final lists = await _storageService.getCustomListNames();

    Map<DateTime, int> heatMap = {};
    timestamps.forEach((key, value) {
      final date = DateTime.fromMillisecondsSinceEpoch(value);
      final normalizedDate = DateTime(date.year, date.month, date.day);
      heatMap[normalizedDate] = (heatMap[normalizedDate] ?? 0) + 1;
    });

    if (mounted) {
      setState(() {
        _heatmapData = heatMap;
        _watchedCount = watched.length;
        _wantCount = want.length;
        _watchingCount = watching.length;
        _favoriteCount = favorites.length;
        _commentCount = commented.length;
        _listCount = lists.length;
      });
    }
  }

  void _showAuthDialog({bool isRegister = false}) {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isRegister ? '注册账户' : '登录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: usernameController, decoration: const InputDecoration(labelText: '用户名', prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 16),
            TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: '密码', prefixIcon: Icon(Icons.lock))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showAuthDialog(isRegister: !isRegister);
            },
            child: Text(isRegister ? '已有账号？去登录' : '没有账号？去注册', style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final username = usernameController.text;
                final password = passwordController.text;
                if (username.isEmpty || password.isEmpty) return;

                if (isRegister) {
                  await _storageService.register(username, password);
                } else {
                  await _storageService.login(username, password);
                }
                
                if (context.mounted) Navigator.pop(context);
                _checkLoginStatus(); 
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: Text(isRegister ? '注册' : '登录'),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    await _storageService.logout();
    setState(() => _currentUser = null);
  }
  
  // 修改头像逻辑：支持默认头像和上传
  void _changeAvatar() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: 350,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('更换头像', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle), child: const Icon(Icons.photo_library, color: Colors.white)),
              title: const Text('从相册选择'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                if (image != null && _currentUser != null) {
                  final updatedUser = _currentUser!.copyWith(avatar: image.path);
                  await _storageService.updateUser(updatedUser);
                  setState(() => _currentUser = updatedUser);
                }
              },
            ),
            const Divider(),
            const Text('选择默认头像', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10),
                itemCount: 8,
                itemBuilder: (context, index) {
                  final url = 'https://i.pravatar.cc/150?img=${index * 5 + 10}';
                  return GestureDetector(
                    onTap: () async {
                      if (_currentUser != null) {
                        final updatedUser = _currentUser!.copyWith(avatar: url);
                        await _storageService.updateUser(updatedUser);
                        setState(() => _currentUser = updatedUser);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    child: CircleAvatar(backgroundImage: NetworkImage(url)),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
  
  ImageProvider _getAvatarProvider(String avatarPath) {
    if (avatarPath.startsWith('http')) {
      return NetworkImage(avatarPath);
    } else {
      return FileImage(File(avatarPath));
    }
  }
  
  // 修改偏好类型逻辑
  void _editPreferences() {
    if (_currentUser == null) return;
    
    List<int> selectedGenres = List.from(_currentUser!.preferredGenres);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('选择爱看的类型'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allGenres.map((genre) {
                    final isSelected = selectedGenres.contains(genre.id);
                    return FilterChip(
                      label: Text(genre.name),
                      selected: isSelected,
                      onSelected: (bool value) {
                        setStateDialog(() {
                          if (value) {
                            selectedGenres.add(genre.id);
                          } else {
                            selectedGenres.remove(genre.id);
                          }
                        });
                      },
                      checkmarkColor: Colors.white,
                      selectedColor: Colors.black,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                      backgroundColor: Colors.grey[200],
                    );
                  }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                onPressed: () async {
                  final updatedUser = _currentUser!.copyWith(preferredGenres: selectedGenres);
                  await _storageService.updateUser(updatedUser);
                  setState(() => _currentUser = updatedUser);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('保存'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: _currentUser != null ? _buildLoggedInView() : _buildLoginView(),
    );
  }

  Widget _buildLoginView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)]),
              child: const Icon(Icons.movie_filter_rounded, size: 60, color: Colors.black),
            ),
            const SizedBox(height: 24),
            const Text('MovieMind', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -1)),
            const SizedBox(height: 8),
            const Text('记录光影，分享感动', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 60),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => _showAuthDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('登录 / 注册', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoggedInView() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 160.0, // 增加高度
          pinned: false,
          backgroundColor: const Color(0xFFF5F5F7),
          flexibleSpace: FlexibleSpaceBar(
            background: Padding(
              padding: const EdgeInsets.fromLTRB(24, 50, 24, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _changeAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(radius: 36, backgroundImage: _getAvatarProvider(_currentUser!.avatar)),
                        Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle), child: const Icon(Icons.edit, size: 12, color: Colors.white))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_currentUser!.username, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _editPreferences,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.favorite, size: 14, color: Colors.redAccent),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _currentUser!.preferredGenres.isEmpty 
                                      ? '点击设置喜好' 
                                      : _allGenres.where((g) => _currentUser!.preferredGenres.contains(g.id)).map((g) => g.name).join(' / '),
                                    style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey),
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
                ],
              ),
            ),
          ),
        ),
        
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 观影热度 - 居中优化
                Center(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                                Row(
                                  children: const [
                                    Icon(Icons.whatshot, color: Color.fromARGB(203, 230, 81, 0), size: 17), 
                                    SizedBox(width: 6),
                                    Text('观影热度', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Text('Less', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                    const SizedBox(width: 4),
                                    _buildLegendBox(const Color(0xFFEEEEEE)),
                                    _buildLegendBox(const Color(0xFFFFE0B2)),
                                    _buildLegendBox(const Color(0xFFFFB74D)),
                                    _buildLegendBox(const Color(0xFFFF9800)),
                                    _buildLegendBox(const Color(0xFFE65100)),
                                    const SizedBox(width: 4),
                                    const Text('More', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                  ],
                                ),
                             ]
                          ),
                        ),
                        const SizedBox(height: 8),
                        ContributionHeatmap(data: _heatmapData),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                  children: [
                    _buildModuleCard('正在看', _watchingCount, Icons.play_circle_fill, Colors.blue, () => _navigateTo(WatchStatus.watching)),
                    _buildModuleCard('待看清单', _wantCount, Icons.bookmark, Colors.orange, () => _navigateTo(WatchStatus.wantToWatch)),
                    _buildModuleCard('观影记录', _watchedCount, Icons.check_circle, Colors.green, () => _navigateTo(WatchStatus.watched)),
                    _buildModuleCard('我的收藏', _favoriteCount, Icons.favorite, Colors.red, () => _navigateTo(null, isFavorite: true)), 
                    _buildModuleCard('我的评论', _commentCount, Icons.comment, Colors.purple, () => _navigateTo(null, isComment: true)), 
                    _buildModuleCard('我的片单', _listCount, Icons.format_list_bulleted, Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomListsPage()))), 
                  ],
                ),
                
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildLegendBox(Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }

  Widget _buildModuleCard(String title, int count, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
                Text('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _navigateTo(WatchStatus? status, {bool isFavorite = false, bool isComment = false}) async {
    await Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => MyMoviesPage(
        status: status ?? WatchStatus.none, 
        isFavorite: isFavorite,
        isComment: isComment,
      ))
    );
    _loadData(); 
  }
}
