import 'package:flutter/material.dart';
import '../../screens/notes_screen.dart';
import '../../services/ai_diagnosis_service.dart';

class OrganizeNotePickerWidget extends StatefulWidget {
  final Function(String) onSelected;
  final String? userId;
  const OrganizeNotePickerWidget(
      {super.key, required this.onSelected, this.userId});
  @override
  State<OrganizeNotePickerWidget> createState() =>
      _OrganizeNotePickerWidgetState();
}

class _OrganizeNotePickerWidgetState extends State<OrganizeNotePickerWidget> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    // Filter by userId to prevent showing other users' notes
    final userId = widget.userId;
    var notes = NotesDatabase.notes
        .where((n) =>
            (userId == null || n.userId == userId) && n.title.contains(_search))
        .toList();

    return Container(
        margin: const EdgeInsets.only(bottom: 14, left: 16, right: 10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
            ]),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                  hintText: '搜尋筆記標題...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0)),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          if (notes.isEmpty)
            Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.note_outlined,
                        size: 36, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text(_search.isEmpty ? '您還沒有任何筆記' : '找不到「$_search」相關筆記',
                        style: const TextStyle(color: Colors.grey)),
                  ],
                )),
          ...notes.take(6).map((n) => ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.article_outlined,
                      color: Theme.of(context).primaryColor, size: 20),
                ),
                title: Text(n.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: Text(n.category,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                trailing: Icon(Icons.chevron_right,
                    size: 18, color: Colors.grey.shade400),
                onTap: () => widget.onSelected(n.title),
              )),
          const SizedBox(height: 4),
        ]));
  }
}

class OrganizedNoteResultWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onReplace;
  final VoidCallback onSaveNew;
  final VoidCallback onImport;

  const OrganizedNoteResultWidget({
    super.key,
    required this.data,
    required this.onReplace,
    required this.onSaveNew,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final noteTitle = data['selected_note_title'] as String? ?? '';
    final points = (data['points'] as List?)?.cast<String>() ?? [];
    final actions = (data['actions'] as List?)?.cast<String>() ?? [];
    final isAi = data['isAiGenerated'] as bool? ?? false;

    // Colour constants
    final brown = Theme.of(context).primaryColor;
    final lightBrown = Theme.of(context).primaryColor;
    const tealAccent = Color(0xFF00897B);

    Widget buildChip(String label, Color bg, Color fg) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
      );
    }

    Widget buildPointRow(String text, int idx) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2, right: 8),
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: lightBrown.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              child: Text('${idx + 1}',
                  style: TextStyle(
                      fontSize: 11,
                      color: lightBrown,
                      fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13, height: 1.5, color: Color(0xFF3E2723))),
            )
          ],
        ),
      );
    }

    Widget buildActionRow(String text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 4, right: 8),
              child:
                  Icon(Icons.check_circle_outline, size: 15, color: tealAccent),
            ),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13, height: 1.5, color: Color(0xFF004D40))),
            )
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14, left: 10, right: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: lightBrown.withValues(alpha: 0.25), width: 1.2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withValues(alpha: 0.7)
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.summarize_outlined,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    noteTitle,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                buildChip(
                    isAi ? 'AI 摘要' : '本地摘要',
                    isAi
                        ? Colors.white.withValues(alpha: 0.22)
                        : Colors.orange.withValues(alpha: 0.25),
                    Colors.white),
              ],
            ),
          ),

          // ── Warning/Hint if Local Fallback ──
          if (!isAi)
            Builder(builder: (context) {
              final now = DateTime.now();
              int secondsLeft = 0;
              if (AiDiagnosisService.nextAvailableTime != null &&
                  AiDiagnosisService.nextAvailableTime!.isAfter(now)) {
                secondsLeft = AiDiagnosisService.nextAvailableTime!
                    .difference(now)
                    .inSeconds;
              }
              return Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFFFFDE7),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 14, color: Color(0xFFFBC02D)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        secondsLeft > 0
                            ? 'AI 額度已達上限，現已切換為本地大綱整理（預計 $secondsLeft 秒後恢復）'
                            : 'AI 服務繁忙，已暫時切換為本地大綱整理',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF5D4037),
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              );
            }),

          // ── Points section ──
          if (points.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: lightBrown.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Text('📌', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text('重點摘要',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: lightBrown)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...points
                      .asMap()
                      .entries
                      .map((e) => buildPointRow(e.value, e.key)),
                ],
              ),
            ),

          // ── Divider ──
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: Colors.grey.shade200, height: 1),
            ),

          // ── Actions section ──
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: tealAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🎯', style: TextStyle(fontSize: 12)),
                        SizedBox(width: 4),
                        Text('行動建議',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: tealAccent)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...actions.map(buildActionRow),
                ],
              ),
            ),

          // ── Buttons ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_to_photos, size: 15),
                    label: const Text('附加至原筆記', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: brown,
                        side: BorderSide(color: lightBrown),
                        padding: const EdgeInsets.symmetric(vertical: 8)),
                    onPressed: onReplace,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.note_add, size: 15),
                    label: const Text('存為新筆記', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: brown,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 8)),
                    onPressed: onSaveNew,
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
