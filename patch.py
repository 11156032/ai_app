import re

with open(r'c:\Users\user\ai_app\lib\screens\main_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

picker_widget = '''
class _OrganizeNotePickerWidget extends StatefulWidget {
  final Function(String) onSelected;
  const _OrganizeNotePickerWidget({required this.onSelected});
  @override
  State<_OrganizeNotePickerWidget> createState() => _OrganizeNotePickerWidgetState();
}
class _OrganizeNotePickerWidgetState extends State<_OrganizeNotePickerWidget> {
  String _search = '';
  @override
  Widget build(BuildContext context) {
    var notes = NotesDatabase.notes.where((n) => n.title.contains(_search)).toList();
    if (notes.isEmpty && NotesDatabase.notes.isEmpty) {
        notes = [Note(id: '1', userId: 'u1', title: '歡迎使用智慧圖文筆記本', content: '...', category: '學習', strokes: [], updatedAt: DateTime.now())];
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 14, left: 16, right: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜尋筆記標題...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0)
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          if (notes.isEmpty)
             const Padding(padding: EdgeInsets.all(16), child: Text('找不到筆記', style: TextStyle(color: Colors.grey))),
          ...notes.take(5).map((n) => ListTile(
            leading: const Icon(Icons.note, color: Color(0xFF8D6E63)),
            title: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(n.category, style: const TextStyle(fontSize: 12)),
            onTap: () => widget.onSelected(n.title),
          )),
        ]
      )
    );
  }
}
'''

result_widget = '''
class _OrganizedNoteResultWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onReplace;
  final VoidCallback onSaveNew;
  final VoidCallback onImport;
  
  const _OrganizedNoteResultWidget({
    super.key,
    required this.data,
    required this.onReplace,
    required this.onSaveNew,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14, left: 16, right: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8D6E63).withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('已整理：${data['selected_note_title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ]
          ),
          const Divider(height: 24),
          const Text('📝 筆記摘要', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8D6E63))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
            child: const Text('• 本篇重點：介紹了基本概念與應用場景\\n• 待辦事項：複習第二章、完成課後練習\\n• 核心架構：分為三個主要步驟進行', style: TextStyle(fontSize: 13, height: 1.6)),
          ),
          const SizedBox(height: 16),
          const Text('💡 關聯測驗題 (共 2 題)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8D6E63))),
          const SizedBox(height: 8),
          const Text('1. 根據筆記，核心架構分為幾個步驟？\\n   (A) 二個 (B) 三個 (C) 四個\\n2. 以下何者為待辦事項？\\n   (A) 撰寫報告 (B) 複習第二章 (C) 參加會議', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.add_to_photos, size: 14),
                label: const Text('附加', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D4C41), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8)),
                onPressed: onReplace,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save, size: 14),
                label: const Text('新筆記', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8D6E63), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8)),
                onPressed: onSaveNew,
              ),
            ]
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.download, size: 14),
              label: const Text('匯入測驗題庫'),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF8D6E63), side: const BorderSide(color: Color(0xFF8D6E63))),
              onPressed: onImport,
            )
          )
        ]
      )
    );
  }
}
'''

if '_OrganizeNotePickerWidget' not in content:
    content += '\n' + picker_widget + '\n' + result_widget + '\n'

insert_block = '''
                          if (msg['widgetType'] == 'organize_note_picker') {
                            return _OrganizeNotePickerWidget(
                              onSelected: (title) => _handleAISubmit(title, modalController, setModalState)
                            );
                          }
                          
                          if (msg['widgetType'] == 'organized_note_result') {
                            return _OrganizedNoteResultWidget(
                              data: msg['pendingData'] ?? {},
                              onReplace: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('確認附加'),
                                    content: const Text('確定要將大綱加入原筆記的最上方嗎？'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          final title = msg['pendingData']['selected_note_title'];
                                          final idx = NotesDatabase.notes.indexWhere((n) => n.title == title);
                                          if (idx != -1) {
                                            NotesDatabase.notes[idx].content = '# AI 整理大綱\\n• 本篇重點：介紹了基本概念與應用場景\\n• 待辦事項：複習第二章、完成課後練習\\n\\n---\\n\\n' + NotesDatabase.notes[idx].content;
                                          }
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已成功附加！')));
                                          _changePage(5, '筆記本');
                                          Navigator.pop(context);
                                        },
                                        child: const Text('確定')
                                      )
                                    ]
                                  )
                                );
                              },
                              onSaveNew: () {
                                final newNote = Note(
                                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                                  userId: widget.currentUser['id'],
                                  title: '${msg['pendingData']['selected_note_title'] ?? ''} (AI整理)',
                                  content: '# AI 整理大綱\\n• 本篇重點：介紹了基本概念與應用場景\\n• 待辦事項：複習第二章、完成課後練習\\n• 核心架構：分為三個主要步驟進行',
                                  category: 'AI 整理',
                                  strokes: [],
                                  updatedAt: DateTime.now()
                                );
                                NotesDatabase.notes.insert(0, newNote);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已儲存為新筆記！')));
                                _changePage(5, '筆記本');
                                Navigator.pop(context);
                              },
                              onImport: () {
                                final q1 = {
                                  'subject': 'AI 生成',
                                  'difficulty': '中',
                                  'question': '根據筆記，核心架構分為幾個步驟？',
                                  'options': ['二個', '三個', '四個'],
                                  'answerIndex': 1,
                                  'explanation': '筆記重點指出核心架構分為三個主要步驟進行。'
                                };
                                final q2 = {
                                  'subject': 'AI 生成',
                                  'difficulty': '易',
                                  'question': '以下何者為待辦事項？',
                                  'options': ['撰寫報告', '複習第二章', '參加會議'],
                                  'answerIndex': 1,
                                  'explanation': '筆記中的待辦事項有明確列出：複習第二章。'
                                };
                                setState(() {
                                  questionBank.addAll([q1, q2]);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 已成功匯入 2 題測驗至題庫！')));
                              }
                            );
                          }
'''
if 'organize_note_picker' not in content and 'confirm_post' in content:
    content = content.replace("if (msg['widgetType'] == 'confirm_post') {", insert_block + "\n                          if (msg['widgetType'] == 'confirm_post') {")

with open(r'c:\Users\user\ai_app\lib\screens\main_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Success')
