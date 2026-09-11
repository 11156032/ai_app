import 'package:flutter_test/flutter_test.dart';
import 'package:ai_app/services/voice_note_service.dart';
import 'package:ai_app/services/voice_recognition_service.dart';

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
      expect(VoiceNoteStyle.meetingSummary.label, '會議摘要');
      expect(VoiceNoteStyle.classKeyPoints.label, '課堂重點');
      expect(VoiceNoteStyle.actionConclusion.label, '代辦結論');
      expect(VoiceNoteStyle.dailyJournal.label, '日常隨筆');
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
  });

  group('VoiceNoteService Tests', () {
    test('Empty transcript returns empty VoiceNoteResult', () async {
      final result = await VoiceNoteService.instance.organizeTranscript(
        transcript: '   ',
        style: VoiceNoteStyle.classKeyPoints,
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
        '今天天氣很好',
      );
      expect(
        VoiceRecognitionService.cleanFillerWords('我想說呃要去找老師'),
        '我想說要去找老師',
      );
      expect(
        VoiceRecognitionService.cleanFillerWords('然後然後這個就是說基本上就是牛頓定律'),
        '然後這個牛頓定律',
      );
      expect(
        VoiceRecognitionService.cleanFillerWords('我我我想問這個問題，那個，請幫忙解答'),
        '我想問這個問題，請幫忙解答',
      );
    });
  });
}
