part of 'main_screen.dart';

// ignore: library_private_types_in_public_api
extension MainScreenActivityTab on _MainScreenState {
  // ─── 貼文類型顏色對應 ───────────────────────────────────────────
  static const Map<String, Color> _postTypeAccentColor = {
    'note': Color(0xFF8D6E63),   // 棕 - 學習筆記
    'mood': Color(0xFFE91E8C),   // 粉 - 心情文章
    'doc':  Color(0xFF1976D2),   // 藍 - 分享資料
  };

  static const Map<String, Color> _postTypeBadgeBg = {
    'note': Color(0xFFF5EEE8),
    'mood': Color(0xFFFCE4EC),
    'doc':  Color(0xFFE3F2FD),
  };

  static const Map<String, Color> _postTypeBadgeBgDark = {
    'note': Color(0xFF3E2723),
    'mood': Color(0xFF880E4F),
    'doc':  Color(0xFF0D47A1),
  };

  // ─── 篩選 chip 定義（與類型對應）────────────────────────────────
  static const List<Map<String, dynamic>> _activityFilterChips = [
    {'label': '全部',      'type': null},
    {'label': '📝 筆記',   'type': 'note'},
    {'label': '💭 心情',   'type': 'mood'},
    {'label': '📄 分享',   'type': 'doc'},
  ];

  // ─── 主入口 ─────────────────────────────────────────────────────
  Widget _buildSocialActivityTab() {
    final isDark = _isDarkMode;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F7);
    final tabBarBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    return StatefulBuilder(
      builder: (context, localSetState) {
        return Container(
          color: bgColor,
          child: Column(
            children: [
              // ── Pill TabBar ─────────────────────────────────────
              Container(
                color: tabBarBg,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0EDEB),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      _buildPillTab(isDark, '📝 我的發佈', 0),
                      _buildPillTab(isDark, '🔖 收藏貼文', 1),
                    ],
                  ),
                ),
              ),
              // ── 篩選 + 排序列 ────────────────────────────────────
              Container(
                color: tabBarBg,
                padding: const EdgeInsets.fromLTRB(0, 0, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 34,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _activityFilterChips.length,
                          itemBuilder: (context, i) {
                            final chip = _activityFilterChips[i];
                            final isSelected = _activityTypeFilter == (chip['type'] as String? ?? '全部');
                            return GestureDetector(
                              onTap: () {
                                _updateState(() {
                                  _activityTypeFilter = chip['type'] as String? ?? '全部';
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF8D6E63)
                                      : (isDark ? Colors.white10 : Colors.grey.shade100),
                                  borderRadius: BorderRadius.circular(20),
                                  border: isSelected
                                      ? null
                                      : Border.all(
                                          color: isDark ? Colors.white12 : Colors.grey.shade200,
                                          width: 1,
                                        ),
                                ),
                                child: Text(
                                  chip['label'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? Colors.white60 : Colors.grey.shade700),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // 排序按鈕
                    GestureDetector(
                      onTap: () {
                        _updateState(() {
                          _activitySortNewest = !_activitySortNewest;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _activitySortNewest
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              size: 13,
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _activitySortNewest ? '最新' : '最舊',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── 內容 ─────────────────────────────────────────────
              Expanded(
                child: _activityTab == 0
                    ? _buildMyPostsContent(isDark)
                    : _buildBookmarkedContent(isDark),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Pill Tab 按鈕 ───────────────────────────────────────────────
  Widget _buildPillTab(bool isDark, String label, int idx) {
    final isSelected = _activityTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => _updateState(() => _activityTab = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF8D6E63)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF8D6E63).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white54 : Colors.grey.shade600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── 我的發佈 ────────────────────────────────────────────────────
  Widget _buildMyPostsContent(bool isDark) {
    var myPosts = socialPosts
        .where((p) => p['userId'] == widget.currentUser['id'])
        .toList();

    // 類型篩選
    if (_activityTypeFilter != '全部') {
      myPosts = myPosts.where((p) => p['postType'] == _activityTypeFilter).toList();
    }

    // 排序
    myPosts.sort((a, b) {
      final aTime = a['createdAt'] as String? ?? a['time'] as String? ?? '';
      final bTime = b['createdAt'] as String? ?? b['time'] as String? ?? '';
      return _activitySortNewest ? bTime.compareTo(aTime) : aTime.compareTo(bTime);
    });

    if (myPosts.isEmpty) {
      return _buildActivityEmptyState(
        isDark,
        icon: Icons.edit_note_rounded,
        title: _activityTypeFilter != '全部' ? '此分類尚無發佈' : '還沒有任何發佈',
        subtitle: _activityTypeFilter != '全部'
            ? '試試其他分類，或去社群發表新貼文！'
            : '分享你的學習心得，讓同學們一起進步！',
        ctaLabel: '去發佈貼文',
        onCta: () => _changePage(2, '社群'),
      );
    }

    return _buildMixedPostsLayout(myPosts, isDark);
  }

  // ─── 收藏貼文 ────────────────────────────────────────────────────
  Widget _buildBookmarkedContent(bool isDark) {
    var bookmarked = socialPosts
        .where((p) => p['isBookmarked'] as bool? ?? false)
        .toList();

    // 類型篩選
    if (_activityTypeFilter != '全部') {
      bookmarked = bookmarked.where((p) => p['postType'] == _activityTypeFilter).toList();
    }

    // 排序
    bookmarked.sort((a, b) {
      final aTime = a['createdAt'] as String? ?? a['time'] as String? ?? '';
      final bTime = b['createdAt'] as String? ?? b['time'] as String? ?? '';
      return _activitySortNewest ? bTime.compareTo(aTime) : aTime.compareTo(bTime);
    });

    if (bookmarked.isEmpty) {
      return _buildActivityEmptyState(
        isDark,
        icon: Icons.bookmark_border_rounded,
        title: _activityTypeFilter != '全部' ? '此分類尚無收藏' : '尚無收藏貼文',
        subtitle: _activityTypeFilter != '全部'
            ? '試試其他分類，或去社群瀏覽更多內容！'
            : '看到感興趣的內容時，點擊 🔖 即可收藏到這裡。',
        ctaLabel: '去瀏覽社群',
        onCta: () => _changePage(2, '社群'),
      );
    }

    return _buildMixedPostsLayout(bookmarked, isDark);
  }

  // ─── 混合佈局（含圖全寬 / 純文字雙欄）──────────────────────────
  Widget _buildMixedPostsLayout(List<Map<String, dynamic>> posts, bool isDark) {
    // 分離含媒體與純文字
    final mediaPosts = <Map<String, dynamic>>[];
    final textPosts = <Map<String, dynamic>>[];

    for (final p in posts) {
      final hasMedia = p['media_blob'] != null ||
          (p['media'] != null && p['media'].toString().isNotEmpty);
      if (hasMedia) {
        mediaPosts.add(p);
      } else {
        textPosts.add(p);
      }
    }

    // 如果沒有媒體貼文，純雙欄
    // 如果有媒體，先全寬顯示媒體貼文，再雙欄顯示純文字
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      children: [
        // 含媒體 - 全寬
        ...mediaPosts.asMap().entries.map((e) =>
          _buildActivityFullWidthCard(e.value, e.key, isDark)),

        // 純文字 - 雙欄瀑布流
        if (textPosts.isNotEmpty)
          _buildTwoColumnGrid(textPosts, isDark),
      ],
    );
  }

  // ─── 全寬卡片（含媒體）─────────────────────────────────────────
  Widget _buildActivityFullWidthCard(Map<String, dynamic> p, int index, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final postType = p['postType'] as String? ?? '';
    final accentColor = _postTypeAccentColor[postType] ?? const Color(0xFF8D6E63);
    final badgeBg = isDark
        ? (_postTypeBadgeBgDark[postType] ?? const Color(0xFF3E2723))
        : (_postTypeBadgeBg[postType] ?? const Color(0xFFF5EEE8));
    final typeLabel = kPostTypeLabel[postType];
    final author = p['author'] as String? ?? '';
    final content = p['content'] as String? ?? '';
    final time = p['time'] as String? ?? '';
    final int likes = p['likes'] as int? ?? 0;
    final int replies = p['replies'] as int? ?? 0;
    final bool isLiked = p['isLiked'] as bool? ?? false;
    final bool isBookmarked = p['isBookmarked'] as bool? ?? false;

    return GestureDetector(
      onTap: () => _onActivityPostTap(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: accentColor, width: 3.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 媒體圖片
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(14),
              ),
              child: _buildActivityMedia(p, height: 170),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 頭像 + 名稱 + 時間 + 類型 badge
                  Row(
                    children: [
                      buildAvatar(
                        blob: p['authorAvatarBlob'] as Uint8List?,
                        colorIdx: (p['authorAvatarColor'] as int?) ?? getAvatarColorIdx(author),
                        initial: author.isEmpty ? '?' : author.substring(0, 1),
                        radius: 14,
                        usePreset: (p['authorAvatarSelected'] as int? ?? 0) == 1 &&
                            p['authorAvatarBlob'] == null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(author,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                )),
                            Text(time,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                                )),
                          ],
                        ),
                      ),
                      if (typeLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  // 動作列
                  _buildActivityActions(p, isDark, likes, replies, isLiked, isBookmarked),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 雙欄瀑布流（純文字）────────────────────────────────────────
  Widget _buildTwoColumnGrid(List<Map<String, dynamic>> posts, bool isDark) {
    // 奇數項放左欄，偶數項放右欄
    final leftPosts = <Map<String, dynamic>>[];
    final rightPosts = <Map<String, dynamic>>[];
    for (int i = 0; i < posts.length; i++) {
      if (i % 2 == 0) {
        leftPosts.add(posts[i]);
      } else {
        rightPosts.add(posts[i]);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: leftPosts.asMap().entries.map((e) =>
              _buildActivityCompactCard(e.value, e.key * 2, isDark)).toList(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: rightPosts.asMap().entries.map((e) =>
              _buildActivityCompactCard(e.value, e.key * 2 + 1, isDark)).toList(),
          ),
        ),
      ],
    );
  }

  // ─── 緊湊卡片（純文字雙欄用）────────────────────────────────────
  Widget _buildActivityCompactCard(Map<String, dynamic> p, int index, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final postType = p['postType'] as String? ?? '';
    final accentColor = _postTypeAccentColor[postType] ?? const Color(0xFF8D6E63);
    final badgeBg = isDark
        ? (_postTypeBadgeBgDark[postType] ?? const Color(0xFF3E2723))
        : (_postTypeBadgeBg[postType] ?? const Color(0xFFF5EEE8));
    final typeLabel = kPostTypeLabel[postType];
    final author = p['author'] as String? ?? '';
    final content = p['content'] as String? ?? '';
    final time = p['time'] as String? ?? '';
    final int likes = p['likes'] as int? ?? 0;
    final int replies = p['replies'] as int? ?? 0;
    final bool isLiked = p['isLiked'] as bool? ?? false;
    final bool isBookmarked = p['isBookmarked'] as bool? ?? false;

    // 嵌入卡片（筆記/問題等）
    final attached = p['attached_data'];
    final hasAttached = attached != null && attached['shared_type'] != null;

    return GestureDetector(
      onTap: () => _onActivityPostTap(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: accentColor, width: 3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 類型 badge
              if (typeLabel != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
              ],
              // 頭像 + 名稱
              Row(
                children: [
                  buildAvatar(
                    blob: p['authorAvatarBlob'] as Uint8List?,
                    colorIdx: (p['authorAvatarColor'] as int?) ?? getAvatarColorIdx(author),
                    initial: author.isEmpty ? '?' : author.substring(0, 1),
                    radius: 11,
                    usePreset: (p['authorAvatarSelected'] as int? ?? 0) == 1 &&
                        p['authorAvatarBlob'] == null,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      author,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: TextStyle(
                  fontSize: 9.5,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
              // 內文
              if (content.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  content,
                  maxLines: hasAttached ? 2 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
              // 嵌入卡片預覽
              if (hasAttached) ...[
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 13,
                        color: isDark ? Colors.white38 : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          attached['title'] as String? ??
                              attached['shared_type'] as String? ?? '附件',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              // 互動列（迷你）
              Row(
                children: [
                  Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    size: 13,
                    color: isLiked ? Colors.redAccent : (isDark ? Colors.white38 : Colors.grey.shade400),
                  ),
                  const SizedBox(width: 3),
                  Text('$likes',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.grey.shade500,
                      )),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.mode_comment_outlined,
                    size: 13,
                    color: isDark ? Colors.white38 : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 3),
                  Text('$replies',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.grey.shade500,
                      )),
                  const Spacer(),
                  Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    size: 13,
                    color: isBookmarked
                        ? const Color(0xFF8D6E63)
                        : (isDark ? Colors.white38 : Colors.grey.shade400),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 媒體圖片顯示 ───────────────────────────────────────────────
  Widget _buildActivityMedia(Map<String, dynamic> p, {double height = 160}) {
    if (p['media_blob'] != null) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: Image.memory(p['media_blob'] as Uint8List, fit: BoxFit.cover),
      );
    }
    final media = p['media']?.toString() ?? '';
    if (media.startsWith('data:image')) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: Image.memory(
          base64Decode(media.split(',').last),
          fit: BoxFit.cover,
        ),
      );
    }
    if (media.startsWith('http') || kIsWeb) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: Image.network(media, fit: BoxFit.cover),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Image.file(File(media), fit: BoxFit.cover),
    );
  }

  // ─── 動作列（全寬卡片用）────────────────────────────────────────
  Widget _buildActivityActions(
    Map<String, dynamic> p,
    bool isDark,
    int likes,
    int replies,
    bool isLiked,
    bool isBookmarked,
  ) {
    final bool isGuest = widget.currentUser['id'] == 'u4';
    return Row(
      children: [
        GestureDetector(
          onTap: () => isGuest ? _showGuestLoginPrompt() : _toggleLike(p),
          child: Row(
            children: [
              Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: 16,
                color: isGuest
                    ? Colors.grey.shade300
                    : (isLiked ? Colors.redAccent : (isDark ? Colors.white38 : Colors.grey.shade400)),
              ),
              const SizedBox(width: 4),
              Text('$likes',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                  )),
            ],
          ),
        ),
        const SizedBox(width: 14),
        GestureDetector(
          onTap: () {
            if (isGuest) {
              _showGuestLoginPrompt();
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PostReplyPage(
                  originalPost: p,
                  currentUser: widget.currentUser,
                ),
              ),
            ).then((_) => _loadData());
          },
          child: Row(
            children: [
              Icon(
                Icons.mode_comment_outlined,
                size: 16,
                color: isGuest ? Colors.grey.shade300 : (isDark ? Colors.white38 : Colors.grey.shade400),
              ),
              const SizedBox(width: 4),
              Text('$replies',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                  )),
            ],
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => isGuest ? _showGuestLoginPrompt() : _toggleBookmark(p),
          child: Icon(
            isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            size: 18,
            color: isGuest
                ? Colors.grey.shade300
                : (isBookmarked
                    ? const Color(0xFF8D6E63)
                    : (isDark ? Colors.white38 : Colors.grey.shade400)),
          ),
        ),
      ],
    );
  }

  // ─── 點擊貼文動作 ────────────────────────────────────────────────
  void _onActivityPostTap(Map<String, dynamic> p) {
    if (widget.currentUser['id'] == 'u4') {
      _showGuestLoginPrompt();
      return;
    }
    if (p['postType'] == 'note') {
      _showNotePreviewDialog(p);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostReplyPage(
            originalPost: p,
            currentUser: widget.currentUser,
          ),
        ),
      ).then((_) => _loadData());
    }
  }

  // ─── Empty State ─────────────────────────────────────────────────
  Widget _buildActivityEmptyState(
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String ctaLabel,
    required VoidCallback onCta,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFF8D6E63).withValues(alpha: isDark ? 0.15 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 42,
                color: const Color(0xFF8D6E63).withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.55,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCta,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: Text(ctaLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8D6E63),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
