import 'package:flutter/material.dart';
import 'tutorial_video_player.dart';
import 'mindmap_node.dart';
import 'mindmap_canvas.dart';
import '../services/app_locale_service.dart';

class TourKeys {
  static final GlobalKey wrongQuestionsTabKey = GlobalKey();
  static final GlobalKey startPracticeFabKey = GlobalKey();
  static final GlobalKey drawerButtonKey = GlobalKey();
  static final GlobalKey bottomNavSettingKey = GlobalKey();
}

// ─────────────────────────────────────────────
// 互動式逐步引導 — 資料模型 & UI 元件
// ─────────────────────────────────────────────

/// 每一個引導步驟的資料描述
class TourStep {
  final String featureTitle; // 功能名稱，例如「🤖 AI 排程」
  final int featureIndex; // 功能索引 0/1/2
  final int stepInFeature; // 在該功能中的步驟 1/2/3
  final int totalInFeature; // 該功能總步驟數
  final int targetPageIndex; // 需要切換的主頁 index（-1 表示維持當前頁）
  final GlobalKey? targetKey; // 目標元件的 GlobalKey（null = 無聚光燈）
  final String title;
  final String description;
  final bool skipForGuest;
  final String? guestNote; // 訪客顯示的替代說明
  final String? tutorialVideoAsset; // 教學示範影片路徑（例如 'assets/demo_tutorial.mp4'）
  final String? tutorialVideoTitle; // 教學示範影片標題
  final VoidCallback? onEnter; // 進入此步驟時執行
  final VoidCallback? onLeaveBackward; // 點選上一步離開此步驟時執行
  /// 個人化推薦理由（有值時顯示「✨ 為你推薦」橫幅）
  final String? recommendReason;
  /// 自訂展示區塊（例如語音轉心智圖即時演示畫布）
  final WidgetBuilder? customPreviewBuilder;

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
    this.tutorialVideoAsset,
    this.tutorialVideoTitle,
    this.onEnter,
    this.onLeaveBackward,
    this.recommendReason,
    this.customPreviewBuilder,
  });
}

// ─────────────────────────────────────────────
// Spotlight 遮罩畫筆
// ─────────────────────────────────────────────

class SpotlightPainter extends CustomPainter {
  final Rect? highlightRect;
  final double borderRadius;
  final double pulseValue;

  SpotlightPainter(
      {this.highlightRect, this.borderRadius = 12.0, this.pulseValue = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = const Color(0x77000000);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (highlightRect == null) {
      canvas.drawRect(fullRect, Paint()..color = const Color(0x33000000));
      return;
    }

    // 計算安全邊距，避免貼邊元素在螢幕邊界被切平或溢出鄰近文字
    const double padding = 5.0;
    final double left =
        (highlightRect!.left - padding).clamp(4.0, size.width - 20.0);
    final double top =
        (highlightRect!.top - padding).clamp(4.0, size.height - 20.0);
    final double right =
        (highlightRect!.right + padding).clamp(20.0, size.width - 4.0);
    final double bottom =
        (highlightRect!.bottom + padding).clamp(20.0, size.height - 4.0);

    final safeRect = Rect.fromLTRB(left, top, right, bottom);

    final path = Path()
      ..addRect(fullRect)
      ..addRRect(
          RRect.fromRectAndRadius(safeRect, Radius.circular(borderRadius)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, overlayPaint);

    // 繪製動態脈衝光圈 (Pulsing ring) 提示使用者點擊
    if (pulseValue > 0) {
      final borderPaint = Paint()
        ..color = Colors.amberAccent.withValues(alpha: 1.0 - pulseValue)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 + (pulseValue * 3.0);

      final pulseRect = Rect.fromLTRB(
        (left - pulseValue * 6).clamp(2.0, size.width - 2.0),
        (top - pulseValue * 6).clamp(2.0, size.height - 2.0),
        (right + pulseValue * 6).clamp(2.0, size.width - 2.0),
        (bottom + pulseValue * 6).clamp(2.0, size.height - 2.0),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            pulseRect, Radius.circular(borderRadius + pulseValue * 3)),
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
// TourOverlayScope — 內部傳遞全螢幕心智圖事件
// ─────────────────────────────────────────────

class TourOverlayScope extends InheritedWidget {
  final void Function(MindMapNode root, String title) openFullscreenMindMap;

  const TourOverlayScope({
    super.key,
    required this.openFullscreenMindMap,
    required super.child,
  });

  static TourOverlayScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TourOverlayScope>();

  @override
  bool updateShouldNotify(TourOverlayScope oldWidget) => false;
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
  final bool showSkipConfirmation;

  const TourOverlay({
    super.key,
    required this.steps,
    required this.isGuest,
    required this.onSkip,
    required this.onComplete,
    required this.onNavigatePage,
    this.showSkipConfirmation = true,
  });

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay>
    with TickerProviderStateMixin {
  int _stepIndex = 0;
  String? _activeVideoAsset;
  String? _activeVideoTitle;
  String? _activeVideoBadge;
  bool _isConfirmingSkip = false;
  MindMapNode? _activeFullscreenMindMapRoot;
  String? _activeFullscreenMindMapTitle;
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
        while (prev >= 0 && widget.isGuest && widget.steps[prev].skipForGuest) {
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

  void _confirmAndSkip() {
    if (widget.showSkipConfirmation) {
      setState(() {
        _isConfirmingSkip = true;
      });
    } else {
      widget.onSkip();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_stepIndex >= widget.steps.length) return const SizedBox.shrink();

    final step = _currentStep;
    final effectiveIdx = _effectiveIndex;

    // 計算可見步驟（訪客非跳過的）
    final visibleSteps =
        widget.steps.where((s) => !(widget.isGuest && s.skipForGuest)).toList();
    final visibleStepNumber = visibleSteps.indexWhere(
          (s) =>
              s.featureIndex == step.featureIndex &&
              s.stepInFeature == step.stepInFeature,
        ) +
        1;

    final targetRect = _getTargetRect(step.targetKey);
    final screenSize = MediaQuery.of(context).size;
    final primaryColor = Theme.of(context).primaryColor;
    final displayDesc = (widget.isGuest && step.guestNote != null)
        ? step.guestNote!
        : step.description;


    final isLastVisible = effectiveIdx >= widget.steps.length - 1 ||
        _allRemainingSkipped(effectiveIdx + 1);
    final isVideoOpen = _activeVideoAsset != null;
    final isMindMapFullscreen = _activeFullscreenMindMapRoot != null;
    final isDimmedOrModal =
        isVideoOpen || _isConfirmingSkip || isMindMapFullscreen;

    return Material(
      type: MaterialType.transparency,
      child: TourOverlayScope(
        openFullscreenMindMap: (root, title) {
          setState(() {
            _activeFullscreenMindMapRoot = root;
            _activeFullscreenMindMapTitle = title;
          });
        },
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Stack(
            children: [
            // ── 遮罩 + 聚光燈（開啟影片、略過確認或全螢幕時聚光燈關閉） ──
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque, // opaque：吸收所有點擊，防止穿透到底層 Widget
                onPointerDown: (event) {
                  if (isDimmedOrModal) return;
                  final liveRect = _getTargetRect(step.targetKey);
                  if (liveRect != null && liveRect.contains(event.position)) {
                    _goNext();
                  }
                },
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (context, child) {
                      final liveRect =
                          isDimmedOrModal ? null : _getTargetRect(step.targetKey);
                      return CustomPaint(
                        painter: SpotlightPainter(
                          highlightRect:
                              isDimmedOrModal ? null : (liveRect ?? targetRect),
                          pulseValue: isDimmedOrModal ? 0.0 : _pulseCtrl.value,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // ── 步驟提示卡（動態避讓聚光燈目標，操作按鈕固定在底部永不遮擋） ──
            if (!isDimmedOrModal)
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, child) {
                final liveRect = _getTargetRect(step.targetKey);
                final curScreenSize = MediaQuery.of(context).size;
                final safePadding = MediaQuery.of(context).padding;
                final safeTop = safePadding.top;
                final safeBottom = safePadding.bottom;

                double? dynamicCardTop, dynamicCardBottom;
                double dynamicMaxHeight;

                if (liveRect != null) {
                  final spaceAbove = (liveRect.top - safeTop - 16.0).clamp(0.0, curScreenSize.height);
                  final spaceBelow = (curScreenSize.height - liveRect.bottom - safeBottom - 16.0).clamp(0.0, curScreenSize.height);

                  if (spaceAbove < 150 && spaceBelow < 150) {
                    // 目標佔據中間大面積，將卡片置於底部安全區上方
                    dynamicCardBottom = safeBottom + 16.0;
                    dynamicMaxHeight = (curScreenSize.height - safeTop - safeBottom - 32.0).clamp(180.0, 500.0);
                  } else if (spaceAbove >= spaceBelow) {
                    // 上方空間較大，卡片置於目標上方
                    dynamicCardBottom = (curScreenSize.height - liveRect.top + 12.0)
                        .clamp(safeBottom + 12.0, curScreenSize.height - safeTop - 120.0);
                    final availableAbove = curScreenSize.height - safeTop - dynamicCardBottom - 12.0;
                    dynamicMaxHeight = availableAbove.clamp(140.0, curScreenSize.height * 0.72);
                  } else {
                    // 下方空間較大，卡片置於目標下方
                    dynamicCardTop = (liveRect.bottom + 12.0)
                        .clamp(safeTop + 12.0, curScreenSize.height - safeBottom - 120.0);
                    final availableBelow = curScreenSize.height - safeBottom - dynamicCardTop - 12.0;
                    dynamicMaxHeight = availableBelow.clamp(140.0, curScreenSize.height * 0.72);
                  }
                } else {
                  // 無聚光燈目標時（如全覽步驟、社群介紹或心智圖演示）置於底部
                  dynamicCardBottom = safeBottom + 20.0;
                  final availableH = curScreenSize.height - safeTop - safeBottom - 40.0;
                  dynamicMaxHeight = availableH.clamp(200.0, step.customPreviewBuilder != null ? 580.0 : 500.0);
                }

                return Positioned(
                  left: 16,
                  right: 16,
                  top: dynamicCardTop,
                  bottom: dynamicCardBottom,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: dynamicMaxHeight,
                    ),
                    child: child!,
                  ),
                );
              },
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 28,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 頂部固定 Header：功能標籤 + 總進度 ──
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
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            tr('tour_step_n', [visibleStepNumber.toString(), visibleSteps.length.toString()]),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 該功能的步驟進度條
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
                      const SizedBox(height: 10),

                      // ── 可滾動主體內容區（內容過長時在此滾動，永不遮擋按鈕） ──
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 個人化推薦橫幅
                              if (step.recommendReason != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        primaryColor.withValues(alpha: 0.12),
                                        primaryColor.withValues(alpha: 0.05),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: primaryColor.withValues(alpha: 0.25),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('✨',
                                          style: TextStyle(fontSize: 13)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          step.recommendReason!,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: primaryColor,
                                            fontWeight: FontWeight.w600,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

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

                              // 若該步驟有自訂展示區塊（如：語音轉心智圖即時演示）
                              if (step.customPreviewBuilder != null) ...[
                                const SizedBox(height: 12),
                                step.customPreviewBuilder!(context),
                              ],

                              // 若該步驟有教學影片按鈕
                              if (step.tutorialVideoAsset != null) ...[
                                const SizedBox(height: 12),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _activeVideoAsset = step.tutorialVideoAsset;
                                        _activeVideoTitle =
                                            step.tutorialVideoTitle ?? tr('tour_demo');
                                        _activeVideoBadge =
                                            step.featureIndex == 2 ? tr('tour_quiz_tutorial') : tr('tour_tutorial');
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 9),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.amber.shade50,
                                            Colors.orange.shade50,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.amber.shade400, width: 1.2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.amber.shade100
                                                .withValues(alpha: 0.6),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.play_circle_fill_rounded,
                                              color: Colors.amber.shade800, size: 22),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              step.tutorialVideoTitle ??
                                                  tr('tour_watch_quiz_video'),
                                              style: TextStyle(
                                                color: Colors.amber.shade900,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Icon(Icons.arrow_forward_ios_rounded,
                                              size: 12, color: Colors.amber.shade800),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 10),

                      // ── 永遠釘在底部、絕不被遮擋的按鈕列 (Pinned Actions Bar) ──
                      Row(
                        children: [
                          if (!isLastVisible) ...[
                            TextButton(
                              onPressed: _confirmAndSkip,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey.shade500,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                minimumSize: const Size(0, 36),
                              ),
                              child: Text(tr('ws_skip'), style: TextStyle(fontSize: 13)),
                            ),
                          ],
                          const Spacer(),
                          if (effectiveIdx > 0) ...[
                            OutlinedButton(
                              onPressed: _goBack,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryColor,
                                side: BorderSide(color: primaryColor, width: 1.2),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 9),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                minimumSize: const Size(0, 38),
                              ),
                              child: Text(tr('tour_prev'),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ),
                            const SizedBox(width: 8),
                          ],
                          ElevatedButton(
                            onPressed: _goNext,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 9),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                              minimumSize: const Size(0, 38),
                            ),
                            child: Text(
                              isLastVisible ? tr('tour_got_it') : tr('tour_next'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── 教學影片播放視窗（最上層、無遮擋、關閉聚光燈、純白典雅底色） ──
          if (isVideoOpen)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.85),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
                alignment: Alignment.center,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: screenSize.height * 0.84,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white, // 純白底色
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFE8DDD5),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 30,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 頂部標題列
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
                        child: Row(
                          children: [
                            const Icon(Icons.play_circle_fill_rounded,
                                color: Color(0xFF8D6E63), size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _activeVideoTitle ?? tr('tour_demo_full'),
                                style: const TextStyle(
                                  color: Color(0xFF3E2723),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: Color(0xFF757575)),
                              onPressed: () {
                                setState(() {
                                  _activeVideoAsset = null;
                                  _activeVideoTitle = null;
                                  _activeVideoBadge = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFEFEBE9)),

                      // 影片播放主體
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: TutorialVideoPlayer(
                            assetPath: _activeVideoAsset!,
                            autoPlay: true,
                            looping: true,
                            isActive: true,
                            badgeLabel: _activeVideoBadge ?? tr('tour_demo'),
                            initialMuted: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
                    // ── 略過引導確認彈窗（最上層、無遮擋、置於最前方） ──
          if (_isConfirmingSkip)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() => _isConfirmingSkip = false);
                },
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GestureDetector(
                    onTap: () {}, // 攔截點擊，避免點擊彈窗內部關閉
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      elevation: 12,
                      shadowColor: Colors.black.withValues(alpha: 0.25),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.help_outline_rounded,
                                  color: primaryColor,
                                  size: 28,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              tr('tour_skip_q'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                                letterSpacing: -0.2,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: Color(0xFFE65100),
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      tr('tour_skip_msg'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF475569),
                                        height: 1.5,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setState(() => _isConfirmingSkip = false);
                                      widget.onSkip();
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF64748B),
                                      side: const BorderSide(
                                          color: Color(0xFFCBD5E1)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 13),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: Text(
                                      tr('tour_confirm_skip'),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() => _isConfirmingSkip = false);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 13),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: Text(
                                      tr('tour_continue'),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // ── 心智圖全螢幕檢視視窗（Overlay最頂層、無遮擋、純淨全螢幕） ──
          if (isMindMapFullscreen)
            Positioned.fill(
              child: FullscreenMindMapView(
                root: _activeFullscreenMindMapRoot!,
                title: _activeFullscreenMindMapTitle ?? tr('tour_mm_title'),
                onClose: () {
                  setState(() {
                    _activeFullscreenMindMapRoot = null;
                    _activeFullscreenMindMapTitle = null;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

// ─────────────────────────────────────────────
// 語音轉心智圖互動導覽演示卡片組件
// ─────────────────────────────────────────────
class VoiceToMindMapTourDemo extends StatefulWidget {
  const VoiceToMindMapTourDemo({super.key});

  @override
  State<VoiceToMindMapTourDemo> createState() => _VoiceToMindMapTourDemoState();
}

class _VoiceToMindMapTourDemoState extends State<VoiceToMindMapTourDemo> {
  int _activeTab = 1; // 0: 語音速記, 1: 結構化心智圖 (預設展示震撼的心智圖畫布)
  late MindMapNode _demoRoot;

  @override
  void initState() {
    super.initState();
    _demoRoot = MindMapNode(
      id: 'demo_root',
      label: tr('tour_mm_root'),
      color: const Color(0xFF2E7D32),
      children: [
        MindMapNode(
          id: 'demo_c1',
          label: tr('tour_mm_c1'),
          color: const Color(0xFF1565C0),
          children: [
            MindMapNode(
              id: 'demo_c1_1',
              label: tr('tour_mm_c1_1'),
              color: const Color(0xFF0288D1),
            ),
            MindMapNode(
              id: 'demo_c1_2',
              label: tr('tour_mm_c1_2'),
              color: const Color(0xFF0097A7),
            ),
          ],
        ),
        MindMapNode(
          id: 'demo_c2',
          label: tr('tour_mm_c2'),
          color: const Color(0xFF6A1B9A),
          children: [
            MindMapNode(
              id: 'demo_c2_1',
              label: tr('tour_mm_c2_1'),
              color: const Color(0xFF8E24AA),
            ),
            MindMapNode(
              id: 'demo_c2_2',
              label: tr('tour_mm_c2_2'),
              color: const Color(0xFFAB47BC),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6DCCD), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 頂部切換頁籤：🎙️ 語音速記 ➔ 🧠 結構化心智圖
          Container(
            color: const Color(0xFFF0EAE1),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                _buildTabButton(
                  index: 0,
                  icon: Icons.mic_rounded,
                  label: tr('tour_voice'),
                  activeColor: const Color(0xFFD84315),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded,
                    size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                _buildTabButton(
                  index: 1,
                  icon: Icons.account_tree_rounded,
                  label: tr('tour_mindmap'),
                  activeColor: const Color(0xFF4A148C),
                ),
                const Spacer(),
                if (_activeTab == 1)
                  InkWell(
                    onTap: () {
                      final scope = TourOverlayScope.of(context);
                      if (scope != null) {
                        scope.openFullscreenMindMap(
                          _demoRoot,
                          tr('tour_mm_title'),
                        );
                      } else {
                        FullscreenMindMapView.open(
                          context,
                          root: _demoRoot,
                          title: tr('tour_mm_title'),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A148C).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fullscreen_rounded,
                              size: 14, color: Color(0xFF4A148C)),
                          SizedBox(width: 2),
                          Text(tr('tour_fullscreen'),
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4A148C))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 主體展示區
          if (_activeTab == 0)
            _buildVoiceTranscriptView()
          else
            _buildMindMapView(),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String label,
    required Color activeColor,
  }) {
    final bool isActive = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: isActive ? activeColor : Colors.grey.shade700),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? activeColor : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceTranscriptView() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tr('tour_recording'),
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tr('tour_speaker'),
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black12),
            ),
            child: Text(
              tr('tour_transcript'),
              style: TextStyle(
                  fontSize: 12, height: 1.5, color: Color(0xFF3E2723)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildTag(tr('tour_tag_bio')),
              const SizedBox(width: 4),
              _buildTag(tr('tour_tag_photo')),
              const SizedBox(width: 4),
              _buildTag(tr('tour_tag_calvin')),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _activeTab = 1),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A148C).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Text(tr('tour_gen_mindmap'),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A148C))),
                      Icon(Icons.chevron_right_rounded,
                          size: 14, color: Color(0xFF4A148C)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 9.5, color: Colors.grey.shade700)),
    );
  }

  Widget _buildMindMapView() {
    return Column(
      children: [
        SizedBox(
          height: 175,
          child: Stack(
            children: [
              InteractiveMindMapView(
                root: _demoRoot,
                showRotateButton: false,
              ),
              Positioned(
                bottom: 6,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pinch_rounded,
                          size: 11, color: Colors.white),
                      SizedBox(width: 3),
                      Text(tr('tour_pinch'),
                          style: TextStyle(
                              fontSize: 9.5, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

