part of 'main_screen.dart';

// ignore: library_private_types_in_public_api
extension MainScreenSocialTab on _MainScreenState {
  // --- 社群分頁 ---
  Widget _buildSocialTab() {
    final typeFilter = kSocialFilterMap[_socialFilter];
    var filtered = typeFilter == null
        ? socialPosts
        : socialPosts.where((p) => p['postType'] == typeFilter).toList();

    if (_socialAuthorFilter.isNotEmpty) {
      filtered = filtered.where((p) => p['userId'] == _socialAuthorFilter).toList();
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
                ...filtered.asMap().entries.map((e) => _buildPostCard(e.value, e.key))
            ])),
      ]),
      if (widget.currentUser['id'] != 'u4')
        Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
                heroTag: 'add_post',
                backgroundColor: Theme.of(context).primaryColor,
                onPressed: _showCreatePostScreen,
                child: const Icon(Icons.add, color: Colors.white)))
    ]);
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
      height: 90,
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
            onTap: () {
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
                            ? const Color(0xFFFF9800)
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: buildAvatar(
                      blob: story['avatarBlob'] as Uint8List?,
                      colorIdx: story['avatarColor'] as int,
                      initial: authorName.substring(0, 1),
                      radius: 20,
                      usePreset: story['avatarSelected'] == 1 && story['avatarBlob'] == null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    authorName,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? const Color(0xFFFF9800)
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
          height: 48,
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
                          ? const Color(0xFF8D6E63)
                          : (_isDarkMode ? Colors.white10 : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: isSelected
                                ? Colors.white
                                : (_isDarkMode ? Colors.white70 : Colors.grey.shade700),
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
                    style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  backgroundColor: const Color(0xFFFF9800),
                  deleteIconColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 1.5,
                  shadowColor: Colors.black26,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.schedule, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Text('待發佈排程',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange))
              ]),
              const SizedBox(height: 10),
              ...scheduledPosts
                  .map((sp) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.orange.shade100)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sp['content'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('排定時間: ${sp['scheduled_at']}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                    minimumSize: const Size(40, 30)),
                                icon: const Icon(Icons.edit,
                                    size: 16, color: Color(0xFF8D6E63)),
                                label: const Text('編輯',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF8D6E63))),
                                onPressed: () =>
                                    _showEditScheduledPostDialog(sp),
                              ),
                              const SizedBox(width: 4),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                    minimumSize: const Size(40, 30)),
                                icon: const Icon(Icons.delete_outline,
                                    size: 16, color: Colors.redAccent),
                                label: const Text('刪除',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.redAccent)),
                                onPressed: () => _deleteScheduledPost(sp),
                              ),
                              const SizedBox(width: 4),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                    minimumSize: const Size(40, 30)),
                                icon: const Icon(Icons.send,
                                    size: 16, color: Colors.orange),
                                label: const Text('立即發佈',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange)),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('刪除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final db = await DatabaseHelper.instance.database;
      final spId = int.tryParse(sp['id'].toString()) ?? sp['id'];
      await db.delete('posts', where: 'id = ?', whereArgs: [spId]);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已刪除排程貼文')));
      }
    }
  }

  Future<void> _publishNow(Map<String, dynamic> sp) async {
    final db = await DatabaseHelper.instance.database;
    final spId = int.tryParse(sp['id'].toString()) ?? sp['id'];
    await db.update('posts', {
      'attached_data': '{}',
      'created_at': DateTime.now().toIso8601String()
    }, where: 'id = ?', whereArgs: [spId]);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('貼文已發佈！')));
    }
  }

  void _showCreatePostScreen() {
    if (widget.currentUser['id'] == 'u4') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('訪客無法發佈貼文，請登入完整帳號')));
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

  Widget _buildPostItem(Map<String, dynamic> p) {
    if (_socialFeedLayout == 'list') {
      return _buildPostItemNewsList(p);
    } else {
      return _buildPostItemPremiumCard(p);
    }
  }

  Widget _buildPostCard(Map<String, dynamic> p, [int? index]) {
    final idx = index ?? 0;
    return FadeInUp(
      key: ValueKey('${p['id']}_${_socialFilter}_${_socialAuthorFilter}_$_socialFeedLayout'),
      duration: const Duration(milliseconds: 350),
      delay: Duration(milliseconds: 50 * (idx % 10)),
      child: _buildPostItem(p),
    );
  }

  // ── 方案A：規格化卡片呈現 ──────────────────────────────────────────
  Widget _buildPostItemPremiumCard(Map<String, dynamic> p) {
    final bool isDark = _isDarkMode;
    final Color cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color borderCol = isDark ? Colors.white10 : Colors.grey.shade100;
    final Color shadowCol = isDark ? Colors.black54 : Colors.black.withValues(alpha: 0.03);

    return Container(
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.brown.shade800 : const Color(0xFFF5F0EE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              kPostTypeLabel[p['postType']]!,
                              style: TextStyle(
                                fontSize: 9.5,
                                color: isDark ? const Color(0xFFFFCC80) : const Color(0xFF8D6E63),
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
                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        ),
                        if ((p['isEdited'] as int? ?? 0) == 1) ...[
                          const SizedBox(width: 6),
                          Text(
                            '已編輯',
                            style: TextStyle(
                              color: isDark ? Colors.white30 : Colors.grey.shade400,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (p['userId'].toString() == widget.currentUser['id'].toString())
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  icon: Icon(Icons.more_horiz, color: isDark ? Colors.white38 : Colors.grey),
                  onSelected: (val) {
                    if (val == 'edit') _editPost(p);
                    if (val == 'delete') _deletePost(p);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('編輯貼文')),
                    const PopupMenuItem(value: 'delete', child: Text('刪除貼文', style: TextStyle(color: Colors.red))),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Content text with show more/less
          StatefulBuilder(
            builder: (context, setStateText) {
              final String content = p['content'] ?? '';
              final bool isLongText = content.length > 120 || '\n'.allMatches(content).length >= 3;
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
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '展開全文',
                              style: TextStyle(
                                color: Color(0xFF8D6E63),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: Color(0xFF8D6E63),
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
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '收起全文',
                              style: TextStyle(
                                color: Color(0xFF8D6E63),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(
                              Icons.keyboard_arrow_up_rounded,
                              size: 16,
                              color: Color(0xFF8D6E63),
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
          if (p['media_blob'] != null || (p['media'] != null && p['media'].toString().isNotEmpty))
            _buildPostMediaPremium(p),
          if (p['fileName'] != null && p['fileName'].toString().isNotEmpty)
            _buildFileAttachment(p),
          _buildSharedResourceCard(p),
          const SizedBox(height: 12),
          Divider(color: borderCol, height: 1),
          const SizedBox(height: 4),
          // Actions
          _buildPostActions(p),
        ],
      ),
    );
  }

  // ── 方案B：新聞式列表呈現 ──────────────────────────────────────────
  Widget _buildPostItemNewsList(Map<String, dynamic> p) {
    final bool isDark = _isDarkMode;
    final Color borderCol = isDark ? Colors.white10 : Colors.grey.shade100;
    final Color textCol = isDark ? Colors.white70 : Colors.black87;
    final hasMedia = p['media_blob'] != null || (p['media'] != null && p['media'].toString().isNotEmpty);

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
                        usePreset: (p['authorAvatarSelected'] as int? ?? 0) == 1 &&
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
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.brown.shade800 : const Color(0xFFF5F0EE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          kPostTypeLabel[p['postType']]!,
                          style: TextStyle(
                            fontSize: 8.5,
                            color: isDark ? const Color(0xFFFFCC80) : const Color(0xFF8D6E63),
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
                    final bool hasAttachment = attached != null && attached['shared_type'] != null;
                    final bool isLongText = content.length > 80 || '\n'.allMatches(content).length >= 2 || hasAttachment;

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
                          _buildSharedResourceCardMini(p),
                          if (isLongText) ...[
                            const SizedBox(height: 6),
                            Center(
                              child: GestureDetector(
                                onTap: () {
                                  setStateText(() {
                                    p['_isExpanded'] = true;
                                  });
                                },
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '展開全文',
                                      style: TextStyle(
                                        color: Color(0xFF8D6E63),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 2),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: Color(0xFF8D6E63),
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
                          _buildSharedResourceCard(p),
                          const SizedBox(height: 6),
                          Center(
                            child: GestureDetector(
                              onTap: () {
                                setStateText(() {
                                  p['_isExpanded'] = false;
                                });
                              },
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '收起內容',
                                    style: TextStyle(
                                      color: Color(0xFF8D6E63),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(
                                    Icons.keyboard_arrow_up_rounded,
                                    size: 16,
                                    color: Color(0xFF8D6E63),
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
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isDark ? Colors.black26 : Colors.grey.shade100,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: (p['media_blob'] != null)
                    ? Image.memory(p['media_blob'] as Uint8List, fit: BoxFit.cover)
                    : (p['media'].toString().startsWith('data:image'))
                        ? Image.memory(base64Decode(p['media'].toString().split(',').last), fit: BoxFit.cover)
                        : (p['media'].toString().startsWith('http') || kIsWeb)
                            ? Image.network(p['media'] as String, fit: BoxFit.cover)
                            : Image.file(File(p['media'] as String), fit: BoxFit.cover),
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
                    ? const Color(0xFF8D6E63)
                    : Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildPostMediaPremium(Map<String, dynamic> p) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _isDarkMode ? Colors.black26 : Colors.grey.shade50,
        border: Border.all(color: _isDarkMode ? Colors.white10 : Colors.grey.shade100),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: (p['media_blob'] != null)
            ? Image.memory(p['media_blob'] as Uint8List, fit: BoxFit.cover)
            : (p['media'].toString().startsWith('data:image'))
                ? Image.memory(base64Decode(p['media'].toString().split(',').last), fit: BoxFit.cover)
                : (p['media'].toString().startsWith('http') || kIsWeb)
                    ? Image.network(p['media'] as String, fit: BoxFit.cover)
                    : Image.file(File(p['media'] as String), fit: BoxFit.cover),
      ),
    );
  }



  Widget _buildFileAttachment(Map<String, dynamic> p) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        const Icon(Icons.attach_file, size: 16, color: Colors.blue),
        const SizedBox(width: 8),
        Expanded(child: Text(p['fileName'] as String, style: const TextStyle(fontSize: 12))),
      ]),
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
              size: 20,
              color: isGuest ? Colors.grey.shade300 : Colors.grey),
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
                      ? const Color(0xFF8D6E63)
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
            color: const Color(0xFFFFF3E0),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_outline_rounded,
              color: Color(0xFFFF9800), size: 32),
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
              backgroundColor: const Color(0xFF8D6E63),
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
        style: const TextStyle(
          color: Color(0xFF1565C0),
          decoration: TextDecoration.underline,
          decorationColor: Color(0xFF1565C0),
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
        style: const TextStyle(fontSize: 14.5, height: 1.4, color: Colors.black87),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F0EE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '這是你',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8D6E63)),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF8F6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEEE5DF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.person_outline,
                          size: 14, color: Color(0xFF8D6E63)),
                      SizedBox(width: 6),
                      Text('個人簡介',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8D6E63),
                              fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      bio.isEmpty ? '這個人很懶，什麼都沒寫 😄' : bio,
                      style: TextStyle(
                        fontSize: 14,
                        color: bio.isEmpty
                            ? Colors.grey.shade400
                            : Colors.black87,
                        fontStyle: bio.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
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
                    backgroundColor: const Color(0xFFF5F0EE),
                    foregroundColor: const Color(0xFF8D6E63),
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
  Widget _buildSharedResourceCard(Map<String, dynamic> p) {
    final attached = p['attached_data'];
    if (attached == null || attached['shared_type'] == null) {
      return const SizedBox.shrink();
    }

    final sharedType = attached['shared_type'];
    final bool isDark = _isDarkMode;
    final cardBg = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF9F7F5);
    final borderCol = isDark ? Colors.white10 : const Color(0xFFE5DCD3);

    if (sharedType == 'note') {
      final String title = attached['title'] ?? '無標題筆記';
      final String category = attached['category'] ?? '未分類';
      final String content = attached['content'] ?? '';
      final bool hasStrokes = attached['strokes'] != null && attached['strokes'].toString() != '[]' && attached['strokes'].toString().isNotEmpty;

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
                const Icon(Icons.sticky_note_2_outlined, color: Color(0xFF8D6E63), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? const Color(0xFFFFCC80) : const Color(0xFF5D4037)
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8D6E63).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF8D6E63), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              content.isEmpty ? '（空白筆記）' : content.replaceAll('#', '').replaceAll('**', '').trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white70 : Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (hasStrokes)
                  Row(
                    children: [
                      Icon(Icons.palette_outlined, size: 14, color: isDark ? Colors.white60 : Colors.blueGrey),
                      const SizedBox(width: 4),
                      Text('包含手寫塗鴉', style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.blueGrey)),
                    ],
                  ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8D6E63),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    elevation: 1,
                  ),
                  icon: const Icon(Icons.download_rounded, size: 15),
                  label: const Text('匯入筆記', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _importSharedNote(attached),
                ),
              ],
            ),
          ],
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
                const Icon(Icons.help_outline_rounded, color: Color(0xFF8D6E63), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '題目挑戰：$subject',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF8D6E63)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8D6E63).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '難度: $difficulty',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF8D6E63), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: isDark ? Colors.white : Colors.black87),
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
                    optBg = isDark ? Colors.green.shade900.withValues(alpha: 0.5) : Colors.green.shade50;
                    border = Colors.green.shade300;
                    suffixIcon = Icons.check_circle_outline_rounded;
                  } else if (isSelected) {
                    optBg = isDark ? Colors.red.shade900.withValues(alpha: 0.5) : Colors.red.shade50;
                    border = Colors.red.shade300;
                    suffixIcon = Icons.highlight_off_rounded;
                  }
                }

                return GestureDetector(
                  onTap: userSelected != null ? null : () {
                    _update(() {
                      p['_selectedOptionIndex'] = idx;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            color: isDark ? Colors.white10 : Colors.grey.shade100,
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + idx),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            options[idx].toString(),
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                        if (suffixIcon != null)
                          Icon(suffixIcon, color: isCorrect ? Colors.green : Colors.red, size: 18),
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
                    const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '解析：$explanation',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.brown.shade800),
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
                    backgroundColor: const Color(0xFF8D6E63),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    elevation: 1,
                  ),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 15),
                  label: const Text('收藏至題庫', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
    final cardBg = isDark ? Colors.white10 : const Color(0xFFFAF9F6);

    if (sharedType == 'note') {
      final String title = attached['title'] ?? '無標題筆記';
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.sticky_note_2_outlined, color: Color(0xFF8D6E63), size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '分享筆記: $title',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8D6E63)),
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
              onPressed: () => _importSharedNote(attached),
              child: const Text('一鍵匯入', style: TextStyle(fontSize: 11, color: Color(0xFF8D6E63), fontWeight: FontWeight.bold)),
            ),
          ],
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
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.help_outline_rounded, color: Color(0xFF8D6E63), size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '分享題目: [$subject] $snippet',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8D6E63)),
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
              child: const Text('一鍵收藏', style: TextStyle(fontSize: 11, color: Color(0xFF8D6E63), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ── 一鍵匯入筆記邏輯 ──────────────────────────────────────────────
  void _importSharedNote(Map<String, dynamic> attached) {
    try {
      final String title = attached['title'] ?? '無標題筆記';
      final String content = attached['content'] ?? '';
      final String category = attached['category'] ?? '學習';
      
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
        category: NotesDatabase.categories.contains(category) ? category : '未分類',
        strokes: strokes,
        updatedAt: DateTime.now(),
      );

      // 匯入至 NotesDatabase 運行時列表中
      NotesDatabase.notes.insert(0, newNote);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 筆記已成功匯入您的筆記本！'),
          backgroundColor: Color(0xFF8D6E63),
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
          const SnackBar(
            content: Text('🎉 題目已成功收藏至您的題庫！'),
            backgroundColor: Color(0xFF8D6E63),
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
}
