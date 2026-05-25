import 'package:flutter/material.dart';

class QuestionPracticePage extends StatefulWidget {
  final Map<String, dynamic> questionData;

  const QuestionPracticePage({
    super.key,
    required this.questionData,
  });

  @override
  State<QuestionPracticePage> createState() => _QuestionPracticePageState();
}

class _QuestionPracticePageState extends State<QuestionPracticePage> {
  late int _selectedAnswer;
  bool _showAnswer = false;
  bool _isAnswered = false;

  @override
  void initState() {
    super.initState();
    _selectedAnswer = -1;
  }

  @override
  Widget build(BuildContext context) {
    var q = widget.questionData;
    List<String> options = [];
    
    // 解析選項（可能是 JSON 陣列或直接陣列）
    if (q['options'] is String) {
      try {
        options = List<String>.from(
          (q['options'] as String)
              .replaceAll('[', '')
              .replaceAll(']', '')
              .replaceAll('"', '')
              .split(',')
              .map((s) => s.trim())
        );
      } catch (e) {
        options = [];
      }
    } else if (q['options'] is List) {
      options = List<String>.from(q['options']);
    }

    int correctAnswer = q['answerIndex'] ?? q['answer'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF8D6E63),
        foregroundColor: Colors.white,
        title: const Text('作答練習'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 題目資訊
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8D6E63),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          q['subject'] ?? '未分類',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '難度: ${q['difficulty'] ?? '中'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    q['question'] ?? '題目內容遺失',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 選項
            const Text(
              '請選擇答案：',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(
              options.length,
              (i) => GestureDetector(
                onTap: _isAnswered ? null : () => setState(() {
                  _selectedAnswer = i;
                  _isAnswered = true;
                }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _selectedAnswer == i
                        ? const Color(0xFF8D6E63).withValues(alpha: 0.1)
                        : Colors.white,
                    border: Border.all(
                      color: _selectedAnswer == i
                          ? const Color(0xFF8D6E63)
                          : Colors.grey.shade300,
                      width: _selectedAnswer == i ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedAnswer == i
                                ? const Color(0xFF8D6E63)
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                          color: _selectedAnswer == i
                              ? const Color(0xFF8D6E63)
                              : Colors.transparent,
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + i), // A, B, C, D...
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _selectedAnswer == i
                                  ? Colors.white
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          options[i],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 顯示答案按鈕
            if (_isAnswered && !_showAnswer)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() => _showAnswer = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8D6E63),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    '顯示答案與解釋',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            // 答案與解釋
            if (_showAnswer) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _selectedAnswer == correctAnswer
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedAnswer == correctAnswer
                        ? Colors.green
                        : Colors.red,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _selectedAnswer == correctAnswer
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: _selectedAnswer == correctAnswer
                              ? Colors.green
                              : Colors.red,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedAnswer == correctAnswer ? '✓ 正確！' : '✗ 錯誤',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _selectedAnswer == correctAnswer
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '正確答案：${String.fromCharCode(65 + correctAnswer)} ${options.isNotEmpty && correctAnswer < options.length ? options[correctAnswer] : ""}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (q['explanation'] != null && q['explanation'].toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      const Text(
                        '詳細解釋：',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        q['explanation'].toString(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 底部按鈕
            if (_isAnswered)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('返回'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setState(() {
                        _selectedAnswer = -1;
                        _showAnswer = false;
                        _isAnswered = false;
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8D6E63),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        '重新作答',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
