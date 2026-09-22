import 'dart:convert';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class CreateLearningPackDialog extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final Map<String, dynamic>? initialData;

  const CreateLearningPackDialog({
    super.key,
    required this.currentUser,
    this.initialData,
  });

  @override
  State<CreateLearningPackDialog> createState() =>
      _CreateLearningPackDialogState();
}

class _CreateLearningPackDialogState extends State<CreateLearningPackDialog> {
  bool _isLoading = true;
  late DateTime _startDate;
  late DateTime _endDate;

  List<Map<String, dynamic>> _allPapers = [];
  final Set<int> _selectedPaperIds = {};
  int _selectedEventCount = 0;

  late final TextEditingController _titleController;
  late final TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
        text: widget.initialData?['pack_title'] as String? ?? '');
    _descController = TextEditingController(
        text: widget.initialData?['pack_description'] as String? ?? '');

    if (widget.initialData != null) {
      if (widget.initialData!['start_date'] != null) {
        _startDate =
            DateTime.tryParse(widget.initialData!['start_date'] as String) ??
                DateTime.now();
      } else {
        _startDate = DateTime.now();
      }
      if (widget.initialData!['end_date'] != null) {
        _endDate =
            DateTime.tryParse(widget.initialData!['end_date'] as String) ??
                DateTime.now().add(const Duration(days: 7));
      } else {
        _endDate = DateTime.now().add(const Duration(days: 7));
      }
      final papers = widget.initialData!['user_papers'] as List?;
      if (papers != null) {
        for (var p in papers) {
          if (p is Map && p['id'] != null) {
            _selectedPaperIds.add(p['id'] as int);
          }
        }
      }
    } else {
      _startDate = DateTime.now();
      _endDate = DateTime.now().add(const Duration(days: 7));
    }

    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = await DatabaseHelper.instance.database;
    final papers = await db.query('user_papers',
        where: 'user_id = ?', whereArgs: [widget.currentUser['id']]);

    if (mounted) {
      setState(() {
        _allPapers = papers;
        _isLoading = false;
      });
      await _countEvents();
    }
  }

  Future<void> _countEvents() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final events = await db.query('calendar_events',
          where: 'user_id = ? AND start_time >= ? AND start_time <= ?',
          whereArgs: [
            widget.currentUser['id'],
            _startDate.toIso8601String(),
            _endDate.add(const Duration(days: 1)).toIso8601String()
          ]);
      if (mounted) {
        setState(() {
          _selectedEventCount = events.length;
        });
      }
    } catch (_) {}
  }

  void _setQuickRange(int days) {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = _startDate.add(Duration(days: days));
    });
    _countEvents();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _countEvents();
    }
  }

  Future<void> _buildAndReturnPack() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text('請輸入 Pack 標題')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Fetch Calendar Events
      final events = await db.query('calendar_events',
          where: 'user_id = ? AND start_time >= ? AND start_time <= ?',
          whereArgs: [
            widget.currentUser['id'],
            _startDate.toIso8601String(),
            _endDate.add(const Duration(days: 1)).toIso8601String()
          ],
          orderBy: 'start_time ASC');

      List<Map<String, dynamic>> packEvents = [];
      if (events.isNotEmpty) {
        DateTime firstEventDate =
            DateTime.parse(events.first['start_time'] as String);
        firstEventDate = DateTime(
            firstEventDate.year, firstEventDate.month, firstEventDate.day);

        for (var e in events) {
          DateTime eStart = DateTime.parse(e['start_time'] as String);
          DateTime eDate = DateTime(eStart.year, eStart.month, eStart.day);
          int offset = eDate.difference(firstEventDate).inDays;

          packEvents.add({
            'title': e['title'],
            'description': e['description'],
            'is_all_day': e['is_all_day'],
            'day_offset': offset,
            'start_hour': eStart.hour,
            'start_minute': eStart.minute,
            'end_time_offset_minutes': DateTime.parse(e['end_time'] as String)
                .difference(eStart)
                .inMinutes,
            'color': e['color'],
            'location': e['location']
          });
        }
      }

      // 2. Fetch User Papers & Questions
      List<Map<String, dynamic>> packPapers = [];
      for (var paperId in _selectedPaperIds) {
        final paper = _allPapers.firstWhere((p) => p['id'] == paperId);
        List<dynamic> qIds = jsonDecode(paper['question_ids'] as String);

        List<Map<String, dynamic>> questions = [];
        for (var qId in qIds) {
          final qList =
              await db.query('questions', where: 'id = ?', whereArgs: [qId]);
          if (qList.isNotEmpty) {
            final q = Map<String, dynamic>.from(qList.first);
            q.remove('id');
            q.remove('user_id'); // We will re-assign user_id on import
            questions.add(q);
          }
        }

        packPapers.add({
          'id': paper['id'],
          'name': paper['name'],
          'questions': questions,
        });
      }

      final packData = {
        'pack_title': _titleController.text.trim(),
        'pack_description': _descController.text.trim(),
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
        'calendar_events': packEvents,
        'user_papers': packPapers,
      };

      if (mounted) {
        Navigator.pop(context, packData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text('打包失敗: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  int _getPaperQuestionCount(Map<String, dynamic> paper) {
    try {
      final qIds = jsonDecode(paper['question_ids'] as String);
      return (qIds as List).length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.92,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 220,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 頂部標題列
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.06),
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9800)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.inventory_2_rounded,
                            color: Color(0xFFE65100),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '建立學習 Pack',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C2523),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '打包讀書排程與練習試卷，讓同學一鍵套用',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // 滾動內容區
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Pack 基本資訊
                          _buildSectionTitle(
                            icon: Icons.edit_note_rounded,
                            title: 'Pack 基本資訊',
                            color: primaryColor,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: 'Pack 標題 *',
                              hintText: '例如：學測衝刺 7 天排程與模考包',
                              filled: true,
                              fillColor: const Color(0xFFF9F7F5),
                              prefixIcon: const Icon(Icons.title_rounded,
                                  size: 20, color: Colors.grey),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: primaryColor, width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _descController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: '簡介描述（選填）',
                              hintText: '說明這個 Pack 適合的年級、科目或複習建議...',
                              filled: true,
                              fillColor: const Color(0xFFF9F7F5),
                              prefixIcon: const Icon(Icons.notes_rounded,
                                  size: 20, color: Colors.grey),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: primaryColor, width: 1.5),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 2. 行事曆排程區間
                          _buildSectionTitle(
                            icon: Icons.calendar_month_rounded,
                            title: '行事曆排程區間',
                            color: const Color(0xFFE65100),
                            badge: '$_selectedEventCount 個事件',
                          ),
                          const SizedBox(height: 8),

                          // 快速選擇膠囊
                          Row(
                            children: [
                              _buildQuickRangeChip('未來 7 天', 7),
                              const SizedBox(width: 6),
                              _buildQuickRangeChip('未來 14 天', 14),
                              const SizedBox(width: 6),
                              _buildQuickRangeChip('未來 30 天', 30),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // 日期區間選取卡片
                          InkWell(
                            onTap: _pickDateRange,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFFFE082)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.date_range_rounded,
                                      color: Color(0xFFE65100), size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${_startDate.toIso8601String().split('T')[0]}  ➔  ${_endDate.toIso8601String().split('T')[0]}',
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF5D4037),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _selectedEventCount > 0
                                              ? '已包含區間內 $_selectedEventCount 個學習排程'
                                              : '此區間內無行事曆排程',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: _selectedEventCount > 0
                                                ? const Color(0xFFE65100)
                                                : Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: const Color(0xFFFFD54F)),
                                    ),
                                    child: const Text(
                                      '變更日期',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFE65100),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 3. 包含試卷
                          Row(
                            children: [
                              _buildSectionTitle(
                                icon: Icons.quiz_rounded,
                                title: '包含題庫試卷',
                                color: const Color(0xFF1565C0),
                                badge: '${_selectedPaperIds.length} 套',
                              ),
                              const Spacer(),
                              if (_allPapers.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (_selectedPaperIds.length ==
                                          _allPapers.length) {
                                        _selectedPaperIds.clear();
                                      } else {
                                        _selectedPaperIds.addAll(_allPapers
                                            .map((p) => p['id'] as int));
                                      }
                                    });
                                  },
                                  child: Text(
                                    _selectedPaperIds.length ==
                                            _allPapers.length
                                        ? '取消全選'
                                        : '全選',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (_allPapers.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9F7F5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.grey.shade200),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.feed_outlined,
                                      color: Colors.grey, size: 28),
                                  SizedBox(height: 6),
                                  Text(
                                    '尚未建立自訂試卷，仍可單獨打包排程！',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          else
                            Column(
                              children: _allPapers.map((paper) {
                                final id = paper['id'] as int;
                                final name =
                                    paper['name'] as String? ?? '未命名試卷';
                                final qCount = _getPaperQuestionCount(paper);
                                final isSelected =
                                    _selectedPaperIds.contains(id);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? primaryColor.withValues(alpha: 0.06)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? primaryColor.withValues(alpha: 0.4)
                                          : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: CheckboxListTile(
                                    dense: true,
                                    activeColor: primaryColor,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 0),
                                    title: Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? Colors.black87
                                            : Colors.grey.shade800,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '包含 $qCount 題題目',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    value: isSelected,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedPaperIds.add(id);
                                        } else {
                                          _selectedPaperIds.remove(id);
                                        }
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // 底部統計與動作按鈕
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // 打包即時概況
                        Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                size: 14, color: primaryColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '已選 $_selectedEventCount 個排程事件 ＋ ${_selectedPaperIds.length} 套試卷',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  foregroundColor: Colors.grey.shade700,
                                  side: BorderSide(
                                      color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('取消'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: _buildAndReturnPack,
                                icon: const Icon(Icons.archive_rounded,
                                    size: 18),
                                label: const Text('確認打包 Pack'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF9800),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
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
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required Color color,
    String? badge,
  }) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C2523),
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickRangeChip(String label, int days) {
    return Expanded(
      child: InkWell(
        onTap: () => _setQuickRange(days),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ),
    );
  }
}
