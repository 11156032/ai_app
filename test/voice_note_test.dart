import 'package:flutter_test/flutter_test.dart';
import 'package:ai_app/services/voice_note_service.dart';
import 'package:ai_app/services/voice_recognition_service.dart';
import 'package:ai_app/screens/notes_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceNoteStyle Tests', () {
    test('All styles have valid emoji, label, description and category', () {
      for (final style in VoiceNoteStyle.values) {
        expect(style.label.isNotEmpty, isTrue);
        expect(style.emoji.isNotEmpty, isTrue);
        expect(style.description.isNotEmpty, isTrue);
        expect(['學習', '工作', '生活', '未分類'].contains(style.suggestedCategory), isTrue);
      }
    });

    test('Style labels match expected descriptions', () {
      expect(VoiceNoteStyle.academicLecture.label, '課堂研討');
      expect(VoiceNoteStyle.agileMeeting.label, '商務會議');
      expect(VoiceNoteStyle.speedSummary.label, '速讀摘要');
      expect(VoiceNoteStyle.structureMindmap.label, '架構心智圖');
      expect(VoiceNoteStyle.inspirationJournal.label, '靈感隨筆');
    });
  });

  group('VoiceNoteResult Tests', () {
    test('copyWith works correctly', () {
      const initial = VoiceNoteResult(
        title: '初始標題',
        category: '學習',
        markdownContent: '內容',
        tags: ['標籤1'],
        rawTranscript: '原始語音',
        isAiGenerated: true,
      );

      final modified = initial.copyWith(
        title: '新標題',
        category: '工作',
      );

      expect(modified.title, '新標題');
      expect(modified.category, '工作');
      expect(modified.markdownContent, '內容');
      expect(modified.tags, ['標籤1']);
      expect(modified.rawTranscript, '原始語音');
      expect(modified.isAiGenerated, isTrue);
    });

    test('Note model holds mindmapJson and actionItems properly', () {
      final note = Note(
        id: 'note_123',
        userId: 'u1',
        title: '物理第一章重點',
        content: '# 慣性定律',
        category: '學習',
        strokes: [],
        updatedAt: DateTime.now(),
        mindmapJson: {
          'id': 'root',
          'label': '牛頓第一定律',
          'color': 0xFF4A148C,
          'children': [
            {'id': 'c1', 'label': '等速運動', 'color': 0xFF1976D2}
          ],
        },
        actionItems: [
          ActionItem(task: '複習觀念題', isCompleted: false),
        ],
      );

      expect(note.mindmapJson != null, isTrue);
      expect(note.mindmapJson!['label'], '牛頓第一定律');
      expect(note.actionItems?.length, 1);
      expect(note.actionItems?.first.task, '複習觀念題');
    });
  });

  group('VoiceNoteService Tests', () {
    test('Empty transcript returns empty VoiceNoteResult', () async {
      final result = await VoiceNoteService.instance.organizeTranscript(
        transcript: '   ',
        style: VoiceNoteStyle.academicLecture,
      );

      expect(result.title, '空白語音筆記');
      expect(result.markdownContent, isEmpty);
      expect(result.isAiGenerated, isFalse);
    });

    test('Organizing transcript with all 4 styles produces valid structured result', () async {
      const sampleTranscript = '今天老師複習了牛頓第一運動定律，也就是慣性定律。如果物體不受外力，靜止的物體會維持靜止，運動的物體會做等速度直線運動。期中考一定會考這題的觀念辨析。';

      for (final style in VoiceNoteStyle.values) {
        final result = await VoiceNoteService.instance.organizeTranscript(
          transcript: sampleTranscript,
          style: style,
        );

        expect(result.title.isNotEmpty, isTrue);
        expect(result.category.isNotEmpty, isTrue);
        expect(result.markdownContent.isNotEmpty, isTrue);
        expect(result.rawTranscript, sampleTranscript);
      }
    });
  });

  group('VoiceRecognitionService Filler Word Cleaning Tests', () {
    test('Cleans common filler words, stutters, and hesitation sounds', () {
      expect(
        VoiceRecognitionService.cleanFillerWords('痾今天天氣很好'),
        '今天天氣很好。',
      );
      expect(
        VoiceRecognitionService.cleanFillerWords('我想說呃要去找老師'),
        '我想說要去找老師。',
      );
      expect(
        VoiceRecognitionService.cleanFillerWords('這個基本上就是牛頓定律'),
        '這個牛頓定律。',
      );
      expect(
        VoiceRecognitionService.cleanFillerWords('我我我想問這個問題，請幫忙解答'),
        '我想問這個問題，請幫忙解答。',
      );
      // 保留正常複疊詞
      expect(
        VoiceRecognitionService.cleanFillerWords('我們來研究研究這個題目'),
        '我們來研究研究這個題目。',
      );
    });

    test('resolveLocaleId returns solid locale fallback', () {
      expect(VoiceRecognitionService.instance.resolveLocaleId('zh_TW'), 'zh_TW');
      expect(VoiceRecognitionService.instance.resolveLocaleId('ja'), 'ja_JP');
      expect(VoiceRecognitionService.instance.resolveLocaleId('ko'), 'ko_KR');
      expect(VoiceRecognitionService.instance.resolveLocaleId(null), 'zh_TW');
    });

    test('VoiceRecognitionService.joinText smart joining for Chinese and English', () {
      // 中文無縫拼接
      expect(VoiceRecognitionService.joinText('我想查詢', '今天的數學作業'), '我想查詢今天的數學作業');
      // 英文空格拼接
      expect(VoiceRecognitionService.joinText('Hello', 'World'), 'Hello World');
      // 標點符號後接中文無縫
      expect(VoiceRecognitionService.joinText('你好，', '請問今天天氣'), '你好，請問今天天氣');
      // 標點符號後接英文保留適當空格
      expect(VoiceRecognitionService.joinText('Note:', 'Chapter 1'), 'Note: Chapter 1');
      // 空白基底安全拼接
      expect(VoiceRecognitionService.joinText('', '開始錄音'), '開始錄音');
      expect(VoiceRecognitionService.joinText('結束錄音', ''), '結束錄音');
    });

    test('Transcript accumulation preserves multiple utterances across pauses without losing text', () {
      String base = '';

      // 模擬第 1 句串流中
      String interim = '我想查詢';
      expect(VoiceRecognitionService.joinText(base, interim), '我想查詢');

      // 使用者停頓，第 1 句定稿
      base = VoiceRecognitionService.joinText(base, interim);
      expect(base, '我想查詢');

      // 使用者停頓後繼續說第 2 句（串流中，前句保留）
      interim = '今天的數學作業';
      expect(VoiceRecognitionService.joinText(base, interim), '我想查詢今天的數學作業');

      // 第 2 句定稿
      base = VoiceRecognitionService.joinText(base, interim);
      expect(base, '我想查詢今天的數學作業');

      // 模擬再次停頓後繼續說第 3 句
      interim = '還有物理公式筆記';
      expect(VoiceRecognitionService.joinText(base, interim), '我想查詢今天的數學作業還有物理公式筆記');

      // 停止收音，整段修飾
      base = VoiceRecognitionService.joinText(base, interim);
      final finalCleaned = VoiceRecognitionService.cleanFillerWords(base);
      expect(finalCleaned.contains('我想查詢今天的數學作業還有物理公式筆記'), isTrue);
    });
  });
}
