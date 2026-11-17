// 真實 AI 筆記整理品質檢查腳本（獨立於 flutter test，可訪問真實網路）
// 用法: dart run tool/ai_style_quality_check.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _kProxyUrl = 'https://ai-app-proxy.adenlee36.workers.dev';

const _styleInstructions = <String, String>{
  '課堂與學術研討': '''
【整理風格：🎓 課堂與學術研討】
架構依據康乃爾分層筆記法，請在 content 中輸出以下結構：
# 🎓 [主題名稱]
## 📖 核心名詞與術語解析
- **[術語名]**：以指定的輸出語言給予清晰白話之定義與核心概念。
## 🧠 課堂脈絡與考點梳理
梳理課程觀念、推導因果與重要關聯點。
## ❓ 自我檢測問答 (Active Recall)
提供 3~5 題幫助主動回憶的問答題：
- **Q1**：[關鍵問題？]
  - **A**：[核心解答提示與解析]
''',
  '敏捷商務會議': '''
【整理風格：💼 敏捷商務會議】
以決策導向與行動落實為核心，請在 content 中輸出以下結構：
# 💼 [會議主題名稱]
## ⚡ 一話決策 (Executive TL;DR)
> 1 句話精準概括本次會議最重大之核心結論或推進決策。
## 🤝 議程共識與決議
條列說明各項討論達成的明確共識。
## ✅ 待辦行動清單
使用可勾選清單，格式嚴格遵循：
- [ ] [具體動作] (負責人: [姓名或未指定] | 預計時程: [日期或待定])
（同時將上述各項待辦填入 JSON 的 action_items 陣列）
''',
  '極速速讀摘要': '''
【整理風格：⚡ 極速速讀摘要】
以極致降噪、快速決策為核心，請在 content 中輸出以下結構（全部使用條列，嚴禁使用表格語法）：
# ⚡ [精華速讀標題]
## 🎯 30秒核心金句
3~5 條「重新提煉」的關鍵事實，每條一句話，嚴禁照抄逐字稿原文、嚴禁殘留贅字或時間戳：
1. [具體事實／數據 1]
2. [具體事實／數據 2]
3. [具體事實／數據 3]
## 📊 重點聚焦
- **[主題 1]**：[核心內容一句話] → [後續動向或注意事項]
- **[主題 2]**：[核心內容一句話] → [後續動向或注意事項]
- **[主題 3]**：[核心內容一句話] → [後續動向或注意事項]
''',
  '架構拆解與心智圖': '''
【整理風格：🧠 架構拆解與心智圖】
以層級結構化拓撲為核心，請在 content 中輸出純文字階層大綱（嚴禁使用 mermaid 或任何程式碼區塊）：
# 🧠 [核心架構主題]
## 🌳 階層化知識大綱
嚴格使用最多三層之標題與符號：
- # 一級架構
  - ## 二級子模組
    - ### 三級要點解析
（同時將樹狀階層結構完整填入 JSON 的 mindmap 欄位，供 App 互動式心智圖畫布展示）
''',
  '靈感閃念與隨筆': '''
【整理風格：💡 靈感閃念與隨筆】
保留思維原味與心流，請在 content 中輸出以下結構：
# 💡 [靈感隨筆主題]
## 🌟 核心閃念亮點
> [提取最具啟發性的 1~2 句思維火花金句]
## 💭 心得感悟與靈感流動
輕盈自然的隨想流動記錄。
## 🏷️ 延伸聯想與思考方向
- #思考延伸 [方向1]
- #未來應用 [方向2]
''',
};

const _transcriptMeeting =
    '呃那個我們今天來討論一下那個期中專題的方向啦痾就是就是那個語音筆記功能'
    '我我我想說可以加入那個AI自動整理，然後那個小明你負責UI的部分下禮拜五之前給我原型'
    '然後大發你去看一下那個Whisper的API文件，我們禮拜三要demo給教授看'
    '那個預算大概就五千塊左右OK那先這樣痾對了下次開會是禮拜三下午兩點在B302教室';

/// 模擬真實單人獨白逐字稿（含時間戳與說話者標籤，無明確待辦）——對應實機回報的失敗案例
const _transcriptRealCase =
    '[00:00] 說話者 1: 畫面上一樣是穿著這個卡洛芙的鞋子。好不好看總共有三種款式耿鬼皮卡丘還有胖丁通通都是免費給玩家兌換領取的'
    '只要到官方的商城兌換優惠裡面輸入這三組序號就能免費兌換請大家趕快換起來那這個鞋子是有出實體版本的'
    '有興趣的朋友可以關注一下它的購買方式。再來第二件事情就是悠遊看直播領取獎勵的活動啦就在這個禮拜五的晚上8點'
    'Pokemon GO的Twitch直播台將會直播PVP對戰請記得到時候鎖定頻道那我們就下次見拜拜';

String _buildPrompt(String styleInstruction, String transcript) {
  return '你是一位頂級的語音筆記整理與逐字稿語意校正專家，擅長把口語化、中英夾雜的逐字稿進行專業校正，'
      '並轉換為自然、清晰、有條理的專業結構化筆記。\n\n'
      '【核心原則】\n'
      '1. 說話者分離 (Diarization) 與標點符號完整校正：\n'
      '   - 說話者辨識 (Diarization)：若輸入語音逐字稿含有多位說話者或時間戳（例如 [00:15] 說話者 1: ... 或對話語境），'
      '請在 "corrected_transcript" 中明確保留與區分「說話者 1」、「說話者 2」或角色名稱。\n'
      '   - content 是整理後的筆記，不是逐字稿：除非是多人對話且區分發言者對理解不可或缺，'
      '否則嚴禁在 content 段落中直接貼入時間戳（如 [00:00]）或「說話者 1:」標籤。\n'
      '   - 標點符號完整化：強制為所有語句補充輸出語言對應的正確標點符號，嚴禁輸出完全無標點符號的連續文字。\n'
      '   - 精確校正中英文專有名詞、專業術語、同音錯字（例如將「摸豆」校正為「Model」、「API」、「Flutter」等），'
      '並剔除口語贅字（如「呃、啊、那個」）。\n'
      '2. 術語規範（僅在輸出語言為繁體中文時適用）：專案（嚴禁「項目」）、使用者（嚴禁「用戶」）、'
      '資料庫（嚴禁「數據庫」）、程式碼（嚴禁「代碼」）、伺服器（嚴禁「服務器」）、透過（嚴禁「通過」）、'
      '資訊（嚴禁「信息」）、預設（嚴禁「默認」）、即時（嚴禁「實時」）、雲端（嚴禁「雲」）。\n'
      '3. 防通靈與防空標籤規範：\n'
      '   - 嚴禁通靈未在語音中提及的人名、日期或數據。若未提及負責人標註「[未指定]」，未提及期限標註「[待定]」。\n'
      '   - 若語音中完全無待辦事項，action_items 必須回傳空陣列 []，嚴禁生成「無」、「無待辦」等佔位文字。\n'
      '4. 防偷懶與防原始符號規範（最高優先）：\n'
      '   - title 必須是概括主題的精煉標題，嚴禁直接複製逐字稿開頭，嚴禁包含時間戳（如 [00:00]）、「說話者 1」等標籤或「0000」等雜訊。\n'
      '   - content 各段落必須是重新提煉、重新組織後的筆記文字，嚴禁整段照抄逐字稿原文；時間戳與說話者標籤只允許出現在 corrected_transcript。\n'
      '   - 嚴禁使用「詳見上方」、「如上所述」等空泛佔位句，每個段落都必須有實質內容。\n'
      '   - 嚴禁在 content 中使用 Markdown 表格語法（| 分欄）或 ``` 程式碼區塊（App 編輯器不會渲染，使用者只會看到原始符號）。\n'
      '5. 【長度適配】：請依據內容長度適當展開，條理清晰、重點分明。\n'
      '6. 【微調層級：📚 詳盡 (Detailed)】：完整梳理邏輯脈絡、推導過程、論述細節與因果關係。\n\n'
      '$styleInstruction\n\n'
      '【JSON 輸出格式規範】\n'
      '你必須只回傳一個乾淨、標準的 JSON 物件，不得包含任何 Markdown 代碼塊前後包裝，直接以 { 開頭以 } 結尾：\n\n'
      '{\n'
      '  "title": "簡短精確的筆記標題（15字以內）",\n'
      '  "category": "工作",\n'
      '  "summary": "核心情境摘要（1~2句）",\n'
      '  "key_points": ["關鍵重點1", "關鍵重點2"],\n'
      '  "action_items": [\n'
      '    { "task": "動作描述", "owner": "負責人（無則填未指定）", "due_date": "期限（無則填待定）", "is_completed": false }\n'
      '  ],\n'
      '  "mindmap": { "id": "root", "label": "核心主題", "color": "#673AB7", "children": [] },\n'
      '  "content": "完整的 Markdown 筆記內容（請嚴格依照風格指示排版）",\n'
      '  "corrected_transcript": "校正後的逐字稿",\n'
      '  "tags": ["關鍵標籤1", "關鍵標籤2"]\n'
      '}\n\n'
      '【原始語音轉文字稿】：\n$transcript\n\n'
      '請使用繁體中文（台灣用語）回答。\n';
}

/// 模擬 App 的思考標籤清理
String stripThinkTags(String raw) {
  return raw
      .replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '')
      .replaceAll(RegExp(r'</?think>'), '');
}

/// 模擬 App 的 cleanRawMarkdown
String cleanRawMarkdown(String raw) {
  var content = raw.trim();
  if (content.startsWith('```markdown')) {
    content = content.replaceFirst(RegExp(r'^```markdown\s*'), '');
    if (content.endsWith('```')) {
      content = content.replaceFirst(RegExp(r'\s*```$'), '');
    }
  } else if (content.startsWith('```md')) {
    content = content.replaceFirst(RegExp(r'^```md\s*'), '');
    if (content.endsWith('```')) {
      content = content.replaceFirst(RegExp(r'\s*```$'), '');
    }
  }
  return content.trim();
}

Future<void> main(List<String> args) async {
  // 可選參數: --model xxx --max-tokens N --style 風格名稱 --transcript meeting|real
  var model = 'openai/gpt-oss-20b';
  int? maxTokens;
  var onlyStyle = '';
  var transcript = _transcriptMeeting;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--model' && i + 1 < args.length) model = args[++i];
    if (args[i] == '--max-tokens' && i + 1 < args.length) {
      maxTokens = int.tryParse(args[++i]);
    }
    if (args[i] == '--style' && i + 1 < args.length) onlyStyle = args[++i];
    if (args[i] == '--transcript' && i + 1 < args.length) {
      transcript = args[++i] == 'real' ? _transcriptRealCase : _transcriptMeeting;
    }
  }
  stdout.writeln('（逐字稿: ${transcript == _transcriptRealCase ? '真實案例獨白' : '混亂會議'}）');

  final secret = File('assets/keys.env')
      .readAsLinesSync()
      .where((l) => l.startsWith('APP_CLIENT_SECRET='))
      .map((l) => l.substring('APP_CLIENT_SECRET='.length))
      .first;

  var pass = 0, fail = 0;
  final problems = <String, List<String>>{};

  for (final entry in _styleInstructions.entries) {
    if (onlyStyle.isNotEmpty && entry.key != onlyStyle) continue;
    if (pass + fail > 0) {
      stdout.writeln('（等待 20 秒避開 Groq TPM 限流...）');
      await Future<void>.delayed(const Duration(seconds: 20));
    }
    final styleName = entry.key;
    stdout.writeln('\n══════════ 測試風格: $styleName ══════════');
    try {
      final client = HttpClient();
      final req = await client.postUrl(Uri.parse(_kProxyUrl));
      req.headers.set('Content-Type', 'application/json; charset=utf-8');
      req.headers.set('x-app-secret', secret);
      final payloadMap = <String, dynamic>{
        'provider': 'groq',
        'model': model,
        'prompt': _buildPrompt(entry.value, transcript),
      };
      if (maxTokens != null) payloadMap['max_tokens'] = maxTokens;
      final payload = jsonEncode(payloadMap);
      stdout.writeln('（模型: $model${maxTokens != null ? ', max_tokens: $maxTokens' : ''}）');
      req.add(utf8.encode(payload));
      final res = await req.close().timeout(const Duration(seconds: 60));
      final body = await res.transform(utf8.decoder).join();
      client.close();

      if (res.statusCode != 200) {
        stdout.writeln('❌ HTTP ${res.statusCode}: ${body.substring(0, body.length.clamp(0, 200))}');
        fail++;
        continue;
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      final rawText = (data['choices']?[0]?['message']?['content'] as String?) ?? '';
      if (rawText.trim().isEmpty) {
        stdout.writeln('❌ 回應無內容');
        fail++;
        continue;
      }

      // ── 模擬 App 解析流程 ──
      var cleaned = stripThinkTags(rawText).trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned
            .replaceFirst(RegExp(r'^```[a-z]*\n?'), '')
            .replaceFirst(RegExp(r'\n?```$'), '')
            .trim();
      }

      final issues = <String>[];
      Map<String, dynamic>? decoded;
      try {
        decoded = jsonDecode(cleaned) as Map<String, dynamic>;
      } catch (e) {
        issues.add('JSON 解析失敗（App 會退化為本地降級）: $e');
      }

      if (decoded != null) {
        final title = ((decoded['title'] as String?) ?? '').trim();
        final content = cleanRawMarkdown((decoded['content'] as String?) ?? '');
        final summary = ((decoded['summary'] as String?) ?? '').trim();
        final tags = decoded['tags'] is List ? (decoded['tags'] as List) : <dynamic>[];
        final actionItems = decoded['action_items'] is List
            ? (decoded['action_items'] as List)
            : <dynamic>[];

        // ── 品質檢查 ──
        if (title.isEmpty) issues.add('標題為空');
        if (title.length > 30) issues.add('標題過長($title)');
        if (RegExp(r'說話者\s*\d|\[\d{2}:\d{2}\]|0000').hasMatch(title)) {
          issues.add('標題含時間戳/說話者標籤/雜訊: $title');
        }
        if (content.trim().isEmpty) issues.add('內容為空');
        if (content.trim().length < transcript.length ~/ 4) {
          issues.add('內容過短(${content.trim().length}字)，疑似沒有實質整理');
        }
        // 逐字稿開頭 12 字原樣出現在內容中 → AI 照抄原文沒整理
        final head = transcript.replaceAll(RegExp(r'^\[.*?\]\s*說話者\s*\d[:：]\s*'), '');
        if (content.contains(head.substring(0, head.length.clamp(0, 12)))) {
          issues.add('內容整段照抄逐字稿原文（金句未重新提煉）');
        }
        if (!content.contains('#')) issues.add('內容缺乏 Markdown 標題結構');
        if (content.contains('</think>')) issues.add('內容殘留思考標籤');
        final fillers = RegExp('[痾呃]').allMatches(content).length;
        if (fillers > 1) issues.add('內容殘留口語贅字 $fillers 處');
        if (RegExp(r'[\uFFFD]').hasMatch(content)) issues.add('內容含亂碼字元');
        if (content.contains('```')) {
          issues.add('內容含程式碼塊，App 編輯器不渲染會顯示原始碼');
        }
        if (RegExp(r'^\s*\|', multiLine: true).hasMatch(content)) {
          issues.add('內容含 Markdown 表格符號(|)，App 編輯器不渲染');
        }
        if (content.contains('詳見') || content.contains('如上所述')) {
          issues.add('內容含空泛佔位句（詳見/如上所述）');
        }
        if ((RegExp(r'說話者\s*\d').hasMatch(content) ||
                RegExp(r'\[\d{2}:\d{2}\]').hasMatch(content)) &&
            styleName != '敏捷商務會議') {
          issues.add('content 殘留時間戳/說話者標籤（只允許在 corrected_transcript）');
        }
        if (actionItems.isEmpty && transcript.contains('負責')) {
          issues.add('逐字稿明確有任務指派，但 action_items 為空');
        }
        if (tags.isEmpty) issues.add('標籤為空');

        stdout.writeln('【標題】$title');
        stdout.writeln('【摘要】$summary');
        stdout.writeln('【標籤】${tags.join(', ')}');
        stdout.writeln('【待辦】${actionItems.map((a) => a['task']).join(' / ')}');
        stdout.writeln('【內容前 500 字】\n${content.substring(0, content.length.clamp(0, 500))}');
      }

      if (issues.isEmpty) {
        stdout.writeln('✅ 通過所有品質檢查');
        pass++;
      } else {
        for (final i in issues) {
          stdout.writeln('⚠️ 問題: $i');
        }
        problems[styleName] = issues;
        fail++;
      }
    } catch (e) {
      stdout.writeln('❌ 例外: $e');
      fail++;
    }
  }

  stdout.writeln('\n══════════ 總結 ══════════');
  stdout.writeln('通過: $pass / ${_styleInstructions.length}');
  problems.forEach((k, v) {
    stdout.writeln('[$k] ${v.join(' | ')}');
  });
  exit(fail == 0 ? 0 : 1);
}
