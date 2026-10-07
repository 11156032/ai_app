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
          debugPrint(
              '語音辨識底層錯誤: ${errorNotification.errorMsg} (permanent: ${errorNotification.permanent})');
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
          if (locId == normalizedPrefix ||
              locId.startsWith('$normalizedPrefix-') ||
              locId.startsWith(normalizedPrefix)) {
            return locale.localeId;
          }
        }
      }

      // 次之找開頭
      for (final prefix in targetPrefixes) {
        final pShort = prefix.split(RegExp(r'[-_]')).first.toLowerCase();
        for (final locale in _systemLocales) {
          final locShort =
              locale.localeId.split(RegExp(r'[-_]')).first.toLowerCase();
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

  // 累積已定稿的文字（跨多個底層 Session 與停頓）
  String _accumulatedFinalText = '';
  // 當前 Session 正在收音的即時臨時辨識文字
  String _currentInterimWords = '';

  // 記錄單次原生 Session 交付的最後內容，防範原生無預警在中途 done 造成丟字
  String _lastRecognizedWords = '';
  bool _lastWasFinal = false;

  bool get isListening => _shouldKeepListening || _speech.isListening;

  /// 當前累積所有已定稿與臨時辨識字詞的即時完整文字
  String get fullRecognizedText => joinText(_accumulatedFinalText, _currentInterimWords);

  /// 智慧拼接前後語句，避免中文間產生多餘空白、英文字詞間缺少空白
  static String joinText(String base, String addition) {
    final b = base.trim();
    final a = addition.trim();
    if (b.isEmpty) return a;
    if (a.isEmpty) return b;

    // 檢查 base 結尾與 addition 開頭
    final lastChar = b.substring(b.length - 1);
    final firstChar = a.substring(0, 1);

    // 如果 base 結尾已有標點符號（如 ，。！？,!?），直接拼接或加適當空格
    final isPunct = RegExp(r'[，。！？；：、\.,!?;:]').hasMatch(lastChar);
    if (isPunct) {
      if (RegExp(r'[a-zA-Z0-9]').hasMatch(firstChar) && RegExp(r'[\.,!?;:]').hasMatch(lastChar)) {
        return '$b $a';
      }
      return '$b$a';
    }

    // 如果前後都是 ASCII 英數字，需要加上空格隔開
    final isBaseAlnum = RegExp(r'[a-zA-Z0-9]').hasMatch(lastChar);
    final isAddAlnum = RegExp(r'[a-zA-Z0-9]').hasMatch(firstChar);
    if (isBaseAlnum && isAddAlnum) {
      return '$b $a';
    }

    // 繁體中文/日韓等 CJK 字符直接無縫拼接
    return '$b$a';
  }

  /// 開始語音辨識
  /// [onResult] 回傳即時辨識出的完整文字與是否為最終結果
  /// [onSoundLevelChange] 回傳即時音量分貝 (0.0 ~ 10.0+)，可供波形視覺化
  /// [onStatusChange] 狀態變動監聽 (listening, notListening, done)
  /// [onError] 錯誤通知
  /// [initialText] 起始文字（若輸入框中原本已有文字，會自動作為底稿繼續拼接）
  Future<bool> startListening({
    required void Function(String words, bool isFinal) onResult,
    void Function(double level)? onSoundLevelChange,
    void Function(String status)? onStatusChange,
    void Function(String errorMessage)? onError,
    String? languageCode,
    String initialText = '',
  }) async {
    _shouldKeepListening = true;
    _onResultCallback = onResult;
    _onSoundLevelCallback = onSoundLevelChange;
    _onStatusCallback = onStatusChange;
    _onErrorCallback = onError;
    _currentLanguageCode = languageCode;
    _accumulatedFinalText = initialText.trim();
    _currentInterimWords = '';
    _lastRecognizedWords = '';
    _lastWasFinal = false;

    if (!_isInitialized) {
      final ok = await initialize(
        onStatus: _handleStatusChange,
        onError: _handleError,
      );
      if (!ok) {
        _shouldKeepListening = false;
        onError?.call(tr('stt_unsupported'));
        return false;
      }
    }

    return _executeListen();
  }

  void _handleStatusChange(String status) {
    debugPrint(
        'VoiceRecognitionService 狀態變更: $status (shouldKeepListening: $_shouldKeepListening)');

    // 若底層 Session 結束（notListening / done），但最後辨識出的文字尚未定稿，強制累積合併
    if (_currentInterimWords.trim().isNotEmpty) {
      _accumulatedFinalText = joinText(_accumulatedFinalText, _currentInterimWords);
      _currentInterimWords = '';
      _lastRecognizedWords = '';
      _lastWasFinal = true;
      _onResultCallback?.call(_accumulatedFinalText, true);
    } else if (_lastRecognizedWords.trim().isNotEmpty && !_lastWasFinal) {
      _accumulatedFinalText = joinText(_accumulatedFinalText, _lastRecognizedWords);
      _lastRecognizedWords = '';
      _lastWasFinal = true;
      _onResultCallback?.call(_accumulatedFinalText, true);
    }

    if (_shouldKeepListening) {
      // 處於持續收音模式下，單次 session 的暫停不向外發送終止狀態，維持 UI 的聆聽波形
      _onStatusCallback?.call('listening');
      if (status == 'notListening' || status == 'done') {
        _scheduleAutoRestart();
      }
    } else {
      _onStatusCallback?.call(status);
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

  void _scheduleAutoRestart([int delayMs = 150]) {
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
        await Future.delayed(const Duration(milliseconds: 30));
      }

      final localeId = resolveLocaleId(_currentLanguageCode);
      debugPrint('啟動語音辨識 Session，使用 localeId: $localeId');

      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          final words = result.recognizedWords.trim();
          _lastRecognizedWords = words;
          _lastWasFinal = result.finalResult;

          if (result.finalResult) {
            if (words.isNotEmpty) {
              _accumulatedFinalText = joinText(_accumulatedFinalText, words);
            }
            _currentInterimWords = '';
            _onResultCallback?.call(_accumulatedFinalText, true);
          } else {
            _currentInterimWords = words;
            final liveFullText = joinText(_accumulatedFinalText, _currentInterimWords);
            if (liveFullText.isNotEmpty) {
              _onResultCallback?.call(liveFullText, false);
            }
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
        _scheduleAutoRestart(300);
      } else {
        _onErrorCallback?.call(tr('stt_start_failed', [e.toString()]));
      }
      return false;
    }
  }

  /// 停止語音辨識並重置狀態，回傳最終文字
  Future<String> stopListening() async {
    _shouldKeepListening = false;
    _restartTimer?.cancel();
    _restartTimer = null;

    if (_currentInterimWords.trim().isNotEmpty) {
      _accumulatedFinalText = joinText(_accumulatedFinalText, _currentInterimWords);
      _currentInterimWords = '';
    } else if (_lastRecognizedWords.trim().isNotEmpty && !_lastWasFinal) {
      _accumulatedFinalText = joinText(_accumulatedFinalText, _lastRecognizedWords);
      _lastRecognizedWords = '';
    }
    _lastWasFinal = true;

    final finalText = _accumulatedFinalText.trim();
    _onResultCallback?.call(finalText, true);
    _onStatusCallback?.call('notListening');

    try {
      await _speech.stop();
    } catch (_) {}

    return finalText;
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

    // 5. 去除相鄰重複的完整片語或重複句子 (如 "你好 你好" -> "你好", "如何修改密碼 如何修改密碼" -> "如何修改密碼")
    final words = cleaned.split(RegExp(r'\s+'));
    if (words.length > 1) {
      final deduped = <String>[];
      for (final w in words) {
        if (deduped.isEmpty || deduped.last != w) {
          deduped.add(w);
        }
      }
      cleaned = deduped.join(' ');
    }

    // 6. 去除中文無空白相連重複句 (如 "如何修改密碼如何修改密碼" -> "如何修改密碼")
    if (cleaned.length >= 6) {
      final half = cleaned.length ~/ 2;
      if (cleaned.substring(0, half) == cleaned.substring(half)) {
        cleaned = cleaned.substring(0, half);
      }
    }

    // 7. 自動補充與修飾繁體中文標點符號
    return ensureChinesePunctuation(cleaned);
  }

  /// 智慧補充繁體中文適當標點符號（句號、逗號、問號、頓號）
  static String ensureChinesePunctuation(String input) {
    if (input.trim().isEmpty) return input;
    String text = input.trim();

    // 1. 全角/半角標點符號標準化
    text = text
        .replaceAll(RegExp(r'\.(?=\s|$)'), '。')
        .replaceAll(RegExp(r'\?(?=\s|$)'), '？')
        .replaceAll(RegExp(r'\!(?=\s|$)'), '！')
        .replaceAll(RegExp(r',(?=\s|$)'), '，');

    // 2. 針對未分句的長句（> 12 字且無標點），在常見連接詞/轉折詞前自動補逗號
    final pauseKeywords = [
      '但是', '不過', '然而', '所以', '因此', '另外', '此外',
      '同時', '接著', '然後', '最後', '假設', '如果', '因為', '由於'
    ];
    for (final kw in pauseKeywords) {
      text = text.replaceAllMapped(
        RegExp('(?<=[^，。！？；：\n\\s])$kw'),
        (match) => '，$kw',
      );
    }

    // 3. 按行處理，確保每一行/句子都有合適的結尾標點
    final lines = text.split('\n');
    final processedLines = lines.map((line) {
      String l = line.trim();
      if (l.isEmpty) return l;

      // 若為 Markdown 標題、代碼塊、清單前綴，保留格式
      if (l.startsWith('#') || l.startsWith('- [') || l.startsWith('```') || l == '---') {
        return l;
      }

      // 檢查句尾是否有標點符號
      final endsWithPunct = RegExp(r'[。！？，；：…\?\!,\.\:\;]$').hasMatch(l);
      if (!endsWithPunct) {
        if (RegExp(r'(嗎|呢|吧|是否|對不對|是不是|對吧|哪裡|什麼|甚麼|怎麼|如何|為什麼)$').hasMatch(l)) {
          l += '？';
        } else {
          l += '。';
        }
      }
      return l;
    }).toList();

    return processedLines.join('\n');
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
