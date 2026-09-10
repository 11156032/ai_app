import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/voice_recognition_service.dart';
import '../services/voice_note_service.dart';

// ============================================================
// 語音速記整理面板 (VoiceNoteSheet)
// 支援即時聲波視覺化、即時逐字稿反饋、暫停/繼續、四大 AI 風格整理與直接儲存
// ============================================================
class VoiceNoteSheet extends StatefulWidget {
  /// 整理完成後回調：傳回標題、分類、Markdown 內容
  final void Function(String title, String category, String markdownContent)? onNoteReady;

  /// 若為 null，則為「新增筆記」模式；若帶值，則為「插入至編輯器」模式
  final String? existingContent;

  /// 外部傳入的 ScrollController (DraggableScrollableSheet 支援)
  final ScrollController? scrollController;

  const VoiceNoteSheet({
    super.key,
    this.onNoteReady,
    this.existingContent,
    this.scrollController,
  });

  @override
  State<VoiceNoteSheet> createState() => _VoiceNoteSheetState();
}

// ============================================================
// 步驟列舉
// ============================================================
enum _SheetStep {
  recording,    // 錄音中 / 暫停 / 逐字稿預覽與風格選擇
  generating,   // AI 智慧整理中
  preview,      // 整理成果預覽與編輯
}

class _VoiceNoteSheetState extends State<VoiceNoteSheet>
    with TickerProviderStateMixin {
  _SheetStep _step = _SheetStep.recording;

  // 語音辨識相關狀態
  bool _isListening = false;
  bool _isPaused = false;
  String _sessionBaseTranscript = '';
  String _currentStreamWords = '';
  double _soundLevel = 0.0;
  Timer? _durationTimer;
  Duration _recordDuration = Duration.zero;

  // 逐字稿編輯控制器
  late TextEditingController _transcriptController;
  final ScrollController _transcriptScrollController = ScrollController();

  // 風格選擇
  VoiceNoteStyle _selectedStyle = VoiceNoteStyle.studyOutline;

  // AI 整理結果
  VoiceNoteResult? _result;
  String? _aiErrorMsg;

  // 成果編輯控制器（預覽步驟）
  late TextEditingController _titleEditController;
  late TextEditingController _contentEditController;
  String _editableCategory = '學習';

  // 動畫控制器
  late AnimationController _waveController;
  late AnimationController _pulseController;
  late AnimationController _starController;

  @override
  void initState() {
    super.initState();
    _transcriptController = TextEditingController();
    _titleEditController = TextEditingController();
    _contentEditController = TextEditingController();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _starController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // 面板開啟後自動嘗試啟動錄音
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startListening();
    });
  }

  @override
  void dispose() {
    VoiceRecognitionService.instance.stopListening();
    _durationTimer?.cancel();
    _waveController.dispose();
    _pulseController.dispose();
    _starController.dispose();
    _transcriptController.dispose();
    _transcriptScrollController.dispose();
    _titleEditController.dispose();
    _contentEditController.dispose();
    super.dispose();
  }

  // ============================================================
  // 語音辨識核心控制
  // ============================================================
  Future<void> _startListening() async {
    if (_isListening) return;

    // 將現有的控制器文字作為基準
    _sessionBaseTranscript = _transcriptController.text.trim();
    _currentStreamWords = '';

    final started = await VoiceRecognitionService.instance.startListening(
      onResult: (words, isFinal) {
        if (!mounted) return;
        if (words.trim().isEmpty && !isFinal) return;

        setState(() {
          _currentStreamWords = words;
          if (isFinal) {
            final cleanedWords = VoiceRecognitionService.cleanFillerWords(words.trim());
            if (cleanedWords.isNotEmpty) {
              if (_sessionBaseTranscript.isEmpty) {
                _sessionBaseTranscript = cleanedWords;
              } else {
                _sessionBaseTranscript = '$_sessionBaseTranscript\n$cleanedWords';
              }
            }
            _currentStreamWords = '';
            _transcriptController.text = _sessionBaseTranscript;
          } else {
            // 即時串流顯示（避免短暫消失）
            final liveText = _sessionBaseTranscript.isEmpty
                ? words
                : '$_sessionBaseTranscript\n$words';
            _transcriptController.text = liveText;
          }
        });
        _autoScrollTranscript();
      },
      onSoundLevelChange: (level) {
        if (!mounted) return;
        setState(() {
          _soundLevel = level.clamp(0.0, 10.0);
        });
      },
      onStatusChange: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          _consolidateInterimText();
          setState(() {
            _isListening = false;
            _isPaused = true;
            _soundLevel = 0.0;
          });
          _durationTimer?.cancel();
        } else if (status == 'listening') {
          setState(() {
            _isListening = true;
            _isPaused = false;
          });
        }
      },
      onError: (errMsg) {
        if (!mounted) return;
        _consolidateInterimText();
        setState(() {
          _isListening = false;
          _isPaused = true;
          _soundLevel = 0.0;
        });
        _durationTimer?.cancel();
        debugPrint('語音辨識通知：$errMsg');
      },
    );

    if (started && mounted) {
      setState(() {
        _isListening = true;
        _isPaused = false;
      });
      _durationTimer?.cancel();
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _isListening) {
          setState(() => _recordDuration += const Duration(seconds: 1));
        }
      });
    }
  }

  /// 暫停收音
  Future<void> _pauseListening() async {
    await VoiceRecognitionService.instance.stopListening();
    _durationTimer?.cancel();
    if (mounted) {
      _consolidateInterimText();
      setState(() {
        _isListening = false;
        _isPaused = true;
        _soundLevel = 0.0;
      });
    }
  }

  /// 停止收音
  Future<void> _stopListening() async {
    await VoiceRecognitionService.instance.stopListening();
    _durationTimer?.cancel();
    if (mounted) {
      _consolidateInterimText();
      setState(() {
        _isListening = false;
        _isPaused = false;
        _soundLevel = 0.0;
      });
    }
  }

  /// 確保暫停或結束時，即時文字完整合併至控制器並自動智慧去贅字
  void _consolidateInterimText() {
    if (_currentStreamWords.trim().isNotEmpty) {
      final processedWords = VoiceRecognitionService.cleanFillerWords(_currentStreamWords.trim());
      if (processedWords.isNotEmpty) {
        if (_sessionBaseTranscript.isEmpty) {
          _sessionBaseTranscript = processedWords;
        } else if (!_sessionBaseTranscript.endsWith(processedWords)) {
          _sessionBaseTranscript = '$_sessionBaseTranscript\n$processedWords';
        }
      }
      _currentStreamWords = '';
    }

    _sessionBaseTranscript = VoiceRecognitionService.cleanFillerWords(_sessionBaseTranscript);
    _transcriptController.text = _sessionBaseTranscript;
  }

  void _clearTranscript() {
    _stopListening();
    setState(() {
      _sessionBaseTranscript = '';
      _currentStreamWords = '';
      _transcriptController.clear();
      _recordDuration = Duration.zero;
      _aiErrorMsg = null;
    });
  }

  void _autoScrollTranscript() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_transcriptScrollController.hasClients) {
        _transcriptScrollController.animateTo(
          _transcriptScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ============================================================
  // AI 整理核心
  // ============================================================
  Future<void> _generateNote() async {
    // 若還在錄音中，先停止並整合文字
    if (_isListening) {
      await _stopListening();
      if (!mounted) return;
    } else {
      _consolidateInterimText();
    }

    final rawText = _transcriptController.text.trim();
    if (rawText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請先錄音或輸入文字內容再進行 AI 整理 🎙️')),
        );
      }
      return;
    }

    setState(() {
      _step = _SheetStep.generating;
      _aiErrorMsg = null;
    });
    _starController.repeat();

    try {
      final result = await VoiceNoteService.instance.organizeTranscript(
        transcript: rawText,
        style: _selectedStyle,
      );

      if (!mounted) return;
      _titleEditController.text = result.title;
      _contentEditController.text = result.markdownContent;
      setState(() {
        _result = result;
        _editableCategory = result.category;
        _step = _SheetStep.preview;
        _starController.stop();
        _starController.reset();
      });
    } catch (e) {
      debugPrint('VoiceNoteSheet generate error: $e');
      if (!mounted) return;
      setState(() {
        _aiErrorMsg = '整理遭遇問題，已為您套用離線版型：$e';
        _step = _SheetStep.recording;
        _starController.stop();
        _starController.reset();
      });
    }
  }

  // ============================================================
  // 直接儲存逐字稿（免 AI 快速記錄）
  // ============================================================
  void _saveRawTranscript() async {
    if (_isListening) {
      await _stopListening();
      if (!mounted) return;
    }
    final rawText = _transcriptController.text.trim();
    if (rawText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無文字內容可儲存 📝')),
        );
      }
      return;
    }

    final defaultTitle = rawText.length > 15
        ? '${rawText.substring(0, 15)}...'
        : rawText;
    final formattedContent = '## 🎙️ 語音逐字稿記錄\n\n$rawText\n\n---\n*記錄時間：${DateTime.now().toString().substring(0, 16)}*';

    widget.onNoteReady?.call(defaultTitle, _selectedStyle.suggestedCategory, formattedContent);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  // ============================================================
  // 完成預覽 - 提交筆記
  // ============================================================
  void _applyNote() {
    final title = _titleEditController.text.trim().isEmpty
        ? _result?.title ?? '語音速記筆記'
        : _titleEditController.text.trim();
    final content = _contentEditController.text.trim().isEmpty
        ? (_result?.markdownContent ?? _transcriptController.text)
        : _contentEditController.text;
    final category = _editableCategory;

    widget.onNoteReady?.call(title, category, content);
    Navigator.pop(context);
  }

  // ============================================================
  // UI 主構建
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 頂部拖曳把手
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          // 頂部標題列
          _buildHeader(),

          const Divider(height: 1),

          // 主滾動區域
          Flexible(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: _buildStepContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final titles = {
      _SheetStep.recording: '🎙️ 語音速記整理',
      _SheetStep.generating: '🤖 AI 智慧整理中...',
      _SheetStep.preview: '📝 整理成果預覽',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 12, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF4A148C).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF4A148C)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              titles[_step] ?? '',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E2723),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.grey),
            onPressed: () => Navigator.pop(context),
            tooltip: '關閉',
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case _SheetStep.recording:
        return _buildRecordingStep();
      case _SheetStep.generating:
        return _buildGeneratingStep();
      case _SheetStep.preview:
        return _buildPreviewStep();
    }
  }

  // ============================================================
  // STEP 1: 錄音、即時文字反饋與風格選擇一體化介面
  // ============================================================
  Widget _buildRecordingStep() {
    final currentText = _transcriptController.text;
    final charCount = currentText.replaceAll(RegExp(r'\s+'), '').length;
    final hasContent = currentText.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // 頂部狀態徽章與錄音波形控制區
        Center(
          child: Column(
            children: [
              // 動態聲波
              _buildSoundWave(),
              const SizedBox(height: 10),

              // 狀態與計時指示器
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _isListening
                      ? Colors.red.shade50
                      : hasContent
                          ? Colors.purple.shade50
                          : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isListening
                        ? Colors.red.shade200
                        : hasContent
                            ? Colors.purple.shade200
                            : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isListening)
                      FadeTransition(
                        opacity: _pulseController,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    else
                      Icon(
                        hasContent ? Icons.check_circle_outline : Icons.mic_none,
                        size: 14,
                        color: hasContent ? const Color(0xFF4A148C) : Colors.grey,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      _isListening
                          ? '正在收音中 · ${_formatDuration(_recordDuration)}'
                          : hasContent
                              ? '錄音已暫停 · 共 $charCount 字'
                              : '點擊下方麥克風開始說話',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isListening
                            ? Colors.red.shade700
                            : hasContent
                                ? const Color(0xFF4A148C)
                                : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 控制按鈕群組 (暫停 / 繼續 / 停止 / 清除 / 智慧去贅字)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 清除按鈕 (有內容時才顯示)
                  if (hasContent) ...[
                    IconButton.filledTonal(
                      onPressed: _clearTranscript,
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.all(12),
                      ),
                      tooltip: '清空重新錄音',
                    ),
                    const SizedBox(width: 14),
                  ],

                  // 核心主按鈕（錄音中為暫停；暫停中為繼續收音）
                  GestureDetector(
                    onTap: _isListening ? _pauseListening : _startListening,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _isListening ? 74 : 68,
                      height: _isListening ? 74 : 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _isListening
                              ? [Colors.red.shade400, Colors.red.shade700]
                              : [const Color(0xFF7B1FA2), const Color(0xFF4A148C)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening
                                    ? Colors.red.shade400
                                    : const Color(0xFF4A148C))
                                .withValues(alpha: 0.35),
                            blurRadius: _isListening ? 18 : 12,
                            spreadRadius: _isListening ? 3 : 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.pause_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),

                  // 停止按鈕（錄音中顯示停止）
                  if (_isListening) ...[
                    const SizedBox(width: 14),
                    IconButton.filledTonal(
                      onPressed: _stopListening,
                      icon: const Icon(Icons.stop_rounded, size: 22),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.all(12),
                      ),
                      tooltip: '結束收音',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _isListening
                    ? '點擊暫停收音 · 右側可結束'
                    : _isPaused
                        ? '已暫停，點擊繼續收音'
                        : hasContent
                            ? '點擊繼續收音'
                            : '點擊開始錄音',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ============================================================
        // 下方空間：即時語音收音文字反饋區
        // ============================================================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.hearing_rounded,
                  size: 16,
                  color: _isListening ? Colors.red.shade600 : const Color(0xFF5D4037),
                ),
                const SizedBox(width: 6),
                const Text(
                  '即時收音逐字稿',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF3E2723),
                  ),
                ),
              ],
            ),
            if (hasContent)
              Text(
                '$charCount 字',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // 即時逐字稿容器
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 110, maxHeight: 180),
          decoration: BoxDecoration(
            color: const Color(0xFFFDFBF9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isListening
                  ? Colors.purple.shade300
                  : const Color(0xFFE5DCD3),
              width: _isListening ? 1.5 : 1.0,
            ),
            boxShadow: [
              if (_isListening)
                BoxShadow(
                  color: Colors.purple.withValues(alpha: 0.05),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: hasContent || _isListening
              ? Scrollbar(
                  controller: _transcriptScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _transcriptScrollController,
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _transcriptController,
                          maxLines: null,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: Color(0xFF2C2523),
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            hintText: _isListening ? '正在收音中...' : '輸入或編輯語音內容...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        if (_isListening)
                          FadeTransition(
                            opacity: _pulseController,
                            child: const Text(
                              '▌',
                              style: TextStyle(
                                color: Color(0xFF4A148C),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isListening ? Icons.graphic_eq_rounded : Icons.speaker_notes_outlined,
                        size: 28,
                        color: _isListening ? Colors.purple.shade300 : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isListening
                            ? '正在聆聽中，請直接說話...\n內容將即時轉為文字'
                            : '尚未收錄語音\n點擊上方麥克風開始說話',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
        ),

        const SizedBox(height: 16),

        // ============================================================
        // 風格選擇卡片區
        // ============================================================
        const Text(
          '✨ 選擇 AI 整理風格',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E2723),
          ),
        ),
        const SizedBox(height: 8),

        // 4 種風格 Choice Chips / 卡片
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: VoiceNoteStyle.values.map((style) {
            final isSelected = _selectedStyle == style;
            return InkWell(
              onTap: () => setState(() => _selectedStyle = style),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF4A148C).withValues(alpha: 0.08)
                      : const Color(0xFFF7F4F1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF4A148C)
                        : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(style.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      style.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? const Color(0xFF4A148C) : const Color(0xFF5D4037),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 6),
        Text(
          _selectedStyle.description,
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
        ),

        if (_aiErrorMsg != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.red.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _aiErrorMsg!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // ============================================================
        // 底部主要操作按鈕列
        // ============================================================
        Row(
          children: [
            // 免 AI 直接儲存
            if (hasContent) ...[
              OutlinedButton.icon(
                onPressed: _saveRawTranscript,
                icon: const Icon(Icons.save_outlined, size: 16),
                label: const Text('直接存', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5D4037),
                  side: const BorderSide(color: Color(0xFF8D6E63)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],

            // 核心 AI 整理按鈕
            Expanded(
              child: ElevatedButton.icon(
                onPressed: hasContent ? _generateNote : null,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  hasContent
                      ? 'AI 智慧整理 (${_selectedStyle.emoji} ${_selectedStyle.label})'
                      : '請先錄入語音內容',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A148C),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  disabledForegroundColor: Colors.grey.shade500,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: hasContent ? 2 : 0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 動態聲波長條
  Widget _buildSoundWave() {
    return SizedBox(
      height: 48,
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(14, (index) {
              final phase = _waveController.value * 2 * math.pi;
              final normalizedIndex = index / 14;
              final baseAmplitude = _isListening
                  ? (_soundLevel / 10.0).clamp(0.2, 1.0)
                  : 0.08;
              final waveHeight = _isListening
                  ? baseAmplitude *
                      (0.3 + 0.7 * math.sin(phase + normalizedIndex * math.pi * 2).abs())
                  : 0.06 + 0.04 * math.sin(phase + normalizedIndex * math.pi).abs();

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.2),
                width: 3.5,
                height: (waveHeight * 44 + 4).clamp(4.0, 44.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: _isListening
                        ? [Colors.red.shade300, Colors.red.shade700]
                        : [Colors.grey.shade300, Colors.grey.shade400],
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  // ============================================================
  // STEP 2: AI 智慧整理中
  // ============================================================
  Widget _buildGeneratingStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _starController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _starController.value * 2 * math.pi,
                child: child,
              );
            },
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF7B1FA2), Color(0xFF4A148C)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A148C).withValues(alpha: 0.35),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Center(
                child: Text('✨', style: TextStyle(fontSize: 34)),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'AI 正在結構化整理您的語音筆記...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E2723),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '以「${_selectedStyle.emoji} ${_selectedStyle.label}」風格提煉重點與排版',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          const SizedBox(
            width: 220,
            child: LinearProgressIndicator(
              backgroundColor: Color(0xFFE8E1F4),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A148C)),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 3: 整理成果預覽與編輯
  // ============================================================
  Widget _buildPreviewStep() {
    if (_result == null) return const SizedBox();
    final categories = ['學習', '工作', '生活', '未分類'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        // AI 生成標籤
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _result!.isAiGenerated
                    ? const Color(0xFF4A148C).withValues(alpha: 0.08)
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _result!.isAiGenerated
                      ? const Color(0xFF4A148C).withValues(alpha: 0.3)
                      : Colors.orange.shade200,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _result!.isAiGenerated ? Icons.auto_awesome : Icons.offline_bolt,
                    size: 13,
                    color: _result!.isAiGenerated ? const Color(0xFF4A148C) : Colors.orange.shade800,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _result!.isAiGenerated ? 'AI 智慧整理完成' : '離線版型整理',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: _result!.isAiGenerated ? const Color(0xFF4A148C) : Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              '風格：${_selectedStyle.label}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // 筆記標題編輯
        const Text(
          '筆記標題',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _titleEditController,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E2723),
          ),
          decoration: InputDecoration(
            hintText: '輸入筆記標題...',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: const Color(0xFFFBF9F7),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4A148C), width: 1.5),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 分類選擇
        const Text(
          '筆記分類',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: categories.map((cat) {
            final isSelected = _editableCategory == cat;
            return ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              selectedColor: const Color(0xFF4A148C).withValues(alpha: 0.15),
              backgroundColor: const Color(0xFFF5F2EF),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF4A148C) : Colors.black54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF4A148C) : Colors.grey.shade300,
                ),
              ),
              onSelected: (selected) {
                if (selected) setState(() => _editableCategory = cat);
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 14),

        // 標籤顯示
        if (_result!.tags.isNotEmpty) ...[
          const Text(
            '關鍵標籤',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _result!.tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8D6E63).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '#$tag',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5D4037),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
        ],

        // 筆記內容編輯
        const Text(
          '筆記內容 (Markdown 格式)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5DCD3)),
            color: const Color(0xFFFBF9F7),
          ),
          child: TextField(
            controller: _contentEditController,
            maxLines: null,
            minLines: 6,
            style: const TextStyle(
              fontSize: 13,
              height: 1.6,
              color: Colors.black87,
              fontFamily: 'monospace',
            ),
            decoration: const InputDecoration(
              hintText: '（AI 整理後的筆記內容）',
              contentPadding: EdgeInsets.all(12),
              border: InputBorder.none,
            ),
          ),
        ),

        const SizedBox(height: 18),

        // 操作按鈕列
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _step = _SheetStep.recording),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('重新錄音/風格'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5D4037),
                  side: const BorderSide(color: Color(0xFF8D6E63)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _applyNote,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  widget.existingContent != null ? '插入至筆記' : '建立此筆記',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5D4037),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
