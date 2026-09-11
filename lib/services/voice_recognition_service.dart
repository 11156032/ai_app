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

  List<LocaleName> _systemLocales = [];
  List<LocaleName> get systemLocales => _systemLocales;

  /// 初始化語音辨識服務
  Future<bool> initialize({
    Function(String status)? onStatus,
    Function(SpeechRecognitionError error)? onError,
  }) async {
    if (onStatus != null) _onStatusCallback = onStatus;
    if (onError != null) {
      _onErrorCallback = (msg) => onError(SpeechRecognitionError(msg, true));
    }

    if (_isInitialized) return _speech.isAvailable;

    try {
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          debugPrint('語音辨識底層狀態變更: $status');
          _handleStatusChange(status);
        },
        onError: (errorNotification) {
          debugPrint('語音辨識底層錯誤: ${errorNotification.errorMsg} (permanent: ${errorNotification.permanent})');
          _handleError(errorNotification);
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
  String resolveLocaleId([String? appLangCode]) {
    final lang = appLangCode ?? AppLocaleService.currentLanguage;

    if (_systemLocales.isNotEmpty) {
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
    }

    // 系統預設或尚未獲取 locales 時的穩固保底語系
    switch (lang) {
      case AppLocaleService.ja:
        return 'ja_JP';
      case AppLocaleService.ko:
        return 'ko_KR';
      case AppLocaleService.zhTW:
      default:
        return 'zh_TW';
    }
  }

  /// 開始語音辨識
  bool _shouldKeepListening = false;
  void Function(String words, bool isFinal)? _onResultCallback;
  void Function(double level)? _onSoundLevelCallback;
  void Function(String status)? _onStatusCallback;
  void Function(String errorMessage)? _onErrorCallback;
  String? _currentLanguageCode;
  Timer? _restartTimer;

  // 記錄單次原生 Session 交付的最後內容，防範原生無預警在中途 done 造成丟字
  String _lastRecognizedWords = '';
  bool _lastWasFinal = false;

  bool get isListening => _shouldKeepListening || _speech.isListening;

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
    _shouldKeepListening = true;
    _onResultCallback = onResult;
    _onSoundLevelCallback = onSoundLevelChange;
    _onStatusCallback = onStatusChange;
    _onErrorCallback = onError;
    _currentLanguageCode = languageCode;
    _lastRecognizedWords = '';
    _lastWasFinal = false;

    if (!_isInitialized) {
      final ok = await initialize(
        onStatus: _handleStatusChange,
        onError: _handleError,
      );
      if (!ok) {
        _shouldKeepListening = false;
        onError?.call('裝置不支援語音辨識或未授予麥克風權限');
        return false;
      }
    }

    return _executeListen();
  }

  void _handleStatusChange(String status) {
    debugPrint('VoiceRecognitionService 狀態變更: $status (shouldKeepListening: $_shouldKeepListening)');
    _onStatusCallback?.call(status);

    // 若底層 Session 結束（notListening / done），但最後辨識出的文字尚未標記為 Final，強制交付定稿
    if (_lastRecognizedWords.trim().isNotEmpty && !_lastWasFinal) {
      debugPrint('VoiceRecognitionService: 原生階段結束，強制保存未定稿字詞: $_lastRecognizedWords');
      _onResultCallback?.call(_lastRecognizedWords.trim(), true);
      _lastRecognizedWords = '';
      _lastWasFinal = true;
    }

    if (_shouldKeepListening && (status == 'notListening' || status == 'done')) {
      _scheduleAutoRestart();
    }
  }

  void _handleError(SpeechRecognitionError errorNotification) {
    debugPrint('VoiceRecognitionService 收到錯誤: ${errorNotification.errorMsg}');
    if (_shouldKeepListening) {
      _scheduleAutoRestart();
    } else {
      _onErrorCallback?.call(errorNotification.errorMsg);
    }
  }

  void _scheduleAutoRestart([int delayMs = 350]) {
    _restartTimer?.cancel();
    if (!_shouldKeepListening) return;

    _restartTimer = Timer(Duration(milliseconds: delayMs), () {
      if (_shouldKeepListening) {
        debugPrint('VoiceRecognitionService: 自動續接持續收音...');
        _executeListen();
      }
    });
  }

  Future<bool> _executeListen() async {
    if (!_isInitialized || !_shouldKeepListening) return false;

    try {
      if (_speech.isListening) {
        await _speech.stop();
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final localeId = resolveLocaleId(_currentLanguageCode);
      debugPrint('啟動語音辨識 Session，使用 localeId: $localeId');

      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          final words = result.recognizedWords;
          _lastRecognizedWords = words;
          _lastWasFinal = result.finalResult;

          if (words.isNotEmpty || result.finalResult) {
            _onResultCallback?.call(words, result.finalResult);
          }
        },
        onSoundLevelChange: _onSoundLevelCallback,
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          autoPunctuation: true,
          sampleRate: 0,
          localeId: localeId,
          pauseFor: const Duration(seconds: 15),
          listenFor: const Duration(minutes: 30),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('啟動語音辨識異常: $e');
      if (_shouldKeepListening) {
        _scheduleAutoRestart(500);
      } else {
        _onErrorCallback?.call('無法啟動語音辨識: $e');
      }
      return false;
    }
  }

  /// 停止語音辨識並重置狀態
  Future<void> stopListening() async {
    _shouldKeepListening = false;
    _restartTimer?.cancel();

    // 如果還有未交付的字詞，立即交付定稿
    if (_lastRecognizedWords.trim().isNotEmpty && !_lastWasFinal) {
      _onResultCallback?.call(_lastRecognizedWords.trim(), true);
      _lastRecognizedWords = '';
      _lastWasFinal = true;
    }

    try {
      await _speech.stop();
    } catch (_) {}
  }

  /// 智慧過濾去除語音常見贅字、語助詞 (如「痾」、「呃」、「唔」與嚴重口吃)
  static String cleanFillerWords(String text) {
    if (text.trim().isEmpty) return text;
    String cleaned = text;

    // 1. 去除單字 3 次以上的嚴重口吃 (例如：「我我我」->「我」、「對對對」->「對」)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'([\u4e00-\u9fa5])\1{2,}'),
      (match) => match.group(1) ?? '',
    );

    // 2. 去除口語停頓語助詞 (痾、呃、唔)
    cleaned = cleaned.replaceAll(RegExp(r'[痾呃唔]'), '');

    // 3. 去除常見純停頓口頭贅詞 (如：「就是說」、「然後呢」、「基本上就是」、「總之就是」)
    cleaned = cleaned.replaceAll(
      RegExp(r'(就是說|然後呢|基本上就是|基本上說|總之就是)'),
      '',
    );

    // 4. 清理多餘的標點符號與空白
    cleaned = cleaned
        .replaceAll(RegExp(r'[，,]{2,}'), '，')
        .replaceAll(RegExp(r'[。]{2,}'), '。')
        .replaceAll(RegExp(r'^[，,。！？\s]+'), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return cleaned;
  }


  /// 取消語音辨識
  Future<void> cancelListening() async {
    _shouldKeepListening = false;
    _restartTimer?.cancel();
    try {
      if (_speech.isListening) {
        await _speech.cancel();
      }
    } catch (e) {
      debugPrint('取消語音辨識異常: $e');
    }
  }
}
