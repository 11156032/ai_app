import '../widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../database/database_helper.dart';
import '../widgets/voice_note_sheet.dart';
import '../services/voice_note_service.dart';
import '../services/voice_note_background_manager.dart';
import '../widgets/mindmap_node.dart';
import '../widgets/mindmap_canvas.dart';

// ==========================================
// 1. 繪圖軌跡資料模型 (Stroke)
// ==========================================
class Stroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final bool isEraser;
  final bool isHighlighter; // 標識是否為螢光重點筆

  Stroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.isEraser = false,
    this.isHighlighter = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'color': color.toARGB32(),
      'strokeWidth': strokeWidth,
      'isEraser': isEraser,
      'isHighlighter': isHighlighter,
    };
  }

  factory Stroke.fromJson(Map<String, dynamic> json) {
    final pointsList = json['points'] as List;
    return Stroke(
      points: pointsList
          .map((p) =>
              Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()))
          .toList(),
      color: Color(json['color'] as int),
      strokeWidth: (json['strokeWidth'] as num).toDouble(),
      isEraser: json['isEraser'] ?? false,
      isHighlighter: json['isHighlighter'] ?? false,
    );
  }
}

// ==========================================
// 2. 筆記資料模型 (Note)
// ==========================================
class Note {
  String id;
  String userId;
  String title;
  String content;
  String category;
  List<Stroke> strokes;
  DateTime updatedAt;
  String? authorName; // 原作者顯示名稱
  String? authorUserId; // 原作者的 userId
  int? authorAvatarColor; // 原作者頭像顏色索引
  Map<String, dynamic>? mindmapJson; // 🧠 關聯心智圖 JSON
  List<ActionItem>? actionItems; // ✅ 關聯待辦行動清單

  Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.category,
    required this.strokes,
    required this.updatedAt,
    this.authorName,
    this.authorUserId,
    this.authorAvatarColor,
    this.mindmapJson,
    this.actionItems,
  });
}

// ==========================================
// 3. 全局模擬記憶體資料庫 (In-Memory DB)
// ==========================================
class NotesDatabase {
  static List<String> categories = ['全部', '未分類', '學習', '工作', '生活'];
  static List<Note> notes = [];

  // 初始化使用者的預設範例筆記
  static void initializeForUser(String userId) {
    final userNotesExist = notes.any((note) => note.userId == userId);
    if (userNotesExist) return;

    notes.addAll([
      Note(
        id: 'note_1_$userId',
        userId: userId,
        title: '歡迎使用智慧文字筆記本 📝',
        content: '# 歡迎使用新一代智慧純文字筆記！\n\n'
            '這是一篇全新的純文字筆記本。您可以使用強大的 Markdown 格式工具列進行排版，並透過 AI 助手生成重點摘要！\n\n'
            '## 💡 核心特色功能：\n'
            '- **富文字格式排版**：使用下方工具列即可設定**粗體**、# 標號、- 清單列表、縮排與彩色文字。\n'
            '- **🎙️ 語音速記轉文字**：點擊右上角的「錄音」按鈕，講話內容即時轉成筆記記錄。\n'
            '- **🤖 AI 智慧摘要整理**：點擊右上角 AI 按鈕，自動產生重點大綱與行動建議。\n'
            '- **🧠 心智圖視覺化**：輕鬆將筆記結構轉化為互動式心智圖！',
        category: '生活',
        strokes: [],
        updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      Note(
        id: 'note_2_$userId',
        userId: userId,
        title: '學習計畫與讀書重點範例 📚',
        content: '# 今日學習目標與複習重點\n\n'
            '## 核心任務：\n'
            '1. 完成數學單元測驗與錯題檢討\n'
            '2. 閱讀英文重點單字與文法解析\n'
            '3. 整理歷史單元筆記並進行 AI 摘要\n\n'
            '> 💡 提示：善用標籤分類與語音速記，可以讓閱讀與紀錄效率大增！',
        category: '學習',
        strokes: [],
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ]);
  }
}

// ==========================================
// 4. 全白筆記本背景 (PaperBackgroundPainter - 純白無線條)
// ==========================================
class PaperBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 保持全白版面整潔，不繪製線條與邊界線
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==========================================
// 5. 智慧 Markdown 即時打字樣式渲染器 (MarkdownTextController)
// ==========================================
class MarkdownTextController extends TextEditingController {
  @override
  TextSpan buildTextSpan(
      {required BuildContext context,
      TextStyle? style,
      required bool withComposing}) {
    final List<TextSpan> spans = [];
    final textVal = text;

    final lines = textVal.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      TextStyle lineStyle = style ??
          const TextStyle(fontSize: 14, color: Colors.black87, height: 1.71);
      String content = line;
      TextSpan? prefixSpan;

      final trimmed = line.trim();

      // A. 解析水平分隔線: "---", "***", "___" (橫條效果)
      if (trimmed.length >= 3 &&
          (trimmed.replaceAll('-', '').isEmpty ||
              trimmed.replaceAll('*', '').isEmpty ||
              trimmed.replaceAll('_', '').isEmpty)) {
        spans.add(TextSpan(
          text: line,
          style: lineStyle.copyWith(
            fontSize: 13,
            letterSpacing: 3.0,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFBCAAA4), // 雅緻暖灰木紋橫條
            decoration: TextDecoration.lineThrough,
            decorationColor: const Color(0xFF8D6E63),
            decorationThickness: 2.8,
          ),
        ));
        if (i < lines.length - 1) {
          spans.add(const TextSpan(text: '\n'));
        }
        continue;
      }

      // B. 解析標頭: "# ", "## ", "### ", "#### "
      if (line.startsWith('# ')) {
        lineStyle = lineStyle.copyWith(
          fontSize: 21,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF3E2723), // 經典暖深褐
        );
        prefixSpan = const TextSpan(
          text: '# ',
          style: TextStyle(fontSize: 0, color: Colors.transparent),
        );
        content = line.substring(2);
      } else if (line.startsWith('## ')) {
        lineStyle = lineStyle.copyWith(
          fontSize: 17.5,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF5D4037),
        );
        prefixSpan = const TextSpan(
          text: '## ',
          style: TextStyle(fontSize: 0, color: Colors.transparent),
        );
        content = line.substring(3);
      } else if (line.startsWith('### ')) {
        lineStyle = lineStyle.copyWith(
          fontSize: 15.5,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF4A148C), // 紫色精選小標
        );
        prefixSpan = const TextSpan(
          text: '### ',
          style: TextStyle(fontSize: 0, color: Colors.transparent),
        );
        content = line.substring(4);
      } else if (line.startsWith('#### ')) {
        lineStyle = lineStyle.copyWith(
          fontSize: 14.5,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF795548),
        );
        prefixSpan = const TextSpan(
          text: '#### ',
          style: TextStyle(fontSize: 0, color: Colors.transparent),
        );
        content = line.substring(5);
      } else if (line.startsWith('> ')) {
        // C. 引用塊 (Blockquote)
        prefixSpan = const TextSpan(
          text: '▎ ',
          style: TextStyle(
            color: Color(0xFF673AB7),
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        );
        lineStyle = lineStyle.copyWith(
          color: const Color(0xFF4A148C),
          fontStyle: FontStyle.italic,
        );
        content = line.substring(2);
      } else if (line.startsWith('- [ ] ') || line.startsWith('* [ ] ')) {
        // D. 待辦清單 (未完成)
        prefixSpan = TextSpan(
          text: '☐ ',
          style: lineStyle.copyWith(
            color: const Color(0xFF8D6E63),
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        );
        content = line.substring(6);
      } else if (line.startsWith('- [x] ') ||
          line.startsWith('- [X] ') ||
          line.startsWith('* [x] ') ||
          line.startsWith('* [X] ')) {
        // D. 待辦清單 (已完成)
        prefixSpan = TextSpan(
          text: '☑ ',
          style: lineStyle.copyWith(
            color: const Color(0xFF2E7D32),
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        );
        lineStyle = lineStyle.copyWith(
          color: Colors.grey.shade500,
          decoration: TextDecoration.lineThrough,
        );
        content = line.substring(6);
      } else if (line.startsWith('- ') ||
          line.startsWith('* ') ||
          line.startsWith('+ ') ||
          line.startsWith('• ')) {
        // E. 項目清單
        prefixSpan = TextSpan(
          text: '• ',
          style: lineStyle.copyWith(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
          ),
        );
        content = line.substring(2);
      }

      if (prefixSpan != null) {
        spans.add(prefixSpan);
      }

      // F. 解析行內文字：**粗體**、~~刪除線~~、`行內代碼` 與 [color=0xFF...]...[/color]
      int index = 0;
      bool isBold = false;
      bool isStrike = false;
      bool isCode = false;
      List<Color> colorStack = [];

      while (index < content.length) {
        int nextBold = content.indexOf('**', index);
        int nextStrike = content.indexOf('~~', index);
        int nextCode = content.indexOf('`', index);
        int nextColor = content.indexOf('[color=', index);
        int nextColorEnd = content.indexOf('[/color]', index);

        // Find the closest tag
        int minIndex = content.length;
        String tagType = '';
        if (nextBold != -1 && nextBold < minIndex) {
          minIndex = nextBold;
          tagType = 'bold';
        }
        if (nextStrike != -1 && nextStrike < minIndex) {
          minIndex = nextStrike;
          tagType = 'strike';
        }
        if (nextCode != -1 && nextCode < minIndex) {
          minIndex = nextCode;
          tagType = 'code';
        }
        if (nextColor != -1 && nextColor < minIndex) {
          minIndex = nextColor;
          tagType = 'color';
        }
        if (nextColorEnd != -1 && nextColorEnd < minIndex) {
          minIndex = nextColorEnd;
          tagType = 'colorEnd';
        }

        if (minIndex > index) {
          // Process text before the tag
          String plainText = content.substring(index, minIndex);
          TextStyle currentStyle = lineStyle;
          if (isBold) {
            currentStyle = currentStyle.copyWith(fontWeight: FontWeight.bold);
          }
          if (isStrike) {
            currentStyle =
                currentStyle.copyWith(decoration: TextDecoration.lineThrough);
          }
          if (isCode) {
            currentStyle = currentStyle.copyWith(
              fontFamily: 'monospace',
              color: const Color(0xFF4A148C),
              backgroundColor: const Color(0xFFEDE7F6),
            );
          }
          if (colorStack.isNotEmpty) {
            currentStyle = currentStyle.copyWith(color: colorStack.last);
          }

          int plainIndex = 0;
          while (plainIndex < plainText.length) {
            int charLength = 1;
            if (plainIndex < plainText.length - 1) {
              final code = plainText.codeUnitAt(plainIndex);
              if (code >= 0xD800 && code <= 0xDBFF) {
                charLength = 2;
              }
            }
            spans.add(TextSpan(
              text: plainText.substring(plainIndex, plainIndex + charLength),
              style: currentStyle,
            ));
            plainIndex += charLength;
          }
        }

        if (minIndex == content.length) break;

        // Process the tag itself
        if (tagType == 'bold') {
          spans.add(const TextSpan(
            text: '**',
            style: TextStyle(fontSize: 0, color: Colors.transparent),
          ));
          isBold = !isBold;
          index = minIndex + 2;
        } else if (tagType == 'strike') {
          spans.add(const TextSpan(
            text: '~~',
            style: TextStyle(fontSize: 0, color: Colors.transparent),
          ));
          isStrike = !isStrike;
          index = minIndex + 2;
        } else if (tagType == 'code') {
          spans.add(const TextSpan(
            text: '`',
            style: TextStyle(fontSize: 0, color: Colors.transparent),
          ));
          isCode = !isCode;
          index = minIndex + 1;
        } else if (tagType == 'color') {
          int closeBracket = content.indexOf(']', minIndex);
          if (closeBracket != -1) {
            String colorHex = content.substring(minIndex + 7, closeBracket);
            int colorVal = int.tryParse(colorHex) ?? Colors.black.toARGB32();
            colorStack.add(Color(Color(colorVal).toARGB32()));
            spans.add(TextSpan(
              text: content.substring(minIndex, closeBracket + 1),
              style: const TextStyle(fontSize: 0, color: Colors.transparent),
            ));
            index = closeBracket + 1;
          } else {
            // Malformed tag, just treat as text
            spans.add(TextSpan(
              text: '[color=',
              style: lineStyle,
            ));
            index = minIndex + 7;
          }
        } else if (tagType == 'colorEnd') {
          if (colorStack.isNotEmpty) colorStack.removeLast();
          spans.add(const TextSpan(
            text: '[/color]',
            style: TextStyle(fontSize: 0, color: Colors.transparent),
          ));
          index = minIndex + 8;
        }
      }

      // 加換行
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return TextSpan(children: spans);
  }
}

// ==========================================
// 6. 筆記主畫面 (NotesScreen)
// ==========================================
class NotesScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;

  const NotesScreen({super.key, required this.currentUser});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String _selectedCategory = '全部';

  @override
  void initState() {
    super.initState();
    NotesDatabase.initializeForUser(widget.currentUser['id']);
    VoiceNoteBackgroundManager.instance
        .addListener(_handleBackgroundManagerUpdate);
  }

  @override
  void dispose() {
    VoiceNoteBackgroundManager.instance
        .removeListener(_handleBackgroundManagerUpdate);
    super.dispose();
  }

  void _handleBackgroundManagerUpdate() {
    if (!mounted) return;
    final manager = VoiceNoteBackgroundManager.instance;
    if (manager.lastCompletedResult != null && manager.lastCreatedNote != null) {
      final newNote = manager.lastCreatedNote!;
      setState(() {});
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🎉 AI 筆記「${newNote.title}」已整理完成！',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: '立即查看',
            textColor: Colors.amber,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NoteEditorScreen(note: newNote),
                ),
              );
            },
          ),
          backgroundColor: const Color(0xFF4A148C),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      manager.dismissCompletedNotification();
    } else {
      setState(() {});
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  // ──────────────────────────────────────────────────
  // 建立一般空白筆記
  // ──────────────────────────────────────────────────
  Future<void> _createNewRegularNote() async {
    final newNote = Note(
      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
      userId: widget.currentUser['id'],
      title: '',
      content: '',
      category: _selectedCategory == '全部' ? '未分類' : _selectedCategory,
      strokes: [],
      updatedAt: DateTime.now(),
    );
    NotesDatabase.notes.insert(0, newNote);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorScreen(note: newNote),
      ),
    );
    _refresh();
  }

  // ──────────────────────────────────────────────────
  // 語音速記整理 BottomSheet
  // ──────────────────────────────────────────────────
  Future<void> _showVoiceNoteSheet() async {
    final userId = widget.currentUser['id']?.toString() ?? '';
    if (userId == 'u4') {
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
        SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text('訪客帳戶無法使用語音筆記功能，請先登入！')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => VoiceNoteSheet(
          scrollController: scrollController,
          userId: userId,
          onNoteReady:
              (title, category, markdownContent, mindmapJson, actionItems) {
            // 確保分類存在
            if (!NotesDatabase.categories.contains(category)) {
              NotesDatabase.categories.add(category);
            }
            final newNote = Note(
              id: 'note_${DateTime.now().millisecondsSinceEpoch}',
              userId: userId,
              title: title.isEmpty ? '語音速記筆記' : title,
              content: markdownContent,
              category: category.isEmpty ? '未分類' : category,
              strokes: [],
              updatedAt: DateTime.now(),
              mindmapJson: mindmapJson,
              actionItems: actionItems,
            );
            NotesDatabase.notes.insert(0, newNote);
            _refresh();
            if (mounted) {
              ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '「${newNote.title}」已成功建立並存入筆記本！',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  duration: const Duration(milliseconds: 1500),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────
  // ──────────────────────────────────────────────────
  // 新增筆記方式選擇彈窗（筆記 / 錄音 雙選項）
  // ──────────────────────────────────────────────────
  void _showCreateNoteOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E24) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                blurRadius: 20,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '✨ 選擇新增筆記方式',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF3E2723),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 選項 1: 🎙️ 語音錄音速記 (Groq Whisper)
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _showVoiceNoteSheet();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              const Color(0xFF7B1FA2).withValues(alpha: 0.25),
                              const Color(0xFF4A148C).withValues(alpha: 0.15),
                            ]
                          : [
                              const Color(0xFF4A148C).withValues(alpha: 0.09),
                              const Color(0xFF7B1FA2).withValues(alpha: 0.04),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF8E24AA)
                          .withValues(alpha: isDark ? 0.45 : 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8E24AA), Color(0xFF4A148C)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4A148C)
                                  .withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.mic_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '🎙️ 語音錄音速記',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? const Color(0xFFCE93D8)
                                        : const Color(0xFF4A148C),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8E24AA),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'AI 整理 ⚡',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '長錄音完整收錄・自動標點・去贅字整理與心智圖',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey.shade700,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isDark
                            ? const Color(0xFFCE93D8)
                            : const Color(0xFF4A148C),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 選項 2: 📝 一般筆記
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _createNewRegularNote();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF282832)
                        : const Color(0xFFFBF9F7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE5DCD3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor.withValues(
                              alpha: isDark ? 0.2 : 0.12),
                        ),
                        child: Icon(
                          Icons.edit_note_rounded,
                          color:
                              isDark ? Colors.white70 : const Color(0xFF5D4037),
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📝 一般筆記',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF3E2723),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Markdown 富文字排版、標籤分類管理與 AI 摘要',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white60
                                    : Colors.grey.shade600,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? Colors.white38 : Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Note> get _filteredNotes {
    final myNotes = NotesDatabase.notes
        .where((note) => note.userId == widget.currentUser['id'])
        .toList();
    if (_selectedCategory == '全部') {
      return myNotes;
    }
    return myNotes.where((note) => note.category == _selectedCategory).toList();
  }

  int _getNoteCount(String category) {
    final myNotes = NotesDatabase.notes
        .where((note) => note.userId == widget.currentUser['id'])
        .toList();
    if (category == '全部') {
      return myNotes.length;
    }
    return myNotes.where((note) => note.category == category).length;
  }

  void _deleteNote(Note note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除確認'),
        content: Text(
            '確定要刪除「${note.title.isEmpty ? '無標題筆記' : note.title}」這篇筆記嗎？此動作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() {
                NotesDatabase.notes.remove(note);
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
                const SnackBar(
                    content: Text('筆記已刪除 🗑️'), duration: Duration(seconds: 1)),
              );
            },
            child: const Text('確定刪除'),
          ),
        ],
      ),
    );
  }

  // 大氣且回饋明確的分類管理對話框
  void _showCategoryManagementDialog() {
    TextEditingController addController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.label_important_outline,
                    color: Theme.of(context).primaryColor),
                SizedBox(width: 8),
                Text('管理分類標籤'),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 新增分類輸入區
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: addController,
                            style: const TextStyle(fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: '新增分類名稱...',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: () {
                            final newCat = addController.text.trim();
                            if (newCat.isNotEmpty) {
                              if (!NotesDatabase.categories.contains(newCat)) {
                                setDialogState(() {
                                  // 將新分類插在 '全部' & '未分類' 後面，提升能見度
                                  NotesDatabase.categories.insert(2, newCat);
                                });
                                setState(() {});
                                addController.clear();
                                // 彈出明確新增成功 SnackBar 提示
                                ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('🎉 分類標籤「$newCat」新增成功！已排在列表最前。'),
                                    backgroundColor:
                                        Theme.of(context).primaryColor,
                                    duration: const Duration(milliseconds: 1500),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
                                  SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, 
                                    content: Text('⚠️ 此分類標籤已經存在！'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('新增'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '現有分類標籤清單：',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 分類列表滾動區域
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: NotesDatabase.categories.length,
                        itemBuilder: (context, index) {
                          final cat = NotesDatabase.categories[index];
                          final isSystem = cat == '全部' || cat == '未分類';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color:
                                  isSystem ? Colors.grey.shade50 : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              visualDensity: VisualDensity.compact,
                              title: Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSystem
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                  color: isSystem
                                      ? Colors.grey.shade600
                                      : const Color(0xFF5D4037),
                                ),
                              ),
                              dense: true,
                              trailing: isSystem
                                  ? const Icon(Icons.lock_outline,
                                      size: 16, color: Colors.grey)
                                  : IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.redAccent, size: 18),
                                      onPressed: () {
                                        setDialogState(() {
                                          NotesDatabase.categories.remove(cat);
                                          for (var note
                                              in NotesDatabase.notes) {
                                            if (note.category == cat) {
                                              note.category = '未分類';
                                            }
                                          }
                                          if (_selectedCategory == cat) {
                                            _selectedCategory = '全部';
                                          }
                                        });
                                        setState(() {});
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, 
                                              content: Text('已刪除分類標籤「$cat」')),
                                        );
                                      },
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('完成',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotes;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 頂部導覽列：分類標籤與編輯標籤功能
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: NotesDatabase.categories.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        final count = _getNoteCount(cat);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: GestureDetector(
                            onLongPress: _showCategoryManagementDialog,
                            child: ChoiceChip(
                              label: Text('$cat ($count)'),
                              selected: isSelected,
                              selectedColor: Theme.of(context).primaryColor,
                              backgroundColor: const Color(0xFFF5F5F5),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF5D4037),
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isSelected
                                      ? Colors.transparent
                                      : Colors.grey.shade300,
                                ),
                              ),
                              elevation: isSelected ? 2 : 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedCategory = cat;
                                  });
                                }
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 🏷️ 編輯標籤按鈕 (取代舊的多選功能位)
                InkWell(
                  onTap: _showCategoryManagementDialog,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .primaryColor
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.label_outline_rounded,
                            color: Theme.of(context).primaryColor, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '編輯標籤',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 🤖 AI 背景處理動態指示橫幅
          if (VoiceNoteBackgroundManager.instance.isGenerating)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF4A148C).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF4A148C).withValues(alpha: 0.25),
                ),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF4A148C)),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '🤖 AI 正在背景為您提煉整理語音筆記，完成後將自動發送推播通知...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4A148C),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 筆記清單一欄 N 列 (ListView)
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_note,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _selectedCategory == '全部'
                              ? '目前沒有任何筆記哦！'
                              : '在「$_selectedCategory」中沒有筆記',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 15),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _createNewRegularNote,
                              icon:
                                  const Icon(Icons.edit_note_rounded, size: 18),
                              label: const Text('一般筆記'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(context).primaryColor,
                                side: BorderSide(
                                    color: Theme.of(context).primaryColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _showVoiceNoteSheet,
                              icon: const Icon(Icons.mic_rounded, size: 18),
                              label: const Text('AI 語音速記'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4A148C),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final note = filtered[index];
                      final plainContent = note.content
                          .replaceAll('#', '')
                          .replaceAll('**', '')
                          .replaceAll(RegExp(r'\[color=.*?\]'), '')
                          .replaceAll('[/color]', '')
                          .trim();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    NoteEditorScreen(note: note),
                              ),
                            );
                            _refresh();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ],
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1.0,
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .primaryColor
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        note.category,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    ),
                                    if (note.mindmapJson != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4A148C)
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.hub_outlined,
                                                size: 12,
                                                color: Color(0xFF4A148C)),
                                            SizedBox(width: 3),
                                            Text(
                                              '心智圖',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF4A148C),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    Text(
                                      DateFormat('yyyy/MM/dd HH:mm')
                                          .format(note.updatedAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _deleteNote(note),
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.delete_outline_rounded,
                                            size: 18,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  note.title.isEmpty ? '無標題筆記' : note.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C2C2C),
                                  ),
                                ),
                                if (plainContent.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    plainContent,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'main_notes_fab',
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        onPressed: _showCreateNoteOptions,
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }
}

// ==========================================
// 7. 智慧圖文筆記編輯器 (NoteEditorScreen)
// ==========================================
class NoteEditorScreen extends StatefulWidget {
  final Note note;

  const NoteEditorScreen({super.key, required this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _titleController;
  late MarkdownTextController _contentController;
  late String _currentCategory;
  final FocusNode _contentFocusNode = FocusNode();
  bool _isExplicitlyDeleted = false;
  bool _isMarkdownPreview = false;

  // 畫布軌跡狀態
  List<Stroke> _strokes = [];

  // 莫蘭迪文字調色盤
  static const List<Color> _morandiPalette = [
    Color(0xFF37474F), // 炭灰
    Color(0xFF8D6E63), // 莫蘭迪棕
    Color(0xFF6B8A96), // 孔雀藍
    Color(0xFF8AA682), // 森林綠
    Color(0xFFC62828), // 珊瑚紅
    Color(0xFFF57F17), // 芥末黃
    Color(0xFF6A1B9A), // 丁香紫
    Color(0xFF4DB6AC), // 灰湖綠
  ];

  // 🧠 心智圖模型
  MindMapNode? _mindmapRootNode;
  bool get _hasMindMap => _mindmapRootNode != null;

  void _initMindMap() {
    if (widget.note.mindmapJson != null) {
      try {
        _mindmapRootNode = MindMapNode.fromJson(widget.note.mindmapJson!);
      } catch (e) {
        debugPrint('Failed to parse note mindmapJson: $e');
        _mindmapRootNode = null;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initMindMap();
    _tabController = TabController(length: _hasMindMap ? 2 : 1, vsync: this);
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = MarkdownTextController()..text = widget.note.content;
    _currentCategory = NotesDatabase.categories.contains(widget.note.category)
        ? widget.note.category
        : '未分類';
    _strokes = List.from(widget.note.strokes);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  bool get _isBlank {
    return _titleController.text.trim().isEmpty &&
        _contentController.text.trim().isEmpty &&
        _strokes.isEmpty;
  }

  void _autoSave() {
    widget.note.title = _titleController.text.trim();
    widget.note.content = _contentController.text;
    widget.note.category = _currentCategory;
    widget.note.strokes = List.from(_strokes);
    widget.note.updatedAt = DateTime.now();
  }

  void _shareNote() async {
    _autoSave();
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    // 讀取目前使用者加入的群組
    List<Map<String, dynamic>> myGroups = [];
    try {
      myGroups = await DatabaseHelper.instance.getMyGroups(widget.note.userId);
    } catch (e) {
      debugPrint('讀取群組失敗: $e');
    }
    if (!mounted) return;

    // 分享目標選擇：'public' (公開社群論壇) 或 group_id (整數)
    dynamic selectedTarget = 'public';

    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
          return SafeArea(
            top: false,
            bottom: true,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              margin: EdgeInsets.only(bottom: bottomPadding),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4.5,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.share_rounded,
                            color: theme.primaryColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '分享筆記',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3E2723),
                              ),
                            ),
                            Text(
                              '《${widget.note.title.isEmpty ? "無標題筆記" : widget.note.title}》',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '選擇分享目的地：',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D4037),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 選項 A: 公開社群論壇
                          InkWell(
                            onTap: () {
                              setModalState(() => selectedTarget = 'public');
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: selectedTarget == 'public'
                                    ? theme.primaryColor.withValues(alpha: 0.08)
                                    : const Color(0xFFFBF9F7),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selectedTarget == 'public'
                                      ? theme.primaryColor
                                      : const Color(0xFFE5DCD3),
                                  width: selectedTarget == 'public' ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.blue.shade50,
                                    ),
                                    child: Icon(Icons.public_rounded,
                                        color: Colors.blue.shade700, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '公開社群論壇',
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF3E2723),
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          '發佈至全站動態牆，所有同學皆可瀏覽與匯入',
                                          style: TextStyle(
                                              fontSize: 11.5,
                                              color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: selectedTarget == 'public'
                                            ? theme.primaryColor
                                            : Colors.grey.shade400,
                                        width:
                                            selectedTarget == 'public' ? 6 : 2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 選項 B: 指定學習群組
                          Row(
                            children: [
                              const Icon(Icons.groups_rounded,
                                  size: 16, color: Color(0xFF4A148C)),
                              const SizedBox(width: 6),
                              const Text(
                                '分享至我的學習群組',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3E2723),
                                ),
                              ),
                              if (myGroups.isNotEmpty)
                                Text(
                                  ' (${myGroups.length})',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (myGroups.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 18, color: Colors.grey.shade600),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '您目前尚未加入任何群組，可先至社群探索並加入學習群組喔！',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...myGroups.map((g) {
                              final groupId = g['id'] as int;
                              final isSelected = selectedTarget == groupId;
                              final emoji = g['icon_emoji']?.toString() ?? '📚';
                              final name = g['name']?.toString() ?? '未命名群組';
                              final memberCount = g['member_count'] ?? 1;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  onTap: () {
                                    setModalState(
                                        () => selectedTarget = groupId);
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF4A148C)
                                              .withValues(alpha: 0.08)
                                          : const Color(0xFFFBF9F7),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF4A148C)
                                            : const Color(0xFFE5DCD3),
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4A148C)
                                                .withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(emoji,
                                              style: const TextStyle(
                                                  fontSize: 18)),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF3E2723),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                '$memberCount 位成員',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        Colors.grey.shade600),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected
                                                  ? const Color(0xFF4A148C)
                                                  : Colors.grey.shade400,
                                              width: isSelected ? 6 : 2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, null),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (selectedTarget == 'public') {
                              Navigator.pop(ctx, {
                                'type': 'public',
                                'targetName': '社群論壇',
                                'groupId': null,
                              });
                            } else {
                              final targetGroup = myGroups.firstWhere(
                                (g) => g['id'] == selectedTarget,
                                orElse: () => {'name': '群組'},
                              );
                              Navigator.pop(ctx, {
                                'type': 'group',
                                'targetName': targetGroup['name'] ?? '群組',
                                'groupId': selectedTarget as int,
                              });
                            }
                          },
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: const Text('確定分享',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14.5)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result != null) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: CircularProgressIndicator(color: theme.primaryColor),
        ),
      );

      try {
        final strokesJson =
            jsonEncode(_strokes.map((s) => s.toJson()).toList());
        final db = await DatabaseHelper.instance.database;

        final isGroup = result['type'] == 'group';
        final targetGroupId = result['groupId'] as int?;
        final targetName = result['targetName'] as String;

        await db.insert('posts', <String, Object?>{
          if (targetGroupId != null) 'group_id': targetGroupId,
          'user_id': widget.note.userId,
          'content':
              '我分享了我的學習筆記《${widget.note.title.isEmpty ? "無標題筆記" : widget.note.title}》，歡迎點擊一鍵匯入！ 📝',
          'type': 'note',
          'attached_data': jsonEncode({
            'shared_type': 'note',
            'title': widget.note.title.isEmpty ? "無標題筆記" : widget.note.title,
            'content': widget.note.content,
            'category': widget.note.category,
            'strokes': strokesJson,
            'mindmap_json': widget.note.mindmapJson,
          }),
          'created_at': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          Navigator.pop(context); // 關閉讀取框
          messenger.clearSnackBars();
          messenger..hideCurrentSnackBar()..showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(isGroup
                        ? '🎉 筆記已成功分享至「$targetName」群組！'
                        : '🎉 筆記已成功公開分享至社群論壇！'),
                  ),
                ],
              ),
              backgroundColor:
                  isGroup ? const Color(0xFF4A148C) : theme.primaryColor,
              duration: const Duration(milliseconds: 1400),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // 關閉讀取框
          messenger.clearSnackBars();
          messenger..hideCurrentSnackBar()..showSnackBar(
            SnackBar(
              content: Text('分享失敗: $e'),
              backgroundColor: Colors.redAccent,
              duration: const Duration(milliseconds: 1400),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (_isExplicitlyDeleted) {
      return true;
    }

    if (_isBlank) {
      NotesDatabase.notes.remove(widget.note);
      if (mounted) {
        ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
          const SnackBar(
            content: Text('已自動捨棄空白筆記 🗑️'),
            duration: Duration(milliseconds: 800),
          ),
        );
      }
      return true;
    }

    _autoSave();
    if (mounted) {
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
        const SnackBar(
          content: Text('筆記已自動儲存 💾'),
          duration: Duration(milliseconds: 800),
        ),
      );
    }
    return true;
  }

  void _deleteCurrentNoteFromEditor() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除確認'),
        content: Text(
          widget.note.title.trim().isNotEmpty
              ? '確定要刪除「${widget.note.title}」這篇筆記嗎？此動作無法復原。'
              : '確定要刪除此篇筆記嗎？此動作無法復原。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              _isExplicitlyDeleted = true;
              NotesDatabase.notes.remove(widget.note);
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
                const SnackBar(
                  content: Text('筆記已刪除 🗑️'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: const Text('確定刪除'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 語音速記整理（編輯器版）
  // ==========================================
  Future<void> _openVoiceNoteSheetForEditor() async {
    _autoSave(); // 先自動儲存
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => VoiceNoteSheet(
          scrollController: scrollController,
          userId: widget.note.userId,
          existingContent: _contentController.text,
          onNoteReady:
              (title, category, markdownContent, mindmapJson, actionItems) {
            // 插入至目前筆記內容末端
            final currentText = _contentController.text;
            final separator =
                currentText.isNotEmpty && !currentText.endsWith('\n')
                    ? '\n\n'
                    : '';
            _contentController.text = '$currentText$separator$markdownContent';
            // 自動更新標題（若原標題為空）
            if (_titleController.text.trim().isEmpty) {
              _titleController.text = title;
            }
            // 若原筆記沒有心智圖但本次生成了心智圖，自動更新
            if (mindmapJson != null) {
              widget.note.mindmapJson = mindmapJson;
              widget.note.actionItems = actionItems;
              _initMindMap();
              if (_hasMindMap && _tabController.length == 2) {
                _tabController.dispose();
                _tabController = TabController(length: 3, vsync: this);
              }
            }
            // 儲存
            _autoSave();
            if (mounted) {
              setState(() {});
              ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
                SnackBar(duration: const Duration(milliseconds: 1500), 
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('語音筆記已插入！'),
                    ],
                  ),
                  backgroundColor: const Color(0xFF4A148C),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  // ==========================================
  // 富文字工具列動作 (Rich Text Formatting Actions)
  // ==========================================

  // 1. 粗體 toggler
  void _toggleBold() {
    final textVal = _contentController.text;
    final selection = _contentController.selection;
    if (selection.isValid && !selection.isCollapsed) {
      final selectedText = textVal.substring(selection.start, selection.end);

      String cleanText = selectedText.replaceAll('**', '');
      final lines = cleanText.split('\n');
      final formattedText = lines.map((l) {
        if (l.trim().isEmpty) return l;
        if (l.startsWith('# ')) return '# **${l.substring(2)}**';
        if (l.startsWith('## ')) return '## **${l.substring(3)}**';
        if (l.startsWith('- ')) return '- **${l.substring(2)}**';
        return '**$l**';
      }).join('\n');

      final newText =
          textVal.replaceRange(selection.start, selection.end, formattedText);
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
            offset: selection.start + formattedText.length),
      );
    } else {
      final start = selection.isValid ? selection.start : textVal.length;
      final newText = textVal.replaceRange(start, start, '****');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + 2),
      );
    }
  }

  // 2. 標頭 H1 (# )
  void _toggleH1() {
    final textVal = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.isValid ? selection.start : textVal.length;

    int lineStart = textVal.lastIndexOf('\n', start - 1);
    lineStart = lineStart == -1 ? 0 : lineStart + 1;
    int lineEnd = textVal.indexOf('\n', start);
    lineEnd = lineEnd == -1 ? textVal.length : lineEnd;

    final fullLine = textVal.substring(lineStart, lineEnd);
    if (fullLine.startsWith('# ')) {
      final newText = textVal.replaceRange(lineStart, lineStart + 2, '');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
            offset: (start - 2).clamp(lineStart, newText.length)),
      );
    } else {
      final newText = textVal.replaceRange(lineStart, lineStart, '# ');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + 2),
      );
    }
  }

  // 3. 次標頭 H2 (## )
  void _toggleH2() {
    final textVal = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.isValid ? selection.start : textVal.length;

    int lineStart = textVal.lastIndexOf('\n', start - 1);
    lineStart = lineStart == -1 ? 0 : lineStart + 1;
    int lineEnd = textVal.indexOf('\n', start);
    lineEnd = lineEnd == -1 ? textVal.length : lineEnd;

    final fullLine = textVal.substring(lineStart, lineEnd);
    if (fullLine.startsWith('## ')) {
      final newText = textVal.replaceRange(lineStart, lineStart + 3, '');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
            offset: (start - 3).clamp(lineStart, newText.length)),
      );
    } else {
      final newText = textVal.replaceRange(lineStart, lineStart, '## ');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + 3),
      );
    }
  }

  // 4. 列點符號 (- )
  void _toggleBullet() {
    final textVal = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.isValid ? selection.start : textVal.length;

    int lineStart = textVal.lastIndexOf('\n', start - 1);
    lineStart = lineStart == -1 ? 0 : lineStart + 1;
    int lineEnd = textVal.indexOf('\n', start);
    lineEnd = lineEnd == -1 ? textVal.length : lineEnd;

    final fullLine = textVal.substring(lineStart, lineEnd);
    if (fullLine.startsWith('- ')) {
      final newText = textVal.replaceRange(lineStart, lineStart + 2, '');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
            offset: (start - 2).clamp(lineStart, newText.length)),
      );
    } else {
      final newText = textVal.replaceRange(lineStart, lineStart, '- ');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + 2),
      );
    }
  }

  // 5. 縮排 (4格空白)
  void _toggleIndent() {
    final textVal = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.isValid ? selection.start : textVal.length;

    int lineStart = textVal.lastIndexOf('\n', start - 1);
    lineStart = lineStart == -1 ? 0 : lineStart + 1;

    final newText = textVal.replaceRange(lineStart, lineStart, '    ');
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + 4),
    );
  }

  // 6. 套用打字顏色 [color=...]
  void _applyTextColor(Color color) {
    final textVal = _contentController.text;
    final selection = _contentController.selection;
    final colorHex = '0x${color.toARGB32().toRadixString(16).toUpperCase()}';
    final tagPrefix = '[color=$colorHex]';
    final tagSuffix = '[/color]';

    if (selection.isValid && !selection.isCollapsed) {
      final selectedText = textVal.substring(selection.start, selection.end);

      String cleanText = selectedText.replaceAll(
          RegExp(r'\[/?color(?:=0x[0-9A-Fa-f]{8})?\]', caseSensitive: false),
          '');
      final lines = cleanText.split('\n');
      final formattedText = lines.map((l) {
        if (l.trim().isEmpty) return l;
        if (l.startsWith('# ')) {
          return '# $tagPrefix${l.substring(2)}$tagSuffix';
        }
        if (l.startsWith('## ')) {
          return '## $tagPrefix${l.substring(3)}$tagSuffix';
        }
        if (l.startsWith('- ')) {
          return '- $tagPrefix${l.substring(2)}$tagSuffix';
        }
        return '$tagPrefix$l$tagSuffix';
      }).join('\n');

      final newText =
          textVal.replaceRange(selection.start, selection.end, formattedText);
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
            offset: selection.start + formattedText.length),
      );
    } else {
      final start = selection.isValid ? selection.start : textVal.length;
      final newText =
          textVal.replaceRange(start, start, '$tagPrefix$tagSuffix');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + tagPrefix.length),
      );
    }
  }

  // 7. 插入水平分隔橫條 (---)
  void _insertHorizontalRule() {
    final textVal = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.isValid ? selection.start : textVal.length;

    final prefix = (start > 0 && !textVal.substring(0, start).endsWith('\n'))
        ? '\n\n'
        : (start > 0 && !textVal.substring(0, start).endsWith('\n\n')
            ? '\n'
            : '');
    final suffix =
        (start < textVal.length && !textVal.substring(start).startsWith('\n'))
            ? '\n\n'
            : '\n';
    final insertStr = '$prefix---$suffix';

    final newText = textVal.replaceRange(start, start, insertStr);
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + insertStr.length),
    );
  }

  // 8. 待辦清單 (- [ ] )
  void _toggleCheckbox() {
    final textVal = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.isValid ? selection.start : textVal.length;

    int lineStart = textVal.lastIndexOf('\n', start - 1);
    lineStart = lineStart == -1 ? 0 : lineStart + 1;
    int lineEnd = textVal.indexOf('\n', start);
    lineEnd = lineEnd == -1 ? textVal.length : lineEnd;

    final fullLine = textVal.substring(lineStart, lineEnd);
    if (fullLine.startsWith('- [ ] ') ||
        fullLine.startsWith('- [x] ') ||
        fullLine.startsWith('- [X] ')) {
      final newText = textVal.replaceRange(lineStart, lineStart + 6, '');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
            offset: (start - 6).clamp(lineStart, newText.length)),
      );
    } else {
      final newText = textVal.replaceRange(lineStart, lineStart, '- [ ] ');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + 6),
      );
    }
  }

  // 9. 引用塊 (> )
  void _toggleQuote() {
    final textVal = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.isValid ? selection.start : textVal.length;

    int lineStart = textVal.lastIndexOf('\n', start - 1);
    lineStart = lineStart == -1 ? 0 : lineStart + 1;
    int lineEnd = textVal.indexOf('\n', start);
    lineEnd = lineEnd == -1 ? textVal.length : lineEnd;

    final fullLine = textVal.substring(lineStart, lineEnd);
    if (fullLine.startsWith('> ')) {
      final newText = textVal.replaceRange(lineStart, lineStart + 2, '');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
            offset: (start - 2).clamp(lineStart, newText.length)),
      );
    } else {
      final newText = textVal.replaceRange(lineStart, lineStart, '> ');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + 2),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isExplicitlyDeleted) {
          Navigator.of(context).pop();
          return;
        }
        final navigator = Navigator.of(context);
        final shouldPop = await _onWillPop();
        if (shouldPop) {
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white, // 全白背景
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: Colors.black87, size: 20),
            onPressed: () async {
              if (_isExplicitlyDeleted) {
                Navigator.of(context).pop();
                return;
              }
              final navigator = Navigator.of(context);
              final shouldPop = await _onWillPop();
              if (shouldPop) {
                navigator.pop();
              }
            },
          ),
          title: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _currentCategory,
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down,
                    color: Theme.of(context).primaryColor),
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
                borderRadius: BorderRadius.circular(12),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    if (newValue == '__add_new__') {
                      _showAddNewCategoryDialog();
                    } else {
                      setState(() {
                        _currentCategory = newValue;
                      });
                    }
                  }
                },
                items: [
                  ...NotesDatabase.categories
                      .where((cat) => cat != '全部')
                      .map((String cat) {
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Text(
                        '分類: $cat',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                  const DropdownMenuItem<String>(
                    value: '__add_new__',
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 16, color: Colors.green),
                        SizedBox(width: 4),
                        Text('新增分類', style: TextStyle(color: Colors.green)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            // 語音錄音速記整理按鈕 (精確控制高度防止 4px 垂直 overflow)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
              height: 34,
              child: ElevatedButton.icon(
                onPressed: _openVoiceNoteSheetForEditor,
                icon: const Icon(Icons.mic_rounded,
                    size: 15, color: Colors.white),
                label: const Text(
                  '錄音',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A1B9A),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 1,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.share,
                  color: Theme.of(context).primaryColor, size: 21),
              tooltip: '分享至社群',
              onPressed: _shareNote,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFD32F2F), size: 21),
              tooltip: '刪除筆記',
              onPressed: _deleteCurrentNoteFromEditor,
            ),
          ],
          bottom: _hasMindMap
              ? TabBar(
                  controller: _tabController,
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Theme.of(context).primaryColor,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle:
                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_note, size: 18),
                          SizedBox(width: 4),
                          Text('純文字內容'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hub_outlined,
                              size: 16, color: Color(0xFF4A148C)),
                          SizedBox(width: 4),
                          Text('心智圖', style: TextStyle(color: Color(0xFF4A148C))),
                        ],
                      ),
                    ),
                  ],
                )
              : null,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // 1. 無邊框標題輸入框 (常駐頂部)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: TextField(
                      controller: _titleController,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E2723),
                      ),
                      decoration: const InputDecoration(
                        hintText: '請輸入筆記標題...',
                        hintStyle: TextStyle(color: Colors.black26),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),

                  // 2. 純文字筆記區塊 (心智圖啟用時可切換)
                  Expanded(
                    child: _hasMindMap
                        ? TabBarView(
                            controller: _tabController,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildPureTextEditorTab(),
                              _buildMindMapTab(),
                            ],
                          )
                        : _buildPureTextEditorTab(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPureTextEditorTab() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // 筆記打字本體 (全白極簡版面，無線條)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _isMarkdownPreview
                  ? RichNoteContentView(
                      content: _contentController.text,
                      isDark: false,
                      selectable: true,
                    )
                  : TextField(
                      controller: _contentController,
                      focusNode: _contentFocusNode,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.7,
                        color: Colors.black87,
                      ),
                      decoration: const InputDecoration(
                        hintText: '在此輸入純文字內容...\n可以使用下方格式工具列。',
                        hintStyle: TextStyle(color: Colors.black26),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
            ),
          ),
          _buildFormattingToolbar(),
        ],
      ),
    );
  }

  // ==========================================
  // 🧠 C. 心智圖互動畫布 Tab
  // ==========================================
  Widget _buildMindMapTab() {
    if (_mindmapRootNode == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hub_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('此筆記尚無關聯心智圖',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 8),
            Text('可透過上方 🎙️ 語音速記生成結構化心智圖',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
      );
    }
    return Column(
      children: [
        // 頂部全螢幕與橫向提示欄
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.touch_app_rounded,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '支援雙指縮放與拖曳移動',
                    style:
                        TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  FullscreenMindMapView.open(
                    context,
                    root: _mindmapRootNode!,
                    title: _titleController.text.isNotEmpty
                        ? _titleController.text
                        : '心智圖全螢幕檢視',
                  );
                },
                icon: const Icon(Icons.fullscreen_rounded, size: 16),
                label: const Text('全螢幕橫向畫布', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4A148C),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF8F5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5DCD3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: InteractiveMindMapView(
              root: _mindmapRootNode!,
            ),
          ),
        ),
      ],
    );
  }

  // 🎨 開啟側盤/底盤自訂字色調色盤
  void _showCustomColorPickerSheet() {
    Color selectedColor = const Color(0xFFC62828);
    TextEditingController hexController = TextEditingController(text: 'C62828');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.palette_rounded,
                        color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    const Text(
                      '自訂筆記字色調色盤',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('經典色系推薦：',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    const Color(0xFF212121), // 炭黑
                    const Color(0xFF37474F), // 深灰藍
                    const Color(0xFF8D6E63), // 莫蘭迪棕
                    const Color(0xFFC62828), // 珊瑚紅
                    const Color(0xFFD81B60), // 玫瑰洋紅
                    const Color(0xFF8E24AA), // 丁香紫
                    const Color(0xFF5E35B1), // 靛青
                    const Color(0xFF1E88E5), // 寶藍
                    const Color(0xFF00897B), // 灰湖綠
                    const Color(0xFF43A047), // 森林綠
                    const Color(0xFFF57F17), // 芥末黃
                    const Color(0xFFFB8C00), // 焦糖橘
                  ].map((color) {
                    final isPicked = selectedColor.toARGB32() == color.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        setSheetState(() {
                          selectedColor = color;
                          hexController.text = color
                              .toARGB32()
                              .toRadixString(16)
                              .substring(2)
                              .toUpperCase();
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isPicked
                                ? Theme.of(context).primaryColor
                                : Colors.grey.shade300,
                            width: isPicked ? 3.0 : 1.0,
                          ),
                          boxShadow: [
                            if (isPicked)
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                        child: isPicked
                            ? const Icon(Icons.check,
                                size: 18, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const Text('自訂 HEX 色碼（例: #FF5722）：',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade400),
                        boxShadow: [
                          BoxShadow(
                            color: selectedColor.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: hexController,
                        maxLength: 6,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          prefixText: '# ',
                          hintText: '輸入 HEX 色碼...',
                          counterText: '',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (val) {
                          if (val.length == 6) {
                            final parsed = int.tryParse('FF$val', radix: 16);
                            if (parsed != null) {
                              setSheetState(() {
                                selectedColor = Color(parsed);
                              });
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.format_color_fill, size: 18),
                    label: const Text('套用此自訂色彩',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _applyTextColor(selectedColor);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // 🛠 A. 打字格式工具列 Widget
  // ==========================================
  Widget _buildFormattingToolbar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEFEBE9), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 格式動作按鈕
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    _isMarkdownPreview
                        ? Icons.edit_note_rounded
                        : Icons.visibility_rounded,
                    color: _isMarkdownPreview
                        ? const Color(0xFF673AB7)
                        : const Color(0xFF5D4037),
                    size: 21,
                  ),
                  tooltip: _isMarkdownPreview ? '切換為編輯模式' : '切換為成果預覽',
                  onPressed: () =>
                      setState(() => _isMarkdownPreview = !_isMarkdownPreview),
                ),
                Container(
                  height: 18,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: Colors.grey.shade300,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.format_bold,
                      color: Color(0xFF5D4037), size: 20),
                  tooltip: '粗體',
                  onPressed: _toggleBold,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.title,
                      color: Color(0xFF5D4037), size: 20),
                  tooltip: '大標頭 H1',
                  onPressed: _toggleH1,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.text_fields,
                      color: Color(0xFF5D4037), size: 20),
                  tooltip: '次標頭 H2',
                  onPressed: _toggleH2,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.horizontal_rule_rounded,
                      color: Color(0xFF5D4037), size: 20),
                  tooltip: '橫條分隔線 (---)',
                  onPressed: _insertHorizontalRule,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.check_box_outlined,
                      color: Color(0xFF2E7D32), size: 19),
                  tooltip: '待辦項目 (- [ ])',
                  onPressed: _toggleCheckbox,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.format_quote_rounded,
                      color: Color(0xFF673AB7), size: 20),
                  tooltip: '引用重點 (>)',
                  onPressed: _toggleQuote,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.format_list_bulleted,
                      color: Color(0xFF5D4037), size: 20),
                  tooltip: '列點',
                  onPressed: _toggleBullet,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.format_indent_increase,
                      color: Color(0xFF5D4037), size: 20),
                  tooltip: '縮排',
                  onPressed: _toggleIndent,
                ),
                // 語音補充按鈕
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.mic_rounded,
                      color: Color(0xFF7B1FA2), size: 20),
                  tooltip: '語音補充內容',
                  onPressed: _openVoiceNoteSheetForEditor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // 打字字色選擇調色盤 (帶有「自訂調色盤」開啟側盤/底盤功能)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('字色: ',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                ..._morandiPalette.map((color) {
                  return GestureDetector(
                    onTap: () => _applyTextColor(color),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 19,
                      height: 19,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 6),
                // 🎨 側盤/底盤自訂色彩按鈕
                InkWell(
                  onTap: _showCustomColorPickerSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.palette_outlined,
                            size: 13, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 3),
                        Text(
                          '自訂調色盤',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 新增分類標籤對話框
  void _showAddNewCategoryDialog() {
    TextEditingController addController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增分類標籤'),
        content: TextField(
          controller: addController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '請輸入新的分類名稱',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final newCat = addController.text.trim();
              if (newCat.isNotEmpty) {
                if (!NotesDatabase.categories.contains(newCat)) {
                  NotesDatabase.categories.insert(2, newCat);
                }
                setState(() {
                  _currentCategory = newCat;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
                  SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text('🎉 已新增並套用分類「$newCat」！')),
                );
              }
            },
            child: const Text('新增並套用'),
          ),
        ],
      ),
    );
  }
  // ──────────────────────────────────────────────────────────────────────────
}

// ==========================================
// 8. 手寫畫布 Widget (DrawingCanvas)
// ==========================================
class DrawingCanvas extends StatelessWidget {
  final List<Stroke> strokes;
  final Function(Offset) onStrokeStart;
  final Function(Offset) onStrokeUpdate;

  const DrawingCanvas({
    super.key,
    required this.strokes,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localPos = box.globalToLocal(details.globalPosition);
        onStrokeStart(localPos);
      },
      onPanUpdate: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localPos = box.globalToLocal(details.globalPosition);
        onStrokeUpdate(localPos);
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.transparent, // 必須為透明以露出底下的橫格線與文字編輯器！
        child: CustomPaint(
          painter: StrokePainter(strokes: strokes),
        ),
      ),
    );
  }
}

// ==========================================
// 9. 手寫畫布渲染畫筆 (StrokePainter)
// ==========================================
class StrokePainter extends CustomPainter {
  final List<Stroke> strokes;

  StrokePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    for (var stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      // 橡皮擦模式直接使用紙面底色
      if (stroke.isEraser) {
        paint.color = Colors.white;
      }

      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first, stroke.strokeWidth / 2,
            paint..style = PaintingStyle.fill);
      } else {
        final path = Path()
          ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant StrokePainter oldDelegate) {
    return oldDelegate.strokes != strokes;
  }
}
