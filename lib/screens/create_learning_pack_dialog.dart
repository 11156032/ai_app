import 'dart:convert';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class CreateLearningPackDialog extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const CreateLearningPackDialog({super.key, required this.currentUser});

  @override
  State<CreateLearningPackDialog> createState() => _CreateLearningPackDialogState();
}

class _CreateLearningPackDialogState extends State<CreateLearningPackDialog> {
  bool _isLoading = true;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  
  List<Map<String, dynamic>> _allPapers = [];
  Set<int> _selectedPaperIds = {};
  int _selectedEventCount = 0;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
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
    } catch (e) {
      // ignore
    }
  }

  Future<void> _buildAndReturnPack() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請輸入 Pack 標題')));
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
        DateTime firstEventDate = DateTime.parse(events.first['start_time'] as String);
        firstEventDate = DateTime(firstEventDate.year, firstEventDate.month, firstEventDate.day);

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
            'end_time_offset_minutes': DateTime.parse(e['end_time'] as String).difference(eStart).inMinutes,
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
          final qList = await db.query('questions', where: 'id = ?', whereArgs: [qId]);
          if (qList.isNotEmpty) {
            final q = Map<String, dynamic>.from(qList.first);
            q.remove('id');
            q.remove('user_id'); // We will re-assign user_id on import
            questions.add(q);
          }
        }
        
        packPapers.add({
          'name': paper['name'],
          'questions': questions
        });
      }

      final packData = {
        'pack_title': _titleController.text.trim(),
        'pack_description': _descController.text.trim(),
        'calendar_events': packEvents,
        'user_papers': packPapers,
      };

      if (mounted) {
        Navigator.pop(context, packData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('打包失敗: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _countEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📦 建立學習 Pack', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Pack 標題 (必填)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Pack 描述 (選填)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  const Text('📅 包含行事曆區間', style: TextStyle(fontWeight: FontWeight.bold)),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${_startDate.toIso8601String().split('T')[0]} ~ ${_endDate.toIso8601String().split('T')[0]}'),
                    subtitle: Text('此區間共包含 $_selectedEventCount 個排程', style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: _pickDateRange,
                  ),
                  const Divider(),
                  const Text('📝 包含試卷', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (_allPapers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('目前沒有任何自訂試卷', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _allPapers.length,
                        itemBuilder: (context, index) {
                          final paper = _allPapers[index];
                          final id = paper['id'] as int;
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(paper['name'] as String),
                            value: _selectedPaperIds.contains(id),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedPaperIds.add(id);
                                } else {
                                  _selectedPaperIds.remove(id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消', style: TextStyle(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        onPressed: _buildAndReturnPack,
                        child: const Text('確認打包'),
                      )
                    ],
                  )
                ],
              ),
      ),
    );
  }
}
