import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../database/database_helper.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dialogs/image_edit_dialogs.dart';
import 'create_learning_pack_dialog.dart';

// --- 貼文發佈頁面 ---
class CreatePostPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final VoidCallback onPosted;
  final int? groupId; // null = 廣場貼文, 非 null = 群組貼文
  const CreatePostPage(
      {super.key,
      required this.currentUser,
      required this.onPosted,
      this.groupId});
  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _contentController = TextEditingController();
  XFile? _selectedImageX;
  double _imgAlignX = 0.0;
  double _imgAlignY = 0.0;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  String? _postType;
  bool _isSubmitting = false;
  DateTime? _scheduledAt; // 定時發佈時間
  Map<String, dynamic>? _learningPackData; // 學習 Pack 的資料
  final ScrollController _typeScrollController = ScrollController();

  Uint8List? _userAvatarBlob;
  int? _userAvatarColor;
  int _userAvatarSelected = 0;
  bool _isLoadingUserAvatar = true;

  @override
  void initState() {
    super.initState();
    _loadUserAvatar();
  }

  @override
  void dispose() {
    _typeScrollController.dispose();
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

        // 手動驗證副檔名 (做為部分系統選擇器忽略 allowedExtensions 的防呆機制)
        if (type == FileType.custom &&
            allowedExtensions != null &&
            allowedExtensions.isNotEmpty) {
          final ext = file.extension?.toLowerCase();
          final allowedLower =
              allowedExtensions.map((e) => e.toLowerCase()).toList();
          if (ext == null || !allowedLower.contains(ext)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('格式不符！請選擇 ${allowedExtensions.join(", ")} 格式的檔案')),
            );
            return;
          }
        }

        setState(() {
          _selectedFileName = file.name;
          _selectedFileBytes = file.bytes;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已附加${labelHint ?? '檔案'}：${file.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('選取檔案失敗，請再試一次')),
        );
      }
    }
  }

  /// 選擇排程時間
  Future<void> _pickScheduleTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(2030),
      locale: const Locale('zh', 'TW'),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
          child: child!),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _submitPost() async {
    if (_contentController.text.isEmpty && _selectedImageX == null) return;
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
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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
          duration: const Duration(seconds: 2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      debugPrint("Error submitting post: $e");
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('發佈失敗: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String displayName = widget.currentUser['display_name'] ??
        widget.currentUser['username'] ??
        '我';
    final String hintText = _postType == 'note'
        ? '寫下你的學習筆記，記錄每一次成長...'
        : _postType == 'mood'
            ? '今天心情怎麼樣呢？說出來和大家分享吧！'
            : _postType == 'learning_pack'
                ? '為你的學習 Pack 寫點介紹，讓大家知道這個 Pack 有多棒！'
                : '有什麼想和大家說的嗎？';

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消',
              maxLines: 1, style: TextStyle(color: Colors.grey, fontSize: 15)),
        ),
        leadingWidth: 80,
        title: const Text('發表新貼文',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _contentController.text.isEmpty
                      ? Colors.grey.shade300
                      : Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(_scheduledAt != null ? '排程' : '發佈',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade100, height: 1),
        ),
      ),
      body: Column(
        children: [
          // ── 主要編輯區 ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 用戶資訊列
                  Row(
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black87)),
                          // 排程提示
                          if (_scheduledAt != null)
                            Text(
                              '⏰ ${_scheduledAt!.year}-${_scheduledAt!.month.toString().padLeft(2, '0')}-${_scheduledAt!.day.toString().padLeft(2, '0')} ${_scheduledAt!.hour.toString().padLeft(2, '0')}:${_scheduledAt!.minute.toString().padLeft(2, '0')} 發布',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w500),
                            )
                          else
                            const Text('公開發布',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // 貼文類型標籤
                  RawScrollbar(
                    controller: _typeScrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    thumbColor:
                        Theme.of(context).primaryColor.withValues(alpha: 0.5),
                    trackColor: Colors.grey.shade200,
                    thickness: 4,
                    radius: const Radius.circular(10),
                    padding: const EdgeInsets.only(top: 8),
                    child: SingleChildScrollView(
                      controller: _typeScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 12), // 為捲軸預留空間
                      child: Row(children: [
                        _buildTypeChip('📝 學習筆記', 'note',
                            selectedColor: const Color(0xFF4CAF50),
                            bgColor: const Color(0xFFE8F5E9)),
                        const SizedBox(width: 8),
                        _buildTypeChip('💭 心情文章', 'mood',
                            selectedColor: const Color(0xFF9C27B0),
                            bgColor: const Color(0xFFF3E5F5)),
                        const SizedBox(width: 8),
                        _buildTypeChip('📄 分享資料', 'doc',
                            selectedColor: const Color(0xFF2196F3),
                            bgColor: const Color(0xFFE3F2FD)),
                        const SizedBox(width: 8),
                        _buildTypeChip('📦 學習 Pack', 'learning_pack',
                            selectedColor: const Color(0xFFFF9800),
                            bgColor: const Color(0xFFFFF3E0)),
                      ]),
                    ),
                  ),
                  if (_postType == 'learning_pack') ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
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
                          });
                          messenger.showSnackBar(
                              const SnackBar(content: Text('已設定學習 Pack！')));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                            color: _learningPackData != null
                                ? Colors.orange.shade50
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: _learningPackData != null
                                    ? Colors.orange
                                    : Colors.grey.shade300)),
                        child: Row(
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                color: _learningPackData != null
                                    ? Colors.orange
                                    : Colors.grey.shade600),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _learningPackData != null
                                        ? ((_learningPackData!['pack_title']
                                                        as String? ??
                                                    '')
                                                .isNotEmpty
                                            ? _learningPackData!['pack_title']
                                            : '已打包 Learning Pack')
                                        : '點擊設定你要打包的排程與試卷',
                                    style: TextStyle(
                                      color: _learningPackData != null
                                          ? Colors.orange.shade900
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (_learningPackData != null) ...[
                                    if ((_learningPackData!['pack_description']
                                                as String? ??
                                            '')
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        _learningPackData!['pack_description'],
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange.shade800),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      '包含: ${_learningPackData!['calendar_events']?.length ?? 0} 個排程, ${_learningPackData!['user_papers']?.length ?? 0} 套試卷 (點擊可重新編輯)',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange.shade700),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: Colors.grey.shade400)
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // 文字輸入區
                  TextField(
                    controller: _contentController,
                    minLines: 6,
                    maxLines: null,
                    autofocus: false,
                    scrollPadding: const EdgeInsets.all(20),
                    style: const TextStyle(
                        fontSize: 17, height: 1.55, color: Colors.black87),
                    decoration: InputDecoration(
                        hintText: hintText,
                        hintStyle: TextStyle(
                            color: Colors.grey.shade400, fontSize: 17),
                        border: InputBorder.none),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  // 已選圖片預覽
                  if (_selectedImageX != null) ...[
                    Stack(alignment: Alignment.center, children: [
                      Container(
                        width: double.infinity,
                        height: 220,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image.file(
                                  File(_selectedImageX!.path),
                                  fit: BoxFit.cover,
                                  alignment: Alignment(_imgAlignX, _imgAlignY),
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: GestureDetector(
                          onTap: () async {
                            final bytes = await _selectedImageX!.readAsBytes();
                            if (!context.mounted) return;
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: const Color(0xFF7C6AFF)
                                      .withValues(alpha: 0.6)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.center_focus_strong,
                                    color: Color(0xFF7C6AFF), size: 14),
                                SizedBox(width: 4),
                                Text(
                                  '🎯 點擊微調社群顯示焦點',
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
                      Positioned(
                        right: 8,
                        top: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedImageX = null),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                  ],
                  // 已選檔案顯示
                  if (_selectedFileName != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade100)),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.description_outlined,
                              size: 16, color: Colors.blue),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(_selectedFileName!,
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.blue))),
                        GestureDetector(
                          onTap: () => setState(() => _selectedFileName = null),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.grey),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // 排程顯示（可點擊清除）
                  if (_scheduledAt != null) ...[
                    GestureDetector(
                      onTap: () => setState(() => _scheduledAt = null),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.shade200)),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.schedule,
                                size: 16, color: Colors.orange),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('定時發布',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange)),
                                Text(
                                  '${_scheduledAt!.year}-${_scheduledAt!.month.toString().padLeft(2, '0')}-${_scheduledAt!.day.toString().padLeft(2, '0')} ${_scheduledAt!.hour.toString().padLeft(2, '0')}:${_scheduledAt!.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.deepOrange),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.close,
                              size: 16, color: Colors.orange),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),

          // ── 底部工具列 ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                  top: BorderSide(color: Colors.grey.shade100, width: 1)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    // 附加圖片
                    _buildToolBtn(
                      icon: Icons.image_outlined,
                      label: '圖片',
                      color: Theme.of(context).primaryColor,
                      onTap: _isSubmitting ? null : _pickImage,
                    ),
                    // 附加文件
                    _buildToolBtn(
                      icon: Icons.attach_file,
                      label: '文件',
                      color: Colors.blue,
                      onTap: _isSubmitting
                          ? null
                          : () => _pickFileWithType(
                              type: FileType.any, labelHint: '檔案'),
                    ),

                    // 定時發布
                    _buildToolBtn(
                      icon: Icons.schedule,
                      label: _scheduledAt != null ? '修改時間' : '定時發布',
                      color: Colors.orange,
                      onTap: _isSubmitting ? null : _pickScheduleTime,
                      isActive: _scheduledAt != null,
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

  Widget _buildToolBtn({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isActive ? color : color.withValues(alpha: 0.7),
                size: 22),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: isActive ? color : Colors.grey.shade600,
                    fontWeight:
                        isActive ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(
    String label,
    String type, {
    Color? selectedColor,
    Color bgColor = const Color(0xFFF5F0EE),
  }) {
    selectedColor ??= Theme.of(context).primaryColor;
    final bool isSelected = _postType == type;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      child: GestureDetector(
        onTap: () => setState(() => _postType = isSelected ? null : type),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
              color: isSelected ? selectedColor : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? selectedColor : Colors.grey.shade200,
                width: 1.2,
              )),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }
}
