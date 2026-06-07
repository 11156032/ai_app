part of 'main_screen.dart';

// ignore: library_private_types_in_public_api
extension MainScreenActivityTab on _MainScreenState {
  Widget _buildSocialActivityTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              labelColor: const Color(0xFF8D6E63),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF8D6E63),
              indicatorWeight: 3,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history_edu, size: 18),
                      const SizedBox(width: 8),
                      const Text('我的發佈', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bookmarks_outlined, size: 18),
                      const SizedBox(width: 8),
                      const Text('收藏貼文', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildMyPostsList(),
                _buildBookmarkedPostsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyPostsList() {
    final myPosts = socialPosts.where((p) => p['userId'] == widget.currentUser['id']).toList();
    
    if (myPosts.isEmpty) {
      return _buildActivityEmptyState(Icons.post_add, '尚未發佈任何貼文', '快去社群分享你的第一篇心得吧！');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: myPosts.length,
      itemBuilder: (context, index) => _buildPostCard(myPosts[index], index),
    );
  }

  Widget _buildBookmarkedPostsList() {
    // 這裡我們需要從 socialPosts 中過濾出被收藏的
    final bookmarked = socialPosts.where((p) => (p['isBookmarked'] as bool? ?? false)).toList();

    if (bookmarked.isEmpty) {
      return _buildActivityEmptyState(Icons.bookmark_border, '尚無收藏貼文', '看到感興趣的內容時，點擊收藏即可在此查看。');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookmarked.length,
      itemBuilder: (context, index) => _buildPostCard(bookmarked[index], index),
    );
  }

  Widget _buildActivityEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}
