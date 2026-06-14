import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';

class PaperBuilderPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final List<Map<String, dynamic>> initialQuestions;
  final int? paperId; // optional: edit existing paper

  const PaperBuilderPage({super.key, required this.currentUser, this.initialQuestions = const [], this.paperId});

  @override
  State<PaperBuilderPage> createState() => _PaperBuilderPageState();
}

class _PaperBuilderPageState extends State<PaperBuilderPage> {
  List<Map<String, dynamic>> _questions = [];
  final Set<int> _selectedIds = {};
  bool _loading = true;
  final TextEditingController _nameCtrl = TextEditingController();
  String _selectedSubjectFilter = '全部';

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadAllQuestions();
    if (widget.paperId != null) _loadPaper(widget.paperId!);
  }

  Future<void> _loadPaper(int id) async {
    try {
      final p = await DatabaseHelper.instance.getPaperById(id);
      if (p == null) return;
      final raw = p['question_ids']?.toString() ?? '[]';
      final decoded = jsonDecode(raw) as List<dynamic>;
      final ids = decoded.map((e) => int.tryParse(e.toString()) ?? 0).where((v) => v > 0).toSet();
      setState(() {
        _selectedIds.clear();
        _selectedIds.addAll(ids);
        _nameCtrl.text = p['name']?.toString() ?? '';
      });
    } catch (e) {
      debugPrint('載入考卷失敗: $e');
    }
  }

  Future<void> _loadAllQuestions() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('questions', orderBy: 'created_at DESC');
      if (!mounted) return;
      setState(() {
        _questions = rows.map((r) {
          final id = int.tryParse(r['id'].toString()) ?? 0;
          return {
            'id': id,
            'question': (r['text'] ?? '').toString(),
            'subject': r['subject'] ?? '',
          };
        }).toList();
        for (final q in widget.initialQuestions) {
          final id = q['id'] as int? ?? int.tryParse(q['id'].toString()) ?? 0;
          if (id > 0) _selectedIds.add(id);
        }
        _loading = false;
      });
    } catch (e) {
      debugPrint('載入所有題目失敗: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<String> get _availableSubjects {
    final set = <String>{};
    for (final q in _questions) {
      final s = q['subject']?.toString() ?? '';
      if (s.isNotEmpty) set.add(s);
    }
    return ['全部', ...set];
  }

  void _toggleSelectAll(List<Map<String, dynamic>> filtered) {
    final allSelected = filtered.isNotEmpty && filtered.every((q) => _selectedIds.contains(q['id'] as int));
    setState(() {
      if (allSelected) {
        for (final q in filtered) {
          _selectedIds.remove(q['id'] as int);
        }
      } else {
        for (final q in filtered) {
          _selectedIds.add(q['id'] as int);
        }
      }
    });
  }

  Future<void> _savePaper() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請輸入考卷名稱')));
      return;
    }
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請至少選一題')));
      return;
    }

    try {
      final uid = widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1';
      if (widget.paperId != null) {
        await DatabaseHelper.instance.updatePaper(widget.paperId!, name, _selectedIds.toList());
      } else {
        await DatabaseHelper.instance.createPaper(uid.toString(), name, _selectedIds.toList());
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('儲存考卷失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('儲存失敗')));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    // Filter questions based on selected subject
    final filteredQuestions = _questions.where((q) {
      if (_selectedSubjectFilter == '全部') return true;
      return q['subject'] == _selectedSubjectFilter;
    }).toList();

    final allSelected = filteredQuestions.isNotEmpty && 
        filteredQuestions.every((q) => _selectedIds.contains(q['id'] as int));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('建立自訂考卷'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: '考卷名稱',
                      filled: true,
                      fillColor: cs.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                // 科目篩選下拉選單
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSubjectFilter,
                    decoration: InputDecoration(
                      labelText: '篩選科目',
                      filled: true,
                      fillColor: cs.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _availableSubjects
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedSubjectFilter = val ?? '全部';
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _toggleSelectAll(filteredQuestions),
                        icon: const Icon(Icons.select_all_rounded),
                        label: Text(allSelected ? '取消全選' : '全選'),
                        style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
                      ),
                      const SizedBox(width: 8),
                      Text('${_selectedIds.length} 題已選', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w500)),
                      if (_selectedSubjectFilter != '全部') ...[
                        const SizedBox(width: 4),
                        Text('(此科目中已選 ${filteredQuestions.where((q) => _selectedIds.contains(q['id'] as int)).length} 題)', 
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filteredQuestions.isEmpty
                      ? Center(
                          child: Text(
                            '此科目目前沒有題目可供選擇',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filteredQuestions.length,
                          itemBuilder: (context, idx) {
                            final q = filteredQuestions[idx];
                            final id = q['id'] as int;
                            final snippet = (q['question'] ?? '').toString();
                            final display = snippet.length > 120 ? '${snippet.substring(0, 120)}...' : snippet;
                            return CheckboxListTile(
                              value: _selectedIds.contains(id),
                              title: Text(display, style: TextStyle(color: cs.onSurface)),
                              subtitle: Text(q['subject'] ?? '', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65))),
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedIds.add(id);
                                  } else {
                                    _selectedIds.remove(id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _savePaper,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('儲存考卷'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
