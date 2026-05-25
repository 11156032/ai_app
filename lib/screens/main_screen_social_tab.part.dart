part of 'main_screen.dart';

extension MainScreenSocialTab on _MainScreenState {
  // --- 社群分頁 ---
  Widget _buildSocialTab() {
    final typeFilter = kSocialFilterMap[_socialFilter];
    final filtered = typeFilter == null
        ? socialPosts
        : socialPosts.where((p) => p['postType'] == typeFilter).toList();

    return Stack(children: [
      Column(children: [
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
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
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 13,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade700,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
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
                ...filtered.map((p) => _buildPostItem(p))
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

  Widget _buildPostItem(Map<String, dynamic> p) => Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => _showUserProfilePopup(p),
          child: buildAvatar(
              blob: p['authorAvatarBlob'] as Uint8List?,
              colorIdx: (p['authorAvatarColor'] as int?) ??
                  getAvatarColorIdx(p['author'] ?? ''),
              initial: (p['author'] ?? '?').substring(0, 1),
              radius: 18,
              usePreset: (p['authorAvatarSelected'] as int? ?? 0) == 1 &&
                  p['authorAvatarBlob'] == null),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(p['author'],
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            Text(p['time'],
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            if ((p['isEdited'] as int? ?? 0) == 1) ...[
              const SizedBox(width: 5),
              const Text('已編輯',
                  style: TextStyle(color: Colors.grey, fontSize: 11)),
            ],
            const Spacer(),
            if (p['userId'].toString() == widget.currentUser['id'].toString())
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 18,
                icon: const Icon(Icons.more_horiz, color: Colors.grey),
                onSelected: (val) {
                  if (val == 'edit') _editPost(p);
                  if (val == 'delete') _deletePost(p);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('編輯貼文')),
                  const PopupMenuItem(value: 'delete', child: Text('刪除貼文', style: TextStyle(color: Colors.red))),
                ],
              ),
          ]),
          if (kPostTypeLabel.containsKey(p['postType'])) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F0EE),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(kPostTypeLabel[p['postType']]!,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF8D6E63))),
            ),
          ],
          const SizedBox(height: 5),
          _buildLinkifiedText(p['content'] ?? ''),
          if (p['media_blob'] != null || (p['media'] != null && p['media'].toString().isNotEmpty))
            _buildPostMedia(p),
          if (p['fileName'] != null && p['fileName'].toString().isNotEmpty)
            _buildFileAttachment(p),
          _buildPostActions(p),
        ]))
      ]));

  Widget _buildPostMedia(Map<String, dynamic> p) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      height: 200,
      width: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade100),
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
    return Row(children: [
      IconButton(
          icon: Icon(p['isLiked'] ? Icons.favorite : Icons.favorite_border,
              size: 20, color: p['isLiked'] ? Colors.redAccent : Colors.grey),
          onPressed: () => _toggleLike(p)),
      Text('${p['likes']}', style: const TextStyle(fontSize: 12)),
      const SizedBox(width: 20),
      IconButton(
          icon: const Icon(Icons.mode_comment_outlined,
              size: 20, color: Colors.grey),
          onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PostReplyPage(
                          originalPost: p, currentUser: widget.currentUser)))
              .then((_) => _loadData())),
      Text('${p['replies']}', style: const TextStyle(fontSize: 12)),
      const Spacer(),
      IconButton(
          icon: Icon(
              (p['isBookmarked'] as bool? ?? false)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
              size: 20,
              color: (p['isBookmarked'] as bool? ?? false)
                  ? const Color(0xFF8D6E63)
                  : Colors.grey),
          onPressed: () => _toggleBookmark(p)),
    ]);
  }

  Future<void> _toggleLike(Map<String, dynamic> p) async {
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
}
