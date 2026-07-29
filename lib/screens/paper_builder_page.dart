import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import 'question_edit_page.dart';

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
  List<Map<String, dynamic>> _questions = [];
  final Set<int> _selectedIds = {};
  bool _loading = true;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  
  String _selectedSubjectFilter = '全部';
  String _selectedDifficultyFilter = '全部';
  String _searchQuery = '';
  int _currentTab = 0; // 0: 選擇題目, 1: 已選清單
  List<Map<String, dynamic>> _tempSelectedQuestions = [];
  bool _onlyFavorites = false;
  bool _onlyWrong = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
        _tempSelectedQuestions = _questions
            .where((q) => _selectedIds.contains(q['id'] as int))
            .toList();
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
      
      final uid = widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1';
      final wrongRows = await DatabaseHelper.instance.getWrongQuestions(uid.toString());
      final wrongIds = wrongRows.map((r) => int.tryParse(r['question_id'].toString()) ?? 0).toSet();

      if (!mounted) return;
      setState(() {
        _questions = rows.map((r) {
          final id = int.tryParse(r['id'].toString()) ?? 0;
          final rawDiff = r['difficulty'];
          final displayDiff = (rawDiff == 'easy' || rawDiff == null) ? '無' : rawDiff.toString();
          return {
            'id': id,
            'question': (r['text'] ?? '').toString(),
            'subject': r['subject'] ?? '一般',
            'difficulty': displayDiff,
            'type': r['type'] ?? '單選題',
            'bookmarked': r['bookmarked'] ?? 0,
            'isWrong': wrongIds.contains(id),
          };
        }).toList();
        for (final q in widget.initialQuestions) {
          final id = q['id'] as int? ?? int.tryParse(q['id'].toString()) ?? 0;
          if (id > 0) _selectedIds.add(id);
        }
        _tempSelectedQuestions = _questions
            .where((q) => _selectedIds.contains(q['id'] as int))
            .toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('載入所有題目失敗: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _addNewQuestionOnTheFly() async {
    final Map<String, List<String>> mockChapters = {
      '資訊管理': ['第一章 緒論', '第二章 資料庫管理', '第三章 網路安全'],
      '國文': ['課文選讀', '文言文解析', '師說'],
      '數學': ['代數', '幾何', '面積'],
      'TOEIC': ['閱讀測驗', '聽力測驗', '文法填空'],
      '歷史': ['台灣史', '中國史', '世界史'],
      '理化': ['力與運動', '化學反應', '基本物理'],
    };

    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionEditPage(
          currentUser: widget.currentUser,
          allSubjects: const ['一般', '國文', '數學', '資訊管理', 'TOEIC', '英文', '歷史', '理化'],
          subjectChapters: mockChapters,
        ),
      ),
    );

    if (result != null) {
      await _loadAllQuestions();
      if (_questions.isNotEmpty) {
        final newestId = _questions.map((q) => q['id'] as int).reduce((a, b) => a > b ? a : b);
        setState(() {
          _selectedIds.add(newestId);
          if (_currentTab == 1) {
            final newQ = _questions.firstWhere((q) => q['id'] == newestId);
            _tempSelectedQuestions.add(newQ);
          }
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('新題目建立成功，已自動為您勾選！'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('請輸入考卷名稱'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('請至少選擇一題'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('儲存失敗，請稍後再試')),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // Helper helper to get visual presentation of difficulties
  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case '易':
        return Colors.green;
      case '中':
        return Colors.orange;
      case '難':
        return Colors.red;
      case '無':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  // Filter logic helper
  List<Map<String, dynamic>> _getFilteredQuestions() {
    return _questions.where((q) {
      final matchSubject = _selectedSubjectFilter == '全部' || q['subject'] == _selectedSubjectFilter;
      final matchDifficulty = _selectedDifficultyFilter == '全部' || q['difficulty'] == _selectedDifficultyFilter;
      final matchQuery = _searchQuery.isEmpty ||
          q['question'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          q['subject'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchFavorite = !_onlyFavorites || (q['bookmarked'] == 1);
      final matchWrong = !_onlyWrong || (q['isWrong'] == true);
      return matchSubject && matchDifficulty && matchQuery && matchFavorite && matchWrong;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    // 1. Filtered questions for the selection list
    final filteredQuestions = _getFilteredQuestions();
    

    // 3. Check if current filtered list is all selected
    final allSelectedInFiltered = filteredQuestions.isNotEmpty &&
        filteredQuestions.every((q) => _selectedIds.contains(q['id'] as int));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.paperId == null ? '建立自訂考卷' : '編輯自訂考卷', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: _addNewQuestionOnTheFly,
            icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 18),
            label: const Text('新增題目', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ],
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Top Name Input Section ──
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: '輸入考卷名稱...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                          prefixIcon: const Icon(Icons.edit_note_rounded, color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Segmented Tab bar
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            _buildTabItem(0, '選擇題目 (${filteredQuestions.length})'),
                            _buildTabItem(1, '已選清單 (${_selectedIds.length})'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Filter section (Only visible on Select Questions tab) ──
                if (_currentTab == 0) ...[
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: '搜尋題目關鍵字...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                  // Horizontal Subject ChoiceChips
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: _availableSubjects.map((subject) {
                        final isSelected = _selectedSubjectFilter == subject;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(subject),
                            selected: isSelected,
                            selectedColor: cs.primary,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected ? Colors.transparent : Colors.grey.shade300,
                              ),
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedSubjectFilter = subject;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Horizontal Difficulty ChoiceChips
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Text(
                            '難度：',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                        ...['全部', '無', '易', '中', '難'].map((diff) {
                          final isSelected = _selectedDifficultyFilter == diff;
                          final diffColor = (diff == '全部' || diff == '無') ? cs.primary : _getDifficultyColor(diff);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(diff),
                              selected: isSelected,
                              selectedColor: diff == '全部' ? cs.primary : diffColor.withValues(alpha: 0.15),
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? (diff == '全部' ? cs.onPrimary : diffColor)
                                    : cs.onSurfaceVariant,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSelected
                                      ? (diff == '全部' ? Colors.transparent : diffColor)
                                      : Colors.grey.shade300,
                                ),
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedDifficultyFilter = diff;
                                  });
                                }
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  // Batch Select Row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => _toggleSelectAll(filteredQuestions),
                            icon: Icon(allSelectedInFiltered ? Icons.deselect_rounded : Icons.select_all_rounded, size: 18),
                            label: Text(allSelectedInFiltered ? '取消此篩選全選' : '此篩選全選', style: const TextStyle(fontWeight: FontWeight.bold)),
                            style: TextButton.styleFrom(
                              foregroundColor: cs.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            avatar: Icon(
                              _onlyFavorites ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: _onlyFavorites ? Colors.amber : Colors.grey,
                              size: 16,
                            ),
                            label: const Text('僅看收藏', style: TextStyle(fontSize: 12)),
                            selected: _onlyFavorites,
                            selectedColor: cs.primary.withValues(alpha: 0.15),
                            checkmarkColor: cs.primary,
                            onSelected: (val) {
                              setState(() {
                                _onlyFavorites = val;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            avatar: Icon(
                              _onlyWrong ? Icons.error_rounded : Icons.error_outline_rounded,
                              color: _onlyWrong ? Colors.redAccent : Colors.grey,
                              size: 16,
                            ),
                            label: const Text('僅看錯題', style: TextStyle(fontSize: 12)),
                            selected: _onlyWrong,
                            selectedColor: cs.primary.withValues(alpha: 0.15),
                            checkmarkColor: cs.primary,
                            onSelected: (val) {
                              setState(() {
                                _onlyWrong = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Matches Count Row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 20, 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '共 ${filteredQuestions.length} 題符合',
                        style: TextStyle(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],

                // ── Main Content Area ──
                Expanded(
                  child: _currentTab == 0
                      ? _buildQuestionList(filteredQuestions, cs)
                      : _buildSelectedList(_tempSelectedQuestions, cs),
                ),

                // ── Bottom Fixed Action Bar ──
                Container(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
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
                          const Text('已選擇題目', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '${_selectedIds.length}',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: cs.primary),
                              ),
                              Text(' / ${_questions.length} 題', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _savePaper,
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('儲存考卷', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
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

  // Custom tab item
  Widget _buildTabItem(int index, String label) {
    final isSelected = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentTab = index;
            if (index == 1) {
              _tempSelectedQuestions = _questions
                  .where((q) => _selectedIds.contains(q['id'] as int))
                  .toList();
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.orange.shade800 : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 1. Render filter list
  Widget _buildQuestionList(List<Map<String, dynamic>> list, ColorScheme cs) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('找不到符合條件的題目', style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: list.length,
      itemBuilder: (context, idx) {
        final q = list[idx];
        final id = q['id'] as int;
        final isSelected = _selectedIds.contains(id);
        return _buildQuestionCard(q, isSelected, cs);
      },
    );
  }

  // 2. Render selected list
  Widget _buildSelectedList(List<Map<String, dynamic>> list, ColorScheme cs) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rule_folder_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('尚未選取任何題目', style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
            const SizedBox(height: 4),
            Text('切換至「選擇題目」開始挑選題目吧！', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: list.length,
      itemBuilder: (context, idx) {
        final q = list[idx];
        final isSelected = _selectedIds.contains(q['id'] as int);
        return _buildQuestionCard(q, isSelected, cs);
      },
    );
  }

  // 3. Question Card UI Builder
  Widget _buildQuestionCard(Map<String, dynamic> q, bool isSelected, ColorScheme cs) {
    final id = q['id'] as int;
    final String subject = q['subject'] ?? '一般';
    final String difficulty = q['difficulty'] ?? '中';
    final String type = q['type'] ?? '單選題';
    final String snippet = (q['question'] ?? '').toString();
    final String displaySnippet = snippet.length > 150 ? '${snippet.substring(0, 150)}...' : snippet;
    
    final diffColor = _getDifficultyColor(difficulty);
    final isTabSelectedList = _currentTab == 1;
    final softDeleted = isTabSelectedList && !isSelected;

    Widget card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected 
            ? Colors.orange.withValues(alpha: 0.03) 
            : (softDeleted ? Colors.grey.shade50 : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected 
              ? Colors.orange.shade400 
              : (softDeleted ? Colors.grey.shade300 : Colors.grey.shade200),
          width: isSelected ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedIds.remove(id);
            } else {
              _selectedIds.add(id);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge row
              Row(
                children: [
                  // Subject tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      subject,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Type tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      type,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple),
                    ),
                  ),
                  if (difficulty != '無') ...[
                    const SizedBox(width: 6),
                    // Difficulty badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: diffColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '難度: $difficulty',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: diffColor),
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Selection Checkbox Icon
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected 
                          ? Colors.orange 
                          : (softDeleted ? Colors.grey.shade300 : Colors.transparent),
                      border: Border.all(
                        color: isSelected 
                            ? Colors.orange 
                            : (softDeleted ? Colors.grey.shade400 : Colors.grey.shade400),
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : (softDeleted 
                            ? const Icon(Icons.undo_rounded, size: 12, color: Colors.white) 
                            : null),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Question description
              Text(
                displaySnippet,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected 
                      ? Colors.black 
                      : (softDeleted ? Colors.grey.shade500 : Colors.black87),
                  decoration: softDeleted ? TextDecoration.lineThrough : null,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return softDeleted ? Opacity(opacity: 0.6, child: card) : card;
  }
}
