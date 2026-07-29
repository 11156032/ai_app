import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'question_set_detail_page.dart';

class SubjectChaptersPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final String subject;
  final List<String> allSubjects;
  final Map<String, List<String>> subjectChapters;

  const SubjectChaptersPage({
    super.key,
    required this.currentUser,
    required this.subject,
    required this.allSubjects,
    required this.subjectChapters,
  });

  @override
  State<SubjectChaptersPage> createState() => _SubjectChaptersPageState();
}

class _SubjectChaptersPageState extends State<SubjectChaptersPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _openChapter(BuildContext context, String chapter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionSetDetailPage(
          currentUser: widget.currentUser,
          title: chapter, // 章節名稱作為標題
          subject: widget.subject,
          chapter: chapter, // 新增的參數
          allSubjects: widget.allSubjects,
          subjectChapters: widget.subjectChapters,
        ),
      ),
    );
  }

  Widget _buildFileCard(BuildContext context, String chapterName, ColorScheme cs) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openChapter(context, chapterName),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.description_rounded, // 檔案圖示
                  color: Colors.blue,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                chapterName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chapters = widget.subjectChapters[widget.subject] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.subject} (章節列表)'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: chapters.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: cs.primary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('這個科目目前沒有章節', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16)),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85, // 調整比例以容納兩行標題，防止底部溢出
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: chapters.length,
              itemBuilder: (context, index) {
                return _buildFileCard(context, chapters[index], cs);
              },
            ),
    );
  }
}
