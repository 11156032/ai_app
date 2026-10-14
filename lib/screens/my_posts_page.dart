import 'package:flutter/material.dart';
import 'post_reply_page.dart';

/// 我的貼文專屬頁面
class MyPostsPage extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final Map<String, dynamic> currentUser;
  final void Function(Map<String, dynamic> post)? onNavigateToPost;

  const MyPostsPage({
    super.key,
    required this.posts,
    required this.currentUser,
    this.onNavigateToPost,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = currentUser['id'] ?? currentUser['uid'];
    final myPosts =
        posts.where((p) => p['userId'] == currentUserId).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('我的貼文'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: myPosts.isEmpty
          ? _buildEmptyState()
          : _buildPostsList(context, myPosts),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('尚未發布任何貼文',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
          const SizedBox(height: 8),
          Text('前往社群分享你的學習心得吧！',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildPostsList(
      BuildContext context, List<Map<String, dynamic>> myPosts) {
    const typeIconMap = {
      'note': Icons.sticky_note_2_outlined,
      'mood': Icons.sentiment_satisfied_alt_outlined,
      'share': Icons.share_outlined,
      'text': Icons.chat_bubble_outline,
    };
    const typeNameMap = {
      'note': '筆記',
      'mood': '心情',
      'share': '分享',
      'text': '一般',
    };

    final primaryColor = Theme.of(context).primaryColor;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: myPosts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final post = myPosts[i];
        final postType = post['postType'] as String? ?? 'text';
        final icon = typeIconMap[postType] ?? Icons.chat_bubble_outline;
        final typeName = typeNameMap[postType] ?? '一般';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.pop(ctx);
              if (onNavigateToPost != null) {
                onNavigateToPost!(post);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostReplyPage(
                      originalPost: post,
                      currentUser: currentUser,
                    ),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 12, color: primaryColor),
                            const SizedBox(width: 4),
                            Text(typeName,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: primaryColor,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(post['time'] as String? ?? '',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    post['content'] as String? ?? '',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.favorite_border,
                          size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text('${post['likes'] ?? 0}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                      const SizedBox(width: 16),
                      Icon(Icons.chat_bubble_outline,
                          size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text('${post['replies'] ?? 0}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                      const Spacer(),
                      Text('前往貼文',
                          style: TextStyle(
                              fontSize: 12,
                              color: primaryColor,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 11, color: primaryColor),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
