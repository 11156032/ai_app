import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../../widgets/common_widgets.dart';

class SocialTab extends StatelessWidget {
  final List<Map<String, dynamic>> socialPosts;
  final List<Map<String, dynamic>> scheduledPosts;
  final String socialFilter;
  final Function(String) onFilterChanged;
  final Function(Map<String, dynamic>) onEditPost;
  final Function(Map<String, dynamic>) onDeletePost;
  final Function(Map<String, dynamic>) onEditScheduledPost;
  final String currentUserId;

  const SocialTab({
    super.key,
    required this.socialPosts,
    required this.scheduledPosts,
    required this.socialFilter,
    required this.onFilterChanged,
    required this.onEditPost,
    required this.onDeletePost,
    required this.onEditScheduledPost,
    required this.currentUserId,
  });

  static const Map<String, String?> _filterMap = {
    '全部': null,
    '📝 學習筆記': 'note',
    '💭 心情文章': 'mood',
    '📄 分享資料': 'doc',
  };

  @override
  Widget build(BuildContext context) {
    final typeFilter = _filterMap[socialFilter];
    final filtered = typeFilter == null
        ? socialPosts
        : socialPosts.where((p) => p['postType'] == typeFilter).toList();

    return Stack(children: [
      Column(children: [
        // 分類篩選
        _buildFilterBar(),
        // 貼文列表
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
            children: [
              if (scheduledPosts.isNotEmpty && socialFilter == '全部') 
                _buildScheduledSection(),
              ...filtered.map((p) => _buildPostCard(p, context)),
            ],
          ),
        ),
      ]),
    ]);
  }

  Widget _buildFilterBar() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        children: _filterMap.keys.map((label) {
          final isSelected = socialFilter == label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onFilterChanged(label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF8D6E63) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildScheduledSection() {
     // ... 這裡放入原本的待發佈排程 UI ...
     return const SizedBox(); // 簡略實作，實際應移入原本代碼
  }

  Widget _buildPostCard(Map<String, dynamic> p, BuildContext context) {
     // ... 這裡放入原本的貼文卡片 UI ...
     return const SizedBox(); // 簡略實作
  }
}
