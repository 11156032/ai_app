import 'package:flutter/material.dart';
import '../database/database_helper.dart';

/// 「加入題本」共用服務
///
/// 統一處理以下流程：
///   1. 顯示「選擇題本」對話框
///   2. 若選擇「建立新題本」則顯示命名對話框
///   3. 寫入資料庫
///   4. 顯示 SnackBar 結果通知
///
/// 呼叫端只需提供 context、userId、questionIds 即可，
/// 不再需要自行建立 AlertDialog 或操作 DatabaseHelper。
abstract final class AddToPaperService {
  /// 將「單一或多個題目 ID」加入（或新建）題本。
  ///
  /// [context]        — 用於顯示 Dialog / SnackBar 的 BuildContext
  /// [userId]         — 當前使用者 ID
  /// [questionIds]    — 要加入的題目 ID 清單（單題時傳一個元素的 list）
  /// [defaultNewName] — 「建立新題本」時的預設名稱提示；
  ///                    若不傳，預設為 "題本 N"（N = 現有題本數 + 1）
  ///
  /// 回傳：成功加入後的題本 `{'id': int, 'name': String}`；
  ///       使用者取消或失敗時回傳 null。
  static Future<Map<String, dynamic>?> show({
    required BuildContext context,
    required String userId,
    required List<int> questionIds,
    String? defaultNewName,
  }) async {
    if (questionIds.isEmpty) return null;

    // ── Step 1：從資料庫取得現有題本列表 ─────────────────────────
    final List<Map<String, dynamic>> papers;
    try {
      papers = await DatabaseHelper.instance.getPapersForUser(userId);
    } catch (e) {
      debugPrint('AddToPaperService: 取得題本列表失敗: $e');
      if (context.mounted) {
        _showSnackBar(context, '載入題本列表失敗，請稍後再試');
      }
      return null;
    }

    if (!context.mounted) return null;

    // ── Step 2：顯示題本選擇對話框 ───────────────────────────────
    final selectedPaper = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('選擇要加入的自訂題本'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: papers.length + 1,
            itemBuilder: (_, index) {
              if (index == 0) {
                return ListTile(
                  leading: const Icon(Icons.add, color: Colors.blue),
                  title: const Text(
                    '建立新題本並加入',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, {'action': 'create_new'}),
                );
              }
              final p = papers[index - 1];
              return ListTile(
                leading: const Icon(
                  Icons.assignment_rounded,
                  color: Colors.orange,
                ),
                title: Text(p['name'] ?? '未命名題本'),
                onTap: () => Navigator.pop(ctx, p),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (selectedPaper == null) return null;
    if (!context.mounted) return null;

    // ── Step 3a：使用者選擇「建立新題本」 ───────────────────────
    if (selectedPaper['action'] == 'create_new') {
      final fallbackName = defaultNewName ?? '題本 ${papers.length + 1}';
      final newNameController = TextEditingController();

      final newPaperName = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('建立新題本'),
          content: TextField(
            controller: newNameController,
            decoration: InputDecoration(
              labelText: '題本名稱',
              hintText: fallbackName,
            ),
            autofocus: true,
            onSubmitted: (text) {
              Navigator.pop(ctx, text.trim().isEmpty ? fallbackName : text.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = newNameController.text.trim();
                Navigator.pop(ctx, text.isEmpty ? fallbackName : text);
              },
              child: const Text('確定'),
            ),
          ],
        ),
      );

      if (newPaperName == null) return null;
      if (!context.mounted) return null;

      try {
        final newId = await DatabaseHelper.instance.createPaper(
          userId,
          newPaperName,
          questionIds,
        );
        if (context.mounted) {
          _showSnackBar(
            context,
            questionIds.length == 1
                ? '已建立並成功加入「$newPaperName」'
                : '已建立並成功匯入 ${questionIds.length} 題至「$newPaperName」',
          );
        }
        return {'id': newId, 'name': newPaperName};
      } catch (e) {
        debugPrint('AddToPaperService: 建立題本失敗: $e');
        if (context.mounted) _showSnackBar(context, '建立失敗，請稍後再試');
        return null;
      }
    }

    // ── Step 3b：使用者選擇現有題本 ─────────────────────────────
    final paperId = int.tryParse(selectedPaper['id'].toString()) ?? 0;
    final paperName = selectedPaper['name'] ?? '未命名題本';

    try {
      final existingIds =
          await DatabaseHelper.instance.getQuestionIdsForPaper(paperId);
      final int originalCount = existingIds.length;
      final Set<int> mergedSet = {...existingIds, ...questionIds};
      final int addedCount = mergedSet.length - originalCount;

      await DatabaseHelper.instance.updatePaper(
        paperId,
        paperName,
        mergedSet.toList(),
      );

      if (!context.mounted) return null;

      if (addedCount == 0) {
        _showSnackBar(
          context,
          questionIds.length == 1
              ? '此題目已存在於「$paperName」中'
              : '選取的題目均已存在於「$paperName」中',
        );
      } else {
        _showSnackBar(
          context,
          questionIds.length == 1
              ? '已將題目成功加入「$paperName」'
              : '已成功加入 $addedCount 題至「$paperName」！',
        );
      }
      return {'id': paperId, 'name': paperName};
    } catch (e) {
      debugPrint('AddToPaperService: 更新題本失敗: $e');
      if (context.mounted) _showSnackBar(context, '加入失敗，請稍後再試');
      return null;
    }
  }

  // ── 私有：統一 SnackBar 樣式 ─────────────────────────────────
  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1800),
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ),
      );
  }
}
