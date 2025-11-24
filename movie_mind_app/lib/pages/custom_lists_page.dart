import 'dart:math';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'my_movies_page.dart';

class CustomListsPage extends StatefulWidget {
  const CustomListsPage({super.key});

  @override
  State<CustomListsPage> createState() => _CustomListsPageState();
}

class _CustomListsPageState extends State<CustomListsPage> {
  final StorageService _storageService = StorageService();
  List<String> _lists = [];
  Map<String, String> _descriptions = {};
  
  final List<Color> _cardColors = [
    const Color(0xFFE8EAF6), // Light Indigo
    const Color(0xFFE0F2F1), // Light Teal
    const Color(0xFFFFEBEE), // Light Red
    const Color(0xFFEFEBE9), // Light Brown
    const Color(0xFFECEFF1), // Light Blue Grey
    const Color(0xFFF3E5F5), // Light Purple
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final lists = await _storageService.getCustomListNames();
    Map<String, String> descs = {};
    for (var list in lists) {
      final desc = await _storageService.getCustomListDescription(list);
      if (desc != null && desc.isNotEmpty) {
        descs[list] = desc;
      }
    }
    
    if (mounted) {
      setState(() {
        _lists = lists;
        _descriptions = descs;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('我的片单', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF5F5F7),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _lists.isEmpty
          ? const Center(child: Text('暂无片单，去详情页添加吧', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _lists.length,
              itemBuilder: (context, index) {
                final listName = _lists[index];
                final desc = _descriptions[listName] ?? '暂无简介';
                final color = _cardColors[index % _cardColors.length];
                
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MyMoviesPage(customListName: listName)),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.movie_filter, color: Colors.grey[700], size: 24),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                listName,
                                style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                desc,
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Colors.black26, size: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
