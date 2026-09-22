import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dialogs/image_edit_dialogs.dart';
import 'create_learning_pack_dialog.dart';

// --- 貼文發佈頁面 ---
class CreatePostPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final VoidCallback onPosted;
  final int? groupId; // null = 廣場貼文, 非 null = 群組貼文
  final Map<String, dynamic>? draftData; // AI 代理人預填草稿
  const CreatePostPage(
      {super.key,
      required this.currentUser,
      required this.onPosted,
      this.groupId,
      this.draftData});
  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();
  XFile? _selectedImageX;
  double _imgAlignX = 0.0;
  double _imgAlignY = 0.0;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  String? _postType;
  bool _isSubmitting = false;
  DateTime? _scheduledAt; // 定時發佈時間
  Map<String, dynamic>? _learningPackData; // 學習 Pack 的資料

  Uint8List? _userAvatarBlob;
  int? _userAvatarColor;
  int _userAvatarSelected = 0;
  bool _isLoadingUserAvatar = true;

  // 熱門標籤清單
  static const List<String> _popularTags = [
    '學習打卡',
    '會考衝刺',
    '解題求助',
    '筆記分享',
    '讀書心得',
    '每日一句',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserAvatar();
    _applyDraftData();
  }

  /// 若從 AI 代理人攜帶草稿資料進入，自動預填
  void _applyDraftData() {
    final draft = widget.draftData;
    if (draft == null) return;
    if (draft['type'] != null) {
      final t = draft['type'].toString();
      if (t == '學習筆記' || t == 'note') {
        _postType = 'note';
      } else if (t == '心情文章' || t == 'mood') {
        _postType = 'mood';
      } else if (t == '分享資料' || t == 'doc') {
        _postType = 'doc';
      } else if (t == '學習 Pack' || t == 'learning_pack') {
        _postType = 'learning_pack';
      } else {
        _postType = null;
      }
    }
    if (draft['content'] != null && (draft['content'] as String).isNotEmpty) {
      _contentController.text = draft['content'] as String;
    }
    if (draft['scheduledAt'] != null) {
      _scheduledAt = DateTime.tryParse(draft['scheduledAt'].toString());
    } else if (draft['time'] != null && draft['time'] != '現在') {
      _scheduledAt = DateTime.tryParse(draft['time'].toString());
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadUserAvatar() async {
    try {
      final userId = widget.currentUser['id'];
      final db = await DatabaseHelper.instance.database;
      final u = await db.query('users', where: 'id = ?', whereArgs: [userId]);
      if (u.isNotEmpty && mounted) {
        setState(() {
          _userAvatarBlob = u.first['avatar_blob'] as Uint8List?;
          _userAvatarColor = u.first['avatar_color'] as int?;
          _userAvatarSelected = (u.first['avatar_selected'] as int?) ?? 0;
          _isLoadingUserAvatar = false;
          widget.currentUser['avatar_blob'] = _userAvatarBlob;
          widget.currentUser['avatar_color'] = _userAvatarColor;
          widget.currentUser['avatar_selected'] = _userAvatarSelected;
        });
      }
    } catch (e) {
      debugPrint('Error loading user avatar in CreatePostPage: $e');
    }
  }

  void _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 3840,
      maxHeight: 3840,
      imageQuality: 100,
    );
    if (image != null && mounted) {
      final Uint8List rawBytes = await image.readAsBytes();
      if (!mounted) return;
      // 啟動畫質掃描與修復底部面板
      final XFile? result = await showModalBottomSheet<XFile>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => ImageQualityEnhanceSheet(
          rawBytes: rawBytes,
          originalXFile: image,
        ),
      );
      if (result != null && mounted) {
        setState(() => _selectedImageX = result);
      }
    }
  }

  void _pickFileWithType({
    FileType type = FileType.custom,
    List<String>? allowedExtensions,
    String? labelHint,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: (type == FileType.custom) ? allowedExtensions : null,
        withData: true,
        dialogTitle: labelHint != null ? '選擇 $labelHint' : '選擇檔案',
      );
      if (result != null && mounted) {
        final file = result.files.single;

        if (type == FileType.custom &&
            allowedExtensions != null &&
            allowedExtensions.isNotEmpty) {
          final ext = file.extension?.toLowerCase();
          final allowedLower =
              allowedExtensions.map((e) => e.toLowerCase()).toList();
          if (ext == null || !allowedLower.contains(ext)) {
            ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
              SnackBar(
                content:
                    Text('格式不符！請選擇 ${allowedExtensions.join(", ")} 格式的檔案'),
                duration: const Duration(milliseconds: 1500),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
        }

        setState(() {
          _selectedFileName = file.name;
          _selectedFileBytes = file.bytes;
        });
        ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
          SnackBar(
            content: Text('已附加${labelHint ?? '檔案'}：${file.name}'),
            duration: const Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
          const SnackBar(
            content: Text('選取檔案失敗，請再試一次'),
            duration: Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 選擇排程時間
  Future<void> _pickScheduleTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now,
      firstDate: now,
      lastDate: DateTime(2030),
      locale: const Locale('zh', 'TW'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _scheduledAt != null
          ? TimeOfDay(hour: _scheduledAt!.hour, minute: _scheduledAt!.minute)
          : TimeOfDay.now(),
      builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
          child: Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: ColorScheme.light(
                primary: Theme.of(ctx).primaryColor,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black87,
              ),
            ),
            child: child!,
          )),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _openLearningPackModal() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => CreateLearningPackDialog(
        currentUser: widget.currentUser,
        initialData: _learningPackData,
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _learningPackData = result;
        _postType = 'learning_pack';
      });
      messenger.hideCurrentSnackBar();
      messenger..hideCurrentSnackBar()..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '已打包：${result['pack_title'] ?? '學習 Pack'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 1500),
          backgroundColor: const Color(0xFFE65100),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _insertTag(String tag) {
    final text = _contentController.text;
    final tagText = '#$tag ';
    if (text.contains('#$tag')) return;

    if (text.isEmpty || text.endsWith(' ') || text.endsWith('\n')) {
      _contentController.text = '$text$tagText';
    } else {
      _contentController.text = '$text $tagText';
    }
    _contentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _contentController.text.length),
    );
    setState(() {});
  }

  void _submitPost() async {
    final hasContent = _contentController.text.trim().isNotEmpty;
    final hasImage = _selectedImageX != null;
    final hasFile = _selectedFileName != null;
    final hasPack = _learningPackData != null;

    if (!hasContent && !hasImage && !hasFile && !hasPack) {
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
        const SnackBar(
          content: Text('請輸入貼文內容或附加媒體資料！'),
          duration: Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final db = await DatabaseHelper.instance.database;
      final userId = widget.currentUser['id'];
      Uint8List? blobData;
      if (_selectedImageX != null) {
        blobData = await _selectedImageX!.readAsBytes();
      }

      // 建立 attached_data
      final Map<String, dynamic> attachedMap = {};
      if (_selectedImageX != null) {
        attachedMap['img_align_x'] = _imgAlignX;
        attachedMap['img_align_y'] = _imgAlignY;
      }
      if (_selectedFileName != null) {
        attachedMap['file_name'] = _selectedFileName;
      }
      if (_scheduledAt != null) {
        attachedMap['scheduled_at'] =
            '${_scheduledAt!.year}-${_scheduledAt!.month.toString().padLeft(2, '0')}-${_scheduledAt!.day.toString().padLeft(2, '0')} ${_scheduledAt!.hour.toString().padLeft(2, '0')}:${_scheduledAt!.minute.toString().padLeft(2, '0')}';
      }

      if (_postType == 'learning_pack' && _learningPackData != null) {
        attachedMap.addAll(_learningPackData!);
      }

      final newId = await db.insert('posts', <String, Object?>{
        'user_id': userId,
        'content': _contentController.text,
        'type': _postType ?? (blobData != null ? 'image' : 'text'),
        'media_blob': blobData,
        'file_blob': _selectedFileBytes,
        'attached_data': jsonEncode(attachedMap),
        'created_at': DateTime.now().toIso8601String(),
        if (widget.groupId != null) 'group_id': widget.groupId,
      });

      if ((widget.currentUser['username'] ?? '') == '訪客') {
        (widget.currentUser['session_post_ids'] as Set<int>?)?.add(newId);
      }

      widget.onPosted();
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _scheduledAt != null ? '⏰ 已設定排程，將於指定時間發佈！' : '🎉 貼文發佈成功！',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          duration: const Duration(milliseconds: 1500),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      debugPrint("Error submitting post: $e");
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
          SnackBar(
            content: Text('發佈失敗: $e'),
            duration: const Duration(milliseconds: 2000),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final String displayName = widget.currentUser['display_name'] ??
        widget.currentUser['username'] ??
        '我';

    final String hintText = _postType == 'note'
        ? '記錄今天的學習筆記、考試重點或讀書摘要...'
        : _postType == 'mood'
            ? '分享今天的心情、讀書體會或給同學一句打氣的話...'
            : _postType == 'doc'
                ? '介紹你分享的這份學習資料，重點是什麼呢？'
                : _postType == 'learning_pack'
                    ? '為你的學習 Pack 寫點介紹，讓大家了解這份排程與試卷的特色！'
                    : '有什麼想和大家分享的嗎？可以加上 #標籤 讓更多人看到！';

    final bool canSubmit = _contentController.text.trim().isNotEmpty ||
        _selectedImageX != null ||
        _selectedFileName != null ||
        _learningPackData != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消',
              maxLines: 1,
              style: TextStyle(
                  color: Colors.black54,
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
        ),
        leadingWidth: 70,
        title: Text(
          widget.groupId != null ? '發表群組貼文' : '發表新貼文',
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B)),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: ElevatedButton.icon(
                onPressed: (_isSubmitting || !canSubmit) ? null : _submitPost,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Icon(
                        _scheduledAt != null
                            ? Icons.alarm_rounded
                            : Icons.send_rounded,
                        size: 16),
                label: Text(
                  _scheduledAt != null ? '排程發佈' : '發佈',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  disabledBackgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.grey.shade500,
                  elevation: canSubmit ? 1 : 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // ── 主要編輯區 ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── AI 草稿來源提示 ──
                  if (widget.draftData != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withValues(alpha: 0.08),
                            const Color(0xFFFFF8E1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: primaryColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              size: 16, color: primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '由 AI 特助預填草稿，您可自由修改後發佈',
                              style: TextStyle(
                                fontSize: 12,
                                color: primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // 用戶資訊列與發布標的
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        buildAvatar(
                          blob: _isLoadingUserAvatar
                              ? (widget.currentUser['avatar_blob'] as Uint8List?)
                              : _userAvatarBlob,
                          colorIdx: (_isLoadingUserAvatar
                                  ? (widget.currentUser['avatar_color'] as int?)
                                  : _userAvatarColor) ??
                              getAvatarColorIdx(displayName),
                          initial: displayName.isNotEmpty
                              ? displayName.substring(0, 1)
                              : '我',
                          radius: 20,
                          usePreset: ((_isLoadingUserAvatar
                                      ? (widget.currentUser['avatar_selected']
                                              as int? ??
                                          0)
                                      : _userAvatarSelected) ==
                                  1) &&
                              (_isLoadingUserAvatar
                                      ? widget.currentUser['avatar_blob']
                                      : _userAvatarBlob) ==
                                  null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: Color(0xFF1E293B))),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: widget.groupId != null
                                          ? const Color(0xFFEEF2FF)
                                          : const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: widget.groupId != null
                                            ? const Color(0xFFC7D2FE)
                                            : const Color(0xFFBBF7D0),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          widget.groupId != null
                                              ? Icons.group_outlined
                                              : Icons.public_rounded,
                                          size: 11,
                                          color: widget.groupId != null
                                              ? const Color(0xFF4338CA)
                                              : const Color(0xFF15803D),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          widget.groupId != null
                                              ? '群組專屬貼文'
                                              : '探索廣場公開',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: widget.groupId != null
                                                ? const Color(0xFF4338CA)
                                                : const Color(0xFF15803D),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_scheduledAt != null) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7ED),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: const Color(0xFFFFEDD5),
                                            width: 0.8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.alarm_rounded,
                                              size: 11,
                                              color: Color(0xFFC2410C)),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${_scheduledAt!.month}/${_scheduledAt!.day} ${DateFormat('HH:mm').format(_scheduledAt!)}',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFC2410C),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── 分類標籤區 (清晰簡潔的分類選擇器) ──
                  const Text(
                    '選擇貼文類別',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.2),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildTypeSegmentChip(
                          icon: Icons.edit_note_rounded,
                          label: '學習筆記',
                          type: 'note',
                          activeColor: const Color(0xFF10B981),
                          activeBgColor: const Color(0xFFECFDF5),
                        ),
                        const SizedBox(width: 8),
                        _buildTypeSegmentChip(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: '心情交流',
                          type: 'mood',
                          activeColor: const Color(0xFF8B5CF6),
                          activeBgColor: const Color(0xFFF5F3FF),
                        ),
                        const SizedBox(width: 8),
                        _buildTypeSegmentChip(
                          icon: Icons.folder_open_rounded,
                          label: '學習資料',
                          type: 'doc',
                          activeColor: const Color(0xFF3B82F6),
                          activeBgColor: const Color(0xFFEFF6FF),
                        ),
                        const SizedBox(width: 8),
                        _buildTypeSegmentChip(
                          icon: Icons.inventory_2_rounded,
                          label: '學習 Pack',
                          type: 'learning_pack',
                          activeColor: const Color(0xFFF59E0B),
                          activeBgColor: const Color(0xFFFFFBEB),
                          onTapExtra: () {
                            if (_learningPackData == null) {
                              _openLearningPackModal();
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  // ── 學習 Pack 特殊卡片 ──
                  if (_postType == 'learning_pack') ...[
                    const SizedBox(height: 12),
                    _buildLearningPackCard(),
                  ],

                  const SizedBox(height: 14),

                  // ── 貼文文字輸入區 ──
                  Container(
                    constraints: const BoxConstraints(minHeight: 140),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: _contentController,
                      focusNode: _contentFocusNode,
                      minLines: 5,
                      maxLines: null,
                      autofocus: false,
                      style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        hintText: hintText,
                        hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 15,
                            height: 1.5),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── 快速熱門話題標籤 ──
                  Row(
                    children: [
                      const Icon(Icons.tag_rounded,
                          size: 15, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      const Text(
                        '熱門標籤：',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8)),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: _popularTags.map((tag) {
                              final isUsed =
                                  _contentController.text.contains('#$tag');
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  onTap: () => _insertTag(tag),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isUsed
                                          ? primaryColor.withValues(alpha: 0.1)
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isUsed
                                            ? primaryColor.withValues(alpha: 0.4)
                                            : Colors.grey.shade200,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      '#$tag',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: isUsed
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isUsed
                                            ? primaryColor
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── 附加檔案預覽卡片 ──
                  if (_selectedImageX != null) ...[
                    _buildImagePreviewCard(),
                    const SizedBox(height: 12),
                  ],

                  if (_selectedFileName != null) ...[
                    _buildFileAttachmentCard(),
                    const SizedBox(height: 12),
                  ],

                  if (_scheduledAt != null) ...[
                    _buildScheduledBanner(),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),

          // ── 底部直覺工具列 ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
              border: Border(
                  top: BorderSide(color: Colors.grey.shade200, width: 0.8)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // 附加圖片按鈕
                    _buildModernToolBtn(
                      icon: Icons.photo_library_rounded,
                      label: '照片',
                      active: _selectedImageX != null,
                      color: const Color(0xFF10B981),
                      onTap: _isSubmitting ? null : _pickImage,
                    ),
                    const SizedBox(width: 6),

                    // 附加文件按鈕
                    _buildModernToolBtn(
                      icon: Icons.attach_file_rounded,
                      label: '文件',
                      active: _selectedFileName != null,
                      color: const Color(0xFF3B82F6),
                      onTap: _isSubmitting
                          ? null
                          : () => _pickFileWithType(
                              type: FileType.any, labelHint: '檔案'),
                    ),
                    const SizedBox(width: 6),

                    // 學習 Pack 打包按鈕
                    _buildModernToolBtn(
                      icon: Icons.inventory_2_rounded,
                      label: '學習Pack',
                      active: _learningPackData != null,
                      color: const Color(0xFFF59E0B),
                      onTap: _isSubmitting ? null : _openLearningPackModal,
                    ),
                    const SizedBox(width: 6),

                    // 定時排程按鈕
                    _buildModernToolBtn(
                      icon: Icons.alarm_rounded,
                      label: _scheduledAt != null ? '已排程' : '定時',
                      active: _scheduledAt != null,
                      color: const Color(0xFFEA580C),
                      onTap: _isSubmitting ? null : _pickScheduleTime,
                    ),

                    const Spacer(),

                    // 清除全部或字數指示
                    if (_contentController.text.isNotEmpty)
                      Text(
                        '${_contentController.text.length} 字',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade400),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 分類標籤 Chip
  Widget _buildTypeSegmentChip({
    required IconData icon,
    required String label,
    required String type,
    required Color activeColor,
    required Color activeBgColor,
    VoidCallback? onTapExtra,
  }) {
    final isSelected = _postType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _postType = isSelected ? null : type;
        });
        if (!isSelected && onTapExtra != null) {
          onTapExtra();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeBgColor : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeColor : Colors.grey.shade600,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : Colors.grey.shade700,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_circle_rounded, size: 14, color: activeColor),
            ],
          ],
        ),
      ),
    );
  }

  /// 學習 Pack 預覽卡片
  Widget _buildLearningPackCard() {
    final bool hasData = _learningPackData != null;

    if (!hasData) {
      return InkWell(
        onTap: _openLearningPackModal,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFDE68A),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: Color(0xFFD97706),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '打包學習 Pack (排程 + 試卷)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '點擊自訂你要分享給同學的學習排程與題庫試卷',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '設定',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 10, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final title = _learningPackData!['pack_title'] as String? ?? '學習 Pack';
    final desc = _learningPackData!['pack_description'] as String? ?? '';
    final events = (_learningPackData!['calendar_events'] as List?)?.length ?? 0;
    final papers = (_learningPackData!['user_papers'] as List?)?.length ?? 0;
    final startDateStr = _learningPackData!['start_date'] as String?;
    final endDateStr = _learningPackData!['end_date'] as String?;

    String dateRange = '';
    if (startDateStr != null && endDateStr != null) {
      final s = DateTime.tryParse(startDateStr);
      final e = DateTime.tryParse(endDateStr);
      if (s != null && e != null) {
        dateRange = '${s.month}/${s.day} ~ ${e.month}/${e.day}';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // 頂部標題列
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            decoration: const BoxDecoration(
              color: Color(0xFFFFFBEB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.inventory_2_rounded,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title.isNotEmpty ? title : '已打包 Learning Pack',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: _openLearningPackModal,
                  icon: const Icon(Icons.edit_rounded,
                      size: 13, color: Color(0xFFD97706)),
                  label: const Text(
                    '編輯',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD97706)),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _learningPackData = null;
                      _postType = null;
                    });
                  },
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // 內容細節
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (desc.isNotEmpty) ...[
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                ],
                // 統計標籤列
                Row(
                  children: [
                    _buildPackStatBadge(
                      icon: Icons.event_note_rounded,
                      label: '$events 個排程',
                      color: const Color(0xFF2563EB),
                      bgColor: const Color(0xFFEFF6FF),
                    ),
                    const SizedBox(width: 8),
                    _buildPackStatBadge(
                      icon: Icons.quiz_rounded,
                      label: '$papers 套試卷',
                      color: const Color(0xFF059669),
                      bgColor: const Color(0xFFECFDF5),
                    ),
                    if (dateRange.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _buildPackStatBadge(
                        icon: Icons.date_range_rounded,
                        label: dateRange,
                        color: const Color(0xFF7C3AED),
                        bgColor: const Color(0xFFF5F3FF),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackStatBadge({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 圖片預覽卡片
  Widget _buildImagePreviewCard() {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(_selectedImageX!.path),
                fit: BoxFit.cover,
                alignment: Alignment(_imgAlignX, _imgAlignY),
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          // 焦點調整按鈕
          Positioned(
            left: 10,
            bottom: 10,
            child: GestureDetector(
              onTap: () async {
                final bytes = await _selectedImageX!.readAsBytes();
                if (!mounted) return;
                final Offset? offset = await showDialog<Offset>(
                  context: context,
                  builder: (_) => ImageFocalPointDialog(
                    rawBytes: bytes,
                    initialAlignX: _imgAlignX,
                    initialAlignY: _imgAlignY,
                  ),
                );
                if (offset != null && mounted) {
                  setState(() {
                    _imgAlignX = offset.dx;
                    _imgAlignY = offset.dy;
                  });
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF7C6AFF).withValues(alpha: 0.8)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.center_focus_strong_rounded,
                        color: Color(0xFF9D8EFF), size: 14),
                    SizedBox(width: 5),
                    Text(
                      '🎯 調整縮圖顯示焦點',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 移除圖片按鈕
          Positioned(
            right: 10,
            top: 10,
            child: GestureDetector(
              onTap: () => setState(() => _selectedImageX = null),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 檔案附加預覽卡片
  Widget _buildFileAttachmentCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.description_rounded,
                size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedFileName!,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E3A8A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  '已附加檔案',
                  style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() {
              _selectedFileName = null;
              _selectedFileBytes = null;
            }),
            icon: const Icon(Icons.close_rounded,
                size: 18, color: Color(0xFF64748B)),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  /// 排程發佈指示橫幅
  Widget _buildScheduledBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFEDD5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.alarm_rounded,
                size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '定時排程發佈',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFC2410C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_scheduledAt!.year}年${_scheduledAt!.month}月${_scheduledAt!.day}日 ${DateFormat('HH:mm').format(_scheduledAt!)}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9A3412),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _pickScheduleTime,
            child: const Text('修改',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC2410C))),
          ),
          IconButton(
            onPressed: () => setState(() => _scheduledAt = null),
            icon: const Icon(Icons.close_rounded,
                size: 18, color: Color(0xFF9A3412)),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  /// 底部工具列按鈕
  Widget _buildModernToolBtn({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool active = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: active
              ? Border.all(color: color.withValues(alpha: 0.3), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: active ? color : const Color(0xFF64748B), size: 18),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? color : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
