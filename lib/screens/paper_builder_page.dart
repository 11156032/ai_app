import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import 'question_edit_page.dart';
import 'ai_upload_paper_page.dart';
import 'question_set_detail_page.dart';
import 'question_discussion_page.dart';
import '../services/app_locale_service.dart';

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
  final TextEditingController _searchCtrl = TextEditingController();

  String _selectedSubject = '全部';
  final Set<int> _selectedQuestionIds = {};
  List<Map<String, dynamic>> _allBankQuestions = [];
  bool _loading = true;
  bool _saving = false;
  String _searchKeyword = '';

  final List<String> _subjects = ['數學', '英文', '理化', '歷史', '國文', '地理', '其他'];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _initializeData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final allRows = await db.query('questions', orderBy: 'id DESC');

      final List<Map<String, dynamic>> formatted = [];
      for (final r in allRows) {
        final id = int.tryParse(r['id'].toString()) ?? 0;
        final rawOpts = r['options'];
        final opts = rawOpts is String
            ? (jsonDecode(rawOpts) as List<dynamic>? ?? [])
            : (rawOpts as List<dynamic>? ?? []);

        formatted.add({
          'id': id,
          'question': (r['text'] ?? '').toString(),
          'options': opts.map((e) => e.toString()).toList(),
          'answerIndex': int.tryParse((r['answer'] ?? '0').toString()) ?? 0,
          'explanation': (r['explanation'] ?? '').toString(),
          'subject': r['subject'] ?? '一般',
          'difficulty': r['difficulty'] ?? '中',
          'type': r['type'] ?? '單選題',
        });
      }

      _allBankQuestions = formatted;

      if (widget.paperId != null) {
        // 1. Edit existing paper
        final p = await DatabaseHelper.instance.getPaperById(widget.paperId!);
        if (p != null) {
          _nameCtrl.text = p['name']?.toString() ?? '';
          final qIds = await DatabaseHelper.instance.getQuestionIdsForPaper(widget.paperId!);
          _selectedQuestionIds.addAll(qIds);
        }
      } else {
        // 2. New paper
        if (widget.initialQuestions.isNotEmpty) {
          for (final q in widget.initialQuestions) {
            final qId = int.tryParse(q['id']?.toString() ?? '0') ?? 0;
            if (qId > 0) _selectedQuestionIds.add(qId);
          }
        }
        // Default auto-generated name
        final now = DateTime.now();
        _nameCtrl.text = tr('pb_default_name', [now.month.toString(), now.day.toString()]);
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      debugPrint('載入題庫失敗: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Color _getDifficultyColor(String diff) {
    switch (diff) {
      case '易':
        return const Color(0xFF10B981);
      case '中':
        return const Color(0xFFF59E0B);
      case '難':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  // 手動寫題
  Future<void> _addNewQuestion() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionEditPage(
          currentUser: widget.currentUser,
          allSubjects: _subjects,
          subjectChapters: const {},
          initialData: {
            'subject': _selectedSubject == '全部' ? '數學' : _selectedSubject,
          },
        ),
      ),
    );

    if (result == true) {
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
          'subject': r['subject'] ?? '一般',
          'difficulty': r['difficulty'] ?? '中',
          'type': r['type'] ?? '單選題',
        };

        setState(() {
          _allBankQuestions.insert(0, newQ);
          _selectedQuestionIds.add(id);
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
          SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text(tr('pb_added_auto')), backgroundColor: Colors.green),
        );
      }
    }
  }

  // AI 拍考卷
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
      final db = await DatabaseHelper.instance.database;
      final uid = (widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1').toString();
      final papers = await DatabaseHelper.instance.getPapersForUser(uid);
      if (papers.isNotEmpty) {
        final latestPaper = papers.first;
        final pid = int.tryParse(latestPaper['id'].toString()) ?? 0;
        final qIds = await DatabaseHelper.instance.getQuestionIdsForPaper(pid);
        for (final qId in qIds) {
          if (!_allBankQuestions.any((q) => q['id'] == qId)) {
            final rows = await db.query('questions', where: 'id = ?', whereArgs: [qId]);
            if (rows.isNotEmpty) {
              final r = rows.first;
              final rawOpts = r['options'];
              final opts = rawOpts is String
                  ? (jsonDecode(rawOpts) as List<dynamic>? ?? [])
                  : (rawOpts as List<dynamic>? ?? []);

              _allBankQuestions.insert(0, {
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
          _selectedQuestionIds.add(qId);
        }
        setState(() {});
        if (!mounted) return;
        ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
          SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text(tr('pb_ai_added')), backgroundColor: Colors.green),
        );
      }
    }
  }

  // 儲存題本
  Future<void> _savePaper() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
        SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text(tr('pb_need_name'))),
      );
      return;
    }

    if (_selectedQuestionIds.isEmpty) {
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
        SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text(tr('pb_need_q'))),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final uid = (widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1').toString();
      final List<int> questionIds = _selectedQuestionIds.toList();

      int finalPaperId;
      if (widget.paperId != null) {
        await DatabaseHelper.instance.updatePaper(widget.paperId!, name, questionIds);
        finalPaperId = widget.paperId!;
      } else {
        finalPaperId = await DatabaseHelper.instance.createPaper(uid, name, questionIds);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
        SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, 
          content: Text(tr('pb_saved', [name.toString(), questionIds.length.toString()])),
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
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
        SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text(tr('pb_save_failed', [e.toString()]))),
      );
    }
  }

  void _openDiscussion(Map<String, dynamic> question) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionDiscussionPage(
          questionData: question,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Filter questions by subject and search keyword
    final filtered = _allBankQuestions.where((q) {
      final sub = q['subject']?.toString() ?? '一般';
      if (_selectedSubject != '全部' && sub != _selectedSubject) return false;

      final text = (q['question'] ?? '').toString().toLowerCase();
      if (_searchKeyword.isNotEmpty && !text.contains(_searchKeyword.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    // Subject counts
    final Map<String, int> subjectCounts = {'全部': _allBankQuestions.length};
    for (final s in _subjects) {
      subjectCounts[s] = _allBankQuestions.where((q) => (q['subject']?.toString() ?? '一般') == s).length;
    }

    final isAllFilteredSelected = filtered.isNotEmpty &&
        filtered.every((q) => _selectedQuestionIds.contains(q['id'] as int));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.paperId == null ? tr('pb_title_new') : tr('pb_title_edit'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Color(0xFF334155)),
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF334155)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF4F46E5)),
            tooltip: tr('pb_manual_new'),
            onPressed: _addNewQuestion,
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF7C3AED)),
            tooltip: tr('pb_ai_snap'),
            onPressed: _aiScanAndAppend,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              children: [
                // ── 1. 題本名稱設定卡片 ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
                      Row(
                        children: [
                          Icon(Icons.assignment_rounded, size: 18, color: Color(0xFF4F46E5)),
                          SizedBox(width: 6),
                          Text(
                            tr('wq_paper_name'),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameCtrl,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        decoration: InputDecoration(
                          hintText: tr('pb_name_hint'),
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── 2. 搜尋列與快速操作 ──
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: tr('pb_search_hint'),
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                            suffixIcon: _searchKeyword.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchKeyword = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (val) => setState(() => _searchKeyword = val.trim()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 一鍵全選 / 取消全選
                    if (filtered.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            if (isAllFilteredSelected) {
                              for (final q in filtered) {
                                _selectedQuestionIds.remove(q['id'] as int);
                              }
                            } else {
                              for (final q in filtered) {
                                _selectedQuestionIds.add(q['id'] as int);
                              }
                            }
                          });
                        },
                        icon: Icon(
                          isAllFilteredSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                          size: 16,
                        ),
                        label: Text(
                          isAllFilteredSelected ? tr('pb_unselect_all') : tr('wq_select_all'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF4F46E5),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey.shade200),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── 3. 學科 ChoiceChips 水平滑動列 ──
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['全部', ..._subjects].map((s) {
                      final isSel = _selectedSubject == s;
                      final count = subjectCounts[s] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text('${trv(s)} ($count)'),
                          selected: isSel,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            color: isSel ? const Color(0xFF4F46E5) : const Color(0xFF475569),
                          ),
                          backgroundColor: Colors.white,
                          selectedColor: const Color(0xFFEEF2FF),
                          checkmarkColor: const Color(0xFF4F46E5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSel ? const Color(0xFF4F46E5) : Colors.grey.shade200,
                            ),
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _selectedSubject = s);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // ── 4. 題目狀態列 ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tr('pb_count_line', [filtered.length.toString(), _selectedQuestionIds.length.toString()]),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                    if (_selectedQuestionIds.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() => _selectedQuestionIds.clear()),
                        child: Text(tr('pb_clear_sel'), style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── 5. 題庫清單主體 ──
                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.search_off_rounded, size: 44, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text(
                          _allBankQuestions.isEmpty ? tr('pb_bank_empty') : tr('pb_no_match'),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _addNewQuestion,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(tr('pb_write_now')),
                        ),
                      ],
                    ),
                  )
                else
                  ...filtered.map((q) {
                    final id = q['id'] as int;
                    final isChecked = _selectedQuestionIds.contains(id);
                    final sub = q['subject']?.toString() ?? '一般';
                    final diff = q['difficulty']?.toString() ?? '中';
                    final diffColor = _getDifficultyColor(diff);
                    final opts = List<String>.from(q['options'] ?? []);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isChecked ? const Color(0xFFEEF2FF) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isChecked ? const Color(0xFF6366F1) : Colors.grey.shade200,
                          width: isChecked ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            setState(() {
                              if (isChecked) {
                                _selectedQuestionIds.remove(id);
                              } else {
                                _selectedQuestionIds.add(id);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 頂部標籤與勾選指標
                                Row(
                                  children: [
                                    // Checkbox circle
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isChecked ? const Color(0xFF4F46E5) : Colors.transparent,
                                        border: Border.all(
                                          color: isChecked ? const Color(0xFF4F46E5) : Colors.grey.shade400,
                                          width: 1.8,
                                        ),
                                      ),
                                      child: isChecked
                                          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                                          : null,
                                    ),
                                    const SizedBox(width: 10),

                                    // Subject badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        sub,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF4F46E5),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),

                                    // Difficulty badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: diffColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        tr('pb_diff_n', [diff.toString()]),
                                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: diffColor),
                                      ),
                                    ),
                                    const Spacer(),

                                    // 討論串按鈕
                                    InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _openDiscussion(q),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.forum_outlined, size: 14, color: Color(0xFF4F46E5)),
                                            SizedBox(width: 4),
                                            Text(
                                              tr('pb_discussion'),
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // 題目主幹
                                Text(
                                  q['question'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                    height: 1.4,
                                  ),
                                ),

                                // 選項膠囊標籤
                                if (opts.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: List.generate(opts.length > 4 ? 4 : opts.length, (oIdx) {
                                      final char = String.fromCharCode(65 + oIdx);
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '$char. ${opts[oIdx]}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),

          // ── 底部固定操作列 ──
          Container(
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
                    Text(tr('pb_selected'), style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    Text(
                      tr('pb_selected_n', [_selectedQuestionIds.length.toString()]),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saving || _selectedQuestionIds.isEmpty ? null : _savePaper,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.rocket_launch_rounded, size: 18),
                    label: Text(
                      _saving
                          ? tr('common_saving')
                          : (_selectedQuestionIds.isEmpty
                              ? tr('pb_pick_q')
                              : (widget.paperId == null ? tr('pb_finish_start') : tr('pb_update'))),
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade200,
                      disabledForegroundColor: Colors.grey.shade400,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
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
}
