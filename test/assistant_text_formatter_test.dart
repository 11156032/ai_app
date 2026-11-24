import 'package:flutter_test/flutter_test.dart';
import 'package:ai_app/utils/assistant_text_formatter.dart';

void main() {
  group('AssistantTextFormatter', () {
    test('移除 Markdown 標題、助理前綴與水平線', () {
      expect(
        AssistantTextFormatter.format('## 標題\n助理：答案\n---\n結尾'),
        ['標題', '答案', '結尾'],
      );
    });

    test('將粗體轉成可讀標籤', () {
      expect(
        AssistantTextFormatter.format('**個人檔案** ➜ **設定**'),
        ['【個人檔案】 ➜ 【設定】'],
      );
    });

    test('路徑行不拆散', () {
      const path = '個人檔案 ➜ 設定與安全 ➜ 自訂導覽列項目順序';
      expect(AssistantTextFormatter.format(path), [path]);
    });

    test('長句在句號後分段', () {
      const text = '這是一段比較長的第一句話，用來測試手機上的換行效果。這是第二句話，長度也超過限制。';
      final lines = AssistantTextFormatter.format(text);
      expect(lines.length, greaterThan(1));
      expect(lines.every((line) => line.isNotEmpty), isTrue);
    });

    test('沒有句號的長句會用逗號分段', () {
      const text = '這是第一段很長的內容需要好好說明，第二段也很長需要繼續補充，第三段繼續延伸更多細節，第四段也要放進來一起閱讀。';
      final lines = AssistantTextFormatter.format(text);
      expect(lines.length, greaterThan(1));
    });

    test('忽略程式碼區塊與表格分隔列', () {
      final lines = AssistantTextFormatter.format(
        '```dart\nprint(1);\n```\n| 功能 | 路徑 |\n|---|---|\n| 客服 | 個人檔案 |',
      );
      expect(lines, ['功能 ｜ 路徑', '客服 ｜ 個人檔案']);
    });

    test('chip 長度限制', () {
      expect(AssistantTextFormatter.shouldUseChip('個人檔案'), isTrue);
      expect(AssistantTextFormatter.shouldUseChip('常見問題與線上客服'), isFalse);
      expect(AssistantTextFormatter.shouldUseChip(''), isFalse);
    });
  });
}
