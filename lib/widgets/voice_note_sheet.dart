import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/groq_whisper_service.dart';
import '../services/voice_note_service.dart';
import 'mindmap_node.dart';
import 'mindmap_canvas.dart';

// ============================================================
// 語音速記整理面板 (VoiceNoteSheet)
// 全面搭載 Groq Whisper 旗艦音訊轉錄引擎（100% 完整無漏句、自動標點、極速 1 秒轉錄）
// 支援即時聲波視覺化、四大 AI 風格整理、心智圖與富文本 Markdown 預覽
// ============================================================
class VoiceNoteSheet extends StatefulWidget {
  /// 整理完成後回調：傳回標題、分類、Markdown 內容、心智圖 JSON、待辦行動清單
  final void Function(
    String title,
    String category,
    String markdownContent,
    Map<String, dynamic>? mindmapJson,
    List<ActionItem>? actionItems,
  )? onNoteReady;

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
  recording,    // 錄音中 / 轉錄中 / 逐字稿預覽與風格選擇
  generating,   // AI 智慧整理中
  preview,      // 整理成果預覽與編輯 (三分頁：摘要 / 心智圖 / Markdown)
}

class _VoiceNoteSheetState extends State<VoiceNoteSheet>
    with TickerProviderStateMixin {
  _SheetStep _step = _SheetStep.recording;

  // Groq Whisper 錄音與轉錄狀態
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isTranscribing = false;
  double _soundLevel = 0.0;
  Timer? _durationTimer;
  Duration _recordDuration = Duration.zero;

  // 逐字稿編輯控制器
  late TextEditingController _transcriptController;
  final ScrollController _transcriptScrollController = ScrollController();

  // 風格選擇
  VoiceNoteStyle _selectedStyle = VoiceNoteStyle.classKeyPoints;

  // AI 整理結果
  VoiceNoteResult? _result;
  String? _aiErrorMsg;

  // 成果編輯控制器（預覽步驟）
  late TextEditingController _titleEditController;
  late TextEditingController _contentEditController;
  String _editableCategory = '學習';

  // 預覽三分頁控制器與狀態
  TabController? _previewTabController;
  int _previewTabIndex = 0;
  List<ActionItem> _editableActionItems = [];
  MindMapNode? _mindmapRootNode;

  // 動畫控制器
  late AnimationController _waveController;
  late AnimationController _pulseController;
  late AnimationController _starController;

  // AI 智慧整理多階段進度與動態狀態
  double _generatingProgress = 0.0;
  int _generatingStage = 0;
  int _generatingTipIndex = 0;
  Timer? _generatingTimer;
  Timer? _tipTimer;
  int _generatingElapsedMs = 0;

  static const List<(String, String)> _kGeneratingStages = [
    ('語意解析', '分析語音轉文字稿脈絡並智能去除口語贅字'),
    ('結構提煉', '梳理核心論點、概念層級與重點大綱'),
    ('心智圖譜', '構建視覺化心智圖樹狀階層與關聯節點'),
    ('行動歸納', '提取可執行待辦清單與核心結論摘要'),
    ('排版渲染', '整合 Markdown 美化排版與全功能成果'),
  ];

  static const List<String> _kAiTips = [
    '正在剔除「嗯、然後」等口語贅字與停頓詞...',
    '正在辨識核心考點、專有名詞與知識結構...',
    '正在為您生成可縮放探索的階層心智圖節點...',
    '正在梳理關鍵待辦事項與行動時間表...',
    '正在套用最佳莫蘭迪視覺化 Markdown 排版...',
  ];

  @override
  void initState() {
    super.initState();
    _transcriptController = TextEditingController();
    _titleEditController = TextEditingController();
    _contentEditController = TextEditingController();

    _previewTabController = TabController(length: 3, vsync: this);
    _previewTabController?.addListener(() {
      if (mounted && _previewTabController != null) {
        setState(() => _previewTabIndex = _previewTabController!.index);
      }
    });

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
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _generatingTimer?.cancel();
    _tipTimer?.cancel();
    if (_isRecording) {
      GroqWhisperService.instance.cancelRecording();
    }
    _waveController.dispose();
    _pulseController.dispose();
    _starController.dispose();
    _previewTabController?.dispose();
    _transcriptController.dispose();
    _transcriptScrollController.dispose();
    _titleEditController.dispose();
    _contentEditController.dispose();
    super.dispose();
  }

  // ============================================================
  // Groq Whisper 錄音與轉錄控制
  // ============================================================

  /// 開始高品質錄音
  Future<void> _startRecording() async {
    if (_isRecording || _isTranscribing) return;

    final started = await GroqWhisperService.instance.startRecording(
      onAmplitudeChange: (level) {
        if (!mounted) return;
        setState(() {
          _soundLevel = level;
        });
      },
    );

    if (started && mounted) {
      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordDuration = Duration.zero;
        _aiErrorMsg = null;
      });
      _durationTimer?.cancel();
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _isRecording && !_isPaused) {
          setState(() => _recordDuration += const Duration(seconds: 1));
        }
      });
    } else if (!started && mounted) {
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('無法啟動麥克風錄音，請確認已授予麥克風權限 🎙️'),
          backgroundColor: Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// 暫停錄音
  Future<void> _pauseRecording() async {
    await GroqWhisperService.instance.pauseRecording();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isPaused = true;
        _soundLevel = 0.0;
      });
    }
  }

  /// 繼續錄音
  Future<void> _resumeRecording() async {
    await GroqWhisperService.instance.resumeRecording();
    if (mounted) {
      setState(() {
        _isRecording = true;
        _isPaused = false;
      });
    }
  }

  /// 停止錄音並呼叫 Groq Whisper 進行轉錄
  Future<void> _stopAndTranscribe() async {
    if (!_isRecording && !_isPaused) return;

    _durationTimer?.cancel();
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _isTranscribing = true;
      _soundLevel = 0.0;
      _aiErrorMsg = null;
    });

    try {
      final transcript = await GroqWhisperService.instance.stopAndTranscribe();
      if (!mounted) return;

      setState(() {
        _isTranscribing = false;
        final currentText = _transcriptController.text.trim();
        if (currentText.isEmpty) {
          _transcriptController.text = transcript;
        } else {
          _transcriptController.text = '$currentText\n$transcript';
        }
        _transcriptController.selection = TextSelection.fromPosition(
          TextPosition(offset: _transcriptController.text.length),
        );
      });
      _autoScrollTranscript();
    } catch (e) {
      debugPrint('Groq Whisper transcribe error: $e');
      if (!mounted) return;
      setState(() {
        _isTranscribing = false;
        _aiErrorMsg = '轉錄發生問題：$e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('語音轉錄遭遇問題：$e'),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 取消當前錄音
  Future<void> _cancelCurrentRecording() async {
    _durationTimer?.cancel();
    await GroqWhisperService.instance.cancelRecording();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isPaused = false;
        _isTranscribing = false;
        _soundLevel = 0.0;
        _recordDuration = Duration.zero;
      });
    }
  }

  /// 清空逐字稿文字
  void _clearTranscript() {
    _cancelCurrentRecording();
    setState(() {
      _transcriptController.clear();
      _aiErrorMsg = null;
    });
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('🗑️ 已清空語音轉文字稿文字'),
          duration: Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
    // 若還在錄音中，先停止並轉錄為文字
    if (_isRecording || _isPaused) {
      await _stopAndTranscribe();
      if (!mounted) return;
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
      _generatingProgress = 0.05;
      _generatingStage = 0;
      _generatingElapsedMs = 0;
      _generatingTipIndex = 0;
    });
    _starController.repeat();

    // 啟動進度條平滑模擬器
    _generatingTimer?.cancel();
    _generatingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || _step != _SheetStep.generating) {
        timer.cancel();
        return;
      }
      setState(() {
        _generatingElapsedMs += 100;
        // 平滑漸進至 92%
        if (_generatingProgress < 0.92) {
          _generatingProgress += (0.92 - _generatingProgress) * 0.045;
        }
        // 更新當前階段
        if (_generatingProgress < 0.22) {
          _generatingStage = 0;
        } else if (_generatingProgress < 0.48) {
          _generatingStage = 1;
        } else if (_generatingProgress < 0.72) {
          _generatingStage = 2;
        } else if (_generatingProgress < 0.88) {
          _generatingStage = 3;
        } else {
          _generatingStage = 4;
        }
      });
    });

    // 啟動 AI 思考小語輪播
    _tipTimer?.cancel();
    _tipTimer = Timer.periodic(const Duration(milliseconds: 1600), (timer) {
      if (!mounted || _step != _SheetStep.generating) {
        timer.cancel();
        return;
      }
      setState(() {
        _generatingTipIndex = (_generatingTipIndex + 1) % _kAiTips.length;
      });
    });

    try {
      final result = await VoiceNoteService.instance.organizeTranscript(
        transcript: rawText,
        style: _selectedStyle,
      );

      if (!mounted) return;
      _generatingTimer?.cancel();
      _tipTimer?.cancel();

      // 完成時快速衝至 100% 並標記所有階段完成
      setState(() {
        _generatingProgress = 1.0;
        _generatingStage = 5;
      });
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;
      _titleEditController.text = result.title;
      _contentEditController.text = result.markdownContent;

      // 複製 action items 為可編輯副本
      _editableActionItems = result.actionItems
              ?.map((a) => ActionItem(
                    task: a.task,
                    owner: a.owner,
                    dueDate: a.dueDate,
                    isCompleted: a.isCompleted,
                  ))
              .toList() ??
          [];

      // 建構心智圖模型 (從 AI JSON 或從重點與摘要 fallback)
      if (result.mindmapJson != null) {
        try {
          _mindmapRootNode = MindMapNode.fromJson(result.mindmapJson!);
        } catch (e) {
          debugPrint('MindMapNode parse error: $e');
          _mindmapRootNode = _buildFallbackMindMap(result);
        }
      } else {
        _mindmapRootNode = _buildFallbackMindMap(result);
      }

      setState(() {
        _result = result;
        _editableCategory = result.category;
        _step = _SheetStep.preview;
        _starController.stop();
        _starController.reset();
      });
    } catch (e) {
      debugPrint('VoiceNoteSheet generate error: $e');
      _generatingTimer?.cancel();
      _tipTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _aiErrorMsg = '整理遭遇問題，已為您套用離線版型：$e';
        _step = _SheetStep.recording;
        _starController.stop();
        _starController.reset();
      });
    }
  }

  /// 建立備份心智圖樹狀結構
  MindMapNode _buildFallbackMindMap(VoiceNoteResult result) {
    final colors = [
      const Color(0xFF673AB7),
      const Color(0xFF3F51B5),
      const Color(0xFF2196F3),
      const Color(0xFF009688),
      const Color(0xFFFF9800),
      const Color(0xFFE91E63),
    ];

    if (result.keyPoints != null && result.keyPoints!.isNotEmpty) {
      return MindMapNode(
        id: 'root',
        label: result.title.isNotEmpty ? result.title : '主題筆記',
        color: const Color(0xFF4A148C),
        children: result.keyPoints!.asMap().entries.map((entry) {
          return MindMapNode(
            id: 'node_${entry.key}',
            label: entry.value,
            color: colors[entry.key % colors.length],
          );
        }).toList(),
      );
    } else {
      return MindMapNode(
        id: 'root',
        label: result.title.isNotEmpty ? result.title : '主題筆記',
        color: const Color(0xFF4A148C),
        children: [
          MindMapNode(
            id: 'node_summary',
            label: result.summary ?? '核心內容重點',
            color: const Color(0xFF3F51B5),
          ),
        ],
      );
    }
  }

  /// 當勾選/取消待辦事項時，同步更新 Markdown 內容
  void _syncActionItemsToMarkdown() {
    if (_editableActionItems.isEmpty) return;
    String content = _contentEditController.text;
    for (final item in _editableActionItems) {
      final checkedBox = '- [x] ${item.task}';
      final uncheckedBox = '- [ ] ${item.task}';
      if (item.isCompleted) {
        if (content.contains(uncheckedBox)) {
          content = content.replaceAll(uncheckedBox, checkedBox);
        }
      } else {
        if (content.contains(checkedBox)) {
          content = content.replaceAll(checkedBox, uncheckedBox);
        }
      }
    }
    _contentEditController.text = content;
  }

  // ============================================================
  // 直接儲存逐字稿（免 AI 快速記錄）
  // ============================================================
  void _saveRawTranscript() async {
    if (_isRecording || _isPaused) {
      await _stopAndTranscribe();
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
    final formattedContent = '## 🎙️ 語音轉文字稿記錄\n\n$rawText\n\n---\n*記錄時間：${DateTime.now().toString().substring(0, 16)}*';

    widget.onNoteReady?.call(
      defaultTitle,
      _selectedStyle.suggestedCategory,
      formattedContent,
      null,
      null,
    );
    if (mounted) {
      Navigator.pop(context);
    }
  }

  // ============================================================
  // 完成預覽 - 提交筆記
  // ============================================================
  void _applyNote() {
    _syncActionItemsToMarkdown();
    final title = _titleEditController.text.trim().isEmpty
        ? _result?.title ?? '語音速記筆記'
        : _titleEditController.text.trim();
    final content = _contentEditController.text.trim().isEmpty
        ? (_result?.markdownContent ?? _transcriptController.text)
        : _contentEditController.text;
    final category = _editableCategory;

    widget.onNoteReady?.call(
      title,
      category,
      content,
      _result?.mindmapJson,
      _editableActionItems,
    );
    Navigator.pop(context);
  }

  // ============================================================
  // UI 主構建
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final safeBottom = math.max(bottomInset, bottomPadding) + 20.0;

    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
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
                  bottom: safeBottom,
                ),
                child: _buildStepContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final titles = {
      _SheetStep.recording: '🎙️ AI 語音速記',
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
            child: const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF4A148C)),
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
  // STEP 1: 錄音、即時波形、Groq Whisper 轉錄與風格選擇
  // ============================================================
  Widget _buildRecordingStep() {
    final currentText = _transcriptController.text;
    final charCount = currentText.replaceAll(RegExp(r'\s+'), '').length;
    final hasContent = currentText.trim().isNotEmpty;
    final isBusyRecording = _isRecording || _isPaused;

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

              // 狀態指示器
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _isTranscribing
                      ? Colors.amber.shade50
                      : _isRecording
                          ? Colors.red.shade50
                          : _isPaused
                              ? Colors.orange.shade50
                              : hasContent
                                  ? Colors.purple.shade50
                                  : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isTranscribing
                        ? Colors.amber.shade300
                        : _isRecording
                            ? Colors.red.shade200
                            : _isPaused
                                ? Colors.orange.shade200
                                : hasContent
                                    ? Colors.purple.shade200
                                    : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isTranscribing)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE65100)),
                        ),
                      )
                    else if (_isRecording)
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
                      _isTranscribing
                          ? '⚡ AI 高速語音辨識中...'
                          : _isRecording
                              ? '高音質收錄中 (無遺漏) · ${_formatDuration(_recordDuration)}'
                              : _isPaused
                                  ? '錄音已暫停 · ${_formatDuration(_recordDuration)} (點擊繼續)'
                                  : hasContent
                                      ? '轉錄已完成 · 共 $charCount 字'
                                      : '點擊下方麥克風開始錄音',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isTranscribing
                            ? const Color(0xFFE65100)
                            : _isRecording
                                ? Colors.red.shade700
                                : _isPaused
                                    ? Colors.orange.shade800
                                    : hasContent
                                        ? const Color(0xFF4A148C)
                                        : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 控制按鈕群組 (清除/取消 | 核心錄音/暫停/繼續 | 轉為文字)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 左側按鈕：錄音或暫停中為「取消錄音」；閒置且有內容為「清空重新錄音」
                  if (isBusyRecording) ...[
                    IconButton.filledTonal(
                      onPressed: _cancelCurrentRecording,
                      icon: const Icon(Icons.close_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.grey.shade800,
                        padding: const EdgeInsets.all(12),
                      ),
                      tooltip: '取消本次錄音',
                    ),
                    const SizedBox(width: 14),
                  ] else if (hasContent) ...[
                    IconButton.filledTonal(
                      onPressed: _clearTranscript,
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.all(12),
                      ),
                      tooltip: '清空逐字稿文字',
                    ),
                    const SizedBox(width: 14),
                  ],

                  // 核心主按鈕（錄音中為暫停；暫停中為繼續；非錄音中為開始/追加錄音）
                  Tooltip(
                    message: _isTranscribing
                        ? '轉錄處理中...'
                        : _isRecording
                            ? '暫停錄音'
                            : _isPaused
                                ? '繼續錄音'
                                : hasContent
                                    ? '追加錄音'
                                    : '開始錄音',
                    child: GestureDetector(
                      onTap: _isTranscribing
                          ? null
                          : _isRecording
                              ? _pauseRecording
                              : _isPaused
                                  ? _resumeRecording
                                  : _startRecording,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: isBusyRecording ? 74 : 68,
                        height: isBusyRecording ? 74 : 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _isTranscribing
                                ? [Colors.grey.shade400, Colors.grey.shade500]
                                : _isRecording
                                    ? [Colors.red.shade400, Colors.red.shade700]
                                    : _isPaused
                                        ? [Colors.orange.shade400, Colors.orange.shade700]
                                        : [const Color(0xFF7B1FA2), const Color(0xFF4A148C)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isRecording
                                      ? Colors.red.shade400
                                      : _isPaused
                                          ? Colors.orange.shade400
                                          : const Color(0xFF4A148C))
                                  .withValues(alpha: 0.35),
                              blurRadius: isBusyRecording ? 18 : 12,
                              spreadRadius: _isRecording ? 3 : 0,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isTranscribing
                              ? Icons.hourglass_top_rounded
                              : _isRecording
                                  ? Icons.pause_rounded
                                  : _isPaused
                                      ? Icons.mic_rounded
                                      : Icons.mic_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                  ),

                  // 右側按鈕：錄音或暫停中顯示「轉為文字」完成按鈕
                  if (isBusyRecording) ...[
                    const SizedBox(width: 14),
                    ElevatedButton.icon(
                      onPressed: _isTranscribing ? null : _stopAndTranscribe,
                      icon: const Icon(Icons.bolt_rounded, size: 20),
                      label: const Text('轉為文字', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A148C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _isTranscribing
                    ? '⚡ AI 語音辨識中...'
                    : _isRecording
                        ? '點擊暫停 · 點擊右側「轉為文字」完成'
                        : _isPaused
                            ? '已暫停，點擊麥克風繼續錄音 · 點擊右側「轉為文字」'
                            : hasContent
                                ? '轉錄已完成，點擊可追加錄音'
                                : '點擊開始錄音（零斷字・全音質收錄）',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ============================================================
        // 逐字稿文字區域 (支援編輯、展示、刪除與狀態提示)
        // ============================================================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.text_snippet_outlined,
                  size: 16,
                  color: Color(0xFF5D4037),
                ),
                const SizedBox(width: 6),
                const Text(
                  '語音轉文字稿內容',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF3E2723),
                  ),
                ),
              ],
            ),
            if (hasContent)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$charCount 字',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _clearTranscript,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 13, color: Colors.red.shade700),
                          const SizedBox(width: 3),
                          Text(
                            '清空文字',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),

        const SizedBox(height: 8),

        // 逐字稿容器
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 110, maxHeight: 180),
          decoration: BoxDecoration(
            color: const Color(0xFFFDFBF9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isTranscribing
                  ? Colors.amber.shade400
                  : isBusyRecording
                      ? Colors.purple.shade300
                      : const Color(0xFFE5DCD3),
              width: (_isTranscribing || isBusyRecording) ? 1.5 : 1.0,
            ),
            boxShadow: [
              if (isBusyRecording)
                BoxShadow(
                  color: Colors.purple.withValues(alpha: 0.05),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: _isTranscribing
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A148C)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '⚡ AI 正在將語音轉為文字...\n（自動生成標點與段落）',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4A148C),
                        ),
                      ),
                    ],
                  ),
                )
              : hasContent
                  ? Scrollbar(
                      controller: _transcriptScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _transcriptScrollController,
                        physics: const BouncingScrollPhysics(),
                        child: TextField(
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
                            hintText: '輸入或編輯語音內容...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {});
                          },
                        ),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isBusyRecording ? Icons.graphic_eq_rounded : Icons.speaker_notes_outlined,
                            size: 28,
                            color: isBusyRecording ? Colors.purple.shade300 : Colors.grey.shade400,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isBusyRecording
                                ? '正在高品質收錄音訊中...\n說完後點擊「轉為文字」即可瞬間轉錄！'
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
        // 風格選擇卡片區 (比照業界頂級 AI 筆記應用規格)
        // ============================================================
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF4A148C)),
            const SizedBox(width: 6),
            const Text(
              '選擇 AI 整理風格',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E2723),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF4A148C).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '6 種整理風格',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A148C),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 2 欄 6 款風格卡片 Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.1,
          ),
          itemCount: VoiceNoteStyle.values.length,
          itemBuilder: (context, index) {
            final style = VoiceNoteStyle.values[index];
            final isSelected = _selectedStyle == style;

            return InkWell(
              onTap: () => setState(() => _selectedStyle = style),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF4A148C).withValues(alpha: 0.07)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF4A148C)
                        : Colors.grey.shade300,
                    width: isSelected ? 1.6 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? const Color(0xFF4A148C).withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.03),
                      blurRadius: isSelected ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF4A148C).withValues(alpha: 0.14)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(style.emoji, style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  style.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? const Color(0xFF4A148C) : const Color(0xFF2C3E50),
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF4A148C)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            style.badgeTag,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isSelected ? const Color(0xFF7B1FA2) : Colors.grey.shade600,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        // 所選風格特性亮點導覽卡片
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF4A148C).withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF4A148C).withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(_selectedStyle.emoji, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 6),
                  Text(
                    '「${_selectedStyle.label}」產出規格：',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A148C),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A148C).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '預設歸類：${_selectedStyle.suggestedCategory}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4A148C),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                _selectedStyle.description,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFF5D4037),
                ),
              ),
              const SizedBox(height: 6),
              ..._selectedStyle.featureHighlights.map((feat) => Padding(
                    padding: const EdgeInsets.only(bottom: 2.5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✦ ', style: TextStyle(fontSize: 11, color: Color(0xFF7B1FA2))),
                        Expanded(
                          child: Text(
                            feat,
                            style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              color: Color(0xFF424242),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
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
            if (hasContent || isBusyRecording) ...[
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

            // 核心 AI 整理按鈕（若錄音中點擊，會自動完成轉錄並整理）
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_isTranscribing)
                    ? null
                    : (hasContent || isBusyRecording)
                        ? _generateNote
                        : null,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  isBusyRecording
                      ? '結束錄音並 AI 整理'
                      : hasContent
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
                  elevation: (hasContent || isBusyRecording) ? 2 : 0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 動態聲波長條（根據實際麥克風分貝動態跳動）
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
              final baseAmplitude = _isRecording && !_isPaused
                  ? (_soundLevel / 10.0).clamp(0.2, 1.0)
                  : 0.08;
              final waveHeight = _isRecording && !_isPaused
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
                    colors: _isRecording && !_isPaused
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
  // STEP 2: AI 智慧整理中 (業界多階段動態載入條與流水線看板)
  // ============================================================
  Widget _buildGeneratingStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Column(
        children: [
          // 呼吸發光能量球
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + _pulseController.value * 0.06;
              final glowAlpha = 0.22 + _pulseController.value * 0.22;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF7B1FA2),
                        Color(0xFF3F51B5),
                        Color(0xFF009688),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7B1FA2).withValues(alpha: glowAlpha),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: const Color(0xFF009688).withValues(alpha: glowAlpha * 0.5),
                        blurRadius: 16,
                        offset: const Offset(3, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _starController,
                        builder: (_, __) => Transform.rotate(
                          angle: _starController.value * 2 * math.pi,
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(_selectedStyle.emoji, style: const TextStyle(fontSize: 32)),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // 標題與風格徽章
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'AI 智慧整理中',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B1FA2).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_selectedStyle.emoji} ${_selectedStyle.label}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7B1FA2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _selectedStyle.subtitle,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 18),

          // ── 進度百分比與動態流光載入條 ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF7B1FA2).withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B1FA2).withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF7B1FA2)),
                        const SizedBox(width: 4),
                        Text(
                          '已處理 ${(_generatingElapsedMs / 1000).toStringAsFixed(1)}s',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${(_generatingProgress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7B1FA2),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // 漸層進度條
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Container(
                        height: 9,
                        width: double.infinity,
                        color: const Color(0xFFF0EBF8),
                      ),
                      FractionallySizedBox(
                        widthFactor: _generatingProgress.clamp(0.04, 1.0),
                        child: Container(
                          height: 9,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF7B1FA2),
                                Color(0xFF3F51B5),
                                Color(0xFF009688),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── 5 階段流水線即時檢核看板 ──
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF8FC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: _kGeneratingStages.indexed.map((entry) {
                final (index, stage) = entry;
                final isDone = index < _generatingStage;
                final isCurrent = index == _generatingStage;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5.5),
                  child: Row(
                    children: [
                      // 狀態指示圓圈
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone
                              ? const Color(0xFF2E7D32)
                              : isCurrent
                                  ? const Color(0xFF7B1FA2)
                                  : Colors.grey.shade300,
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                              : isCurrent
                                  ? const SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 階段名稱與說明
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stage.$1,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                color: isDone
                                    ? const Color(0xFF2E7D32)
                                    : isCurrent
                                        ? const Color(0xFF7B1FA2)
                                        : Colors.grey.shade500,
                              ),
                            ),
                            Text(
                              stage.$2,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isCurrent ? const Color(0xFF5D4037) : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 右側狀態標籤
                      if (isDone)
                        const Text('✓ 完成', style: TextStyle(fontSize: 10.5, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold))
                      else if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7B1FA2).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('處理中...', style: TextStyle(fontSize: 10, color: Color(0xFF7B1FA2), fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // ── AI 思考浮動氣泡 ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Container(
              key: ValueKey<int>(_generatingTipIndex),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF7B1FA2).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF7B1FA2).withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  const Text('💡', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _kAiTips[_generatingTipIndex],
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF4A148C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 3: 整理成果預覽 - 三分頁設計
  // ============================================================
  Widget _buildPreviewStep() {
    if (_result == null) return const SizedBox();
    final categories = ['學習', '工作', '生活', '未分類'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        // AI 生成標籤列
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
                    color: _result!.isAiGenerated
                        ? const Color(0xFF4A148C)
                        : Colors.orange.shade800,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _result!.isAiGenerated ? 'AI 智慧整理完成' : '離線版型整理',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: _result!.isAiGenerated
                          ? const Color(0xFF4A148C)
                          : Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              '${_selectedStyle.emoji} ${_selectedStyle.label}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 筆記標題編輯
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

        const SizedBox(height: 10),

        // 分類選擇
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
                fontSize: 12.5,
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

        if (_result!.tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _result!.tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF8D6E63).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '#$tag',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF5D4037)),
                ),
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: 14),

        // ============================================================
        // 三分頁切換器 (筆記內容 | 結構心智圖 | 重點摘要)
        // ============================================================
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F2EF),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(3),
          child: TabBar(
            controller: _previewTabController,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            labelColor: const Color(0xFF4A148C),
            unselectedLabelColor: Colors.grey.shade600,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.article_outlined, size: 16),
                    SizedBox(width: 4),
                    Text('筆記內容'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hub_outlined, size: 15),
                    SizedBox(width: 4),
                    Text('心智圖'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_outlined, size: 15),
                    SizedBox(width: 4),
                    Text('重點摘要'),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 分頁內容
        IndexedStack(
          index: _previewTabIndex,
          children: [
            _buildNoteContentTab(),
            _buildMindmapTab(),
            _buildSummaryTab(),
          ],
        ),

        const SizedBox(height: 18),

        // 底部操作按鈕列
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _step = _SheetStep.recording),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('重錄/換風格'),
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

  // ============================================================
  // TAB 1: 結構化摘要
  // ============================================================
  Widget _buildSummaryTab() {
    final hasSummary = _result?.summary != null && _result!.summary!.trim().isNotEmpty;
    final hasKeyPoints = _result?.keyPoints != null && _result!.keyPoints!.isNotEmpty;
    final hasActionItems = _editableActionItems.isNotEmpty;

    if (!hasSummary && !hasKeyPoints && !hasActionItems) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFDFBF9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5DCD3)),
        ),
        child: MarkdownBody(
          data: _contentEditController.text,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: const TextStyle(fontSize: 13.5, height: 1.6, color: Color(0xFF2C2523)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 核心摘要 Callout 卡片
        if (hasSummary) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E5F5).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
              border: const Border(
                left: BorderSide(color: Color(0xFF673AB7), width: 4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFF673AB7)),
                    SizedBox(width: 6),
                    Text(
                      '核心情境摘要',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A148C),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _result!.summary!,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.55,
                    color: Color(0xFF2C2523),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // 核心重點條列
        if (hasKeyPoints) ...[
          Row(
            children: [
              const Icon(Icons.format_list_bulleted_rounded, size: 16, color: Color(0xFF5D4037)),
              const SizedBox(width: 6),
              Text(
                '重點提煉 (${_result!.keyPoints!.length})',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3E2723),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._result!.keyPoints!.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final point = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEFE8E1)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A148C).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$idx',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A148C),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      point,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: Color(0xFF2C2523),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 14),
        ],

        // 待辦行動清單
        if (hasActionItems) ...[
          Row(
            children: [
              const Icon(Icons.checklist_rounded, size: 16, color: Color(0xFF2E7D32)),
              const SizedBox(width: 6),
              Text(
                '待辦行動 (${_editableActionItems.where((a) => a.isCompleted).length}/${_editableActionItems.length})',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3E2723),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._editableActionItems.asMap().entries.map((entry) {
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: item.isCompleted ? const Color(0xFFF1F8E9) : const Color(0xFFFDFDFD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: item.isCompleted ? Colors.green.shade200 : const Color(0xFFE5DCD3),
                ),
              ),
              child: CheckboxListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                dense: true,
                value: item.isCompleted,
                activeColor: const Color(0xFF2E7D32),
                title: Text(
                  item.task,
                  style: TextStyle(
                    fontSize: 13,
                    decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                    color: item.isCompleted ? Colors.grey.shade600 : const Color(0xFF2C2523),
                    fontWeight: item.isCompleted ? FontWeight.normal : FontWeight.w500,
                  ),
                ),
                subtitle: (item.owner != '未指定' || item.dueDate != '無')
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            if (item.owner != '未指定')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '👤 ${item.owner}',
                                  style: TextStyle(fontSize: 10.5, color: Colors.blue.shade800),
                                ),
                              ),
                            if (item.dueDate != '無')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '⏰ ${item.dueDate}',
                                  style: TextStyle(fontSize: 10.5, color: Colors.orange.shade800),
                                ),
                              ),
                          ],
                        ),
                      )
                    : null,
                onChanged: (val) {
                  setState(() {
                    item.isCompleted = val ?? false;
                  });
                },
              ),
            );
          }),
        ],
      ],
    );
  }

  // ============================================================
  // TAB 2: 心智圖畫布
  // ============================================================
  Widget _buildMindmapTab() {
    if (_mindmapRootNode == null) {
      return Container(
        height: 260,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF9F7F5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5DCD3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hub_outlined, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              '尚未生成心智圖',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 工具列（全螢幕展開按鈕與說明）
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.touch_app_rounded, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '支援雙指縮放與拖曳移動',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _openFullscreenMindmap,
              icon: const Icon(Icons.fullscreen_rounded, size: 16),
              label: const Text('全螢幕畫布', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4A148C),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // 心智圖畫布容器
        Container(
          height: 320,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF9F7F5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5DCD3)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InteractiveMindMapView(
            root: _mindmapRootNode!,
          ),
        ),
      ],
    );
  }

  /// 打開全螢幕心智圖檢視（支援手機旋轉橫向與一鍵切換寬螢幕）
  void _openFullscreenMindmap() {
    if (_mindmapRootNode == null) return;
    FullscreenMindMapView.open(
      context,
      root: _mindmapRootNode!,
      title: _titleEditController.text.isNotEmpty
          ? _titleEditController.text
          : '心智圖全螢幕檢視',
    );
  }

  // ============================================================
  // TAB 1: 筆記內容 (業界級乾淨排版，無原始碼標籤干擾)
  // ============================================================
  Widget _buildNoteContentTab() {
    final cleanContent = VoiceNoteService.cleanRawMarkdown(_contentEditController.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 頂部小標與複製按鈕
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.article_outlined, size: 16, color: Color(0xFF4A148C)),
                SizedBox(width: 6),
                Text(
                  '完整整理成果',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E2723),
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF5D4037)),
              tooltip: '複製筆記內容',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: cleanContent));
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('📋 已複製筆記內容至剪貼簿'),
                      duration: Duration(milliseconds: 1200),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
              },
            ),
          ],
        ),

        const SizedBox(height: 6),

        // 內容區域（純淨富文本 Markdown 排版）
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5DCD3)),
            color: const Color(0xFFFBF9F7),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: MarkdownBody(
            data: cleanContent,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              h1: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E2723),
                height: 1.5,
              ),
              h2: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A148C),
                height: 1.5,
              ),
              h3: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D4037),
              ),
              p: const TextStyle(
                fontSize: 13.5,
                height: 1.6,
                color: Color(0xFF2C2523),
              ),
              listBullet: const TextStyle(color: Color(0xFF4A148C)),
              blockquoteDecoration: BoxDecoration(
                color: const Color(0xFFF3E5F5).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: const Border(
                  left: BorderSide(color: Color(0xFF673AB7), width: 3.5),
                ),
              ),
              codeblockDecoration: BoxDecoration(
                color: const Color(0xFF2E2A27),
                borderRadius: BorderRadius.circular(8),
              ),
              code: const TextStyle(
                backgroundColor: Color(0xFFEDE7F6),
                color: Color(0xFF4A148C),
                fontSize: 12.5,
              ),
            ),
          ),
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
