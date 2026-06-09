import 'package:flutter/material.dart';
import 'question_set_detail_page.dart';

class SubjectChaptersPage extends StatelessWidget {
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

  void _openChapter(BuildContext context, String chapter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionSetDetailPage(
          currentUser: currentUser,
          title: chapter, // 章節名稱作為標題
          subject: subject,
          chapter: chapter, // 新增的參數
          allSubjects: allSubjects,
          subjectChapters: subjectChapters,
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
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.description_rounded, // 檔案圖示
                  color: Colors.blue,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                chapterName,
                style: TextStyle(
                  fontSize: 16,
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
    final chapters = subjectChapters[subject] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('$subject (章節列表)'),
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
                childAspectRatio: 1.0, // 讓卡片更接近正方形
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
