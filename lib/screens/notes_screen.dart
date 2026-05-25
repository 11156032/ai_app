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

  Stroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.isEraser = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'color': color.value,
      'strokeWidth': strokeWidth,
      'isEraser': isEraser,
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
    );
  }
}

// ==========================================
// 2. 筆記資料模型 (Note)
// ==========================================
class Note {
  String id;
  String title;
  String content;
  String category;
  List<Stroke> strokes;
  DateTime updatedAt;

  Note({
    required this.id,
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
  
  static List<Note> notes = [
    Note(
      id: 'note_1',
      title: '歡迎使用個人智慧筆記本 📝',
      content: '這是一個全新設計的筆記功能！\n\n'
          '✨ 功能重點：\n'
          '1. 【打字與手寫融合】：上方有兩個分頁，「文字紀錄」供您打字編寫，「手寫塗鴉」提供高靈敏的畫布，適合畫心智圖、架構草圖或簽名。\n'
          '2. 【筆記分類】：主頁上方有橫向過濾晶片，您可以點擊右側的設定按鈕管理自訂分類。\n'
          '3. 【質感設計】：全面使用質感高雅的莫蘭迪配色卡片，並具備自動儲存功能。\n\n'
          '快點選右下角浮動按鈕 ＋ 建立第一篇筆記，或點開下方「手寫塗鴉範例」試玩手寫板吧！🎨✍️',
      category: '生活',
      strokes: [],
      updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    Note(
      id: 'note_2',
      title: '手寫塗鴉與線條範例 🏠☀️',
      content: '點進本篇筆記後，切換至「手寫塗鴉」分頁即可看到用自訂線條畫成的小房屋與黃色暖陽！\n\n'
          '畫布支援：\n'
          '• 橡皮擦、復原（Undo）與重做（Redo）動作。\n'
          '• 精心挑選的 8 種高雅莫蘭迪氣質色彩。\n'
          '• 三種不同粗細的筆觸調整。',
      category: '學習',
      strokes: [
        // 屋頂 Red
        Stroke(
          points: [
            const Offset(130, 200),
            const Offset(200, 130),
            const Offset(270, 200),
          ],
          color: const Color(0xFFC62828),
          strokeWidth: 5.0,
        ),
        // 牆壁 Blue
        Stroke(
          points: [
            const Offset(150, 200),
            const Offset(150, 270),
            const Offset(250, 270),
            const Offset(250, 200),
            const Offset(150, 200),
          ],
          color: const Color(0xFF6B8A96),
          strokeWidth: 4.0,
        ),
        // 門 Brown
        Stroke(
          points: [
            const Offset(185, 270),
            const Offset(185, 230),
            const Offset(215, 230),
            const Offset(215, 270),
          ],
          color: const Color(0xFF8D6E63),
          strokeWidth: 4.0,
        ),
        // 門把
        Stroke(
          points: [const Offset(210, 250)],
          color: const Color(0xFFF57F17),
          strokeWidth: 6.0,
        ),
        // 太陽 Yellow
        Stroke(
          points: [
            const Offset(290, 110),
            const Offset(305, 95),
            const Offset(320, 110),
            const Offset(305, 125),
            const Offset(290, 110),
          ],
          color: const Color(0xFFF57F17),
          strokeWidth: 4.0,
        ),
        // 太陽光芒
        Stroke(
          points: [const Offset(305, 85), const Offset(305, 75)],
          color: const Color(0xFFF57F17),
          strokeWidth: 3.0,
        ),
        Stroke(
          points: [const Offset(330, 110), const Offset(340, 110)],
          color: const Color(0xFFF57F17),
          strokeWidth: 3.0,
        ),
        Stroke(
          points: [const Offset(305, 135), const Offset(305, 145)],
          color: const Color(0xFFF57F17),
          strokeWidth: 3.0,
        ),
      ],
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];
}

// ==========================================
// 4. 筆記主畫面 (NotesScreen)
// ==========================================
class NotesScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;

  const NotesScreen({super.key, required this.currentUser});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String _selectedCategory = '全部';

  void _refresh() {
    if (mounted) setState(() {});
  }

  // 取得篩選後的筆記
  List<Note> get _filteredNotes {
    if (_selectedCategory == '全部') {
      return NotesDatabase.notes;
    }
    return NotesDatabase.notes
        .where((note) => note.category == _selectedCategory)
        .toList();
  }

  // 計算每個分類的筆記數
  int _getNoteCount(String category) {
    if (category == '全部') {
      return NotesDatabase.notes.length;
    }
    return NotesDatabase.notes.where((note) => note.category == category).length;
  }

  // 刪除筆記
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

  // 開啟分類管理面板
  void _showCategoryManagementDialog() {
    TextEditingController addController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('管理分類標籤'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 新增分類輸入框
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: addController,
                          decoration: const InputDecoration(
                            hintText: '輸入新分類名稱',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8D6E63),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onPressed: () {
                          final newCat = addController.text.trim();
                          if (newCat.isNotEmpty &&
                              !NotesDatabase.categories.contains(newCat)) {
                            setDialogState(() {
                              NotesDatabase.categories.add(newCat);
                            });
                            setState(() {});
                            addController.clear();
                          }
                        },
                        child: const Text('新增'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '目前分類標籤（點擊垃圾桶刪除）：',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 分類列表
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: NotesDatabase.categories.length,
                      itemBuilder: (context, index) {
                        final cat = NotesDatabase.categories[index];
                        final isSystem = cat == '全部' || cat == '未分類';
                        return ListTile(
                          title: Text(cat, style: const TextStyle(fontSize: 14)),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          trailing: isSystem
                              ? const Icon(Icons.lock_outline, size: 16, color: Colors.grey)
                              : IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent, size: 18),
                                  onPressed: () {
                                    setDialogState(() {
                                      NotesDatabase.categories.remove(cat);
                                      // 將該分類的筆記重設為 '未分類'
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
                                  },
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('完成'),
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
      backgroundColor: const Color(0xFFF8F6F4), // 極淡暖灰色背景，呼應莫蘭迪色系
      body: Column(
        children: [
          // 頂部橫向滾動分類導覽晶片 (Chips)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
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
                    color: const Color(0xFF8D6E63).withOpacity(0.1),
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
                      // 莫蘭迪柔和配色庫，依 ID 取餘數決定配色
                      final cardColors = [
                        const Color(0xFFE8ECE9), // 青灰
                        const Color(0xFFF1EAE4), // 暖杏
                        const Color(0xFFE5ECEF), // 藍灰
                        const Color(0xFFEAE5EF), // 淡紫
                        const Color(0xFFEFECE5), // 淺茶
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
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ],
                            border: Border.all(
                              color: Colors.black.withOpacity(0.05),
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 分類與選單按鈕
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8D6E63).withOpacity(0.12),
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
                                  // 有手寫軌跡就顯示畫筆圖案
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
                              // 標題
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
                              // 內容預覽
                              Expanded(
                                child: Text(
                                  note.content.isEmpty ? '（空白筆記內容）' : note.content,
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
                              // 更新時間
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
          // 新增一篇空白筆記
          final newNote = Note(
            id: 'note_${DateTime.now().millisecondsSinceEpoch}',
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
// 5. 多功能筆記編輯器 (NoteEditorScreen)
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
  late TextEditingController _contentController;
  late String _currentCategory;

  // 畫布狀態
  List<Stroke> _strokes = [];
  final List<List<Stroke>> _undoStack = [];
  final List<List<Stroke>> _redoStack = [];

  // 畫筆控制
  Color _selectedColor = const Color(0xFF37474F); // 預設深灰炭黑
  double _strokeWidth = 4.0;
  bool _isEraser = false;

  // 莫蘭迪高雅色系調色盤
  final List<Color> _morandiPalette = [
    const Color(0xFF37474F), // 炭灰
    const Color(0xFF8D6E63), // 暖棕
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
    _contentController = TextEditingController(text: widget.note.content);
    _currentCategory = NotesDatabase.categories.contains(widget.note.category)
        ? widget.note.category
        : '未分類';

    // 複製現有筆記畫布線條，避免直接操作原參考
    _strokes = List.from(widget.note.strokes);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // 執行自動存檔
  void _autoSave() {
    widget.note.title = _titleController.text.trim();
    widget.note.content = _contentController.text;
    widget.note.category = _currentCategory;
    widget.note.strokes = List.from(_strokes);
    widget.note.updatedAt = DateTime.now();
  }

  // 返回上一頁並自動存檔
  Future<bool> _onWillPop() async {
    _autoSave();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已自動儲存筆記 ✨'),
        duration: Duration(milliseconds: 800),
      ),
    );
    return true;
  }

  // 畫布操作：新增線條
  void _onStrokeStart(Offset localPos) {
    _saveToUndoStack();
    _redoStack.clear();
    setState(() {
      _strokes.add(
        Stroke(
          points: [localPos],
          color: _isEraser ? const Color(0xFFFAFAFA) : _selectedColor,
          strokeWidth: _strokeWidth,
          isEraser: _isEraser,
        ),
      );
    });
  }

  void _onStrokeUpdate(Offset localPos) {
    if (_strokes.isEmpty) return;
    setState(() {
      // 由於 Stroke points 是 final/不可變，我們必須重置點名單
      final lastStroke = _strokes.last;
      final updatedPoints = List<Offset>.from(lastStroke.points)..add(localPos);
      _strokes[_strokes.length - 1] = Stroke(
        points: updatedPoints,
        color: lastStroke.color,
        strokeWidth: lastStroke.strokeWidth,
        isEraser: lastStroke.isEraser,
      );
    });
  }

  // 儲存至復原堆疊
  void _saveToUndoStack() {
    _undoStack.add(List.from(_strokes));
    if (_undoStack.length > 30) {
      _undoStack.removeAt(0); // 限制最多復原 30 步，避免佔用過多記憶體
    }
  }

  // 復原
  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _redoStack.add(List.from(_strokes));
      _strokes = _undoStack.removeLast();
    });
  }

  // 重做
  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(List.from(_strokes));
      _strokes = _redoStack.removeLast();
    });
  }

  // 清空畫布
  void _clearCanvas() {
    if (_strokes.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空手寫板'),
        content: const Text('確定要清除畫布上的所有軌跡線條嗎？'),
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
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
            onPressed: () {
              _autoSave();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已自動儲存筆記 ✨'),
                  duration: Duration(milliseconds: 800),
                ),
              );
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
                    // 彈出新增分類對話框
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
              tooltip: '手動儲存',
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
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.keyboard_outlined, size: 18),
                    SizedBox(width: 6),
                    Text('文字紀錄'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.gesture_outlined, size: 18),
                    SizedBox(width: 6),
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
              // 無縫無框 標題 TextField (常駐頂部)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: TextField(
                  controller: _titleController,
                  style: const TextStyle(
                    fontSize: 20,
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Divider(height: 16),
              ),

              // Tab 內容切換
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(), // 避免畫布繪製與滑動衝突
                  children: [
                    // --- 1. 文字編輯分頁 ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: TextField(
                        controller: _contentController,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                        decoration: const InputDecoration(
                          hintText: '在此輸入詳細文字內容...\n• 返回頁面會自動為您存檔',
                          hintStyle: TextStyle(color: Colors.black26),
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    // --- 2. 手寫畫布分頁 ---
                    Column(
                      children: [
                        // 畫筆控制工具面板
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: Colors.white,
                          child: Row(
                            children: [
                              // 復原 Undo
                              IconButton(
                                icon: const Icon(Icons.undo, size: 20),
                                color: _undoStack.isNotEmpty ? Colors.black87 : Colors.grey.shade300,
                                onPressed: _undoStack.isNotEmpty ? _undo : null,
                                tooltip: '復原 (Undo)',
                              ),
                              // 重做 Redo
                              IconButton(
                                icon: const Icon(Icons.redo, size: 20),
                                color: _redoStack.isNotEmpty ? Colors.black87 : Colors.grey.shade300,
                                onPressed: _redoStack.isNotEmpty ? _redo : null,
                                tooltip: '重做 (Redo)',
                              ),
                              // 清空 Clear
                              IconButton(
                                icon: const Icon(Icons.delete_sweep_outlined, size: 20, color: Colors.redAccent),
                                onPressed: _strokes.isNotEmpty ? _clearCanvas : null,
                                tooltip: '清空畫布',
                              ),
                              const Spacer(),
                              // 橡皮擦切換
                              GestureDetector(
                                onTap: () => setState(() => _isEraser = !_isEraser),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _isEraser
                                        ? const Color(0xFF8D6E63).withOpacity(0.2)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _isEraser ? const Color(0xFF8D6E63) : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.cleaning_services_outlined,
                                        size: 16,
                                        color: _isEraser ? const Color(0xFF8D6E63) : Colors.black87,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '橡皮擦',
                                        style: TextStyle(
                                          fontSize: 12,
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
                        ),

                        // 粗細與顏色設定條
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 畫筆粗細
                              Row(
                                children: [
                                  const Text('粗細: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: const Color(0xFF8D6E63),
                                        thumbColor: const Color(0xFF8D6E63),
                                        overlayColor: const Color(0xFF8D6E63).withOpacity(0.12),
                                        trackHeight: 3.0,
                                      ),
                                      child: Slider(
                                        value: _strokeWidth,
                                        min: 1.0,
                                        max: 20.0,
                                        onChanged: (v) => setState(() => _strokeWidth = v),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${_strokeWidth.toInt()} px',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // 質感色票
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: _morandiPalette.map((color) {
                                    final isSelected = _selectedColor == color && !_isEraser;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedColor = color;
                                          _isEraser = false; // 選了顏色就自動關閉橡皮擦
                                        });
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 6),
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected ? Colors.orange : Colors.grey.shade300,
                                            width: isSelected ? 3 : 1,
                                          ),
                                          boxShadow: [
                                            if (isSelected)
                                              BoxShadow(
                                                color: Colors.orange.withOpacity(0.3),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                              )
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 手寫畫布本體
                        Expanded(
                          child: DrawingCanvas(
                            strokes: _strokes,
                            onStrokeStart: _onStrokeStart,
                            onStrokeUpdate: _onStrokeUpdate,
                          ),
                        ),
                      ],
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

  // 新增分類的對話框
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
                  NotesDatabase.categories.add(newCat);
                }
                setState(() {
                  _currentCategory = newCat;
                });
                Navigator.pop(ctx);
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
// 6. 手寫畫布 Widget (DrawingCanvas)
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
        color: const Color(0xFFFAFAFA), // 象牙白底
        child: CustomPaint(
          painter: StrokePainter(strokes: strokes),
        ),
      ),
    );
  }
}

// ==========================================
// 7. 自訂畫布渲染畫筆 (StrokePainter)
// ==========================================
class StrokePainter extends CustomPainter {
  final List<Stroke> strokes;

  StrokePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    // 限制畫筆超出畫布邊界
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    for (var stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      // 橡皮擦混合模式
      if (stroke.isEraser) {
        // 在 in-memory 渲染中，直接塗上背景色是最安全、最相容各種平台（包含 Web/CanvasKit）的方式
        paint.color = const Color(0xFFFAFAFA);
      }

      if (stroke.points.length == 1) {
        // 單點繪製
        canvas.drawCircle(stroke.points.first, stroke.strokeWidth / 2, paint..style = PaintingStyle.fill);
      } else {
        // 多點繪製 (用 Path 連接線條更流暢)
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
