import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ======================================================================
// AI 代理人對話內嵌互動卡片元件
// ======================================================================

// ─── 【模式一】發文草稿卡片 ─────────────────────────────────────────
/// 在對話串中渲染可視化的「發文草稿預覽 + 操作」卡片
class AIDraftPostCard extends StatefulWidget {
  final Map<String, dynamic> draftData;
  final String cardState; // 'active' | 'completed' | 'cancelled'
  final Function(Map<String, dynamic> data) onQuickPublish;
  final Function(Map<String, dynamic> data) onOpenFullEditor;
  final VoidCallback onCancel;

  const AIDraftPostCard({
    super.key,
    required this.draftData,
    required this.cardState,
    required this.onQuickPublish,
    required this.onOpenFullEditor,
    required this.onCancel,
  });

  @override
  State<AIDraftPostCard> createState() => _AIDraftPostCardState();
}

class _AIDraftPostCardState extends State<AIDraftPostCard> {
  late String _selectedType;
  late TextEditingController _contentController;

  static const _typeOptions = [
    {'label': '一般', 'icon': '💬', 'color': Color(0xFF78909C)},
    {'label': '學習筆記', 'icon': '📝', 'color': Color(0xFF43A047)},
    {'label': '心情文章', 'icon': '💭', 'color': Color(0xFF7E57C2)},
    {'label': '分享資料', 'icon': '📄', 'color': Color(0xFF1E88E5)},
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = (widget.draftData['type'] as String?) ?? '一般';
    _contentController = TextEditingController(
        text: (widget.draftData['content'] as String?) ?? '');
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildPayload() {
    return {
      'type': _selectedType,
      'content': _contentController.text.trim(),
      'time': widget.draftData['scheduledAt'],
    };
  }

  bool get _isActive => widget.cardState == 'active';

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isCompleted = widget.cardState == 'completed';
    final isCancelled = widget.cardState == 'cancelled';
    final overlayOpacity = _isActive ? 1.0 : 0.55;

    return Opacity(
      opacity: overlayOpacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, left: 16, right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 頂部標題列 ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF6D4C41), primaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isCompleted
                          ? Icons.check_circle_rounded
                          : isCancelled
                              ? Icons.cancel_rounded
                              : Icons.edit_note_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCompleted
                              ? '貼文已發佈'
                              : isCancelled
                                  ? '已取消發佈'
                                  : '發文草稿',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          isCompleted
                              ? '貼文已成功發佈至社群'
                              : isCancelled
                                  ? '此草稿已取消'
                                  : '可在下方編輯後一鍵發佈',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── 內容區域 ──
            if (_isActive) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 類型選擇膠囊
                    const Text(
                      '貼文類型',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8D6E63),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _typeOptions.map((t) {
                        final label = t['label'] as String;
                        final icon = t['icon'] as String;
                        final color = t['color'] as Color;
                        final isSelected = _selectedType == label;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedType = label);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withValues(alpha: 0.15)
                                  : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? color : Colors.grey.shade300,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(icon, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 5),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? color
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    // 內容輸入區
                    const Text(
                      '貼文內容',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8D6E63),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE8DDD8)),
                      ),
                      child: TextField(
                        controller: _contentController,
                        maxLines: 4,
                        minLines: 2,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF4E342E),
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText: '輸入你想分享的內容...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── 底部操作按鈕 ──
              const Divider(height: 1, color: Color(0xFFF0E9E6)),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // 取消
                    TextButton(
                      onPressed: widget.onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade500,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close_rounded, size: 15),
                          SizedBox(width: 4),
                          Text('取消', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // 前往完整發佈頁
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(color: primaryColor, width: 1.2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => widget.onOpenFullEditor(_buildPayload()),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_new_rounded, size: 14),
                          SizedBox(width: 5),
                          Text('完整發佈頁',
                              style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 一鍵快速發佈
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D4C41),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (_contentController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('請先輸入貼文內容'),
                              duration: const Duration(milliseconds: 1500),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                          return;
                        }
                        widget.onQuickPublish(_buildPayload());
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.send_rounded, size: 14),
                          SizedBox(width: 5),
                          Text('一鍵發佈', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // 非 active 狀態：只顯示摘要
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F0EE),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFBCAAA4), width: 1),
                        ),
                        child: Text(
                          _selectedType,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5D4037),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isCompleted
                            ? Icons.check_circle
                            : Icons.cancel,
                        size: 16,
                        color: isCompleted ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCompleted ? '已發佈' : '已取消',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isCompleted ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ]),
                    if (_contentController.text.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        _contentController.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8D6E63),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── 【模式二】智慧預填喚起原生彈窗卡片 ────────────────────────────
/// 顯示 AI 偵測到的意圖與預填參數，一鍵喚起原生 Dialog
class AISmartLaunchCard extends StatelessWidget {
  final String targetDialog; // 'schedule_form' | 'create_post_page' | etc.
  final Map<String, dynamic> prefillData;
  final String cardState; // 'active' | 'completed' | 'cancelled'
  final VoidCallback onLaunch;
  final VoidCallback onCancel;

  const AISmartLaunchCard({
    super.key,
    required this.targetDialog,
    required this.prefillData,
    required this.cardState,
    required this.onLaunch,
    required this.onCancel,
  });

  // 根據 targetDialog 取得對應 icon、標題、色彩
  _DialogMeta get _meta {
    switch (targetDialog) {
      case 'schedule_form':
        return _DialogMeta(
          icon: Icons.calendar_today_rounded,
          title: '新增行程',
          subtitle: '已為您預填行程資訊，一鍵開啟行程表單',
          color: const Color(0xFF42A5F5),
          gradient: [const Color(0xFF1565C0), const Color(0xFF42A5F5)],
        );
      case 'todo_form':
        return _DialogMeta(
          icon: Icons.check_circle_outline_rounded,
          title: '新增待辦',
          subtitle: '已為您預填待辦事項，一鍵開啟編輯',
          color: const Color(0xFF66BB6A),
          gradient: [const Color(0xFF2E7D32), const Color(0xFF66BB6A)],
        );
      case 'create_post_page':
        return _DialogMeta(
          icon: Icons.dynamic_feed_rounded,
          title: '發佈社群貼文',
          subtitle: '前往完整發佈頁面，帶入 AI 草稿',
          color: const Color(0xFFFF7043),
          gradient: [const Color(0xFFE64A19), const Color(0xFFFF7043)],
        );
      case 'profile_edit':
        return _DialogMeta(
          icon: Icons.person_rounded,
          title: '修改個人檔案',
          subtitle: '一鍵開啟個人資料編輯',
          color: const Color(0xFF7E57C2),
          gradient: [const Color(0xFF4527A0), const Color(0xFF7E57C2)],
        );
      case 'quiz_jump':
        return _DialogMeta(
          icon: Icons.quiz_rounded,
          title: '題庫測驗',
          subtitle: '前往題庫頁面開始練習',
          color: const Color(0xFF26A69A),
          gradient: [const Color(0xFF00695C), const Color(0xFF26A69A)],
        );
      default:
        return _DialogMeta(
          icon: Icons.touch_app_rounded,
          title: '智慧操作',
          subtitle: '一鍵開啟相關功能',
          color: const Color(0xFF78909C),
          gradient: [const Color(0xFF455A64), const Color(0xFF78909C)],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    final isActive = cardState == 'active';
    final isCompleted = cardState == 'completed';

    return Opacity(
      opacity: isActive ? 1.0 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, left: 16, right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: meta.color.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: meta.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isCompleted
                          ? Icons.check_circle_rounded
                          : meta.icon,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCompleted ? '${meta.title} — 已完成' : meta.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          isCompleted ? '已成功開啟並完成操作' : meta.subtitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── 預填參數預覽 ──
            if (prefillData.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI 偵測參數',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8D6E63),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F5),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: const Color(0xFFEEE0D8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildParamRows(),
                      ),
                    ),
                  ],
                ),
              ),
            // ── 操作按鈕 ──
            if (isActive) ...[
              const Divider(height: 1, color: Color(0xFFF0E9E6)),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade500,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close_rounded, size: 15),
                          SizedBox(width: 4),
                          Text('取消', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: meta.color,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: onLaunch,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(meta.icon, size: 15),
                          const SizedBox(width: 6),
                          const Text('一鍵開啟',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildParamRows() {
    final labelMap = {
      'title': '標題',
      'date': '日期',
      'startTime': '開始時間',
      'endTime': '結束時間',
      'content': '內容',
      'type': '類型',
      'subject': '科目',
    };
    return prefillData.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .map((e) {
      final label = labelMap[e.key] ?? e.key;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 60,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFBCAAA4),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                e.value.toString(),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF4E342E),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _DialogMeta {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final List<Color> gradient;
  const _DialogMeta({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.gradient,
  });
}

// ─── 操作結果回饋卡片 ──────────────────────────────────────────────
/// 操作完成後的視覺化回饋
class AIActionResultCard extends StatelessWidget {
  final String resultType; // 'success' | 'cancelled' | 'error'
  final String actionType; // 'create_post' | 'create_schedule' | etc.
  final String summary;

  const AIActionResultCard({
    super.key,
    required this.resultType,
    required this.actionType,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = resultType == 'success';
    final isCancelled = resultType == 'cancelled';
    final color = isSuccess
        ? const Color(0xFF43A047)
        : isCancelled
            ? const Color(0xFF78909C)
            : const Color(0xFFE53935);
    final icon = isSuccess
        ? Icons.check_circle_rounded
        : isCancelled
            ? Icons.cancel_rounded
            : Icons.error_rounded;
    final bgColor = isSuccess
        ? const Color(0xFFE8F5E9)
        : isCancelled
            ? const Color(0xFFF5F5F5)
            : const Color(0xFFFFEBEE);

    return Container(
      margin: const EdgeInsets.only(bottom: 14, left: 16, right: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              summary,
              style: TextStyle(
                fontSize: 13,
                color: color.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
