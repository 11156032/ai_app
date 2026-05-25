import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
          .map((p) => Offset(
              (p['x'] as num).toDouble(), (p['y'] as num).toDouble()))
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

  Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.category,
    required this.strokes,
    required this.updatedAt,
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
        title: '歡迎使用智慧圖文筆記本 📝🎨',
        content: '# 歡迎使用新一代手寫圖文筆記！\n\n'
            '這是一篇全新的圖文分頁筆記。現在**打字與手寫皆擁有完整的大版面**，透過上方切換更寬敞舒適！\n\n'
            '## 💡 互動小秘笈：\n'
            '- 在 **[📝 文字紀錄]** 分頁中，您可以使用下方的富文字格式工具列來設定**粗體**、# 標頭、- 列表、縮排，或加上 [color=0xFFC62828]彩色字體[/color]。\n'
            '- 在 **[🎨 手寫塗鴉]** 分頁中，即可直接使用莫蘭迪筆觸寫字、畫箭頭或塗鴉。\n'
            '- **[🖍️ 螢光筆功能]**：在畫筆模式下開啟螢光筆，能以半透明色彩在文字上完美畫重點！\n\n'
            '現在就切換模式，用黃色螢光筆在下方這行字畫重點試試看吧：\n'
            '**這是一行超級適合用螢光筆塗上黃色重點的文字！** 🌟',
        category: '生活',
        strokes: [
          // 模擬螢光筆重點線條 (黃色半透明)
          Stroke(
            points: [
              const Offset(40, 312),
              const Offset(320, 312),
            ],
            color: const Color(0xFFFFF176).withValues(alpha: 0.4),
            strokeWidth: 15.0,
            isHighlighter: true,
          ),
        ],
        updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      Note(
        id: 'note_2_$userId',
        userId: userId,
        title: '手寫重點與塗鴉範例 🏠☀️',
        content: '# 手寫塗鴉覆蓋文字範例\n\n'
            '下方是一個預先繪製的小房屋與黃色太陽太陽，它們直接覆蓋在背景文字的上面！\n\n'
            '您可以點擊 **[🎨 畫筆重點]**：\n'
            '- 使用調色盤選用「森林綠」畫一些小草 🌲\n'
            '- 切換至 **[📝 打字編輯]** 繼續在下方打字打字...\n\n'
            '這是一個完美融合的手寫紙張，雙模式隨心所欲！',
        category: '學習',
        strokes: [
          // 屋頂 Red
          Stroke(
            points: [
              const Offset(130, 260),
              const Offset(200, 190),
              const Offset(270, 260),
            ],
            color: const Color(0xFFC62828),
            strokeWidth: 5.0,
          ),
          // 牆壁 Blue
          Stroke(
            points: [
              const Offset(150, 260),
              const Offset(150, 330),
              const Offset(250, 330),
              const Offset(250, 260),
              const Offset(150, 260),
            ],
            color: const Color(0xFF6B8A96),
            strokeWidth: 4.0,
          ),
          // 門 Brown
          Stroke(
            points: [
              const Offset(185, 330),
              const Offset(185, 290),
              const Offset(215, 290),
              const Offset(215, 330),
            ],
            color: const Color(0xFF8D6E63),
            strokeWidth: 4.0,
          ),
          // 太陽 Yellow
          Stroke(
            points: [
              const Offset(290, 160),
              const Offset(305, 145),
              const Offset(320, 160),
              const Offset(305, 175),
              const Offset(290, 160),
            ],
            color: const Color(0xFFF57F17),
            strokeWidth: 4.0,
          ),
        ],
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ]);
  }
}

// ==========================================
// 4. 精美筆記本背景橫線繪製器 (PaperBackgroundPainter)
// ==========================================
class PaperBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFE0ECE4) // 極淡藍綠灰橫線
      ..strokeWidth = 1.0;

    final marginPaint = Paint()
      ..color = const Color(0xFFFFCCBC) // 紅色雙邊界豎線
      ..strokeWidth = 1.2;

    // 1. 繪製紅色豎線 (筆記本左側邊界線)
    canvas.drawLine(const Offset(36, 0), const Offset(36, double.maxFinite), marginPaint);

    // 2. 繪製橫向橫格線，配合文字高度 (24.0px 行高)
    const double lineSpacing = 24.0;
    for (double y = 44.0; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(36, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==========================================
// 5. 智慧 Markdown 即時打字樣式渲染器 (MarkdownTextController)
// ==========================================
class MarkdownTextController extends TextEditingController {
  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final List<TextSpan> spans = [];
    final textVal = text;

    final lines = textVal.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      TextStyle lineStyle = style ?? const TextStyle(fontSize: 15, color: Colors.black87, height: 1.6);
      String content = line;

      // A. 解析標頭: "# " 或 "## "
      if (line.startsWith('# ')) {
        lineStyle = lineStyle.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF3E2723), // 經典暖深褐
        );
        content = content.substring(2);
      } else if (line.startsWith('## ')) {
        lineStyle = lineStyle.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF5D4037),
        );
        content = content.substring(3);
      }

      // B. 解析列點: "- " 或 "• "
      bool isBullet = false;
      if (line.startsWith('- ')) {
        isBullet = true;
        content = content.substring(2);
      } else if (line.startsWith('• ')) {
        isBullet = true;
        content = content.substring(2);
      }

      // C. 解析行內文字：**粗體** 與 [color=0xFF...]...[/color]
      final List<TextSpan> inlineSpans = [];
      int index = 0;
      while (index < content.length) {
        // 1. 粗體解析
        if (content.startsWith('**', index)) {
          final nextIdx = content.indexOf('**', index + 2);
          if (nextIdx != -1) {
            inlineSpans.add(TextSpan(
              text: content.substring(index + 2, nextIdx),
              style: lineStyle.copyWith(fontWeight: FontWeight.bold),
            ));
            index = nextIdx + 2;
            continue;
          }
        }
        
        // 2. 顏色解析 [color=0x...]
        if (content.startsWith('[color=', index)) {
          final colorEnd = content.indexOf(']', index);
          if (colorEnd != -1) {
            final colorHex = content.substring(index + 7, colorEnd);
            final tagEnd = content.indexOf('[/color]', colorEnd + 1);
            if (tagEnd != -1) {
              final colorVal = int.tryParse(colorHex) ?? Colors.black.toARGB32();
              inlineSpans.add(TextSpan(
                text: content.substring(colorEnd + 1, tagEnd),
                style: lineStyle.copyWith(color: Color(colorVal)),
              ));
              index = tagEnd + 8;
              continue;
            }
          }
        }

        // 3. 一般文字
        inlineSpans.add(TextSpan(
          text: content[index],
          style: lineStyle,
        ));
        index++;
      }

      // 組合列表符號
      if (isBullet) {
        spans.add(TextSpan(
          text: '  •  ',
          style: lineStyle.copyWith(
            color: const Color(0xFF8D6E63),
            fontWeight: FontWeight.bold,
          ),
        ));
      }

      spans.addAll(inlineSpans);

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
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<Note> get _filteredNotes {
    final myNotes = NotesDatabase.notes
        .where((note) => note.userId == widget.currentUser['id'])
        .toList();
    if (_selectedCategory == '全部') {
      return myNotes;
    }
    return myNotes
        .where((note) => note.category == _selectedCategory)
        .toList();
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
        content: Text('確定要刪除「${note.title}」這篇筆記嗎？此動作無法復原。'),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('筆記已刪除'), duration: Duration(seconds: 1)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.label_important_outline, color: Color(0xFF8D6E63)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                            backgroundColor: const Color(0xFF8D6E63),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('🎉 分類標籤「$newCat」新增成功！已排在列表最前。'),
                                    backgroundColor: const Color(0xFF8D6E63),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
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
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
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
                              color: isSystem ? Colors.grey.shade50 : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              visualDensity: VisualDensity.compact,
                              title: Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSystem ? FontWeight.normal : FontWeight.bold,
                                  color: isSystem ? Colors.grey.shade600 : const Color(0xFF5D4037),
                                ),
                              ),
                              dense: true,
                              trailing: isSystem
                                  ? const Icon(Icons.lock_outline, size: 16, color: Colors.grey)
                                  : IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.redAccent, size: 18),
                                      onPressed: () {
                                        setDialogState(() {
                                          NotesDatabase.categories.remove(cat);
                                          for (var note in NotesDatabase.notes) {
                                            if (note.category == cat) {
                                              note.category = '未分類';
                                            }
                                          }
                                          if (_selectedCategory == cat) {
                                            _selectedCategory = '全部';
                                          }
                                        });
                                        setState(() {});
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('已刪除分類標籤「$cat」')),
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
                child: const Text('完成', style: TextStyle(fontWeight: FontWeight.bold)),
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
      backgroundColor: const Color(0xFFF8F6F4),
      body: Column(
        children: [
          // 頂部橫向滾動分類導覽晶片 (Chips)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
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
                          child: ChoiceChip(
                            label: Text('$cat ($count)'),
                            selected: isSelected,
                            selectedColor: const Color(0xFF8D6E63),
                            backgroundColor: const Color(0xFFEFEBE9),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF5D4037),
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isSelected ? Colors.transparent : Colors.grey.shade300,
                              ),
                            ),
                            elevation: isSelected ? 2 : 0,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedCategory = cat;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 管理分類按鈕
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF8D6E63).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.settings, color: Color(0xFF8D6E63), size: 20),
                    tooltip: '管理分類',
                    onPressed: _showCategoryManagementDialog,
                  ),
                ),
              ],
            ),
          ),

          // 筆記卡片網格 (Grid View)
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_note, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _selectedCategory == '全部' ? '目前沒有任何筆記哦！' : '在「$_selectedCategory」中沒有筆記',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '點擊右下角按鈕開始記錄你的筆記吧 ✍️',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final note = filtered[index];
                      final cardColors = [
                        const Color(0xFFE8ECE9),
                        const Color(0xFFF1EAE4),
                        const Color(0xFFE5ECEF),
                        const Color(0xFFEAE5EF),
                        const Color(0xFFEFECE5),
                      ];
                      final bgColor = cardColors[note.id.hashCode % cardColors.length];

                      return GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NoteEditorScreen(note: note),
                            ),
                          );
                          _refresh();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ],
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.05),
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8D6E63).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      note.category,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF5D4037),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (note.strokes.isNotEmpty)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 4.0),
                                      child: Icon(Icons.palette_outlined, size: 14, color: Color(0xFF8D6E63)),
                                    ),
                                  GestureDetector(
                                    onTap: () => _deleteNote(note),
                                    child: const Icon(Icons.delete_outline, size: 16, color: Colors.black54),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                note.title.isEmpty ? '無標題筆記' : note.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3E2723),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: Text(
                                  note.content
                                      .replaceAll('#', '')
                                      .replaceAll('**', '')
                                      .replaceAll(RegExp(r'\[color=.*?\]'), '')
                                      .replaceAll('[/color]', '')
                                      .trim()
                                      .isEmpty
                                          ? '（空白筆記內容）'
                                          : note.content
                                              .replaceAll('#', '')
                                              .replaceAll('**', '')
                                              .replaceAll(RegExp(r'\[color=.*?\]'), '')
                                              .replaceAll('[/color]', '')
                                              .trim(),
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  DateFormat('MM/dd HH:mm').format(note.updatedAt),
                                  style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF8D6E63),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () async {
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
        },
        child: const Icon(Icons.add, size: 28),
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

class _NoteEditorScreenState extends State<NoteEditorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _titleController;
  late MarkdownTextController _contentController;
  late String _currentCategory;
  final FocusNode _contentFocusNode = FocusNode();

  // 畫布軌跡狀態
  List<Stroke> _strokes = [];
  final List<List<Stroke>> _undoStack = [];
  final List<List<Stroke>> _redoStack = [];

  // 畫筆參數
  Color _selectedColor = const Color(0xFF37474F); // 預設深炭灰
  double _strokeWidth = 4.0;
  bool _isEraser = false;
  bool _isHighlighter = false; // 是否為半透明螢光重點筆

  // 莫蘭迪調色盤
  final List<Color> _morandiPalette = [
    const Color(0xFF37474F), // 炭灰
    const Color(0xFF8D6E63), // 莫蘭迪棕
    const Color(0xFF6B8A96), // 孔雀藍
    const Color(0xFF8AA682), // 森林綠
    const Color(0xFFC62828), // 珊瑚紅
    const Color(0xFFF57F17), // 芥末黃
    const Color(0xFF6A1B9A), // 丁香紫
    const Color(0xFF4DB6AC), // 灰湖綠
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

  bool get _isModified {
    final currentTitle = _titleController.text.trim();
    final currentContent = _contentController.text;
    
    bool strokesChanged = false;
    if (_strokes.length != widget.note.strokes.length) {
      strokesChanged = true;
    } else {
      for (int i = 0; i < _strokes.length; i++) {
        if (_strokes[i].points.length != widget.note.strokes[i].points.length ||
            _strokes[i].color != widget.note.strokes[i].color ||
            _strokes[i].strokeWidth != widget.note.strokes[i].strokeWidth ||
            _strokes[i].isHighlighter != widget.note.strokes[i].isHighlighter) {
          strokesChanged = true;
          break;
        }
      }
    }

    return currentTitle != widget.note.title ||
        currentContent != widget.note.content ||
        _currentCategory != widget.note.category ||
        strokesChanged;
  }

  void _autoSave() {
    widget.note.title = _titleController.text.trim();
    widget.note.content = _contentController.text;
    widget.note.category = _currentCategory;
    widget.note.strokes = List.from(_strokes);
    widget.note.updatedAt = DateTime.now();
  }

  Future<bool> _showExitConfirmationDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.save_outlined, color: Color(0xFF8D6E63)),
            SizedBox(width: 8),
            Text('儲存確認'),
          ],
        ),
        content: const Text('您已修改筆記內容，是否要儲存變更？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('繼續編輯', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (widget.note.title.isEmpty &&
                  widget.note.content.isEmpty &&
                  widget.note.strokes.isEmpty) {
                NotesDatabase.notes.remove(widget.note);
              }
              Navigator.pop(ctx, 'discard');
            },
            child: const Text('捨棄變更', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8D6E63),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              _autoSave();
              Navigator.pop(ctx, 'save');
            },
            child: const Text('儲存並返回'),
          ),
        ],
      ),
    );

    if (!mounted) return false;
    final messenger = ScaffoldMessenger.of(context);

    if (result == 'save') {
      messenger.showSnackBar(
        const SnackBar(content: Text('筆記已儲存 ✨'), duration: Duration(milliseconds: 800)),
      );
      return true;
    } else if (result == 'discard') {
      messenger.showSnackBar(
        const SnackBar(content: Text('已捨棄變更 ↩️'), duration: Duration(milliseconds: 800)),
      );
      return true;
    }
    return false;
  }

  Future<bool> _onWillPop() async {
    if (_isBlank) {
      NotesDatabase.notes.remove(widget.note);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已自動捨棄空白筆記 🗑️'), duration: Duration(milliseconds: 800)),
      );
      return true;
    }

    if (_isModified) {
      return await _showExitConfirmationDialog();
    }

    return true;
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
      final newText = textVal.replaceRange(selection.start, selection.end, '**$selectedText**');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + 2 + selectedText.length + 2),
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
    
    final currentLine = textVal.substring(lineStart, start);
    if (currentLine.startsWith('# ')) {
      final newText = textVal.replaceRange(lineStart, lineStart + 2, '');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start - 2),
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
    
    final currentLine = textVal.substring(lineStart, start);
    if (currentLine.startsWith('## ')) {
      final newText = textVal.replaceRange(lineStart, lineStart + 3, '');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start - 3),
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
    
    final currentLine = textVal.substring(lineStart, start);
    if (currentLine.startsWith('- ')) {
      final newText = textVal.replaceRange(lineStart, lineStart + 2, '');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start - 2),
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
    
    if (selection.isValid && !selection.isCollapsed) {
      final selectedText = textVal.substring(selection.start, selection.end);
      final newText = textVal.replaceRange(selection.start, selection.end, '[color=$colorHex]$selectedText[/color]');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + 15 + selectedText.length + 8),
      );
    } else {
      final start = selection.isValid ? selection.start : textVal.length;
      final newText = textVal.replaceRange(start, start, '[color=$colorHex][/color]');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + 15),
      );
    }
  }

  // ==========================================
  // 畫布動作手勢與控制 (Canvas Gesture Actions)
  // ==========================================
  void _onStrokeStart(Offset localPos) {
    _saveToUndoStack();
    _redoStack.clear();
    
    Color strokeColor = _isEraser 
        ? const Color(0xFFFAFAFA) 
        : (_isHighlighter ? _selectedColor.withValues(alpha: 0.35) : _selectedColor);

    setState(() {
      _strokes.add(
        Stroke(
          points: [localPos],
          color: strokeColor,
          strokeWidth: _isHighlighter ? 18.0 : _strokeWidth, // 螢光重點筆使用固定粗筆觸
          isEraser: _isEraser,
          isHighlighter: _isHighlighter,
        ),
      );
    });
  }

  void _onStrokeUpdate(Offset localPos) {
    if (_strokes.isEmpty) return;
    setState(() {
      final lastStroke = _strokes.last;
      final updatedPoints = List<Offset>.from(lastStroke.points)..add(localPos);
      _strokes[_strokes.length - 1] = Stroke(
        points: updatedPoints,
        color: lastStroke.color,
        strokeWidth: lastStroke.strokeWidth,
        isEraser: lastStroke.isEraser,
        isHighlighter: lastStroke.isHighlighter,
      );
    });
  }

  void _saveToUndoStack() {
    _undoStack.add(List.from(_strokes));
    if (_undoStack.length > 30) _undoStack.removeAt(0);
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _redoStack.add(List.from(_strokes));
      _strokes = _undoStack.removeLast();
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(List.from(_strokes));
      _strokes = _redoStack.removeLast();
    });
  }

  void _clearCanvas() {
    if (_strokes.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空手寫板'),
        content: const Text('確定要清除所有繪圖與螢光筆軌跡線條嗎？文字記錄會完整保留。'),
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
              _saveToUndoStack();
              _redoStack.clear();
              setState(() {
                _strokes.clear();
              });
              Navigator.pop(ctx);
            },
            child: const Text('確定清除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final shouldPop = await _onWillPop();
        if (shouldPop) {
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F2EE), // 精緻淡雅紙板背景色
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final shouldPop = await _onWillPop();
              if (shouldPop) {
                navigator.pop();
              }
            },
          ),
          title: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _currentCategory,
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF8D6E63)),
              style: const TextStyle(
                color: Color(0xFF8D6E63),
                fontWeight: FontWeight.bold,
                fontSize: 14,
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
                    child: Text('分類: $cat'),
                  );
                }),
                const DropdownMenuItem<String>(
                  value: '__add_new__',
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 16, color: Colors.green),
                      SizedBox(width: 4),
                      Text('新增分類標籤', style: TextStyle(color: Colors.green)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save, color: Color(0xFF8D6E63)),
              tooltip: '儲存筆記',
              onPressed: () {
                _autoSave();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('筆記已儲存 ✨'), duration: Duration(seconds: 1)),
                );
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF8D6E63),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF8D6E63),
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.keyboard_outlined, size: 16),
                    SizedBox(width: 4),
                    Text('文字紀錄'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.gesture_outlined, size: 16),
                    SizedBox(width: 4),
                    Text('手寫塗鴉'),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
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
              const Divider(height: 1, color: Color(0xFFEFEBE9)),

              // 2. Tab 內容切換
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(), // 避免手勢衝突
                  children: [
                    // --- A. 文字紀錄頁面 (寬敞滿版) ---
                    Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
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
                      child: Column(
                        children: [
                          // 筆記打字本體 (帶有橫線底圖)
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: PaperBackgroundPainter(),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.fromLTRB(48, 16, 20, 16),
                                      child: TextField(
                                        controller: _contentController,
                                        focusNode: _contentFocusNode,
                                        maxLines: null,
                                        keyboardType: TextInputType.multiline,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.71, // 配合行格高度 (24.0px 行高)
                                          color: Colors.black87,
                                        ),
                                        decoration: const InputDecoration(
                                          hintText: '在此輸入文字內容...\n可以使用下方格式工具列。',
                                          hintStyle: TextStyle(color: Colors.black26),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // 打字格式工具列
                          _buildFormattingToolbar(),
                        ],
                      ),
                    ),

                    // --- B. 手寫畫布頁面 (寬敞滿版) ---
                    Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
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
                      child: Column(
                        children: [
                          // 手寫畫布本體 (以微格子作為底圖)
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Container(
                                      color: const Color(0xFFFAF9F6), // 極淡象牙白
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: DrawingCanvas(
                                      strokes: _strokes,
                                      onStrokeStart: _onStrokeStart,
                                      onStrokeUpdate: _onStrokeUpdate,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // 畫筆調色盤工具列
                          _buildDrawingToolbar(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.format_bold, color: Color(0xFF5D4037), size: 20),
                tooltip: '粗體',
                onPressed: _toggleBold,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.title, color: Color(0xFF5D4037), size: 20),
                tooltip: '大標頭 H1',
                onPressed: _toggleH1,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.text_fields, color: Color(0xFF5D4037), size: 20),
                tooltip: '次標頭 H2',
                onPressed: _toggleH2,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.format_list_bulleted, color: Color(0xFF5D4037), size: 20),
                tooltip: '列點',
                onPressed: _toggleBullet,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.format_indent_increase, color: Color(0xFF5D4037), size: 20),
                tooltip: '縮排',
                onPressed: _toggleIndent,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 打字字色選擇調色盤 (莫蘭迪色系)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('字色: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ..._morandiPalette.map((color) {
                  return GestureDetector(
                    onTap: () => _applyTextColor(color),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 🎨 B. 畫筆調色盤工具列 Widget
  // ==========================================
  Widget _buildDrawingToolbar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEFEBE9), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 畫筆主要控制 (Undo, Redo, Eraser, Highlighter)
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.undo, size: 20),
                color: _undoStack.isNotEmpty ? Colors.black87 : Colors.grey.shade300,
                onPressed: _undoStack.isNotEmpty ? _undo : null,
                tooltip: '復原',
              ),
              IconButton(
                icon: const Icon(Icons.redo, size: 20),
                color: _redoStack.isNotEmpty ? Colors.black87 : Colors.grey.shade300,
                onPressed: _redoStack.isNotEmpty ? _redo : null,
                tooltip: '重做',
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, size: 20, color: Colors.redAccent),
                onPressed: _strokes.isNotEmpty ? _clearCanvas : null,
                tooltip: '清空手寫筆跡',
              ),
              const Spacer(),
              // 鋼筆 / 螢光筆切換
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isHighlighter = !_isHighlighter;
                    _isEraser = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isHighlighter
                        ? Colors.yellow.shade100
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isHighlighter ? Colors.orange.shade300 : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.border_color,
                        size: 14,
                        color: _isHighlighter ? Colors.orange.shade800 : Colors.black87,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '螢光筆重點',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _isHighlighter ? FontWeight.bold : FontWeight.normal,
                          color: _isHighlighter ? Colors.orange.shade800 : Colors.black87,
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 橡皮擦切換
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isEraser = !_isEraser;
                    _isHighlighter = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isEraser ? const Color(0xFF8D6E63).withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isEraser ? const Color(0xFF8D6E63) : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cleaning_services_outlined,
                        size: 14,
                        color: _isEraser ? const Color(0xFF8D6E63) : Colors.black87,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '橡皮擦',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _isEraser ? FontWeight.bold : FontWeight.normal,
                          color: _isEraser ? const Color(0xFF8D6E63) : Colors.black87,
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 12),
          // 畫筆粗細與調色盤
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 筆觸粗細 (只有鋼筆模式需要調整粗細，螢光筆固定大筆觸)
              if (!_isHighlighter && !_isEraser)
                Row(
                  children: [
                    const Text('筆觸: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFF8D6E63),
                          thumbColor: const Color(0xFF8D6E63),
                          trackHeight: 2.0,
                        ),
                        child: Slider(
                          value: _strokeWidth,
                          min: 1.0,
                          max: 15.0,
                          onChanged: (v) => setState(() => _strokeWidth = v),
                        ),
                      ),
                    ),
                    Text('${_strokeWidth.toInt()}px', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              const SizedBox(height: 4),
              // 調色盤
              Row(
                children: [
                  const Text('色彩: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _morandiPalette.map((color) {
                          final isSelected = _selectedColor == color && !_isEraser;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedColor = color;
                                _isEraser = false;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.orange : Colors.grey.shade300,
                                  width: isSelected ? 3 : 1,
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
            ],
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
              backgroundColor: const Color(0xFF8D6E63),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('🎉 已新增並套用分類「$newCat」！')),
                );
              }
            },
            child: const Text('新增並套用'),
          ),
        ],
      ),
    );
  }
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
        canvas.drawCircle(stroke.points.first, stroke.strokeWidth / 2, paint..style = PaintingStyle.fill);
      } else {
        final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
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
