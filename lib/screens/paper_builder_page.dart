import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import 'question_edit_page.dart';
import 'ai_upload_paper_page.dart';
import 'question_set_detail_page.dart';

class PaperBuilderPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final List<Map<String, dynamic>> initialQuestions;
  final int? paperId; // optional: edit existing paper

  const PaperBuilderPage({
    super.key,
    required this.currentUser,
    this.initialQuestions = const [],
    this.paperId,
  });

  @override
  State<PaperBuilderPage> createState() => _PaperBuilderPageState();
}

class _PaperBuilderPageState extends State<PaperBuilderPage> {
  final TextEditingController _nameCtrl = TextEditingController();
  String _selectedSubject = '數學';
  List<Map<String, dynamic>> _paperQuestions = [];
  bool _loading = true;
  bool _saving = false;

  final List<String> _subjects = ['數學', '英文', '理化', '歷史', '國文', '地理', '其他'];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      if (widget.paperId != null) {
        // 1. Load Existing Paper
        final p = await DatabaseHelper.instance.getPaperById(widget.paperId!);
        if (p != null) {
          _nameCtrl.text = p['name']?.toString() ?? '';
          final qIds = await DatabaseHelper.instance.getQuestionIdsForPaper(widget.paperId!);
          if (qIds.isNotEmpty) {
            final db = await DatabaseHelper.instance.database;
            final placeholders = List.filled(qIds.length, '?').join(',');
            final rows = await db.rawQuery(
              'SELECT * FROM questions WHERE id IN ($placeholders)',
              qIds,
            );

            final Map<int, Map<String, dynamic>> map = {};
            for (final r in rows) {
              final id = int.tryParse(r['id'].toString()) ?? 0;
              final rawOpts = r['options'];
              final opts = rawOpts is String
                  ? (jsonDecode(rawOpts) as List<dynamic>? ?? [])
                  : (rawOpts as List<dynamic>? ?? []);

              map[id] = {
                'id': id,
                'question': (r['text'] ?? '').toString(),
                'options': opts.map((e) => e.toString()).toList(),
                'answerIndex': int.tryParse((r['answer'] ?? '0').toString()) ?? 0,
                'explanation': (r['explanation'] ?? '').toString(),
                'subject': r['subject'] ?? '一般',
                'difficulty': r['difficulty'] ?? '中',
                'type': r['type'] ?? '單選題',
              };
            }

            // Keep original paper question order
            final List<Map<String, dynamic>> ordered = [];
            for (final id in qIds) {
              if (map.containsKey(id)) {
                ordered.add(map[id]!);
              }
            }

            _paperQuestions = ordered;
            if (_paperQuestions.isNotEmpty) {
              final firstSub = _paperQuestions.first['subject']?.toString() ?? '';
              if (_subjects.contains(firstSub)) {
                _selectedSubject = firstSub;
              }
            }
          }
        }
      } else {
        // 2. Initial questions if passed
        _paperQuestions = List.from(widget.initialQuestions);
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      debugPrint('載入題本資料失敗: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // --- Actions ---

  // 1. 手動新增一題 (開啟 QuestionEditPage 並直接加回本題本)
  Future<void> _addNewQuestion() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionEditPage(
          currentUser: widget.currentUser,
          allSubjects: _subjects,
          subjectChapters: const {},
          initialData: {
            'subject': _selectedSubject,
          },
        ),
      ),
    );

    if (result != null) {
      // Reload latest questions by looking up the most recently added question or by ID
      final db = await DatabaseHelper.instance.database;
      final uid = (widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1').toString();
      final latestRows = await db.query(
        'questions',
        where: 'user_id = ?',
        whereArgs: [uid],
        orderBy: 'id DESC',
        limit: 1,
      );

      if (latestRows.isNotEmpty) {
        final r = latestRows.first;
        final id = int.tryParse(r['id'].toString()) ?? 0;
        final rawOpts = r['options'];
        final opts = rawOpts is String
            ? (jsonDecode(rawOpts) as List<dynamic>? ?? [])
            : (rawOpts as List<dynamic>? ?? []);

        final newQ = {
          'id': id,
          'question': (r['text'] ?? '').toString(),
          'options': opts.map((e) => e.toString()).toList(),
          'answerIndex': int.tryParse((r['answer'] ?? '0').toString()) ?? 0,
          'explanation': (r['explanation'] ?? '').toString(),
          'subject': r['subject'] ?? _selectedSubject,
          'difficulty': r['difficulty'] ?? '中',
          'type': r['type'] ?? '單選題',
        };

        if (!_paperQuestions.any((q) => q['id'] == id)) {
          setState(() {
            _paperQuestions.add(newQ);
          });
        }
      }
    }
  }

  // 2. 從題庫挑選加入 (收納式彈窗 BottomSheet)
  Future<void> _showPickFromBankDialog() async {
    final db = await DatabaseHelper.instance.database;
    final allRows = await db.query('questions', orderBy: 'created_at DESC');

    final existingIds = _paperQuestions.map((q) => q['id'] as int).toSet();
    final Set<int> newlySelectedIds = {};

    String searchKeyword = '';
    String filterSub = '全部';

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = allRows.where((r) {
              final id = int.tryParse(r['id'].toString()) ?? 0;
              if (existingIds.contains(id)) return false; // Already in paper

              final sub = r['subject']?.toString() ?? '一般';
              if (filterSub != '全部' && sub != filterSub) return false;

              final text = (r['text'] ?? '').toString().toLowerCase();
              if (searchKeyword.isNotEmpty && !text.contains(searchKeyword.toLowerCase())) {
                return false;
              }
              return true;
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '從題庫挑選題目',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Search Bar
                  TextField(
                    decoration: InputDecoration(
                      hintText: '搜尋題目關鍵字...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        searchKeyword = val.trim();
                      });
                    },
                  ),
                  const SizedBox(height: 10),

                  // Subject Choice Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['全部', ..._subjects].map((s) {
                        final isSel = filterSub == s;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(s),
                            selected: isSel,
                            onSelected: (val) {
                              if (val) {
                                setModalState(() => filterSub = s);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(height: 20),

                  // Questions List
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('沒有符合條件或尚未加入的題目'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, idx) {
                              final r = filtered[idx];
                              final id = int.tryParse(r['id'].toString()) ?? 0;
                              final isChecked = newlySelectedIds.contains(id);
                              final text = (r['text'] ?? '').toString();
                              final sub = r['subject'] ?? '一般';

                              return CheckboxListTile(
                                value: isChecked,
                                activeColor: Theme.of(context).primaryColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                title: Text(
                                  text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text('學科：$sub', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                                onChanged: (val) {
                                  setModalState(() {
                                    if (val == true) {
                                      newlySelectedIds.add(id);
                                    } else {
                                      newlySelectedIds.remove(id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),

                  // Bottom Confirm Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: newlySelectedIds.isEmpty
                          ? null
                          : () {
                              for (final id in newlySelectedIds) {
                                final row = allRows.firstWhere((r) => int.tryParse(r['id'].toString()) == id);
                                final rawOpts = row['options'];
                                final opts = rawOpts is String
                                    ? (jsonDecode(rawOpts) as List<dynamic>? ?? [])
                                    : (rawOpts as List<dynamic>? ?? []);

                                _paperQuestions.add({
                                  'id': id,
                                  'question': (row['text'] ?? '').toString(),
                                  'options': opts.map((e) => e.toString()).toList(),
                                  'answerIndex': int.tryParse((row['answer'] ?? '0').toString()) ?? 0,
                                  'explanation': (row['explanation'] ?? '').toString(),
                                  'subject': row['subject'] ?? '一般',
                                  'difficulty': row['difficulty'] ?? '中',
                                  'type': row['type'] ?? '單選題',
                                });
                              }
                              setState(() {});
                              Navigator.pop(ctx);
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('確認加入 (${newlySelectedIds.length} 題)', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 3. AI 拍照追加 (呼叫 AiUploadPaperPage)
  Future<void> _aiScanAndAppend() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AiUploadPaperPage(
          currentUser: widget.currentUser,
          allSubjects: _subjects,
          subjectChapters: const {},
        ),
      ),
    );

    if (result == true) {
      // Reload newly created questions
      final db = await DatabaseHelper.instance.database;
      final uid = (widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1').toString();
      final papers = await DatabaseHelper.instance.getPapersForUser(uid);
      if (papers.isNotEmpty) {
        final latestPaper = papers.first;
        final pid = int.tryParse(latestPaper['id'].toString()) ?? 0;
        final qIds = await DatabaseHelper.instance.getQuestionIdsForPaper(pid);
        for (final qId in qIds) {
          if (!_paperQuestions.any((q) => q['id'] == qId)) {
            final rows = await db.query('questions', where: 'id = ?', whereArgs: [qId]);
            if (rows.isNotEmpty) {
              final r = rows.first;
              final rawOpts = r['options'];
              final opts = rawOpts is String
                  ? (jsonDecode(rawOpts) as List<dynamic>? ?? [])
                  : (rawOpts as List<dynamic>? ?? []);

              _paperQuestions.add({
                'id': qId,
                'question': (r['text'] ?? '').toString(),
                'options': opts.map((e) => e.toString()).toList(),
                'answerIndex': int.tryParse((r['answer'] ?? '0').toString()) ?? 0,
                'explanation': (r['explanation'] ?? '').toString(),
                'subject': r['subject'] ?? '一般',
                'difficulty': r['difficulty'] ?? '中',
                'type': r['type'] ?? '單選題',
              });
            }
          }
        }
        setState(() {});
      }
    }
  }

  // 4. 儲存題本
  Future<void> _savePaper() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入題本名稱')),
      );
      return;
    }

    if (_paperQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('題本內至少需要包含一道題目')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final uid = (widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1').toString();
      final List<int> questionIds = _paperQuestions.map((q) => q['id'] as int).toList();

      int finalPaperId;
      if (widget.paperId != null) {
        await DatabaseHelper.instance.updatePaper(widget.paperId!, name, questionIds);
        finalPaperId = widget.paperId!;
      } else {
        finalPaperId = await DatabaseHelper.instance.createPaper(uid, name, questionIds);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('成功儲存題本「$name」！共 ${questionIds.length} 題。'),
          backgroundColor: Colors.green,
        ),
      );

      // Direct redirection to QuestionSetDetailPage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuestionSetDetailPage(
            currentUser: widget.currentUser,
            title: name,
            paperId: finalPaperId,
            allSubjects: _subjects,
            subjectChapters: const {},
          ),
        ),
      );
    } catch (e) {
      debugPrint('儲存題本錯誤: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('儲存失敗: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          widget.paperId == null ? '建立專屬題本' : '編輯題本',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                    children: [
                      // 1. Paper Meta Info Card
                      _buildPaperInfoCard(cs),
                      const SizedBox(height: 20),

                      // 2. Action Buttons (手動新增 / 題庫挑選 / AI 拍照)
                      _buildAddActionsRow(cs),
                      const SizedBox(height: 24),

                      // 3. Section Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: cs.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '題本收錄題目 (${_paperQuestions.length} 題)',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                          if (_paperQuestions.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _paperQuestions.clear();
                                });
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('清空題目', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 4. Questions List
                      if (_paperQuestions.isEmpty)
                        _buildEmptyQuestionsCard(cs)
                      else
                        ...List.generate(_paperQuestions.length, (index) {
                          final q = _paperQuestions[index];
                          return _buildQuestionCard(index, q, cs);
                        }),
                    ],
                  ),
                ),

                // 5. Fixed Bottom Save Bar
                _buildBottomSaveBar(cs),
              ],
            ),
    );
  }

  // --- Sub Widgets ---

  Widget _buildPaperInfoCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('題本名稱', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4B5563))),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              hintText: '例如：高二數學空間向量第一次複習...',
              prefixIcon: Icon(Icons.assignment_rounded, color: cs.primary),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('學科領域', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4B5563))),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _subjects.map((sub) {
                final isSelected = _selectedSubject == sub;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(sub),
                    selected: isSelected,
                    selectedColor: cs.primary.withValues(alpha: 0.15),
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(
                      color: isSelected ? cs.primary : const Color(0xFF374151),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: isSelected ? cs.primary : Colors.transparent),
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedSubject = sub);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddActionsRow(ColorScheme cs) {
    return Row(
      children: [
        // 1. 手動新增一題
        Expanded(
          child: _buildActionButton(
            label: '手動寫題',
            icon: Icons.edit_note_rounded,
            color: const Color(0xFF4F46E5),
            bgColor: const Color(0xFFEEF2FF),
            onTap: _addNewQuestion,
          ),
        ),
        const SizedBox(width: 8),
        // 2. 題庫挑選
        Expanded(
          child: _buildActionButton(
            label: '題庫挑選',
            icon: Icons.library_add_rounded,
            color: const Color(0xFFD97706),
            bgColor: const Color(0xFFFFFBEB),
            onTap: _showPickFromBankDialog,
          ),
        ),
        const SizedBox(width: 8),
        // 3. AI 拍照
        Expanded(
          child: _buildActionButton(
            label: 'AI 拍考卷',
            icon: Icons.auto_awesome_rounded,
            color: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFF5F3FF),
            onTap: _aiScanAndAppend,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyQuestionsCard(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.post_add_rounded, size: 44, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text(
            '題本目前尚未包含題目',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 4),
          Text(
            '點擊上方「手動寫題」、「題庫挑選」或「AI 拍考卷」加入題目！',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int index, Map<String, dynamic> q, ColorScheme cs) {
    final List<String> options = List<String>.from(q['options'] ?? []);
    final int ansIndex = q['answerIndex'] as int? ?? 0;
    final String explanation = q['explanation'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '第 ${index + 1} 題',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: cs.primary),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    q['subject'] ?? _selectedSubject,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                onPressed: () {
                  setState(() {
                    _paperQuestions.removeAt(index);
                  });
                },
                tooltip: '從題本移除',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Question Text
          Text(
            q['question'] ?? '',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),

          // Options List
          ...List.generate(options.length, (oIdx) {
            final isCorrect = oIdx == ansIndex;
            final char = String.fromCharCode(65 + oIdx);

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isCorrect ? const Color(0xFFECFDF5) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCorrect ? const Color(0xFF10B981) : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '$char. ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isCorrect ? const Color(0xFF059669) : Colors.grey.shade700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      options[oIdx],
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isCorrect ? const Color(0xFF065F46) : const Color(0xFF374151),
                        fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isCorrect)
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                ],
              ),
            );
          }),

          // Explanation
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Text(
                '解析：$explanation',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E), height: 1.3),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomSaveBar(ColorScheme cs) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 12, 18, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('目前收錄', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
              Text(
                '${_paperQuestions.length} 道題目',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _savePaper,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_rounded),
              label: Text(
                _saving ? '儲存中...' : (widget.paperId == null ? '建立並開始測驗' : '更新題本'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
