// ignore_for_file: prefer_final_fields
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/mascot_tip_service.dart';
import 'common_widgets.dart';
import '../services/app_locale_service.dart';

/// 伴學精靈吉祥物元件（預設極簡跑馬燈膠囊型態）
///
/// 功能規格：
/// - 精靈本體：官方葉子 Logo，平時隨風微擺（Sway）+ 上下呼吸微浮動（Float）
/// - 點擊精靈或膠囊：觸發彈跳（Bounce）+ 觸覺震動反饋 + 即時切換下一句成長小語
/// - 跑馬燈膠囊（Marquee Capsule）：
///   - 左側：淡薄荷綠膠囊徽章 [ 葉棒小語 ]
///   - 中右側：單行跑馬燈文字平滑捲動，左右邊緣柔和漸隱（ShaderMask）
///   - 右側小尾巴（Tail）優雅指向精靈本體
class MascotCompanion extends StatefulWidget {
  final String lang;
  final bool isDarkMode;
  final Color primaryColor;

  const MascotCompanion({
    super.key,
    this.lang = 'zh_TW',
    this.isDarkMode = false,
    required this.primaryColor,
  });

  @override
  State<MascotCompanion> createState() => _MascotCompanionState();
}

class _MascotCompanionState extends State<MascotCompanion>
    with TickerProviderStateMixin {
  // ── Sway 動畫（持續隨風左右微擺動）
  late AnimationController _swayCtrl;
  late Animation<double> _swayAnim;

  // ── Float 動畫（持續上下呼吸微浮動）
  late AnimationController _floatCtrl;
  late Animation<double> _floatAnim;

  // ── Bounce 動畫（點擊時彈跳一次）
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  // ── 膠囊滑入/淡入動畫
  late AnimationController _bubbleCtrl;
  late Animation<double> _bubbleFade;
  late Animation<Offset> _bubbleSlide;

  // ── 小語狀態
  String _currentTip = '';

  @override
  void initState() {
    super.initState();

    // 取得冷啟動小語
    _currentTip = MascotTipService.getTip(widget.lang);

    // ── Sway：持續左右擺動，振幅 ±3.5°
    _swayCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _swayAnim = Tween<double>(begin: -0.06, end: 0.06).animate(
      CurvedAnimation(parent: _swayCtrl, curve: Curves.easeInOut),
    );

    // ── Float：持續上下呼吸微浮動，幅度 -3.0dp
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: 0.0, end: -3.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    // ── Bounce：點擊時縮小再放大彈跳
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.78)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.78, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 25,
      ),
    ]).animate(_bounceCtrl);

    // ── 膠囊滑入：延遲 500ms 後從右側優雅滑入
    _bubbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _bubbleFade = CurvedAnimation(parent: _bubbleCtrl, curve: Curves.easeOut);
    _bubbleSlide = Tween<Offset>(
      begin: const Offset(0.25, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _bubbleCtrl, curve: Curves.easeOut));

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _bubbleCtrl.forward();
    });
  }

  @override
  void dispose() {
    _swayCtrl.dispose();
    _floatCtrl.dispose();
    _bounceCtrl.dispose();
    _bubbleCtrl.dispose();
    super.dispose();
  }

  // ── 點擊精靈或膠囊：彈跳 + 刷新小語
  void _onMascotTap() {
    HapticFeedback.selectionClick();
    _bounceCtrl.forward(from: 0);
    setState(() {
      _currentTip = MascotTipService.refreshTip(widget.lang);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── 跑馬燈膠囊（靠右，精靈左邊）
          Flexible(
            child: FadeTransition(
              opacity: _bubbleFade,
              child: SlideTransition(
                position: _bubbleSlide,
                child: _buildMarqueeCapsuleWithTail(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // ── 精靈本體
          _buildMascot(),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────
  // 跑馬燈膠囊本體（含右側小尾巴）
  // ────────────────────────────────────────────────
  Widget _buildMarqueeCapsuleWithTail() {
    final isDark = widget.isDarkMode;
    final bgColor =
        isDark ? const Color(0xF0222228) : const Color(0xF5FFFFFF);
    final borderColor = isDark
        ? const Color(0xFF3E4C42)
        : const Color(0xFF81C784).withValues(alpha: 0.35);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.centerRight,
      children: [
        // 膠囊主體
        _buildMarqueeCapsule(isDark, bgColor, borderColor),
        // 右側指向精靈的微型小尾巴
        Positioned(
          right: -5.5,
          child: CustomPaint(
            size: const Size(6, 10),
            painter: SpeechBubbleTailPainter(
              color: bgColor,
              borderColor: borderColor,
            ),
          ),
        ),
      ],
    );
  }

  // 膠囊內部結構：[葉棒小語 標籤] + [跑馬燈文字]
  Widget _buildMarqueeCapsule(
      bool isDark, Color bgColor, Color borderColor) {
    final textColor =
        isDark ? const Color(0xFFEEEEEE) : const Color(0xFF2C342E);

    final badgeBgColor =
        isDark ? const Color(0xFF1E3A2B) : const Color(0xFFE8F5E9);
    final badgeBorderColor = isDark
        ? const Color(0xFF2E7D32).withValues(alpha: 0.45)
        : const Color(0xFFA5D6A7).withValues(alpha: 0.6);
    final badgeTextColor =
        isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);

    return GestureDetector(
      onTap: _onMascotTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 34,
        constraints: const BoxConstraints(maxWidth: 260, minWidth: 140),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: borderColor, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 左側綠色小徽章 [ 葉棒小語 ]
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: badgeBgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: badgeBorderColor, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 4.5,
                    height: 4.5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: badgeTextColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tr('mascot_tip_title'),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: badgeTextColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // 中右側跑馬燈文字
            Expanded(
              child: _MascotMarqueeText(
                key: ValueKey(_currentTip),
                text: _currentTip,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                  letterSpacing: 0.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────
  // 精靈本體：淡薄荷綠漸層 + 1px 邊框 + Soft Glow + 上下呼吸浮動
  // ────────────────────────────────────────────────
  Widget _buildMascot() {
    final isDark = widget.isDarkMode;

    final gradientColors = isDark
        ? const [Color(0xFF1D3B2E), Color(0xFF142920)]
        : const [Color(0xFFE8F8F0), Color(0xFFF1FCF6)];

    final borderColor = isDark
        ? const Color(0xFF2E6647).withValues(alpha: 0.6)
        : const Color(0xFF81C784).withValues(alpha: 0.45);

    final glowColor = isDark
        ? const Color(0xFF4CAF50).withValues(alpha: 0.22)
        : const Color(0xFF81C784).withValues(alpha: 0.28);

    return GestureDetector(
      onTap: _onMascotTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([_swayAnim, _floatAnim, _bounceAnim]),
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatAnim.value),
            child: Transform.rotate(
              angle: _swayAnim.value,
              alignment: Alignment.bottomCenter,
              child: Transform.scale(
                scale: _bounceAnim.value,
                child: child,
              ),
            ),
          );
        },
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            border: Border.all(
              color: borderColor,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor,
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: CustomPaint(
              size: const Size(24, 24),
              painter: const LeafYLogoPainter(
                progress: 1.0,
                leftLeafScale: 1.0,
                rightLeafScale: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ────────────────────────────────────────────────
/// 平滑無縫跑馬燈文字元件 (Marquee Text)
/// ────────────────────────────────────────────────
class _MascotMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MascotMarqueeText({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  State<_MascotMarqueeText> createState() => _MascotMarqueeTextState();
}

class _MascotMarqueeTextState extends State<_MascotMarqueeText> {
  late ScrollController _scrollController;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMarqueeLoop());
  }

  @override
  void didUpdateWidget(covariant _MascotMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _startMarqueeLoop());
    }
  }

  Future<void> _startMarqueeLoop() async {
    if (_isDisposed || !mounted || !_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return; // 單行字數已可完整呈現，無需捲動

    while (!_isDisposed && mounted && _scrollController.hasClients) {
      // 1. 起始停留 1.6 秒
      await Future.delayed(const Duration(milliseconds: 1600));
      if (_isDisposed || !mounted || !_scrollController.hasClients) break;

      final currentMax = _scrollController.position.maxScrollExtent;
      if (currentMax <= 0) break;

      // 2. 均速跑馬燈滑向末端（每 32px 耗時約 1 秒，保持舒適閱讀速度）
      final durationMs = (currentMax * 32).clamp(2200, 12000).toInt();
      await _scrollController.animateTo(
        currentMax,
        duration: Duration(milliseconds: durationMs),
        curve: Curves.linear,
      );

      // 3. 末端停留 1.5 秒
      await Future.delayed(const Duration(milliseconds: 1500));
      if (_isDisposed || !mounted || !_scrollController.hasClients) break;

      // 4. 重置回起點，循環播放
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) {
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0.0, 0.04, 0.94, 1.0],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}

/// 對話框小尾巴繪製器（指向右側吉祥物）
class SpeechBubbleTailPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  SpeechBubbleTailPainter({
    required this.color,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(0, 0);
    path.quadraticBezierTo(
      size.width * 0.65,
      size.height * 0.25,
      size.width,
      size.height * 0.5,
    );
    path.quadraticBezierTo(
      size.width * 0.65,
      size.height * 0.75,
      0,
      size.height,
    );
    path.close();

    canvas.drawPath(path, fillPaint);

    final strokePath = Path();
    strokePath.moveTo(0, 0);
    strokePath.quadraticBezierTo(
      size.width * 0.65,
      size.height * 0.25,
      size.width,
      size.height * 0.5,
    );
    strokePath.quadraticBezierTo(
      size.width * 0.65,
      size.height * 0.75,
      0,
      size.height,
    );
    canvas.drawPath(strokePath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant SpeechBubbleTailPainter oldDelegate) =>
      color != oldDelegate.color || borderColor != oldDelegate.borderColor;
}
