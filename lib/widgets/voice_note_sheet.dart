import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path_provider/path_provider.dart';
import '../services/groq_whisper_service.dart';
import '../services/voice_note_service.dart';
import '../services/voice_note_background_manager.dart';
import 'mindmap_node.dart';
import 'mindmap_canvas.dart';
import '../services/app_locale_service.dart';

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

  /// 當前使用者 ID（用於背景儲存）
  final String? userId;

  const VoiceNoteSheet({
    super.key,
    this.onNoteReady,
    this.existingContent,
    this.scrollController,
    this.userId,
  });

  @override
  State<VoiceNoteSheet> createState() => _VoiceNoteSheetState();
}

// ============================================================
// 步驟列舉
// ============================================================
enum _SheetStep {
  recording, // 錄音中 / 轉錄中 / 逐字稿預覽與風格選擇
  generating, // AI 智慧整理中
  preview, // 整理成果預覽與編輯 (三分頁：摘要 / 心智圖 / Markdown)
}

class _VoiceNoteSheetState extends State<VoiceNoteSheet>
    with TickerProviderStateMixin {
  _SheetStep _step = _SheetStep.recording;

  // Gladia / 錄音與轉錄狀態
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isTranscribing = false;
  String? _transcribingStatusMsg;
  double _soundLevel = 0.0;
  Timer? _durationTimer;
  Duration _recordDuration = Duration.zero;

  // 逐字稿編輯控制器與草稿狀態
  late TextEditingController _transcriptController;
  final ScrollController _transcriptScrollController = ScrollController();
  String? _pendingDraftText;
  String? _pendingDraftTime;

  // 風格選擇與微調細緻度
  VoiceNoteStyle _selectedStyle = VoiceNoteStyle.academicLecture;
  VoiceNoteDetailLevel _selectedDetailLevel = VoiceNoteDetailLevel.detailed;

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

  static List<(String, String)> get _kGeneratingStages => [
    (tr('vn_stage1'), tr('vn_stage1_d')),
    (tr('vn_stage2'), tr('vn_stage2_d')),
    (tr('vn_stage3'), tr('vn_stage3_d')),
    (tr('vn_stage4'), tr('vn_stage4_d')),
    (tr('vn_stage5'), tr('vn_stage5_d')),
  ];

  static List<String> get _kAiTips => [
    tr('vn_tip1'),
    tr('vn_tip2'),
    tr('vn_tip3'),
    tr('vn_tip4'),
    tr('vn_tip5'),
  ];

  // ──────────────────────────────────────────
  // 草稿本機安全儲存 (防止滑掉/跳出遺失)
  // ──────────────────────────────────────────
  static File? _draftFile;
  static Future<File> _getDraftFile() async {
    if (_draftFile != null) return _draftFile!;
    final dir = await getApplicationDocumentsDirectory();
    _draftFile = File('${dir.path}/voice_note_draft_v1.json');
    return _draftFile!;
  }

  Future<void> _saveDraftToStorage() async {
    try {
      final text = _transcriptController.text.trim();
      final file = await _getDraftFile();
      if (text.isEmpty) {
        if (await file.exists()) await file.delete();
      } else {
        final data = {
          'transcript': text,
          'style': _selectedStyle.name,
          'savedAt': DateTime.now().toIso8601String(),
        };
        await file.writeAsString(jsonEncode(data));
      }
    } catch (e) {
      debugPrint('Error saving draft: $e');
    }
  }

  Future<void> _checkAndPromptDraft() async {
    try {
      final file = await _getDraftFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        final draftText = map['transcript'] as String? ?? '';
        final savedAtStr = map['savedAt'] as String?;
        if (draftText.isNotEmpty && _transcriptController.text.trim().isEmpty) {
          if (mounted) {
            setState(() {
              _pendingDraftText = draftText;
              _pendingDraftTime = savedAtStr;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking draft: $e');
    }
  }

  Future<void> _clearDraftStorage() async {
    try {
      final file = await _getDraftFile();
      if (await file.exists()) await file.delete();
      if (mounted) {
        setState(() {
          _pendingDraftText = null;
          _pendingDraftTime = null;
        });
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _transcriptController = TextEditingController();
    _transcriptController.addListener(_saveDraftToStorage);
    _checkAndPromptDraft();

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

  // 【錄影專用・暫時】--dart-define=DEMO_TRANSCRIPT=true 時以模擬逐字稿取代實際錄音轉錄
  static const bool _kDemoTranscript = bool.fromEnvironment('DEMO_TRANSCRIPT');
  static const String _kDemoTranscriptText =
      '同學們好，今天我們來複習牛頓三大運動定律。第一定律是慣性定律：物體在不受外力時，靜者恆靜，動者恆作等速度運動。'
      '第二定律告訴我們，物體的加速度與所受的淨力成正比，與質量成反比，也就是 F 等於 m 乘以 a。'
      '第三定律是作用力與反作用力定律：兩個物體之間的作用力，大小相等、方向相反，而且作用在不同物體上。'
      '考試常考的重點有三個：第一，判斷物體是否處於力平衡；第二，用 F 等於 m a 計算加速度；第三，分辨作用力與反作用力，不要和平衡力搞混。'
      '下課前請大家完成課本第五十頁的練習題。';
  Timer? _demoLevelTimer;

  /// 開始高品質錄音
  Future<void> _startRecording() async {
    if (_isRecording || _isTranscribing) return;

    if (_kDemoTranscript) {
      final rnd = math.Random();
      _demoLevelTimer?.cancel();
      _demoLevelTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted && _isRecording) {
          setState(() => _soundLevel = 3 + rnd.nextDouble() * 6);
        }
      });
    }
    final started = _kDemoTranscript ||
        await GroqWhisperService.instance.startRecording(
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
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
        SnackBar(
          content: Text(tr('vn_mic_failed')),
          backgroundColor: Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1500),
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

  /// 停止錄音並呼叫 Gladia V2 進行轉錄 (含說話者分離與時間戳)
  Future<void> _stopAndTranscribe() async {
    if (!_isRecording && !_isPaused) return;

    _durationTimer?.cancel();
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _isTranscribing = true;
      _transcribingStatusMsg = tr('vn_gladia_uploading');
      _soundLevel = 0.0;
      _aiErrorMsg = null;
    });

    try {
      if (_kDemoTranscript) {
        _demoLevelTimer?.cancel();
        await Future.delayed(const Duration(seconds: 2));
      }
      final result = _kDemoTranscript
          ? null
          : await GroqWhisperService.instance.stopAndTranscribeResult(
              onProgressStatus: (msg) {
                if (mounted) setState(() => _transcribingStatusMsg = msg);
              },
            );
      if (!mounted) return;

      final transcript = result == null
          ? _kDemoTranscriptText
          : result.toFormattedDiarizedText().trim();
      if (transcript.isEmpty) {
        throw Exception('未能從音訊中識別出清晰人聲語音，請靠近麥克風並確保音量清晰後重試 🎙️');
      }

      setState(() {
        _isTranscribing = false;
        _transcribingStatusMsg = null;
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

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(result?.isDiarized == true
                  ? tr('vn_done_diarized')
                  : tr('vn_done_plain')),
              duration: const Duration(milliseconds: 1800),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF2E7D32),
            ),
          );
      }
    } catch (e) {
      debugPrint('Voice note transcribe error: $e');
      if (!mounted) return;
      final cleanMsg = e.toString().replaceAll('Exception:', '').trim();
      setState(() {
        _isTranscribing = false;
        _transcribingStatusMsg = null;
        _aiErrorMsg = cleanMsg;
      });
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(tr('vn_hint_msg', [cleanMsg.toString()])),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 1500),
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
    _clearDraftStorage();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(tr('vn_cleared')),
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
  // 全螢幕大視窗舒適校對模式
  // ============================================================
  Future<void> _openFullscreenTranscriptEditor() async {
    final tempController =
        TextEditingController(text: _transcriptController.text);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final updatedText = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final count = tempController.text.trim().length;
          final bottomPadding = MediaQuery.of(ctx).viewInsets.bottom;

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.92,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                // 頂部拖曳指示條
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 頂部功能列
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 14, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A148C).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.edit_note_rounded,
                            size: 20, color: Color(0xFF4A148C)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('vn_fullscreen_proof'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              tr('vn_char_count_hint', [count.toString()]),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark
                                    ? Colors.white60
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(modalCtx, tempController.text);
                        },
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(tr('vn_proof_done'),
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4A148C),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // 工具列快捷鍵 (複製、清空)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: isDark ? Colors.white10 : const Color(0xFFF9F7FA),
                  child: Row(
                    children: [
                      Text(
                        tr('vn_proof_tip'),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: tempController.text));
                          ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
                            SnackBar(
                              content: Text(tr('vn_copied_transcript')),
                              duration: Duration(milliseconds: 1000),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: Text(tr('vn_copy'), style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF4A148C),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: () {
                          setModalState(() {
                            tempController.clear();
                          });
                        },
                        icon:
                            const Icon(Icons.delete_outline_rounded, size: 14),
                        label: Text(tr('common_clear'), style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                ),

                // 核心大文字編輯區
                Expanded(
                  child: Padding(
                    padding:
                        EdgeInsets.fromLTRB(16, 12, 16, bottomPadding + 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF14141E)
                            : const Color(0xFFFCFBF9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white12
                              : const Color(0xFFE5DCD3),
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: tempController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        autofocus: false,
                        style: TextStyle(
                          fontSize: 15.5,
                          height: 1.7,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF2C2523),
                          fontWeight: FontWeight.w400,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: tr('vn_transcript_hint'),
                        ),
                        onChanged: (val) {
                          setModalState(() {});
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (updatedText != null && mounted) {
      setState(() {
        _transcriptController.text = updatedText;
        _transcriptController.selection = TextSelection.fromPosition(
          TextPosition(offset: _transcriptController.text.length),
        );
      });
      _saveDraftToStorage();
    }
  }

  /// 轉至背景執行 AI 整理（使用者可退出做其他事）
  void _runInBackgroundTask() {
    final rawText = _transcriptController.text.trim();
    _generatingTimer?.cancel();
    _tipTimer?.cancel();
    _starController.stop();

    if (rawText.isNotEmpty) {
      VoiceNoteBackgroundManager.instance.startBackgroundTask(
        transcript: rawText,
        style: _selectedStyle,
        detailLevel: _selectedDetailLevel,
        userId: widget.userId ?? 'u1',
        onNoteReady: widget.onNoteReady,
      );
      _clearDraftStorage();
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(tr('vn_bg_processing')),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4A148C),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ============================================================
  // 防誤觸離開確認機制
  // ============================================================
  Future<bool> _handleCloseAttempt() async {
    final hasContent = _transcriptController.text.trim().isNotEmpty;
    final isBusyRecording = _isRecording || _isPaused;
    final isGenerating = _step == _SheetStep.generating;
    final isPreview = _step == _SheetStep.preview;

    if (!hasContent && !isBusyRecording && !isGenerating && !isPreview) {
      return true; // 空白狀態直接安全離開
    }

    if (isBusyRecording) {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.mic_off_rounded, color: Colors.red, size: 22),
              SizedBox(width: 8),
              Text(tr('vn_recording'),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(tr('vn_leave_recording')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('vn_continue_rec')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('vn_discard_leave')),
            ),
          ],
        ),
      );
      if (shouldExit == true) {
        await _cancelCurrentRecording();
        return true;
      }
      return false;
    }

    if (isGenerating) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: Color(0xFF7B1FA2), size: 22),
              SizedBox(width: 8),
              Text(tr('vn_ai_working'),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            tr('vn_ai_working_msg'),
            style: TextStyle(fontSize: 13.5, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child:
                  Text(tr('vn_abort_ai'), style: TextStyle(color: Colors.red.shade700)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'wait'),
              child: Text(tr('vn_wait_fg')),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4A148C)),
              onPressed: () => Navigator.pop(ctx, 'background'),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(tr('vn_to_bg')),
            ),
          ],
        ),
      );

      if (action == 'background') {
        _runInBackgroundTask();
        return false;
      } else if (action == 'cancel') {
        _generatingTimer?.cancel();
        _tipTimer?.cancel();
        _starController.stop();
        return true;
      }
      return false;
    }

    // 逐字稿校對或預覽步驟：自動暫存草稿並詢問確認
    await _saveDraftToStorage();
    if (!mounted) return false;
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.save_as_outlined,
                color: Color(0xFF4A148C), size: 22),
            SizedBox(width: 8),
            Text(tr('vn_leave_title'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content:
            Text(tr('vn_leave_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('vn_keep_editing')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4A148C)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('vn_save_leave')),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  // ============================================================
  // AI 整理核心
  // ============================================================
  Future<void> _generateNote() async {
    // 若還在錄音中，先停止並轉錄為文字，並停留在逐字稿校對步驟，讓使用者先確認文字無誤
    if (_isRecording || _isPaused) {
      await _stopAndTranscribe();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(tr('vn_review_first')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF4A148C),
            duration: Duration(milliseconds: 1500),
          ),
        );
      return;
    }

    final rawText = _transcriptController.text.trim();
    if (rawText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
          SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text(tr('vn_need_content'))),
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

    // 啟動多階段平滑動態進度條（徹底解決卡在 91% 的問題）
    _generatingTimer?.cancel();
    _generatingTimer =
        Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted || _step != _SheetStep.generating) {
        timer.cancel();
        return;
      }
      setState(() {
        _generatingElapsedMs += 80;
        final seconds = _generatingElapsedMs / 1000.0;

        double target;
        if (seconds <= 1.5) {
          target = 0.05 + (seconds / 1.5) * 0.25;
          _generatingStage = 0;
        } else if (seconds <= 3.5) {
          target = 0.30 + ((seconds - 1.5) / 2.0) * 0.28;
          _generatingStage = 1;
        } else if (seconds <= 6.0) {
          target = 0.58 + ((seconds - 3.5) / 2.5) * 0.20;
          _generatingStage = 2;
        } else if (seconds <= 9.0) {
          target = 0.78 + ((seconds - 6.0) / 3.0) * 0.14;
          _generatingStage = 3;
        } else {
          final extraSec = seconds - 9.0;
          target = 0.92 + 0.065 * (1.0 - math.exp(-extraSec / 6.0));
          _generatingStage = 4;
        }
        _generatingProgress = target.clamp(0.05, 0.985);
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
        detailLevel: _selectedDetailLevel,
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
        _aiErrorMsg = tr('vn_offline_fallback', [e.toString()]);
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
        label: result.title.isNotEmpty ? result.title : tr('vn_topic_note'),
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
        label: result.title.isNotEmpty ? result.title : tr('vn_topic_note'),
        color: const Color(0xFF4A148C),
        children: [
          MindMapNode(
            id: 'node_summary',
            label: result.summary ?? tr('vn_core_points'),
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
        ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
          SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text(tr('vn_nothing_to_save'))),
        );
      }
      return;
    }

    final defaultTitle =
        rawText.length > 15 ? '${rawText.substring(0, 15)}...' : rawText;
    final formattedContent =
        '## 🎙️ 語音轉文字稿記錄\n\n$rawText\n\n---\n*記錄時間：${DateTime.now().toString().substring(0, 16)}*';

    await _clearDraftStorage();
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
  void _applyNote() async {
    _syncActionItemsToMarkdown();
    final title = _titleEditController.text.trim().isEmpty
        ? _result?.title ?? tr('notes_voice_default_title')
        : _titleEditController.text.trim();
    final content = _contentEditController.text.trim().isEmpty
        ? (_result?.markdownContent ?? _transcriptController.text)
        : _contentEditController.text;
    final category = _editableCategory;

    await _clearDraftStorage();
    widget.onNoteReady?.call(
      title,
      category,
      content,
      _result?.mindmapJson,
      _editableActionItems,
    );
    if (mounted) {
      Navigator.pop(context);
    }
  }

  // ============================================================
  // UI 主構建 (含 PopScope 防誤觸離開)
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final safeBottom = bottomInset > 0
        ? (bottomInset - bottomPadding).clamp(0.0, double.infinity) + 16.0
        : 20.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final shouldPop = await _handleCloseAttempt();
        if (shouldPop && mounted) {
          nav.pop();
        }
      },
      child: SafeArea(
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
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.only(bottom: safeBottom),
                  child: SingleChildScrollView(
                    controller: widget.scrollController,
                    physics: const BouncingScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 8,
                      bottom: 8,
                    ),
                    child: _buildStepContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final hasContent = _transcriptController.text.trim().isNotEmpty;
    final isBusyRecording = _isRecording || _isPaused;

    String title = '';
    String subtitle = '';

    if (_step == _SheetStep.recording) {
      if (hasContent && !isBusyRecording) {
        title = tr('vn_step2');
        subtitle = tr('vn_step2_sub');
      } else {
        title = tr('vn_step1');
        subtitle = tr('vn_step1_sub');
      }
    } else if (_step == _SheetStep.generating) {
      title = tr('vn_step3_busy');
      subtitle = tr('vn_step3_busy_sub');
    } else {
      title = tr('vn_step3');
      subtitle = tr('vn_step3_sub');
    }

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
            child: const Icon(Icons.bolt_rounded,
                size: 16, color: Color(0xFF4A148C)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E2723),
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: hasContent &&
                              !isBusyRecording &&
                              _step == _SheetStep.recording
                          ? const Color(0xFF7B1FA2)
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.grey),
            onPressed: () async {
              final nav = Navigator.of(context);
              final shouldPop = await _handleCloseAttempt();
              if (shouldPop && mounted) {
                nav.pop();
              }
            },
            tooltip: tr('btn_close'),
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

  /// 逐字稿草稿恢復橫幅 (防誤關閉/意外跳出)
  Widget _buildDraftRecoveryBanner() {
    if (_pendingDraftText == null ||
        _pendingDraftText!.trim().isEmpty ||
        _transcriptController.text.trim().isNotEmpty) {
      return const SizedBox.shrink();
    }

    final draftExcerpt = _pendingDraftText!.trim();
    final displayExcerpt = draftExcerpt.length > 38
        ? '${draftExcerpt.substring(0, 38)}...'
        : draftExcerpt;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF4A148C).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_edu_rounded,
                  size: 20, color: Color(0xFF4A148C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('vn_draft_found'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A148C),
                  ),
                ),
              ),
              InkWell(
                onTap: _clearDraftStorage,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded,
                      size: 16, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '「$displayExcerpt」',
            style: TextStyle(
              fontSize: 12,
              color: Colors.purple.shade900,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (_pendingDraftTime != null) ...[
            const SizedBox(height: 4),
            Text(
              tr('vn_draft_time', [(DateTime.tryParse(_pendingDraftTime!)?.toLocal().toString().substring(0, 16) ?? _pendingDraftTime).toString()]),
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.purple.shade700.withValues(alpha: 0.8),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _clearDraftStorage,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(tr('agent_discard'), style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _transcriptController.text = _pendingDraftText!;
                    _pendingDraftText = null;
                    _pendingDraftTime = null;
                    _transcriptController.selection =
                        TextSelection.fromPosition(
                      TextPosition(offset: _transcriptController.text.length),
                    );
                  });
                  ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
                    SnackBar(
                      content: Text(tr('vn_draft_restored')),
                      duration: Duration(milliseconds: 1500),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.restore_rounded, size: 14),
                label: Text(tr('vn_restore_draft'),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4A148C),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFFE65100)),
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
                        hasContent
                            ? Icons.check_circle_outline
                            : Icons.mic_none,
                        size: 14,
                        color:
                            hasContent ? const Color(0xFF4A148C) : Colors.grey,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      _isTranscribing
                          ? (_transcribingStatusMsg ?? tr('vn_gladia_diarizing'))
                          : _isRecording
                              ? tr('vn_status_rec', [(_formatDuration(_recordDuration)).toString()])
                              : _isPaused
                                  ? tr('vn_status_paused', [(_formatDuration(_recordDuration)).toString()])
                                  : hasContent
                                      ? tr('vn_status_done', [charCount.toString()])
                                      : tr('vn_status_idle'),
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
                      tooltip: tr('vn_cancel_rec'),
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
                      tooltip: tr('vn_clear_transcript'),
                    ),
                    const SizedBox(width: 14),
                  ],

                  // 核心主按鈕（錄音中為暫停；暫停中為繼續；非錄音中為開始/追加錄音）
                  Tooltip(
                    message: _isTranscribing
                        ? tr('vn_transcribing')
                        : _isRecording
                            ? tr('vn_pause_rec')
                            : _isPaused
                                ? tr('vn_continue_rec')
                                : hasContent
                                    ? tr('vn_append_rec')
                                    : tr('vn_start_rec'),
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
                                        ? [
                                            Colors.orange.shade400,
                                            Colors.orange.shade700
                                          ]
                                        : [
                                            const Color(0xFF7B1FA2),
                                            const Color(0xFF4A148C)
                                          ],
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
                      label: Text(tr('vn_to_text'),
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A148C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
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
                    ? tr('vn_ai_recognizing')
                    : _isRecording
                        ? tr('vn_hint_rec')
                        : _isPaused
                            ? tr('vn_hint_paused')
                            : hasContent
                                ? tr('vn_hint_done')
                                : tr('vn_hint_idle'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 逐字稿草稿恢復橫幅 (防誤關閉)
        _buildDraftRecoveryBanner(),

        // 逐字稿校對指引橫幅
        if (hasContent && !isBusyRecording) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF4A148C).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF4A148C).withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    size: 18, color: Color(0xFF4A148C)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('vn_transcribed_review'),
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: const Color(0xFF4A148C).withValues(alpha: 0.95),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // ============================================================
        // 逐字稿文字區域 (支援編輯、放大校對、展示、刪除與狀態提示)
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
                Text(
                  hasContent ? tr('vn_transcript') : tr('vn_transcript_content'),
                  style: const TextStyle(
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
                    tr('vn_chars_n', [charCount.toString()]),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 6),
                  // 全螢幕 / 放大舒適校對按鈕
                  InkWell(
                    onTap: _openFullscreenTranscriptEditor,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF4A148C).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFF4A148C)
                                .withValues(alpha: 0.25),
                            width: 0.9),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_full_rounded,
                              size: 12, color: Color(0xFF4A148C)),
                          SizedBox(width: 3),
                          Text(
                            tr('vn_zoom_proof'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A148C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: currentText));
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(tr('vn_copied_transcript2')),
                            duration: Duration(milliseconds: 1000),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.grey.shade300, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded,
                              size: 12, color: Colors.grey.shade700),
                          const SizedBox(width: 3),
                          Text(
                            tr('vn_copy'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: _clearTranscript,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.red.shade200, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 12, color: Colors.red.shade700),
                          const SizedBox(width: 3),
                          Text(
                            tr('common_clear'),
                            style: TextStyle(
                              fontSize: 11,
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
          constraints: const BoxConstraints(minHeight: 110, maxHeight: 220),
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
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF4A148C)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _transcribingStatusMsg ??
                            tr('vn_converting'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
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
                            hintText: tr('vn_edit_hint'),
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
                  : _aiErrorMsg != null && !isBusyRecording
                      ? Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 32,
                                  color: Colors.red.shade400,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _aiErrorMsg!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  tr('vn_retalk'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
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
                                isBusyRecording
                                    ? Icons.graphic_eq_rounded
                                    : Icons.speaker_notes_outlined,
                                size: 28,
                                color: isBusyRecording
                                    ? Colors.purple.shade300
                                    : Colors.grey.shade400,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isBusyRecording
                                    ? tr('vn_busy_hint')
                                    : tr('vn_empty_hint'),
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
            const Icon(Icons.auto_awesome_rounded,
                size: 16, color: Color(0xFF4A148C)),
            const SizedBox(width: 6),
            Text(
              tr('vn_pick_style'),
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
              child: Text(
                tr('vn_five_styles'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A148C),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── 整理細緻度切換膠囊 (⚡ 精簡 vs. 📚 詳盡) ──
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300, width: 0.8),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() =>
                      _selectedDetailLevel = VoiceNoteDetailLevel.concise),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedDetailLevel == VoiceNoteDetailLevel.concise
                          ? const Color(0xFF4A148C)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: _selectedDetailLevel ==
                              VoiceNoteDetailLevel.concise
                          ? [
                              BoxShadow(
                                color: const Color(0xFF4A148C)
                                    .withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(VoiceNoteDetailLevel.concise.emoji,
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text(
                          tr('vn_concise_n', [VoiceNoteDetailLevel.concise.label.toString()]),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: _selectedDetailLevel ==
                                    VoiceNoteDetailLevel.concise
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() =>
                      _selectedDetailLevel = VoiceNoteDetailLevel.detailed),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedDetailLevel == VoiceNoteDetailLevel.detailed
                          ? const Color(0xFF4A148C)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: _selectedDetailLevel ==
                              VoiceNoteDetailLevel.detailed
                          ? [
                              BoxShadow(
                                color: const Color(0xFF4A148C)
                                    .withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(VoiceNoteDetailLevel.detailed.emoji,
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text(
                          tr('vn_detailed_n', [VoiceNoteDetailLevel.detailed.label.toString()]),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: _selectedDetailLevel ==
                                    VoiceNoteDetailLevel.detailed
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                        child: Text(style.emoji,
                            style: const TextStyle(fontSize: 18)),
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
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? const Color(0xFF4A148C)
                                        : const Color(0xFF2C3E50),
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded,
                                    size: 14, color: Color(0xFF4A148C)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            style.badgeTag,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isSelected
                                  ? const Color(0xFF7B1FA2)
                                  : Colors.grey.shade600,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
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
                  Text(_selectedStyle.emoji,
                      style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 6),
                  Text(
                    tr('vn_style_spec', [_selectedStyle.label.toString()]),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A148C),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A148C).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tr('vn_default_cat', [trv(_selectedStyle.suggestedCategory)]),
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
                        const Text('✦ ',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF7B1FA2))),
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
                label: Text(tr('vn_save_direct'), style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5D4037),
                  side: const BorderSide(color: Color(0xFF8D6E63)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
                      ? tr('vn_end_rec')
                      : hasContent
                          ? tr('vn_start_ai', [_selectedStyle.emoji.toString(), _selectedStyle.label.toString()])
                          : tr('vn_need_record'),
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.bold),
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
                      (0.3 +
                          0.7 *
                              math
                                  .sin(phase + normalizedIndex * math.pi * 2)
                                  .abs())
                  : 0.06 +
                      0.04 * math.sin(phase + normalizedIndex * math.pi).abs();

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
                        color: const Color(0xFF7B1FA2)
                            .withValues(alpha: glowAlpha),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: const Color(0xFF009688)
                            .withValues(alpha: glowAlpha * 0.5),
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
                      Text(_selectedStyle.emoji,
                          style: const TextStyle(fontSize: 32)),
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
              Text(
                tr('vn_ai_organizing'),
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
              border: Border.all(
                  color: const Color(0xFF7B1FA2).withValues(alpha: 0.15)),
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
                        const Icon(Icons.timer_outlined,
                            size: 14, color: Color(0xFF7B1FA2)),
                        const SizedBox(width: 4),
                        Text(
                          tr('vn_elapsed', [((_generatingElapsedMs / 1000).toStringAsFixed(1)).toString()]),
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
                              ? const Icon(Icons.check_rounded,
                                  size: 14, color: Colors.white)
                              : isCurrent
                                  ? const SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
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
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.w600,
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
                                color: isCurrent
                                    ? const Color(0xFF5D4037)
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 右側狀態標籤
                      if (isDone)
                        Text(tr('vn_done_mark'),
                            style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold))
                      else if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF7B1FA2).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(tr('vn_processing'),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF7B1FA2),
                                  fontWeight: FontWeight.bold)),
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
                border: Border.all(
                    color: const Color(0xFF7B1FA2).withValues(alpha: 0.12)),
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

          const SizedBox(height: 18),

          // ── 轉至背景整理按鈕（使用者可退出做其他事） ──
          OutlinedButton.icon(
            onPressed: _runInBackgroundTask,
            icon: const Icon(Icons.open_in_new_rounded, size: 17),
            label: Text(
              tr('vn_to_bg2'),
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4A148C),
              side: BorderSide(
                color: const Color(0xFF4A148C).withValues(alpha: 0.35),
                width: 1.2,
              ),
              backgroundColor:
                  const Color(0xFF4A148C).withValues(alpha: 0.04),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr('vn_bg_note'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
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
                    _result!.isAiGenerated
                        ? Icons.auto_awesome
                        : Icons.offline_bolt,
                    size: 13,
                    color: _result!.isAiGenerated
                        ? const Color(0xFF4A148C)
                        : Colors.orange.shade800,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _result!.isAiGenerated ? tr('vn_ai_done') : tr('vn_offline_done'),
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
            hintText: tr('vn_title_hint'),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: const Color(0xFFFBF9F7),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF4A148C), width: 1.5),
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
              label: Text(trv(cat)),
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
                  color: isSelected
                      ? const Color(0xFF4A148C)
                      : Colors.grey.shade300,
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
                  style:
                      const TextStyle(fontSize: 11.5, color: Color(0xFF5D4037)),
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
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
            dividerColor: Colors.transparent,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.article_outlined, size: 16),
                    SizedBox(width: 4),
                    Text(tr('vn_tab_content')),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hub_outlined, size: 15),
                    SizedBox(width: 4),
                    Text(tr('notes_mindmap')),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_outlined, size: 15),
                    SizedBox(width: 4),
                    Text(tr('vn_tab_summary')),
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
                label: Text(tr('vn_redo')),
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
                  widget.existingContent != null ? tr('vn_insert') : tr('vn_create'),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
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
    final hasSummary =
        _result?.summary != null && _result!.summary!.trim().isNotEmpty;
    final hasKeyPoints =
        _result?.keyPoints != null && _result!.keyPoints!.isNotEmpty;
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
            p: const TextStyle(
                fontSize: 13.5, height: 1.6, color: Color(0xFF2C2523)),
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
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded,
                        size: 16, color: Color(0xFF673AB7)),
                    SizedBox(width: 6),
                    Text(
                      tr('vn_summary_title'),
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
              const Icon(Icons.format_list_bulleted_rounded,
                  size: 16, color: Color(0xFF5D4037)),
              const SizedBox(width: 6),
              Text(
                tr('vn_key_points_n', [(_result!.keyPoints!.length).toString()]),
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
              const Icon(Icons.checklist_rounded,
                  size: 16, color: Color(0xFF2E7D32)),
              const SizedBox(width: 6),
              Text(
                tr('vn_actions_n', [(_editableActionItems.where((a) => a.isCompleted).length).toString(), _editableActionItems.length.toString()]),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3E2723),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  final text = _editableActionItems.map((a) {
                    final check = a.isCompleted ? '[x]' : '[ ]';
                    final owner = a.owner != '未指定' ? ' (${a.owner})' : '';
                    final due = a.dueDate != '無' && a.dueDate != '待定'
                        ? tr('vn_due', [a.dueDate.toString()])
                        : '';
                    return '- $check ${a.task}$owner$due';
                  }).join('\n');
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
                    SnackBar(
                      content: Text(tr('vn_copied_todos')),
                      duration: Duration(milliseconds: 1500),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded,
                          size: 13, color: Color(0xFF2E7D32)),
                      SizedBox(width: 4),
                      Text(
                        tr('vn_copy_all'),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
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
                color: item.isCompleted
                    ? const Color(0xFFF1F8E9)
                    : const Color(0xFFFDFDFD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: item.isCompleted
                      ? Colors.green.shade200
                      : const Color(0xFFE5DCD3),
                ),
              ),
              child: CheckboxListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                dense: true,
                value: item.isCompleted,
                activeColor: const Color(0xFF2E7D32),
                title: Text(
                  item.task,
                  style: TextStyle(
                    fontSize: 13,
                    decoration:
                        item.isCompleted ? TextDecoration.lineThrough : null,
                    color: item.isCompleted
                        ? Colors.grey.shade600
                        : const Color(0xFF2C2523),
                    fontWeight:
                        item.isCompleted ? FontWeight.normal : FontWeight.w500,
                  ),
                ),
                subtitle: (item.owner != '未指定' || item.dueDate != '無')
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            if (item.owner != '未指定')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '👤 ${item.owner}',
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.blue.shade800),
                                ),
                              ),
                            if (item.dueDate != '無')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '⏰ ${item.dueDate}',
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.orange.shade800),
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
              tr('vn_no_mindmap'),
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
                Icon(Icons.touch_app_rounded,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  tr('notes_mindmap_gesture'),
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _openFullscreenMindmap,
              icon: const Icon(Icons.fullscreen_rounded, size: 16),
              label: Text(tr('vn_fullscreen'), style: TextStyle(fontSize: 12)),
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
          : tr('notes_mindmap_fullscreen'),
    );
  }

  // ============================================================
  // TAB 1: 筆記內容 (業界級乾淨排版，無原始碼標籤干擾)
  // ============================================================
  Widget _buildNoteContentTab() {
    final cleanContent =
        VoiceNoteService.cleanRawMarkdown(_contentEditController.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 頂部小標與複製按鈕
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.article_outlined,
                    size: 16, color: Color(0xFF4A148C)),
                SizedBox(width: 6),
                Text(
                  tr('vn_full_result'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E2723),
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded,
                  size: 18, color: Color(0xFF5D4037)),
              tooltip: tr('vn_copy_note'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: cleanContent));
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(tr('vn_copied_note')),
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
            styleSheet:
                MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
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
