import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'app_locale_service.dart';

/// 語音辨識特助服務：封裝即時語音轉文字 (Speech-To-Text)、語言包適配與狀態監聽
class VoiceRecognitionService {
  VoiceRecognitionService._();
  static final VoiceRecognitionService instance = VoiceRecognitionService._();

  final SpeechToText _speech = SpeechToText();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  bool get isAvailable => _speech.isAvailable;
  bool get isListening => _speech.isListening;

  List<LocaleName> _systemLocales = [];
  List<LocaleName> get systemLocales => _systemLocales;

  /// 初始化語音辨識服務
  Future<bool> initialize({
    Function(String status)? onStatus,
    Function(SpeechRecognitionError error)? onError,
  }) async {
    if (_isInitialized) return _speech.isAvailable;

    try {
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          debugPrint('語音辨識狀態變更: $status');
          onStatus?.call(status);
        },
        onError: (errorNotification) {
          debugPrint('語音辨識錯誤: ${errorNotification.errorMsg} (permanent: ${errorNotification.permanent})');
          onError?.call(errorNotification);
        },
        debugLogging: kDebugMode,
      );

      if (_isInitialized) {
        _systemLocales = await _speech.locales();
        debugPrint('語音辨識初始化成功，可用語系數: ${_systemLocales.length}');
      }
      return _isInitialized;
    } catch (e) {
      debugPrint('語音辨識初始化異常: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// 依據 App 當前語系找到最適合的辨識 Locale ID
  String? resolveLocaleId([String? appLangCode]) {
    final lang = appLangCode ?? AppLocaleService.currentLanguage;

    if (_systemLocales.isEmpty) return null;

    List<String> targetPrefixes;
    switch (lang) {
      case AppLocaleService.ja:
        targetPrefixes = ['ja_JP', 'ja-JP', 'ja'];
        break;
      case AppLocaleService.ko:
        targetPrefixes = ['ko_KR', 'ko-KR', 'ko'];
        break;
      case AppLocaleService.zhTW:
      default:
        targetPrefixes = [
          'zh_TW',
          'zh-TW',
          'zh_HK',
          'zh-HK',
          'cmn-Hant-TW',
          'cmn-TW',
          'zh'
        ];
        break;
    }

    // 先尋找完全相符或前綴符合
    for (final prefix in targetPrefixes) {
      final normalizedPrefix = prefix.toLowerCase().replaceAll('_', '-');
      for (final locale in _systemLocales) {
        final locId = locale.localeId.toLowerCase().replaceAll('_', '-');
        if (locId == normalizedPrefix || locId.startsWith('$normalizedPrefix-') || locId.startsWith(normalizedPrefix)) {
          return locale.localeId;
        }
      }
    }

    // 次之找開頭
    for (final prefix in targetPrefixes) {
      final pShort = prefix.split(RegExp(r'[-_]')).first.toLowerCase();
      for (final locale in _systemLocales) {
        final locShort = locale.localeId.split(RegExp(r'[-_]')).first.toLowerCase();
        if (locShort == pShort) {
          return locale.localeId;
        }
      }
    }

    return null;
  }

  /// 開始語音辨識
  /// [onResult] 回傳即時辨識出的文字與是否為最終結果
  /// [onSoundLevelChange] 回傳即時音量分貝 (0.0 ~ 10.0+)，可供波形視覺化
  /// [onStatusChange] 狀態變動監聽 (listening, notListening, done)
  /// [onError] 錯誤通知
  Future<bool> startListening({
    required void Function(String words, bool isFinal) onResult,
    void Function(double level)? onSoundLevelChange,
    void Function(String status)? onStatusChange,
    void Function(String errorMessage)? onError,
    String? languageCode,
  }) async {
    if (!_isInitialized) {
      final ok = await initialize(
        onStatus: onStatusChange,
        onError: (err) => onError?.call(err.errorMsg),
      );
      if (!ok) {
        onError?.call('裝置不支援語音辨識或未授予麥克風權限');
        return false;
      }
    }

    if (_speech.isListening) {
      await stopListening();
    }

    final localeId = resolveLocaleId(languageCode);
    debugPrint('啟動語音辨識，使用 localeId: $localeId');

    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          final words = result.recognizedWords;
          // 即時傳送部分結果或最終結果 (忽略空白雜訊)
          if (words.isNotEmpty || result.finalResult) {
            onResult(words, result.finalResult);
          }
        },
        onSoundLevelChange: onSoundLevelChange,
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          onDevice: false,
          autoPunctuation: true,
          sampleRate: 0,
          localeId: localeId,
          pauseFor: const Duration(seconds: 15), // 提高停頓容忍時間至 15 秒，避免講話中途換氣被中斷
          listenFor: const Duration(minutes: 5),  // 提高最長單次收音時間
        ),
      );
      return true;
    } catch (e) {
      debugPrint('啟動語音辨識失敗: $e');
      onError?.call('無法啟動語音辨識: $e');
      return false;
    }
  }

  /// 智慧過濾去除語音常見贅字、語助詞與口吃重複詞 (如「痾」、「呃」、「那個」、「就是說」等)
  static String cleanFillerWords(String text) {
    if (text.trim().isEmpty) return text;
    String cleaned = text;

    // 1. 去除單字 3 次以上的嚴重口吃 (例如：「我我我」->「我」、「對對對」->「對」)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'([\u4e00-\u9fa5])\1{2,}'),
      (match) => match.group(1) ?? '',
    );

    // 2. 去除 2~3 字詞連續重複的口吃 (例如：「這個這個」->「這個」、「然後然後」->「然後」)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'([\u4e00-\u9fa5]{2,3})\1+'),
      (match) => match.group(1) ?? '',
    );

    // 3. 去除口語語助詞與停頓音 (痾、呃、唔)
    cleaned = cleaned.replaceAll(RegExp(r'[痾呃唔]'), '');

    // 4. 去除常見口語贅語 (如：「就是說」、「然後呢」、「應該是說」、「基本上就是」)
    cleaned = cleaned.replaceAll(
      RegExp(r'(就是說|然後呢|應該是說|基本上就是|基本上說|總之就是)'),
      '',
    );

    // 5. 去除句首或標點前後的「那個」
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(^|[\s，,。！？\n])那個+([\s，,。！？\n]|$)'),
      (match) => '${match.group(1) ?? ''}${match.group(2) ?? ''}',
    );

    // 6. 去除句首的停頓嘆詞 (如：「嗯、啊、欸、喔」)
    cleaned = cleaned.replaceAll(
      RegExp(r'^[嗯啊欸喔捏啦嘛]+[\s，,。！？]*'),
      '',
    );

    // 6. 清理多餘的標點符號與空白
    cleaned = cleaned
        .replaceAll(RegExp(r'[，,]{2,}'), '，')
        .replaceAll(RegExp(r'[。]{2,}'), '。')
        .replaceAll(RegExp(r'^[，,。！？\s]+'), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return cleaned;
  }

  /// 停止語音辨識（保留目前已辨識內容）
  Future<void> stopListening() async {
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (e) {
      debugPrint('停止語音辨識異常: $e');
    }
  }

  /// 取消語音辨識
  Future<void> cancelListening() async {
    try {
      if (_speech.isListening) {
        await _speech.cancel();
      }
    } catch (e) {
      debugPrint('取消語音辨識異常: $e');
    }
  }
}
