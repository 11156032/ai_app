/// 將 AI 回覆整理成適合手機窄螢幕閱讀的短行。
///
/// 模型偶爾會輸出 Markdown 標題、表格、程式碼區塊，或一整段沒有斷行的長文。
/// 這裡只做「顯示層」的保守清理，不刪減語意，也不改動原始訊息（複製時仍可取得全文）。
class AssistantTextFormatter {
  const AssistantTextFormatter._();

  /// 一行超過這個長度時，優先在句號、問號、驚嘆號後換行。
  static const int softLineLimit = 40;

  /// 回傳顯示用行；空字串代表段落間距。
  static List<String> format(String text) {
    final result = <String>[];
    var inCodeBlock = false;

    for (final rawLine in text.split('\n')) {
      final trimmed = rawLine.trim();
      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        inCodeBlock = !inCodeBlock;
        continue;
      }
      if (inCodeBlock) continue;

      if (trimmed.isEmpty) {
        if (result.isNotEmpty && result.last.isNotEmpty) {
          result.add('');
        }
        continue;
      }

      final line = sanitizeLine(trimmed);
      if (line.isEmpty) continue;
      result.addAll(splitLongLine(line));
    }

    while (result.isNotEmpty && result.first.isEmpty) {
      result.removeAt(0);
    }
    while (result.isNotEmpty && result.last.isEmpty) {
      result.removeLast();
    }
    return result;
  }

  static String sanitizeLine(String raw) {
    var line = raw.trim();
    if (line.isEmpty) return '';

    // 水平線與 Markdown 表格分隔列
    if (RegExp(r'^[-*_]{3,}$').hasMatch(line)) return '';
    if (line.contains('|') &&
        RegExp(r'^\|?[\s:\-|]+\|?$').hasMatch(line) &&
        line.contains('-')) {
      return '';
    }

    line = line.replaceAll(RegExp(r'^#{1,6}\s*'), '');
    line = line.replaceAll(RegExp(r'^>\s?'), '');
    line = line.replaceAll(RegExp(r'^(助理|助手|AI|回答|答)\s*[:：]\s*'), '');
    line = line.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*'),
      (m) => '【${m.group(1)}】',
    );
    line = line.replaceAll('**', '');
    line = line.replaceAll('`', '');
    line = line.replaceFirst(RegExp(r'^[-*]\s+'), '• ');
    line = line.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF\u00A0]'), ' ');
    line = line.replaceAll(RegExp(r'[ \t]{2,}'), ' ');

    if (line.contains('|')) {
      line = line
          .replaceAll(RegExp(r'\s*\|\s*'), ' ｜ ')
          .replaceAll(RegExp(r'^\s*｜\s*|\s*｜\s*$'), '')
          .trim();
    }
    return line;
  }

  static List<String> splitLongLine(String line) {
    if (line.length <= softLineLimit) return [line];
    // 路徑行讓它自然換行，避免把「 ➜ 」串接的步驟拆散。
    if (line.contains('➜')) return [line];

    final parts = <String>[];
    final buffer = StringBuffer();
    var bracketDepth = 0;

    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      buffer.write(ch);
      if (ch == '【') bracketDepth++;
      if (ch == '】' && bracketDepth > 0) bracketDepth--;

      final isSentenceEnd = bracketDepth == 0 &&
          (ch == '。' || ch == '！' || ch == '？' || ch == '；');
      final remaining = line.length - i - 1;
      if (isSentenceEnd && buffer.length >= 24 && remaining >= 8) {
        parts.add(buffer.toString().trim());
        buffer.clear();
      }
    }

    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) parts.add(tail);

    if (parts.length <= 1 && line.length > softLineLimit + 12) {
      return _splitAtComma(line);
    }
    return parts.isEmpty ? [line] : parts;
  }

  static List<String> _splitAtComma(String line) {
    final parts = <String>[];
    var start = 0;
    for (var i = 0; i < line.length; i++) {
      if ((line[i] == '，' || line[i] == '、') && i - start >= 28) {
        parts.add(line.substring(start, i + 1).trim());
        start = i + 1;
      }
    }
    if (start < line.length) {
      parts.add(line.substring(start).trim());
    }
    return parts.where((part) => part.isNotEmpty).toList();
  }

  /// 太長的關鍵詞若做成 chip，在窄螢幕或放大字體時容易溢出。
  static bool shouldUseChip(String keyword) {
    return keyword.isNotEmpty && keyword.length <= 7 && !keyword.contains('➜');
  }
}
