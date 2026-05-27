import 'package:flutter/material.dart';
import 'dart:convert';
import '../database/database_helper.dart';

class QuestionEditPage extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final Map<String, dynamic> currentUser;
  final List<String> allSubjects;
  final Map<String, List<String>> subjectChapters;

  const QuestionEditPage({
    super.key,
    this.initialData,
    required this.currentUser,
    required this.allSubjects,
    required this.subjectChapters,
  });

  @override
  State<QuestionEditPage> createState() => _QuestionEditPageState();
}

class _QuestionEditPageState extends State<QuestionEditPage> {
  final _formKey = GlobalKey<FormState>();
  late String subject;
  late String type;
  late String difficulty;
  final TextEditingController _questionCtrl = TextEditingController();
  final TextEditingController _explanationCtrl = TextEditingController();
  List<TextEditingController> _optionCtrls = [];
  int answerIndex = 0;

  @override
  void initState() {
    super.initState();
    subject = widget.initialData?['subject'] ?? widget.allSubjects.first;
    type = widget.initialData?['type'] ?? '單選題';
    difficulty = widget.initialData?['difficulty'] ?? '易';
    _questionCtrl.text = widget.initialData?['question'] ?? '';
    _explanationCtrl.text = widget.initialData?['explanation'] ?? '';
    final options = widget.initialData?['options'];
    if (options is List) {
      _optionCtrls = options.map((o) => TextEditingController(text: o)).toList();
    } else {
      _optionCtrls = List.generate(4, (_) => TextEditingController());
    }
    answerIndex = widget.initialData?['answerIndex'] ?? 0;
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _explanationCtrl.dispose();
    for (var c in _optionCtrls) c.dispose();
    super.dispose();
  }

  Future<void> _saveQuestion() async {
    if (!_formKey.currentState!.validate()) return;
    final text = _questionCtrl.text.trim();
    final explanation = _explanationCtrl.text.trim();
    final options = _optionCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    final answer = answerIndex.toString();

    final db = await DatabaseHelper.instance.database;
    final values = {
      'user_id': widget.initialData?['user_id'] ?? widget.currentUser['id'],
      'text': text,
      'options': jsonEncode(options),
      'answer': answer,
      'explanation': explanation,
      'subject': subject,
      'difficulty': difficulty,
      'bookmarked': widget.initialData?['bookmarked'] ?? 0,
      'is_public': widget.initialData?['is_public'] ?? 0,
    };

    if (widget.initialData?['id'] != null) {
      await db.update(
        'questions',
        values,
        where: 'id = ?',
        whereArgs: [widget.initialData!['id']],
      );
    } else {
      await db.insert('questions', values);
    }

    if (mounted) Navigator.pop(context, true);
  }

  void _addOption() {
    setState(() => _optionCtrls.add(TextEditingController()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialData == null ? '新增題目' : '編輯題目'),
        backgroundColor: const Color(0xFF8D6E63),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                initialValue: subject,
                decoration: const InputDecoration(labelText: '科目'),
                items: widget.allSubjects
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => subject = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: difficulty,
                decoration: const InputDecoration(labelText: '難度'),
                items: ['易', '中', '難']
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) => setState(() => difficulty = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _questionCtrl,
                decoration: const InputDecoration(labelText: '題目'),
                validator: (v) => (v == null || v.trim().isEmpty) ? '請輸入題目' : null,
              ),
              const SizedBox(height: 12),
              const Text('選項'),
              const SizedBox(height: 8),
              ..._optionCtrls.asMap().entries.map((e) {
                final idx = e.key;
                final ctrl = e.value;
                return Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: ctrl,
                      decoration: InputDecoration(labelText: '選項 ${idx + 1}'),
                    ),
                  ),
                  Radio<int>(
                    value: idx,
                    groupValue: answerIndex,
                    onChanged: (v) => setState(() => answerIndex = v ?? 0),
                  )
                ]);
              }).toList(),
              TextButton.icon(onPressed: _addOption, icon: const Icon(Icons.add), label: const Text('新增選項')),
              const SizedBox(height: 12),
              TextFormField(
                controller: _explanationCtrl,
                decoration: const InputDecoration(labelText: '解析（選填）'),
                maxLines: 4,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8D6E63)),
                onPressed: _saveQuestion,
                child: const Text('儲存'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
