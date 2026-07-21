import 'package:flutter/material.dart';

class TourKeys {
  static final GlobalKey wrongQuestionsTabKey = GlobalKey();
  static final GlobalKey startPracticeFabKey = GlobalKey();
}

// ─────────────────────────────────────────────
// 互動式逐步引導 — 資料模型 & UI 元件
// ─────────────────────────────────────────────

/// 每一個引導步驟的資料描述
class TourStep {
  final String featureTitle;   // 功能名稱，例如「🤖 AI 分身」
  final int featureIndex;      // 功能索引 0/1/2
  final int stepInFeature;     // 在該功能中的步驟 1/2/3
  final int totalInFeature;    // 該功能總步驟數
  final int targetPageIndex;   // 需要切換的主頁 index（-1 表示維持當前頁）
  final GlobalKey? targetKey;  // 目標元件的 GlobalKey（null = 無聚光燈）
  final String title;
  final String description;
  final bool skipForGuest;
  final String? guestNote;     // 訪客顯示的替代說明
  final VoidCallback? onEnter; // 進入此步驟時執行
  final VoidCallback? onLeaveBackward; // 點選上一步離開此步驟時執行

  const TourStep({
    required this.featureTitle,
    required this.featureIndex,
    required this.stepInFeature,
    required this.totalInFeature,
    required this.targetPageIndex,
    this.targetKey,
    required this.title,
    required this.description,
    this.skipForGuest = false,
    this.guestNote,
    this.onEnter,
    this.onLeaveBackward,
  });
}

// ─────────────────────────────────────────────
// Spotlight 遮罩畫筆
// ─────────────────────────────────────────────

class SpotlightPainter extends CustomPainter {
  final Rect? highlightRect;
  final double borderRadius;
  final double pulseValue;

  SpotlightPainter({this.highlightRect, this.borderRadius = 8.0, this.pulseValue = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = const Color(0x77000000);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (highlightRect == null) {
      canvas.drawRect(fullRect, Paint()..color = const Color(0x33000000));
      return;
    }

    final inflated = highlightRect!.inflate(8);

    final path = Path()
      ..addRect(fullRect)
      ..addRRect(RRect.fromRectAndRadius(
          inflated, Radius.circular(borderRadius)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, overlayPaint);
    
    // 繪製動態脈衝光圈 (Pulsing ring) 提示使用者點擊
    if (pulseValue > 0) {
      final borderPaint = Paint()
        ..color = Colors.amberAccent.withValues(alpha: 1.0 - pulseValue)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 + (pulseValue * 4.0);
      
      final pulseRect = highlightRect!.inflate(8 + pulseValue * 10);
      canvas.drawRRect(
        RRect.fromRectAndRadius(pulseRect, Radius.circular(borderRadius + pulseValue * 5)),
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(SpotlightPainter oldDelegate) {
    return oldDelegate.highlightRect != highlightRect ||
           oldDelegate.borderRadius != borderRadius ||
           oldDelegate.pulseValue != pulseValue;
  }
}

// ─────────────────────────────────────────────
// TourOverlay — 主要 Overlay Widget
// ─────────────────────────────────────────────

class TourOverlay extends StatefulWidget {
  final List<TourStep> steps;
  final bool isGuest;
  final VoidCallback onSkip;
  final VoidCallback onComplete;
  final void Function(int pageIndex) onNavigatePage;

  const TourOverlay({
    super.key,
    required this.steps,
    required this.isGuest,
    required this.onSkip,
    required this.onComplete,
    required this.onNavigatePage,
  });

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay>
    with TickerProviderStateMixin {
  int _stepIndex = 0;
  late AnimationController _animController;
  late AnimationController _pulseCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);

    _animController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateIfNeeded();
      widget.steps[_effectiveIndex].onEnter?.call();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // 計算有效的步驟index（跳過訪客限制的步驟）
  int get _effectiveIndex {
    int idx = _stepIndex;
    while (idx < widget.steps.length &&
        widget.isGuest &&
        widget.steps[idx].skipForGuest) {
      idx++;
    }
    return idx;
  }

  TourStep get _currentStep {
    final idx = _effectiveIndex;
    return idx < widget.steps.length ? widget.steps[idx] : widget.steps.last;
  }

  void _navigateIfNeeded() {
    final step = _currentStep;
    if (step.targetPageIndex >= 0) {
      widget.onNavigatePage(step.targetPageIndex);
    }
  }

  void _goNext() {
    final prevPageIndex = _currentStep.targetPageIndex;
    _animController.reverse().then((_) async {
      if (!mounted) return;
      setState(() {
        int next = _stepIndex + 1;
        while (next < widget.steps.length &&
            widget.isGuest &&
            widget.steps[next].skipForGuest) {
          next++;
        }
        _stepIndex = next;
      });
      if (_stepIndex >= widget.steps.length) {
        widget.onComplete();
      } else {
        final nextPageIndex = _currentStep.targetPageIndex;
        _navigateIfNeeded();
        widget.steps[_effectiveIndex].onEnter?.call();
        // 若切換了頁面，稍等讓使用者看清楚畫面再顯示下一步卡片
        if (nextPageIndex >= 0 && nextPageIndex != prevPageIndex) {
          await Future.delayed(const Duration(milliseconds: 380));
        }
        if (mounted) {
          _animController.forward();
          Future.delayed(const Duration(milliseconds: 250), () {
            if (mounted) setState(() {});
          });
        }
      }
    });
  }


  void _goBack() {
    if (_stepIndex <= 0) return;
    final prevPageIndex = _currentStep.targetPageIndex;
    widget.steps[_effectiveIndex].onLeaveBackward?.call();
    _animController.reverse().then((_) async {
      if (!mounted) return;
      setState(() {
        int prev = _stepIndex - 1;
        while (prev >= 0 &&
            widget.isGuest &&
            widget.steps[prev].skipForGuest) {
          prev--;
        }
        if (prev >= 0) _stepIndex = prev;
      });
      final nextPageIndex = _currentStep.targetPageIndex;
      _navigateIfNeeded();
      widget.steps[_effectiveIndex].onEnter?.call();
      // 若切換了頁面，稍等讓使用者看清楚畫面再顯示上一步卡片
      if (nextPageIndex >= 0 && nextPageIndex != prevPageIndex) {
        await Future.delayed(const Duration(milliseconds: 380));
      }
      if (mounted) {
        _animController.forward();
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) setState(() {});
        });
      }
    });
  }

  Rect? _getTargetRect(GlobalKey? key) {
    if (key == null) return null;
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final pos = box.localToGlobal(Offset.zero);
    return pos & box.size;
  }

  bool _allRemainingSkipped(int fromIdx) {
    for (int i = fromIdx; i < widget.steps.length; i++) {
      if (!(widget.isGuest && widget.steps[i].skipForGuest)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_stepIndex >= widget.steps.length) return const SizedBox.shrink();

    final step = _currentStep;
    final effectiveIdx = _effectiveIndex;

    // 計算可見步驟（訪客非跳過的）
    final visibleSteps = widget.steps
        .where((s) => !(widget.isGuest && s.skipForGuest))
        .toList();
    final visibleStepNumber = visibleSteps.indexWhere(
          (s) =>
              s.featureIndex == step.featureIndex &&
              s.stepInFeature == step.stepInFeature,
        ) +
        1;

    final targetRect = _getTargetRect(step.targetKey);
    final screenSize = MediaQuery.of(context).size;
    final primaryColor = Theme.of(context).primaryColor;
    final displayDesc =
        (widget.isGuest && step.guestNote != null) ? step.guestNote! : step.description;

    // 決定提示卡位置：目標元件下方有空間則放下方，否則放上方
    double? cardTop, cardBottom;
    if (targetRect != null && targetRect.bottom + 230 < screenSize.height) {
      cardTop = targetRect.bottom + 20;
    } else if (targetRect != null) {
      cardBottom = screenSize.height - targetRect.top + 20;
    } else {
      cardBottom = 80; // 無目標時放畫面下方，避免擋住中間的 Dialog
    }

    final isLastVisible = effectiveIdx >= widget.steps.length - 1 ||
        _allRemainingSkipped(effectiveIdx + 1);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Stack(
        children: [
          // ── 遮罩 + 聚光燈 ──
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque, // opaque：吸收所有點擊，防止穿透到底層 Widget
              onPointerDown: (event) {
                final liveRect = _getTargetRect(step.targetKey);
                if (liveRect != null && liveRect.contains(event.position)) {
                  _goNext();
                }
              },
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (context, child) {
                    final liveRect = _getTargetRect(step.targetKey);
                    return CustomPaint(
                      painter: SpotlightPainter(
                        highlightRect: liveRect ?? targetRect,
                        pulseValue: _pulseCtrl.value,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // ── 步驟提示卡 ──
          Positioned(
            left: 20,
            right: 20,
            top: cardTop,
            bottom: cardBottom,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 功能標籤 + 總進度
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            step.featureTitle,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '步驟 $visibleStepNumber / ${visibleSteps.length}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 功能內步驟進度點
                    Row(
                      children: List.generate(step.totalInFeature, (i) {
                        final active = i == step.stepInFeature - 1;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 5),
                          width: active ? 16 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: active
                                ? primaryColor
                                : primaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),

                    // 步驟標題
                    Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // 步驟說明
                    Text(
                      displayDesc,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF555555),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 按鈕列
                    Row(
                      children: [
                        TextButton(
                          onPressed: widget.onSkip,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade500,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: const Size(0, 36),
                          ),
                          child: const Text('略過'),
                        ),
                        const Spacer(),
                        if (effectiveIdx > 0) ...[
                          OutlinedButton(
                            onPressed: _goBack,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: BorderSide(color: primaryColor),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('← 上一步', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          const SizedBox(width: 8),
                        ],
                        ElevatedButton(
                          onPressed: _goNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text(
                            isLastVisible ? '已了解 ✅' : '下一步 →',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
