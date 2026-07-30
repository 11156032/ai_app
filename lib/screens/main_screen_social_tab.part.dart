part of 'main_screen.dart';

// ignore: library_private_types_in_public_api
extension MainScreenSocialTab on _MainScreenState {
  // --- 社群分頁 ---
  Widget _buildSocialTab() {
    final isDark = _isDarkMode;
    return Column(children: [
      // ── 頂部廣場/群組切換列 ──────────────────────────────────────
      _buildSocialMainTabBar(isDark),
      // ── 內容 ──
      Expanded(
        child: PageView(
          controller: _socialPageController,
          onPageChanged: (index) => _updateState(() => _socialMainTab = index),
          children: [
            _buildPlazaContent(isDark),
            _buildGroupsContent(isDark),
          ],
        ),
      ),
    ]);
  }

  // ── 廣場 / 群組 頂部切換列 ───────────────────────────────────────────
  Widget _buildSocialMainTabBar(bool isDark) {
    final int totalPendingRequests = myGroups.fold(0, (sum, g) {
      final role = g['role'] as String?;
      if (role == 'owner' || role == 'admin') {
        return sum + ((g['pending_count'] as int?) ?? 0);
      }
      return sum;
    });

    final int totalUnreadPosts =
        myGroups.fold(0, (sum, g) => sum + ((g['unread_count'] as int?) ?? 0));

    return Container(
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _updateState(() => _socialMainTab = 0);
                    _socialPageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _socialMainTab == 0
                              ? _currentPrimaryColor
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Text(
                      '🌐 廣場',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _socialMainTab == 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _socialMainTab == 0
                            ? _currentPrimaryColor
                            : (isDark ? Colors.white54 : Colors.black45),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _updateState(() => _socialMainTab = 1);
                    _socialPageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _socialMainTab == 1
                              ? _currentPrimaryColor
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '👥 群組',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _socialMainTab == 1
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _socialMainTab == 1
                                ? _currentPrimaryColor
                                : (isDark ? Colors.white54 : Colors.black45),
                          ),
                        ),
                        if (totalPendingRequests > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade700,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('$totalPendingRequests',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ] else if (totalUnreadPosts > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('$totalUnreadPosts',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static final Map<String, dynamic> _tourDemoNotePost = {
    'id': -999,
    'userId': 'u5',
    'author': 'Aden',
    'authorAvatarColor': 0,
    'authorAvatarSelected': 0,
    'authorBio': 'AI 學習助手',
    'time': '18 天前',
    'content': '我分享了我的學習筆記《測試》，歡迎點擊一鍵匯入！ 📝',
    'postType': 'share',
    'isEdited': 0,
    'isLiked': false,
    'isBookmarked': false,
    'likes': 12,
    'replies': 3,
    'attached_data': {
      'shared_type': 'note',
      'title': '測試',
      'category': '未分類',
      'content':
          '巴威颱風強勢逼近台灣，北部地區首當其衝。台北市、新北市、基隆市及桃園市達成共識，宣布今（10）日停止上班上課。然而，外界有輿論質疑...',
    },
  };

  List<Map<String, dynamic>> _getEffectiveSocialPosts() {
    final bool hasNotePost = socialPosts.any((p) =>
        p['attached_data'] != null &&
        p['attached_data']['shared_type'] == 'note');

    if ((_tourOverlayEntry != null || _isTourActive) && !hasNotePost) {
      return [_tourDemoNotePost, ...socialPosts];
    }
    return socialPosts;
  }

  // ── 廣場原有邏輯（完全不變）──────────────────────────────────────────
  Widget _buildPlazaContent(bool isDark) {
    final effectivePosts = _getEffectiveSocialPosts();
    final typeFilter = kSocialFilterMap[_socialFilter];
    var filtered = typeFilter == null
        ? effectivePosts
        : effectivePosts.where((p) => p['postType'] == typeFilter).toList();

    if (_socialAuthorFilter.isNotEmpty) {
      filtered =
          filtered.where((p) => p['userId'] == _socialAuthorFilter).toList();
    }

    return Stack(children: [
      Column(children: [
        _buildStoriesBar(),
        _buildFilterBar(),
        Expanded(
            child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                children: [
              if (scheduledPosts.isNotEmpty && _socialFilter == '全部') ...[
                _buildScheduledSection()
              ],
              if (filtered.isEmpty)
                Center(
                    child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Text(
                          _socialFilter == '全部'
                              ? '還沒有任何貼文，快來發表第一篇！'
                              : '此分類目前沒有貼文',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 14),
                        )))
              else
                ...filtered
                    .asMap()
                    .entries
                    .map((e) => _buildPostCard(e.value, e.key, true))
            ])),
      ]),
      if (widget.currentUser['id'] != 'u4')
        Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
                heroTag: 'add_post',
                backgroundColor: _currentPrimaryColor,
                onPressed: _showCreatePostScreen,
                child: const Icon(Icons.add, color: Colors.white)))
    ]);
  }

  // ── 群組頁面 ─────────────────────────────────────────────────────────
  Widget _buildGroupsContent(bool isDark) {
    final bool isGuest = widget.currentUser['id'] == 'u4';
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final secondaryBg = isDark ? Colors.white10 : Colors.grey.shade50;
    final borderCol = isDark ? Colors.white10 : Colors.grey.shade100;

    return Column(children: [
      // ── 子 Tab: 我的群組 / 探索群組 ──
      Container(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Row(
          children: [
            _buildGroupSubTabChip(isDark, myGroups.isNotEmpty ? '我的群組 (${myGroups.length})' : '我的群組', 0),
            const SizedBox(width: 8),
            _buildGroupSubTabChip(isDark, '探索群組', 1),
            const Spacer(),
            // 邀請連結加入按鈕
            TextButton.icon(
              onPressed: () => _showJoinByLinkDialog(isDark),
              icon: Icon(Icons.link, size: 16, color: _currentPrimaryColor),
              label: Text('用連結加入',
                  style: TextStyle(
                      fontSize: 12,
                      color: _currentPrimaryColor,
                      fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
            ),
          ],
        ),
      ),
      // ── 內容 ──
      Expanded(
        child: Stack(
          children: [
            _groupSubTab == 0
                ? _buildMyGroupsList(isDark, cardBg, borderCol, isGuest)
                : _buildExploreGroups(isDark, cardBg, secondaryBg, borderCol),
            // 建立群組 FAB
            if (!isGuest)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  heroTag: 'create_group_fab',
                  backgroundColor: _currentPrimaryColor,
                  onPressed: () => _showCreateGroupDialog(),
                  icon: const Icon(Icons.add, color: Colors.white, size: 20),
                  label: const Text('建立群組',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildGroupSubTabChip(bool isDark, String label, int idx) {
    final isSelected = _groupSubTab == idx;
    return GestureDetector(
      onTap: () => _updateState(() => _groupSubTab = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? _currentPrimaryColor
              : (isDark ? Colors.white10 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      ),
    );
  }

  // ── 我的群組列表 ──────────────────────────────────────────────────────
  Widget _buildMyGroupsList(
      bool isDark, Color cardBg, Color borderCol, bool isGuest) {
    if (isGuest) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded,
                size: 48, color: isDark ? Colors.white30 : Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('登入後才能加入或建立群組',
                style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey, fontSize: 15)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showGuestLoginPrompt(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _currentPrimaryColor,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder()),
              child: const Text('去登入'),
            ),
          ],
        ),
      );
    }

    if (myGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📚', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('還沒有加入任何群組',
                style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey, fontSize: 15)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _updateState(() => _groupSubTab = 1),
              child: Text('去探索群組 →',
                  style: TextStyle(color: _currentPrimaryColor)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: myGroups.length,
      itemBuilder: (context, idx) {
        final g = myGroups[idx];
        return _buildGroupCard(g, isDark, cardBg, borderCol, isMember: true);
      },
    );
  }

  // ── 探索群組 ──────────────────────────────────────────────────────────
  Widget _buildExploreGroups(
      bool isDark, Color cardBg, Color secondaryBg, Color borderCol) {
    if (allGroups.isEmpty && _exploreGroupSearchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔭', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('目前還沒有任何群組',
                style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey, fontSize: 15)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _showCreateGroupDialog(),
              child: Text('建立第一個群組 →',
                  style: TextStyle(color: _currentPrimaryColor)),
            ),
          ],
        ),
      );
    }

    final filteredGroups = allGroups.where((g) {
      final query = _exploreGroupSearchQuery.toLowerCase();
      if (query.isEmpty) return true;
      final name = g['name']?.toString().toLowerCase() ?? '';
      final desc = g['description']?.toString().toLowerCase() ?? '';
      final tags = g['tags']?.toString().toLowerCase() ?? '';
      return name.contains(query) || desc.contains(query) || tags.contains(query);
    }).toList();

    return Column(
      children: [
        // 搜尋列
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            onChanged: (val) {
              _updateState(() {
                _exploreGroupSearchQuery = val;
              });
            },
            decoration: InputDecoration(
              hintText: '搜尋群組名稱、描述或標籤...',
              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
              prefixIcon: Icon(Icons.search, color: isDark ? Colors.white54 : Colors.grey),
              filled: true,
              fillColor: secondaryBg,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
        ),
        // 群組列表
        Expanded(
          child: filteredGroups.isEmpty
              ? Center(
                  child: Text('找不到符合的群組',
                      style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey, fontSize: 15)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: filteredGroups.length,
                  itemBuilder: (context, idx) {
                    final g = filteredGroups[idx];
                    final isMember = myGroups.any(
                        (m) => m['id'].toString() == g['id'].toString());
                    return _buildGroupCard(g, isDark, cardBg, borderCol, isMember: isMember);
                  },
                ),
        ),
      ],
    );
  }

  // ── 群組卡片 ─────────────────────────────────────────────────────────
  Widget _buildGroupCard(
      Map<String, dynamic> g, bool isDark, Color cardBg, Color borderCol,
      {required bool isMember}) {
    final iconEmoji = g['icon_emoji'] as String? ?? '📚';
    final name = g['name'] as String? ?? '群組';
    final desc = g['description'] as String? ?? '';
    final isPrivate = g['type'] == 'private';
    final memberCount = g['member_count'] as int? ?? 0;
    final int pendingCount = (g['pending_count'] as int?) ?? 0;
    final int unreadCount = (g['unread_count'] as int?) ?? 0;
    final bool isMuted = (g['is_muted'] as int? ?? 0) == 1;
    final String role = g['role'] as String? ?? '';
    final bool isOwnerOrAdmin = role == 'owner' || role == 'admin';
    List tags = [];
    try {
      tags = jsonDecode((g['tags'] as String?) ?? '[]') as List;
    } catch (_) {}

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupDetailPage(
              group: g,
              currentUser: widget.currentUser,
            ),
          ),
        ).then((_) => _loadData());
      },
      onLongPress: () {
        if (!isMember) return;
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(iconEmoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const Divider(height: 24),
                ListTile(
                  leading: Icon(
                      isMuted
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_rounded,
                      color: _currentPrimaryColor),
                  title: Text(isMuted ? '開啟群組通知 🔔' : '關閉群組通知 (靜音) 🔕'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final newMuted = await DatabaseHelper.instance
                        .toggleGroupMute(g['id'] as int, widget.currentUser['id']);
                    await _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(newMuted ? '🔕 已將群組設定為靜音' : '🔔 已開啟群組通知'),
                          backgroundColor: _currentPrimaryColor,
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Icon(
                      unreadCount > 0
                          ? Icons.mark_chat_read_rounded
                          : Icons.mark_chat_unread_rounded,
                      color: Colors.orange),
                  title: Text(unreadCount > 0 ? '標示為已讀 ✓' : '標示為未讀 🔴'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (unreadCount > 0) {
                      await DatabaseHelper.instance
                          .markGroupAsRead(g['id'] as int, widget.currentUser['id']);
                    } else {
                      await DatabaseHelper.instance.markGroupAsUnread(
                          g['id'] as int, widget.currentUser['id']);
                    }
                    await _loadData();
                  },
                ),
                if (g['owner_id'].toString() == widget.currentUser['id'].toString() || role == 'owner')
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                    title: const Text('刪除群組', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final groupName = name;
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dlgCtx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text('確定要刪除群組？'),
                          content: Text('刪除後「$groupName」內的所有公告與訊息將會被永久清空。'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dlgCtx, false),
                              child: const Text('取消', style: TextStyle(color: Colors.grey)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => Navigator.pop(dlgCtx, true),
                              child: const Text('確定刪除'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await DatabaseHelper.instance.deleteGroup(g['id'] as int);
                        await _loadData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已刪除群組「$groupName」'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderCol),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji 圖示（若有未讀動態，右上角加上紅點；靜音顯示灰色點）
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _currentPrimaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                      child: Text(iconEmoji,
                          style: const TextStyle(fontSize: 26))),
                ),
                if (isMember && unreadCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isMuted ? Colors.grey : Colors.redAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: cardBg, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(name,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (isMuted) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.notifications_off_rounded,
                                  size: 14, color: Colors.grey),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isPrivate
                              ? Colors.orange.withValues(alpha: 0.12)
                              : Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isPrivate ? '🔒 私人' : '🌐 公開',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isPrivate
                                  ? Colors.orange.shade700
                                  : Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                  if (desc.isNotEmpty) ...[  
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                          height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.people_outline,
                          size: 14,
                          color: isDark ? Colors.white38 : Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text('$memberCount 位成員',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white38
                                  : Colors.grey.shade500)),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        ...tags.take(2).map((t) => Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _currentPrimaryColor
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(t.toString(),
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: _currentPrimaryColor)),
                            )),
                      ],
                      const Spacer(),
                      if (isOwnerOrAdmin && pendingCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.4)),
                          ),
                          child: Text('⏳ $pendingCount 待審核',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold)),
                        )
                      else if (isMember && unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isMuted
                                ? Colors.grey.withValues(alpha: 0.15)
                                : Colors.redAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: isMuted
                                    ? Colors.grey.withValues(alpha: 0.4)
                                    : Colors.redAccent.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                              isMuted
                                  ? '🔕 $unreadCount 則新動態'
                                  : '🔴 $unreadCount 則新動態',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isMuted ? Colors.grey : Colors.redAccent,
                                  fontWeight: FontWeight.bold)),
                        )
                      else if (isMember)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _currentPrimaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('✓ 已加入',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: _currentPrimaryColor,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 建立群組 ─────────────────────────────────────────────────────────
  void _showCreateGroupDialog() {
    if (widget.currentUser['id'] == 'u4') {
      _showGuestLoginPrompt();
      return;
    }
    showDialog(
      context: context,
      builder: (_) => CreateGroupDialog(
        currentUser: widget.currentUser,
        onCreated: () {
          _loadData();
          _updateState(() {
            _socialMainTab = 1;
            _groupSubTab = 0;
          });
        },
      ),
    );
  }

  // ── 透過邀請連結加入 ──────────────────────────────────────────────────
  void _showJoinByLinkDialog(bool isDark) {
    if (widget.currentUser['id'] == 'u4') {
      _showGuestLoginPrompt();
      return;
    }
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.link_rounded, color: _currentPrimaryColor),
          SizedBox(width: 8),
          Text('用邀請連結加入', style: TextStyle(fontSize: 17)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '請貼上對方分享的邀請連結',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: 'app://join?token=...',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste, size: 18),
                  onPressed: () async {
                    final data =
                        await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) {
                      ctrl.text = data!.text!;
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _currentPrimaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _joinByLink(ctrl.text.trim());
            },
            child: const Text('加入'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinByLink(String link) async {
    String? token;
    String? type;
    String? ref;
    try {
      final uri = Uri.tryParse(link);
      token = uri?.queryParameters['token'];
      type = uri?.queryParameters['type'];
      ref = uri?.queryParameters['ref'];
    } catch (_) {}

    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無效的邀請連結，請確認後再試')),
        );
      }
      return;
    }

    try {
      final group = await DatabaseHelper.instance.getGroupByToken(token);
      if (group == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('找不到對應的群組，連結可能已失效或過期'),
                backgroundColor: Colors.redAccent),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupDetailPage(
              group: group,
              currentUser: widget.currentUser,
              inviteType: type,
              inviteRefId: ref,
            ),
          ),
        ).then((_) => _loadData());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加入失敗：$e')),
        );
      }
    }
  }

  // ── Stories 活躍成員列 ───────────────────────────────────────────
  Widget _buildStoriesBar() {
    final Map<String, Map<String, dynamic>> authorMap = {};
    for (var p in socialPosts) {
      final uid = p['userId'];
      if (uid != null && !authorMap.containsKey(uid)) {
        authorMap[uid] = {
          'userId': uid,
          'author': p['author'],
          'avatarColor': p['authorAvatarColor'],
          'avatarBlob': p['authorAvatarBlob'],
          'avatarSelected': p['authorAvatarSelected'],
        };
      }
    }
    final stories = authorMap.values.toList();

    if (stories.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 98,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.black26 : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: _isDarkMode ? Colors.white10 : Colors.grey.shade100,
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: stories.length,
        itemBuilder: (context, index) {
          final story = stories[index];
          final String uid = story['userId'];
          final String authorName = story['author'];
          final bool isSelected = (_socialAuthorFilter == uid);

          return GestureDetector(
            key: index == 0 ? _tourFirstPostAvatarKey : null,
            onTap: () {
              // 若是為了引導，點擊時如果不是在篩選，就顯示個資
              if (_tourOverlayEntry != null && index == 0) {
                _showUserProfilePopup(story);
                return;
              }
              _update(() {
                if (_socialAuthorFilter == uid) {
                  _socialAuthorFilter = ''; // 點擊已選中的則清除篩選
                } else {
                  _socialAuthorFilter = uid; // 篩選該成員
                }
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? _currentPrimaryColor
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: buildAvatar(
                      blob: story['avatarBlob'] as Uint8List?,
                      colorIdx: story['avatarColor'] as int,
                      initial: authorName.substring(0, 1),
                      radius: 20,
                      usePreset: story['avatarSelected'] == 1 &&
                          story['avatarBlob'] == null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    authorName,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? _currentPrimaryColor
                          : (_isDarkMode ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 貼文篩選列與成員標籤 ──────────────────────────────────────────
  Widget _buildFilterBar() {
    String authorName = '';
    if (_socialAuthorFilter.isNotEmpty) {
      final postWithAuthor = socialPosts.firstWhere(
        (p) => p['userId'] == _socialAuthorFilter,
        orElse: () => <String, dynamic>{},
      );
      if (postWithAuthor.isNotEmpty) {
        authorName = postWithAuthor['author'];
      } else {
        authorName = '未知用戶';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: kSocialFilterMap.keys.map((label) {
              final isSelected = _socialFilter == label;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _update(() => _socialFilter = label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _currentPrimaryColor
                          : (_isDarkMode
                              ? Colors.white10
                              : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: isSelected
                                ? Colors.white
                                : (_isDarkMode
                                    ? Colors.white70
                                    : Colors.grey.shade700),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (_socialAuthorFilter.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                InputChip(
                  label: Text(
                    '🔍 $authorName 的貼文',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500),
                  ),
                  backgroundColor: _currentPrimaryColor,
                  deleteIconColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 1.5,
                  shadowColor: Colors.black26,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  onDeleted: () {
                    _update(() {
                      _socialAuthorFilter = '';
                    });
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildScheduledSection() {
    return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.orange.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.schedule, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text('待發佈排程',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.orange))
          ]),
          const SizedBox(height: 10),
          ...scheduledPosts.map((sp) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade100)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sp['content'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('排定時間: ${sp['scheduled_at']}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(40, 30)),
                        icon: Icon(Icons.edit,
                            size: 16, color: _currentPrimaryColor),
                        label: Text('編輯',
                            style: TextStyle(
                                fontSize: 12, color: _currentPrimaryColor)),
                        onPressed: () => _showEditScheduledPostDialog(sp),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(40, 30)),
                        icon: const Icon(Icons.delete_outline,
                            size: 16, color: Colors.redAccent),
                        label: const Text('刪除',
                            style: TextStyle(
                                fontSize: 12, color: Colors.redAccent)),
                        onPressed: () => _deleteScheduledPost(sp),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(40, 30)),
                        icon: const Icon(Icons.send,
                            size: 16, color: Colors.orange),
                        label: const Text('立即發佈',
                            style:
                                TextStyle(fontSize: 12, color: Colors.orange)),
                        onPressed: () => _publishNow(sp),
                      ),
                    ],
                  )
                ],
              )))
        ]));
  }

  Future<void> _deleteScheduledPost(Map<String, dynamic> sp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('確認刪除'),
        content: const Text('確定要刪除這篇排程貼文嗎？此操作無法復原。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('刪除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final db = await DatabaseHelper.instance.database;
      final spId = int.tryParse(sp['id'].toString()) ?? sp['id'];
      await db.delete('posts', where: 'id = ?', whereArgs: [spId]);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已刪除排程貼文')));
      }
    }
  }

  Future<void> _publishNow(Map<String, dynamic> sp) async {
    final db = await DatabaseHelper.instance.database;
    final spId = int.tryParse(sp['id'].toString()) ?? sp['id'];
    await db.update('posts',
        {'attached_data': '{}', 'created_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [spId]);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('貼文已發佈！')));
    }
  }

  void _showCreatePostScreen() {
    if (widget.currentUser['id'] == 'u4') {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('訪客無法發佈貼文，請登入完整帳號')));
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CreatePostPage(
                  currentUser: widget.currentUser,
                  onPosted: _loadData,
                )));
  }

  Widget _buildPostItem(Map<String, dynamic> p, [int? index, bool isSocialFeed = false]) {
    if (_socialFeedLayout == 'list') {
      return _buildPostItemNewsList(p, index, isSocialFeed);
    } else {
      return _buildPostItemPremiumCard(p, index, isSocialFeed);
    }
  }

  Widget _buildPostCard(Map<String, dynamic> p, [int? index, bool isSocialFeed = false]) {
    final idx = index ?? 0;
    return FadeInUp(
      key: ValueKey(
          '${p['id']}_${_socialFilter}_${_socialAuthorFilter}_${_socialFeedLayout}_$_themeColorIdx'),
      duration: const Duration(milliseconds: 350),
      delay: Duration(milliseconds: 50 * (idx % 10)),
      child: _buildPostItem(p, idx, isSocialFeed),
    );
  }

  // ── 方案A：規格化卡片呈現 ──────────────────────────────────────────
  Widget _buildPostItemPremiumCard(Map<String, dynamic> p, [int? index, bool isSocialFeed = false]) {
    final bool isDark = _isDarkMode;
    final Color cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color borderCol = isDark ? Colors.white10 : Colors.grey.shade100;
    final Color shadowCol =
        isDark ? Colors.black54 : Colors.black.withValues(alpha: 0.03);
    final bool isGuest = widget.currentUser['id'] == 'u4';

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (isGuest) {
          _showGuestLoginPrompt();
          return;
        }
        if (p['postType'] == 'note') {
          _showNotePreviewDialog(p);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PostReplyPage(originalPost: p, currentUser: widget.currentUser),
            ),
          ).then((_) => _loadData());
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderCol, width: 1),
          boxShadow: [
            BoxShadow(
              color: shadowCol,
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar, Name, Time, Actions
            Row(
              children: [
                GestureDetector(
                  onTap: () => _showUserProfilePopup(p),
                  child: buildAvatar(
                    blob: p['authorAvatarBlob'] as Uint8List?,
                    colorIdx: (p['authorAvatarColor'] as int?) ??
                        getAvatarColorIdx(p['author'] ?? ''),
                    initial: (p['author'] ?? '?').substring(0, 1),
                    radius: 20,
                    usePreset: (p['authorAvatarSelected'] as int? ?? 0) == 1 &&
                        p['authorAvatarBlob'] == null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            p['author'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (kPostTypeLabel.containsKey(p['postType'])) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: _currentPrimaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                kPostTypeLabel[p['postType']]!,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: _currentPrimaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            p['time'],
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white38
                                  : Colors.grey.shade500,
                              fontSize: 11,
                            ),
                          ),
                          if ((p['isEdited'] as int? ?? 0) == 1) ...[
                            const SizedBox(width: 6),
                            Text(
                              '已編輯',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white30
                                    : Colors.grey.shade400,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (p['userId'].toString() ==
                    widget.currentUser['id'].toString())
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    icon: Icon(Icons.more_horiz,
                        color: isDark ? Colors.white38 : Colors.grey),
                    onSelected: (val) {
                      if (val == 'edit') _editPost(p);
                      if (val == 'delete') _deletePost(p);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('編輯貼文')),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Text('刪除貼文',
                              style: TextStyle(color: Colors.red))),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Content text with show more/less
            StatefulBuilder(
              builder: (context, setStateText) {
                final String content = p['content'] ?? '';
                final bool isLongText = content.length > 120 ||
                    '\n'.allMatches(content).length >= 3;
                bool isExpanded = p['_isExpanded'] as bool? ?? false;

                if (isLongText && !isExpanded) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLinkifiedText(
                        '${content.substring(0, content.length > 120 ? 120 : content.length)}...',
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            setStateText(() {
                              p['_isExpanded'] = true;
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '展開全文',
                                style: TextStyle(
                                  color: _currentPrimaryColor,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: _currentPrimaryColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                } else if (isLongText && isExpanded) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLinkifiedText(content),
                      const SizedBox(height: 6),
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            setStateText(() {
                              p['_isExpanded'] = false;
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '收起全文',
                                style: TextStyle(
                                  color: _currentPrimaryColor,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.keyboard_arrow_up_rounded,
                                size: 16,
                                color: _currentPrimaryColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return _buildLinkifiedText(content);
                }
              },
            ),
            // Media attachments
            if (p['media_blob'] != null ||
                (p['media'] != null && p['media'].toString().isNotEmpty))
              _buildPostMediaPremium(p),
            if (p['fileName'] != null && p['fileName'].toString().isNotEmpty)
              _buildFileAttachment(p),
            _buildSharedResourceCard(p, index ?? 0, isSocialFeed),
            const SizedBox(height: 12),
            Divider(color: borderCol, height: 1),
            const SizedBox(height: 4),
            // Actions
            _buildPostActions(p),
          ],
        ),
      ),
    );
  }

  // ── 方案B：新聞式列表呈現 ──────────────────────────────────────────
  Widget _buildPostItemNewsList(Map<String, dynamic> p, [int? index, bool isSocialFeed = false]) {
    final idx = index ?? 0;
    final bool isDark = _isDarkMode;
    final Color borderCol = isDark ? Colors.white10 : Colors.grey.shade100;
    final Color textCol = isDark ? Colors.white70 : Colors.black87;
    final hasMedia = p['media_blob'] != null ||
        (p['media'] != null && p['media'].toString().isNotEmpty);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          bottom: BorderSide(color: borderCol, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content Left
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author row
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showUserProfilePopup(p),
                      child: buildAvatar(
                        blob: p['authorAvatarBlob'] as Uint8List?,
                        colorIdx: (p['authorAvatarColor'] as int?) ??
                            getAvatarColorIdx(p['author'] ?? ''),
                        initial: (p['author'] ?? '?').substring(0, 1),
                        radius: 12,
                        usePreset:
                            (p['authorAvatarSelected'] as int? ?? 0) == 1 &&
                                p['authorAvatarBlob'] == null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      p['author'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      p['time'],
                      style: TextStyle(
                        color: isDark ? Colors.white30 : Colors.grey.shade500,
                        fontSize: 10.5,
                      ),
                    ),
                    if (kPostTypeLabel.containsKey(p['postType'])) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: isDark
                              ? _currentPrimaryColor.withValues(alpha: 0.2)
                              : _currentPrimaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          kPostTypeLabel[p['postType']]!,
                          style: TextStyle(
                            fontSize: 8.5,
                            color: isDark
                                ? Theme.of(context).colorScheme.primary
                                : _currentPrimaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                StatefulBuilder(
                  builder: (context, setStateText) {
                    final attached = p['attached_data'];
                    final String content = p['content'] ?? '';
                    final bool isExpanded = p['_isExpanded'] as bool? ?? false;
                    final bool hasAttachment =
                        attached != null && attached['shared_type'] != null;
                    final bool isLongText = content.length > 80 ||
                        '\n'.allMatches(content).length >= 2 ||
                        hasAttachment;

                    if (!isExpanded) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setStateText(() {
                                p['_isExpanded'] = true;
                              });
                            },
                            child: Text(
                              content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.45,
                                color: textCol,
                              ),
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setStateText(() {
                                p['_isExpanded'] = true;
                              });
                            },
                            child: _buildSharedResourceCardMini(p),
                          ),
                          if (isLongText) ...[
                            const SizedBox(height: 6),
                            Center(
                              child: GestureDetector(
                                onTap: () {
                                  setStateText(() {
                                    p['_isExpanded'] = true;
                                  });
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '展開全文',
                                      style: TextStyle(
                                        color: _currentPrimaryColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 2),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: _currentPrimaryColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              color: textCol,
                            ),
                          ),
                          _buildSharedResourceCard(p, idx, isSocialFeed),
                          const SizedBox(height: 6),
                          Center(
                            child: GestureDetector(
                              onTap: () {
                                setStateText(() {
                                  p['_isExpanded'] = false;
                                });
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '收起內容',
                                    style: TextStyle(
                                      color: _currentPrimaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(
                                    Icons.keyboard_arrow_up_rounded,
                                    size: 16,
                                    color: _currentPrimaryColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                // Actions row
                _buildPostActionsMini(p),
              ],
            ),
          ),
          // Thumbnail Right
          if (hasMedia) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _showImagePreviewDialog(p),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isDark ? Colors.black26 : Colors.grey.shade100,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: (p['media_blob'] != null)
                      ? Image.memory(p['media_blob'] as Uint8List,
                          fit: BoxFit.cover, gaplessPlayback: true)
                      : (p['media'].toString().startsWith('data:image'))
                          ? Image.memory(
                              base64Decode(p['media'].toString().split(',').last),
                              fit: BoxFit.cover,
                              gaplessPlayback: true)
                          : (p['media'].toString().startsWith('http') || kIsWeb)
                              ? Image.network(p['media'] as String,
                                  fit: BoxFit.cover, gaplessPlayback: true)
                              : Image.file(File(p['media'] as String),
                                  fit: BoxFit.cover, gaplessPlayback: true),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 新聞式列表小型動作列 ──────────────────────────────────────────
  Widget _buildPostActionsMini(Map<String, dynamic> p) {
    final bool isGuest = widget.currentUser['id'] == 'u4';
    final bool isDark = _isDarkMode;
    final textStyle = TextStyle(
      fontSize: 11,
      color: isDark ? Colors.white30 : Colors.grey.shade500,
    );

    return Row(
      children: [
        GestureDetector(
          onTap: () => isGuest ? _showGuestLoginPrompt() : _toggleLike(p),
          child: Row(
            children: [
              Icon(
                p['isLiked'] ? Icons.favorite : Icons.favorite_border,
                size: 14,
                color: isGuest
                    ? Colors.grey.shade300
                    : (p['isLiked'] ? Colors.redAccent : Colors.grey),
              ),
              const SizedBox(width: 4),
              Text('${p['likes']}', style: textStyle),
            ],
          ),
        ),
        const SizedBox(width: 16),
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
                            originalPost: p, currentUser: widget.currentUser)))
                .then((_) => _loadData());
          },
          child: Row(
            children: [
              Icon(
                Icons.mode_comment_outlined,
                size: 14,
                color: isGuest ? Colors.grey.shade300 : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text('${p['replies']}', style: textStyle),
            ],
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => isGuest ? _showGuestLoginPrompt() : _toggleBookmark(p),
          child: Icon(
            (p['isBookmarked'] as bool? ?? false)
                ? Icons.bookmark
                : Icons.bookmark_border,
            size: 14,
            color: isGuest
                ? Colors.grey.shade300
                : ((p['isBookmarked'] as bool? ?? false)
                    ? _currentPrimaryColor
                    : Colors.grey),
          ),
        ),
      ],
    );
  }

  void _showImagePreviewDialog(Map<String, dynamic> p) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 可手勢縮放/拖曳的全螢幕圖片
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Center(
                child: (p['media_blob'] != null)
                    ? Image.memory(p['media_blob'] as Uint8List,
                        fit: BoxFit.contain, gaplessPlayback: true)
                    : (p['media'].toString().startsWith('data:image'))
                        ? Image.memory(
                            base64Decode(p['media'].toString().split(',').last),
                            fit: BoxFit.contain,
                            gaplessPlayback: true)
                        : (p['media'].toString().startsWith('http') || kIsWeb)
                            ? Image.network(p['media'] as String,
                                fit: BoxFit.contain, gaplessPlayback: true)
                            : Image.file(File(p['media'] as String),
                                fit: BoxFit.contain, gaplessPlayback: true),
              ),
            ),
            // 頂部關閉按鈕
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ),
            // 底部發文者資訊與提示
            Positioned(
              bottom: MediaQuery.of(ctx).padding.bottom + 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p['author'] != null ? '${p['author']} 的動態圖片（雙指可放大）' : '圖片大圖預覽（雙指可放大）',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostMediaPremium(Map<String, dynamic> p) {
    return GestureDetector(
      onTap: () => _showImagePreviewDialog(p),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _isDarkMode ? Colors.black26 : Colors.grey.shade50,
          border: Border.all(
              color: _isDarkMode ? Colors.white10 : Colors.grey.shade100),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: (p['media_blob'] != null)
              ? Image.memory(p['media_blob'] as Uint8List,
                  fit: BoxFit.cover, gaplessPlayback: true)
              : (p['media'].toString().startsWith('data:image'))
                  ? Image.memory(
                      base64Decode(p['media'].toString().split(',').last),
                      fit: BoxFit.cover,
                      gaplessPlayback: true)
                  : (p['media'].toString().startsWith('http') || kIsWeb)
                      ? Image.network(p['media'] as String,
                          fit: BoxFit.cover, gaplessPlayback: true)
                      : Image.file(File(p['media'] as String),
                          fit: BoxFit.cover, gaplessPlayback: true),
        ),
      ),
    );
  }

  Widget _buildFileAttachment(Map<String, dynamic> p) {
    final fileName = p['fileName'] as String? ?? '未命名文件';
    final isDark = _isDarkMode;
    final primary = _currentPrimaryColor;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Icon(Icons.description, size: 52, color: primary),
                  const SizedBox(height: 12),
                  Text(fileName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      maxLines: 2),
                  const SizedBox(height: 8),
                  Text('文件大小：未知 • 類型：文件',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFileActionBtn(ctx, Icons.visibility_rounded, '線上預覽', () async {
                        Navigator.pop(ctx);
                        try {
                          final dir = await getTemporaryDirectory();
                          // Force .txt extension for preview if it's dummy so OpenFilex knows how to open it
                          final ext = fileName.contains('.') ? '' : '.txt';
                          final file = File('${dir.path}/$fileName$ext');
                          if (p['file_blob'] != null) {
                            await file.writeAsBytes(p['file_blob'] as Uint8List);
                          } else {
                            await file.writeAsString('這是一個示範用的檔案預覽內容：\n\n$fileName\n\n這是社群分享的文件內容...');
                          }
                          final result = await OpenFilex.open(file.path);
                          if (result.type != ResultType.done && mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('預覽失敗: ${result.message}')));
                          }
                        } catch (e) {
                           if (mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('預覽發生錯誤: $e')));
                           }
                        }
                      }),
                      _buildFileActionBtn(ctx, Icons.download_rounded, '下載檔案', () async {
                        Navigator.pop(ctx);
                        try {
                          Directory? dir;
                          if (Platform.isAndroid) {
                            final publicDownload = Directory('/storage/emulated/0/Download');
                            if (await publicDownload.exists()) {
                              dir = publicDownload;
                            }
                          }
                          dir ??= await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();

                          final ext = fileName.contains('.') ? '' : '.txt';
                          final file = File('${dir.path}/$fileName$ext');
                          if (p['file_blob'] != null) {
                            await file.writeAsBytes(p['file_blob'] as Uint8List);
                          } else {
                            await file.writeAsString('這是一個示範用的檔案內容：\n\n檔名：$fileName\n下載時間：${DateTime.now()}\n\n這是社群分享的文件內容...');
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('已下載至手機「Downloads (下載)」目錄'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.green.shade600,
                                duration: const Duration(seconds: 5),
                                action: SnackBarAction(
                                  label: '開啟檔案',
                                  textColor: Colors.white,
                                  onPressed: () => OpenFilex.open(file.path),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('下載失敗: $e')),
                            );
                          }
                        }
                      }),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade100)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.description_rounded, size: 24, color: primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fileName,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.blue.shade200 : Colors.blue.shade900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('點擊預覽或下載',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.grey.shade600)),
              ],
            ),
          ),
          Icon(Icons.download_for_offline_rounded, size: 22, color: primary),
        ]),
      ),
    );
  }

  Widget _buildFileActionBtn(BuildContext ctx, IconData icon, String label, VoidCallback onTap) {
    final primary = Theme.of(ctx).primaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: primary, size: 28),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildPostActions(Map<String, dynamic> p) {
    final bool isGuest = widget.currentUser['id'] == 'u4';
    return Row(children: [
      IconButton(
          icon: Icon(p['isLiked'] ? Icons.favorite : Icons.favorite_border,
              size: 20,
              color: isGuest
                  ? Colors.grey.shade300
                  : (p['isLiked'] ? Colors.redAccent : Colors.grey)),
          onPressed: () => isGuest ? _showGuestLoginPrompt() : _toggleLike(p)),
      Text('${p['likes']}', style: const TextStyle(fontSize: 12)),
      const SizedBox(width: 20),
      IconButton(
          icon: Icon(Icons.mode_comment_outlined,
              size: 20, color: isGuest ? Colors.grey.shade300 : Colors.grey),
          onPressed: () {
            if (isGuest) {
              _showGuestLoginPrompt();
              return;
            }
            Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PostReplyPage(
                            originalPost: p, currentUser: widget.currentUser)))
                .then((_) => _loadData());
          }),
      Text('${p['replies']}', style: const TextStyle(fontSize: 12)),
      const Spacer(),
      IconButton(
          icon: Icon(
              (p['isBookmarked'] as bool? ?? false)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
              size: 20,
              color: isGuest
                  ? Colors.grey.shade300
                  : ((p['isBookmarked'] as bool? ?? false)
                      ? _currentPrimaryColor
                      : Colors.grey)),
          onPressed: () =>
              isGuest ? _showGuestLoginPrompt() : _toggleBookmark(p)),
    ]);
  }

  Future<void> _toggleLike(Map<String, dynamic> p) async {
    // 訪客限制
    if (widget.currentUser['id'] == 'u4') {
      _showGuestLoginPrompt();
      return;
    }
    final db = await DatabaseHelper.instance.database;
    final currentUserId = widget.currentUser['id'];
    int currentLikes = p['likes'] ?? 0;

    if (p['isLiked']) {
      await db.delete('post_likes',
          where: 'post_id = ? AND user_id = ?',
          whereArgs: [p['id'], currentUserId]);
      currentLikes = (currentLikes > 0) ? currentLikes - 1 : 0;
      await db.execute(
          'UPDATE posts SET likes = ? WHERE id = ?', [currentLikes, p['id']]);
    } else {
      await db
          .insert('post_likes', {'post_id': p['id'], 'user_id': currentUserId});
      currentLikes = currentLikes + 1;
      await db.execute(
          'UPDATE posts SET likes = ? WHERE id = ?', [currentLikes, p['id']]);
    }
    _loadData();
  }

  // ── 訪客登入提示 ─────────────────────────────────────────
  void _showGuestLoginPrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _currentPrimaryColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.lock_outline_rounded,
              color: _currentPrimaryColor, size: 32),
        ),
        title: const Text('需要登入才能使用',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: const Text(
          '此功能僅限登入的會員使用。\n請先登入或註冊正式帳號，\n即可發文、留言與互動！',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: Colors.black54, height: 1.6),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('待會兒再看'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 返回登入頁
              widget.onLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _currentPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('去登入'),
          ),
        ],
      ),
    );
  }

  // ── 超連結文字渲染 ──────────────────────────────────────────────
  static final RegExp _urlRegex = RegExp(
    r'(https?://[^\s,，。！？]+)',
    caseSensitive: false,
  );

  Widget _buildLinkifiedText(String text) {
    final matches = _urlRegex.allMatches(text);
    if (matches.isEmpty) {
      return Text(text);
    }
    final spans = <TextSpan>[];
    int lastEnd = 0;
    for (final m in matches) {
      if (m.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, m.start),
          style: const TextStyle(color: Colors.black87),
        ));
      }
      final url = m.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: TextStyle(
          color: _currentPrimaryColor,
          decoration: TextDecoration.underline,
          decorationColor: _currentPrimaryColor,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final uri = Uri.tryParse(url);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
      ));
      lastEnd = m.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(color: Colors.black87),
      ));
    }
    return RichText(
      text: TextSpan(
        style:
            const TextStyle(fontSize: 14.5, height: 1.4, color: Colors.black87),
        children: spans,
      ),
    );
  }

  // ── 點擊頭像顯示個人資料 ─────────────────────────────────────────
  void _showUserProfilePopup(Map<String, dynamic> p) {
    final String author = p['author'] ?? '未知用戶';
    final String bio = (p['authorBio'] as String? ?? '').trim();
    final bool isOwnPost = p['userId'] == widget.currentUser['id'];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildAvatar(
                blob: p['authorAvatarBlob'] as Uint8List?,
                colorIdx: (p['authorAvatarColor'] as int?) ??
                    getAvatarColorIdx(author),
                initial: author.substring(0, 1),
                radius: 36,
                usePreset: (p['authorAvatarSelected'] as int? ?? 0) == 1 &&
                    p['authorAvatarBlob'] == null,
              ),
              const SizedBox(height: 12),
              Text(
                author,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (isOwnPost) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _currentPrimaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '這是你',
                    style: TextStyle(fontSize: 11, color: _currentPrimaryColor),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _currentPrimaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _currentPrimaryColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.person_outline,
                          size: 14, color: _currentPrimaryColor),
                      SizedBox(width: 6),
                      Text('個人簡介',
                          style: TextStyle(
                              fontSize: 11,
                              color: _currentPrimaryColor,
                              fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      bio.isEmpty ? '這個人很懶，什麼都沒寫 😄' : bio,
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            bio.isEmpty ? Colors.grey.shade400 : Colors.black87,
                        fontStyle:
                            bio.isEmpty ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: _currentPrimaryColor.withValues(alpha: 0.1),
                    foregroundColor: _currentPrimaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('關閉',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 資源分享預覽卡片 (Premium) ──────────────────────────────────
  Widget _buildSharedResourceCard(Map<String, dynamic> p, [int? index, bool isSocialFeed = false]) {
    final attached = p['attached_data'];
    if (attached == null || attached['shared_type'] == null) {
      return const SizedBox.shrink();
    }

    final sharedType = attached['shared_type'];
    final bool isDark = _isDarkMode;
    final cardBg = isDark ? const Color(0xFF2C2C2C) : _currentPrimaryColor.withValues(alpha: 0.05);
    final borderCol = isDark ? Colors.white10 : _currentPrimaryColor.withValues(alpha: 0.2);

    if (sharedType == 'note') {
      final String title = attached['title'] ?? '無標題筆記';
      final String category = attached['category'] ?? '未分類';
      final String content = attached['content'] ?? '';
      final bool hasStrokes = attached['strokes'] != null &&
          attached['strokes'].toString() != '[]' &&
          attached['strokes'].toString().isNotEmpty;

      final effectivePosts = _getEffectiveSocialPosts();
      final firstNotePost = effectivePosts.firstWhere(
        (post) =>
            post['attached_data'] != null &&
            post['attached_data']['shared_type'] == 'note',
        orElse: () => <String, dynamic>{},
      );
      final bool isTargetNotePost =
          firstNotePost.isNotEmpty && firstNotePost['id'] == p['id'];

      return GestureDetector(
        onTap: () => _showNotePreviewDialog(p),
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderCol, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sticky_note_2_outlined,
                    color: _currentPrimaryColor, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark
                            ? Theme.of(context).colorScheme.primary
                            : _currentPrimaryColor),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _currentPrimaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                        fontSize: 10,
                        color: _currentPrimaryColor,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              content.isEmpty
                  ? '（空白筆記）'
                  : content.replaceAll('#', '').replaceAll('**', '').trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (hasStrokes)
                  Row(
                    children: [
                      Icon(Icons.palette_outlined,
                          size: 14,
                          color: isDark ? Colors.white60 : Colors.blueGrey),
                      const SizedBox(width: 4),
                      Text('包含手寫塗鴉',
                          style: TextStyle(
                              fontSize: 11,
                              color:
                                  isDark ? Colors.white60 : Colors.blueGrey)),
                    ],
                  ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentPrimaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    elevation: 1,
                  ),
                  icon: const Icon(Icons.download_rounded, size: 15),
                  label: const Text('匯入筆記',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _importSharedNote(p),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  key: isSocialFeed && isTargetNotePost && _tourOverlayEntry != null && _currentIndex == 2 ? _tourDialogSummonKey : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentPrimaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    elevation: 1,
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 15),
                  label: const Text('召喚分身',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _summonAuthorClone(p),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    } else if (sharedType == 'question') {
      final String text = attached['text'] ?? '';
      final List<dynamic> options = attached['options'] is String
          ? jsonDecode(attached['options'] as String) as List<dynamic>
          : (attached['options'] as List<dynamic>? ?? []);
      final String answer = attached['answer'] ?? '0';
      final String explanation = attached['explanation'] ?? '';
      final String subject = attached['subject'] ?? '一般';
      final String difficulty = attached['difficulty'] ?? '中';

      final int correctIdx = int.tryParse(answer) ?? 0;
      final int? userSelected = p['_selectedOptionIndex'] as int?;

      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderCol, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline_rounded,
                    color: _currentPrimaryColor, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '題目挑戰：$subject',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _currentPrimaryColor),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _currentPrimaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '難度: $difficulty',
                    style: TextStyle(
                        fontSize: 10,
                        color: _currentPrimaryColor,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                  color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 12),
            // 選項列表
            Column(
              children: List.generate(options.length, (idx) {
                final isSelected = userSelected == idx;
                final isCorrect = idx == correctIdx;

                Color optBg = isDark ? const Color(0xFF333333) : Colors.white;
                Color border = isDark ? Colors.white10 : Colors.grey.shade200;
                IconData? suffixIcon;

                if (userSelected != null) {
                  if (isCorrect) {
                    optBg = isDark
                        ? Colors.green.shade900.withValues(alpha: 0.5)
                        : Colors.green.shade50;
                    border = Colors.green.shade300;
                    suffixIcon = Icons.check_circle_outline_rounded;
                  } else if (isSelected) {
                    optBg = isDark
                        ? Colors.red.shade900.withValues(alpha: 0.5)
                        : Colors.red.shade50;
                    border = Colors.red.shade300;
                    suffixIcon = Icons.highlight_off_rounded;
                  }
                }

                return GestureDetector(
                  onTap: userSelected != null
                      ? null
                      : () {
                          _update(() {
                            p['_selectedOptionIndex'] = idx;
                          });
                        },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: optBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                isDark ? Colors.white10 : Colors.grey.shade100,
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + idx),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            options[idx].toString(),
                            style: TextStyle(
                                fontSize: 13,
                                color:
                                    isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                        if (suffixIcon != null)
                          Icon(suffixIcon,
                              color: isCorrect ? Colors.green : Colors.red,
                              size: 18),
                      ],
                    ),
                  ),
                );
              }),
            ),
            if (userSelected != null && explanation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: Colors.orange, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '解析：$explanation',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white70
                                : _currentPrimaryColor.withValues(alpha: 0.2)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentPrimaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    elevation: 1,
                  ),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 15),
                  label: const Text('收藏至題庫',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _importSharedQuestion(attached),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ── 資源分享預覽卡片 (Mini) ───────────────────────────────────────
  Widget _buildSharedResourceCardMini(Map<String, dynamic> p) {
    final attached = p['attached_data'];
    if (attached == null || attached['shared_type'] == null) {
      return const SizedBox.shrink();
    }

    final sharedType = attached['shared_type'];
    final bool isDark = _isDarkMode;
    final cardBg = isDark ? Colors.white10 : _currentPrimaryColor.withValues(alpha: 0.05);

    if (sharedType == 'note') {
      final String title = attached['title'] ?? '無標題筆記';
      return GestureDetector(
        onTap: () => _showNotePreviewDialog(p),
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          ),
          child: Row(
            children: [
            Icon(Icons.sticky_note_2_outlined,
                color: _currentPrimaryColor, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '分享筆記: $title',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _currentPrimaryColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _importSharedNote(p),
              child: Text('一鍵匯入',
                  style: TextStyle(
                      fontSize: 11,
                      color: _currentPrimaryColor,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(Icons.auto_awesome,
                  size: 12, color: _currentPrimaryColor),
              label: Text('召喚分身',
                  style: TextStyle(
                      fontSize: 11,
                      color: _currentPrimaryColor,
                      fontWeight: FontWeight.bold)),
              onPressed: () => _summonAuthorClone(p),
            ),
          ],
        ),
      ),
    );
    } else if (sharedType == 'question') {
      final String subject = attached['subject'] ?? '一般';
      final String text = attached['text'] ?? '';
      final snippet = text.length > 15 ? '${text.substring(0, 15)}...' : text;

      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.help_outline_rounded,
                color: _currentPrimaryColor, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '分享題目: [$subject] $snippet',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _currentPrimaryColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _importSharedQuestion(attached),
              child: Text('一鍵收藏',
                  style: TextStyle(
                      fontSize: 11,
                      color: _currentPrimaryColor,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ── 一鍵匯入筆記邏輯 ──────────────────────────────────────────────
  void _importSharedNote(Map<String, dynamic> p) {
    final attached = p['attached_data'];
    if (attached == null) return;
    try {
      final String title = attached['title'] ?? '無標題筆記';
      final String content = attached['content'] ?? '';
      final String category = attached['category'] ?? '學習';
      final String authorName = p['author'] ?? '未知用戶';
      final String authorUserId = p['userId']?.toString() ?? '';
      final int authorAvatarColor = p['authorAvatarColor'] as int? ?? 0;

      final List<Stroke> strokes = [];
      final String? strokesJson = attached['strokes'];
      if (strokesJson != null && strokesJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(strokesJson) as List;
          for (var s in decoded) {
            strokes.add(Stroke.fromJson(s as Map<String, dynamic>));
          }
        } catch (e) {
          debugPrint('解析筆記繪圖失敗: $e');
        }
      }

      final newNote = Note(
        id: 'note_${DateTime.now().millisecondsSinceEpoch}',
        userId: widget.currentUser['id'],
        title: '$title (社群匯入)',
        content: content,
        category:
            NotesDatabase.categories.contains(category) ? category : '未分類',
        strokes: strokes,
        updatedAt: DateTime.now(),
        authorName: authorName,
        authorUserId: authorUserId,
        authorAvatarColor: authorAvatarColor,
      );

      // 匯入至 NotesDatabase 運行時列表中
      NotesDatabase.notes.insert(0, newNote);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 筆記已成功匯入您的筆記本！'),
          backgroundColor: _currentPrimaryColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('匯入失敗: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ── 召喚作者 AI 分身 ──────────────────────────────────────────────
  void _summonAuthorClone(Map<String, dynamic> p) {
    final attached = p['attached_data'];
    if (attached == null) return;

    final String authorName = p['author'] ?? '未知用戶';
    final String authorUserId = p['userId']?.toString() ?? '';
    final int authorAvatarColor = p['authorAvatarColor'] as int? ?? 0;
    final String title = attached['title'] ?? '無標題筆記';
    final String content = attached['content'] ?? '';
    final String strokesJson = attached['strokes']?.toString() ?? '';

    // 計算手寫軌跡數量
    int strokeCount = 0;
    if (strokesJson.isNotEmpty && strokesJson != '[]') {
      try {
        final decoded = jsonDecode(strokesJson);
        if (decoded is List) {
          strokeCount = decoded.length;
        }
      } catch (_) {}
    }

    // 設置分身聊天上下文
    _cloneContext = {
      'author': authorName,
      'userId': authorUserId,
      'avatarColor': authorAvatarColor,
      'title': title,
      'content': content,
      'strokeCount': strokeCount,
    };

    _aiFlowState = 'clone_chat';

    // 初始化對話紀錄，加入歡迎詞與快捷提問標記
    chatLogs = [
      {
        'isAI': true,
        'text':
            '💡 成功召喚 $authorName 的 AI 鏡像分身！\n我現在是這份筆記「$title」的作者。你可以問我關於這篇筆記的任何邏輯、細節或推導過程喔！',
        'isCard': false,
        'author': authorName,
        'avatarColor': authorAvatarColor,
      },
      {
        'isAI': true,
        'text': '',
        'isCard': false,
        'widgetType': 'clone_chat_welcome_chips',
      }
    ];

    // 開啟全域助理面板
    _openChatModal();
  }

  // ── 一鍵收藏題目邏輯 ──────────────────────────────────────────────
  void _importSharedQuestion(Map<String, dynamic> attached) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final String text = attached['text'] ?? '';
      final List<dynamic> options = attached['options'] is String
          ? jsonDecode(attached['options'] as String) as List<dynamic>
          : (attached['options'] as List<dynamic>? ?? []);
      final String answer = attached['answer'] ?? '0';
      final String explanation = attached['explanation'] ?? '';
      final String subject = attached['subject'] ?? '一般';
      final String difficulty = attached['difficulty'] ?? '中';

      await db.insert('questions', {
        'user_id': widget.currentUser['id'],
        'text': text,
        'options': jsonEncode(options),
        'answer': answer,
        'explanation': explanation,
        'subject': subject,
        'difficulty': difficulty,
        'is_public': 0,
        'bookmarked': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 重新載入全域資料
      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 題目已成功收藏至您的題庫！'),
            backgroundColor: _currentPrimaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('收藏失敗: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ── 點擊學習筆記卡片顯示預覽視窗 (Premium Preview) ─────────────────────
  void _showNotePreviewDialog(Map<String, dynamic> p) {
    final attached = p['attached_data'];
    if (attached == null) return;

    final String title = attached['title'] ?? '無標題筆記';
    final String content = attached['content'] ?? '';
    final String category = attached['category'] ?? '未分類';
    final String authorName = p['author'] ?? '未知用戶';
    final String timeStr = p['time'] ?? '';

    // 解析 strokes
    final List<Stroke> strokes = [];
    final String? strokesJson = attached['strokes'];
    if (strokesJson != null && strokesJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(strokesJson) as List;
        for (var s in decoded) {
          strokes.add(Stroke.fromJson(s as Map<String, dynamic>));
        }
      } catch (e) {
        debugPrint('解析筆記繪圖失敗: $e');
      }
    }

    final bool isDark = _isDarkMode;
    final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderCol = isDark ? Colors.white10 : _currentPrimaryColor.withValues(alpha: 0.2);

    showDialog(
      context: context,
      builder: (context) {
        bool showDrawing = false; // 用於切換文字/手寫
        
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final controller = MarkdownTextController()..text = content;
            final textSpan = controller.buildTextSpan(
              context: context,
              style: TextStyle(
                fontSize: 14,
                height: 1.71,
                color: isDark ? const Color(0xFFE0E0E0) : Colors.black87,
              ),
              withComposing: false,
            );

            return Dialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 標題與關閉按鈕
                    Row(
                      children: [
                        Icon(Icons.sticky_note_2_outlined,
                            color: _currentPrimaryColor, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Theme.of(context).colorScheme.primary : _currentPrimaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 作者資訊與分類
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _currentPrimaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 11,
                              color: _currentPrimaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•  由 $authorName 分享於 $timeStr',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // 如果有手寫筆跡，顯示切換頁籤
                    if (strokes.isNotEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setStateDialog(() => showDrawing = false),
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: !showDrawing
                                          ? _currentPrimaryColor
                                          : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '📝 文字內容',
                                  style: TextStyle(
                                    fontWeight: !showDrawing ? FontWeight.bold : FontWeight.normal,
                                    color: !showDrawing
                                        ? _currentPrimaryColor
                                        : (isDark ? Colors.white60 : Colors.black54),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setStateDialog(() => showDrawing = true),
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: showDrawing
                                          ? _currentPrimaryColor
                                          : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '🎨 手寫塗鴉',
                                  style: TextStyle(
                                    fontWeight: showDrawing ? FontWeight.bold : FontWeight.normal,
                                    color: showDrawing
                                        ? _currentPrimaryColor
                                        : (isDark ? Colors.white60 : Colors.black54),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 內容顯示區
                    Container(
                      height: 350,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _currentPrimaryColor.withValues(alpha: 0.05), // 極淡象牙白，貼合紙張質感
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderCol, width: 1.2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: showDrawing
                            ? CustomPaint(
                                painter: StrokePainter(strokes: strokes),
                              )
                            : Stack(
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: PaperBackgroundPainter(),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.fromLTRB(48, 16, 20, 16),
                                      child: SelectableText.rich(textSpan),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 底部按鈕區
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('關閉',
                              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentPrimaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('匯入筆記',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.pop(context);
                            _importSharedNote(p);
                          },
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentPrimaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('召喚分身',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.pop(context);
                            _summonAuthorClone(p);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}