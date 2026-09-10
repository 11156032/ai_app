import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/voice_recognition_service.dart';
import '../services/voice_note_service.dart';

// ============================================================
// 語音速記整理面板 (VoiceNoteSheet)
// BottomSheet 浮層 - 分三步驟流程：錄音 → 風格選擇 → AI 整理預覽
// ============================================================
class VoiceNoteSheet extends StatefulWidget {
  /// 整理完成後回調：傳回標題、分類、Markdown 內容
  final void Function(String title, String category, String markdownContent)? onNoteReady;

  /// 若為 null，則為「新增筆記」模式；若帶值，則為「插入至編輯器」模式
  final String? existingContent;

  const VoiceNoteSheet({
    super.key,
    this.onNoteReady,
    this.existingContent,
  });

  @override
  State<VoiceNoteSheet> createState() => _VoiceNoteSheetState();
}

// ============================================================
// 狀態列舉
// ============================================================
enum _SheetStep {
  recording,    // 錄音中 / 等待開始
  styleSelect,  // 風格選擇 & 逐字稿確認
  generating,   // AI 整理中
  preview,      // 成果預覽
}

class _VoiceNoteSheetState extends State<VoiceNoteSheet>
    with TickerProviderStateMixin {
  _SheetStep _step = _SheetStep.recording;

  // 語音辨識相關
  bool _isListening = false;
  String _transcript = '';
  String _interimTranscript = '';
  double _soundLevel = 0.0;
  Timer? _durationTimer;
  Duration _recordDuration = Duration.zero;

  // 風格選擇
  VoiceNoteStyle _selectedStyle = VoiceNoteStyle.studyOutline;

  // AI 整理結果
  VoiceNoteResult? _result;
  String? _aiErrorMsg;

  // 標題/分類編輯器（預覽步驟）
  late TextEditingController _titleEditController;
  String _editableCategory = '';
  late TextEditingController _contentEditController;

  // 動態聲波動畫
  late AnimationController _waveController;
  late AnimationController _starController;

  @override
  void initState() {
    super.initState();
    _titleEditController = TextEditingController();
    _contentEditController = TextEditingController();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _starController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  @override
  void dispose() {
    VoiceRecognitionService.instance.stopListening();
    _durationTimer?.cancel();
    _waveController.dispose();
    _starController.dispose();
    _titleEditController.dispose();
    _contentEditController.dispose();
    super.dispose();
  }

  // ============================================================
  // 語音辨識控制
  // ============================================================
  Future<void> _startListening() async {
    if (_isListening) return;

    final started = await VoiceRecognitionService.instance.startListening(
      onResult: (words, isFinal) {
        if (!mounted) return;
        setState(() {
          if (isFinal) {
            // 最終結果：附加到逐字稿
            if (words.isNotEmpty) {
              _transcript = _transcript.isEmpty
                  ? words
                  : '$_transcript\n$words';
            }
            _interimTranscript = '';
          } else {
            _interimTranscript = words;
          }
        });
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
          setState(() {
            _isListening = false;
            _soundLevel = 0.0;
          });
          _durationTimer?.cancel();
        } else if (status == 'listening') {
          setState(() => _isListening = true);
        }
      },
      onError: (errMsg) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _soundLevel = 0.0;
        });
        _durationTimer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('語音辨識錯誤：$errMsg'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      },
    );

    if (started && mounted) {
      setState(() {
        _isListening = true;
        _recordDuration = Duration.zero;
      });
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _isListening) {
          setState(() => _recordDuration += const Duration(seconds: 1));
        }
      });
    }
  }

  Future<void> _stopListening() async {
    await VoiceRecognitionService.instance.stopListening();
    _durationTimer?.cancel();
    if (mounted) {
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
        // 合併 interim 到逐字稿
        if (_interimTranscript.isNotEmpty) {
          _transcript = _transcript.isEmpty
              ? _interimTranscript
              : '$_transcript\n$_interimTranscript';
          _interimTranscript = '';
        }
      });
    }
  }

  void _clearTranscript() {
    setState(() {
      _transcript = '';
      _interimTranscript = '';
      _recordDuration = Duration.zero;
    });
  }

  void _goToStyleSelect() async {
    await _stopListening();
    if (!mounted) return;
    if (_transcript.trim().isEmpty && _interimTranscript.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先錄入語音內容再繼續 🎙️')),
      );
      return;
    }
    setState(() => _step = _SheetStep.styleSelect);
  }

  // ============================================================
  // AI 整理
  // ============================================================
  Future<void> _generateNote() async {
    final transcriptToProcess = _transcript.isNotEmpty
        ? _transcript
        : _interimTranscript;

    setState(() {
      _step = _SheetStep.generating;
      _aiErrorMsg = null;
    });
    _starController.repeat();

    try {
      final result = await VoiceNoteService.instance.organizeTranscript(
        transcript: transcriptToProcess,
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
        _aiErrorMsg = '整理失敗，請重試：$e';
        _step = _SheetStep.styleSelect;
        _starController.stop();
        _starController.reset();
      });
    }
  }

  // ============================================================
  // 完成 - 回傳結果
  // ============================================================
  void _applyNote() {
    final title = _titleEditController.text.trim().isEmpty
        ? _result?.title ?? '語音筆記'
        : _titleEditController.text.trim();
    final content = _contentEditController.text;
    final category = _editableCategory;

    widget.onNoteReady?.call(title, category, content);
    Navigator.pop(context);
  }

  // ============================================================
  // UI 主體
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
          // 頂部拖曳指示條
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 動態標題列
          _buildHeader(),

          const Divider(height: 1),

          // 主內容區域（可捲動）
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
      _SheetStep.styleSelect: '✨ 選擇整理風格',
      _SheetStep.generating: '🤖 AI 智慧整理中...',
      _SheetStep.preview: '📝 整理成果預覽',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titles[_step] ?? '',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E2723),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case _SheetStep.recording:
        return _buildRecordingStep();
      case _SheetStep.styleSelect:
        return _buildStyleSelectStep();
      case _SheetStep.generating:
        return _buildGeneratingStep();
      case _SheetStep.preview:
        return _buildPreviewStep();
    }
  }

  // ============================================================
  // STEP 1: 錄音步驟
  // ============================================================
  Widget _buildRecordingStep() {
    final fullTranscript = _transcript +
        (_transcript.isNotEmpty && _interimTranscript.isNotEmpty ? '\n' : '') +
        _interimTranscript;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),

        // 聲波視覺化
        _buildSoundWave(),

        const SizedBox(height: 12),

        // 計時器
        Text(
          _isListening
              ? '${_recordDuration.inMinutes.toString().padLeft(2, '0')}:${(_recordDuration.inSeconds % 60).toString().padLeft(2, '0')} 🔴'
              : _transcript.isNotEmpty
                  ? '已錄製完成，可繼續錄入'
                  : '點擊麥克風開始錄音',
          style: TextStyle(
            fontSize: 13,
            color: _isListening ? Colors.red.shade600 : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 24),

        // 麥克風主按鈕
        GestureDetector(
          onTap: _isListening ? _stopListening : _startListening,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isListening ? 80 : 72,
            height: _isListening ? 80 : 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isListening
                    ? [Colors.red.shade400, Colors.red.shade700]
                    : [const Color(0xFF8D6E63), const Color(0xFF5D4037)],
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isListening ? Colors.red : const Color(0xFF8D6E63))
                      .withValues(alpha: 0.4),
                  blurRadius: _isListening ? 20 : 12,
                  spreadRadius: _isListening ? 4 : 0,
                ),
              ],
            ),
            child: Icon(
              _isListening ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),

        const SizedBox(height: 8),
        Text(
          _isListening ? '點擊停止' : '點擊開始',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),

        const SizedBox(height: 24),

        // 即時逐字稿顯示區域
        if (fullTranscript.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '語音逐字稿',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF5D4037),
                ),
              ),
              if (_transcript.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearTranscript,
                  icon: const Icon(Icons.delete_outline, size: 14),
                  label: const Text('清除', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 80, maxHeight: 180),
            decoration: BoxDecoration(
              color: const Color(0xFFFBF9F7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5DCD3)),
            ),
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              child: Text(
                fullTranscript,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: _interimTranscript.isNotEmpty
                      ? Colors.black87
                      : Colors.black54,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '共 ${fullTranscript.replaceAll(RegExp(r'\s+'), '').length} 字',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],

        const SizedBox(height: 24),

        // 繼續按鈕
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _transcript.isNotEmpty || _interimTranscript.isNotEmpty
                ? _goToStyleSelect
                : null,
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('選擇整理風格 →', style: TextStyle(fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5D4037),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade200,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // 動態聲波視覺化
  Widget _buildSoundWave() {
    return SizedBox(
      height: 60,
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(12, (index) {
              final phase = _waveController.value * 2 * math.pi;
              final normalizedIndex = index / 12;
              final baseAmplitude = _isListening
                  ? (_soundLevel / 10.0).clamp(0.15, 1.0)
                  : 0.08;
              final waveHeight = _isListening
                  ? baseAmplitude *
                      (0.4 + 0.6 * math.sin(phase + normalizedIndex * math.pi * 2).abs())
                  : 0.08 + 0.04 * math.sin(phase + normalizedIndex * math.pi).abs();

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 4,
                height: (waveHeight * 50 + 4).clamp(4.0, 54.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: _isListening
                        ? [Colors.red.shade300, Colors.red.shade600]
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
  // STEP 2: 風格選擇步驟
  // ============================================================
  Widget _buildStyleSelectStep() {
    final displayTranscript = _transcript.isNotEmpty ? _transcript : _interimTranscript;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        // 逐字稿摘要
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F2EF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5DCD3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.text_snippet_outlined,
                      size: 14, color: Color(0xFF8D6E63)),
                  const SizedBox(width: 6),
                  const Text(
                    '已錄製逐字稿',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8D6E63),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _step = _SheetStep.recording),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF5D4037),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('重錄', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                displayTranscript.length > 120
                    ? '${displayTranscript.substring(0, 120)}...'
                    : displayTranscript,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '共 ${displayTranscript.replaceAll(RegExp(r'\s+'), '').length} 字',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
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
            child: Text(
              _aiErrorMsg!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
          ),
        ],

        const SizedBox(height: 20),

        const Text(
          '選擇 AI 整理風格',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E2723),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '請選擇最符合您語音內容類型的整理方式',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),

        const SizedBox(height: 14),

        // 風格選擇卡片
        ...VoiceNoteStyle.values.map((style) => _buildStyleCard(style)),

        const SizedBox(height: 20),

        // AI 整理按鈕
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _generateNote,
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(
              'AI 智慧整理 ${_selectedStyle.emoji}',
              style: const TextStyle(fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A148C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildStyleCard(VoiceNoteStyle style) {
    final isSelected = _selectedStyle == style;
    return GestureDetector(
      onTap: () => setState(() => _selectedStyle = style),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isSelected ? const Color(0xFF4A148C).withValues(alpha: 0.06) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF4A148C) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4A148C).withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF4A148C).withValues(alpha: 0.12)
                    : const Color(0xFFF5F2EF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(style.emoji, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    style.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected
                          ? const Color(0xFF4A148C)
                          : const Color(0xFF3E2723),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    style.description,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF4A148C), size: 20),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STEP 3: AI 生成中
  // ============================================================
  Widget _buildGeneratingStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
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
              width: 80,
              height: 80,
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
                child: Text('✨', style: TextStyle(fontSize: 36)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'AI 正在分析您的語音內容...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E2723),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '以「${_selectedStyle.label}」風格提煉重點與排版',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          const LinearProgressIndicator(
            backgroundColor: Color(0xFFE8E1F4),
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A148C)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 4: 預覽步驟
  // ============================================================
  Widget _buildPreviewStep() {
    if (_result == null) return const SizedBox();
    final categories = ['學習', '工作', '生活', '未分類'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        // AI 生成徽章
        if (_result!.isAiGenerated)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF4A148C).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF4A148C).withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 12, color: Color(0xFF4A148C)),
                SizedBox(width: 4),
                Text(
                  'AI 智慧整理完成',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF4A148C),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        if (!_result!.isAiGenerated)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.offline_bolt, size: 12, color: Colors.orange),
                SizedBox(width: 4),
                Text(
                  '離線整理（AI 暫時無法連線）',
                  style: TextStyle(fontSize: 11, color: Colors.orange),
                ),
              ],
            ),
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
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
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

        const SizedBox(height: 14),

        // 關鍵標籤顯示
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          '筆記內容',
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

        const SizedBox(height: 16),

        // 重新整理 & 確認按鈕列
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _step = _SheetStep.styleSelect),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('重新整理'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5D4037),
                  side: const BorderSide(color: Color(0xFF8D6E63)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                  style: const TextStyle(fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5D4037),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
