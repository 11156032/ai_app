// ignore_for_file: prefer_final_fields
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/mascot_tip_service.dart';
import 'common_widgets.dart';

/// 伴學精靈吉祥物元件
///
/// 功能規格：
/// - 以官方葉子 Logo 作為精靈本體，平時輕微隨風擺動（Sway）+ 呼吸上下微浮動（Float）
/// - 圓形外框：淡薄荷綠柔和漸層 + 1px 淺色邊框 + 輕微環境光暈（Soft Glow）
/// - 點擊精靈本體：彈跳（Bounce）動畫 + 刷新成長小語（若收合則自動展開）
/// - 成長小語氣泡：
///   - 右側指向精靈的對話框小尾巴（Bubble Tail）
///   - 左上角淡綠色小膠囊標籤（Badge: 葉棒小語，主題深綠字體）
///   - 右上角微型關閉/收合圖示
///   - 內文適度行距與左右 14dp 內距
/// - 顯示範圍：由外層決定（首頁儀表板 + 日曆頁；作答與筆記等隱藏）
/// - 每次冷啟動自動換一句（由 MascotTipService 種子控制）
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

  // ── 氣泡滑入/滑出動畫
  late AnimationController _bubbleCtrl;
  late Animation<double> _bubbleFade;
  late Animation<Offset> _bubbleSlide;

  // ── 小語狀態
  String _currentTip = '';
  bool _isBubbleCollapsed = false;

  @override
  void initState() {
    super.initState();

    // 取得冷啟動小語
    _currentTip = MascotTipService.getTip(widget.lang);

    // ── Sway：持續左右擺動，振幅 ±4°
    _swayCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _swayAnim = Tween<double>(begin: -0.06, end: 0.06).animate(
      CurvedAnimation(parent: _swayCtrl, curve: Curves.easeInOut),
    );

    // ── Float：持續上下呼吸微浮動，幅度 -3.5dp
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: 0.0, end: -3.5).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    // ── Bounce：點擊時縮小再放大彈跳
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.75)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.75, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 25,
      ),
    ]).animate(_bounceCtrl);

    // ── 氣泡滑入：延遲 600ms 後從右側滑入
    _bubbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _bubbleFade = CurvedAnimation(parent: _bubbleCtrl, curve: Curves.easeOut);
    _bubbleSlide = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _bubbleCtrl, curve: Curves.easeOut));

    // 冷啟動 600ms 後氣泡優雅滑入
    Future.delayed(const Duration(milliseconds: 600), () {
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

  // ── 點擊精靈：彈跳 + 換小語 + 自動展開氣泡
  void _onMascotTap() {
    HapticFeedback.mediumImpact();
    _bounceCtrl.forward(from: 0);
    setState(() {
      _currentTip = MascotTipService.refreshTip(widget.lang);
      _isBubbleCollapsed = false;
    });
  }

  // ── 點擊收合/展開氣泡
  void _toggleBubble() {
    HapticFeedback.selectionClick();
    setState(() => _isBubbleCollapsed = !_isBubbleCollapsed);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── 氣泡（靠右，精靈左邊）
          Flexible(
            child: FadeTransition(
              opacity: _bubbleFade,
              child: SlideTransition(
                position: _bubbleSlide,
                child: _buildBubbleWithTail(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ── 精靈本體（葉子 Logo + Sway + Float + Bounce + 柔和薄荷漸層與光暈）
          _buildMascot(),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────
  // 精靈本體：淡薄荷綠柔和漸層 + 1px 邊框 + Soft Glow + 上下呼吸微浮動
  // ────────────────────────────────────────────────
  Widget _buildMascot() {
    final isDark = widget.isDarkMode;

    // 淡薄荷綠柔和漸層
    final gradientColors = isDark
        ? const [Color(0xFF1D3B2E), Color(0xFF142920)]
        : const [Color(0xFFE8F8F0), Color(0xFFF1FCF6)];

    // 1px 淺色邊框
    final borderColor = isDark
        ? const Color(0xFF2E6647).withValues(alpha: 0.6)
        : const Color(0xFF81C784).withValues(alpha: 0.45);

    // 環境光暈
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
          width: 44,
          height: 44,
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
              // 環境光暈 (Soft Glow)
              BoxShadow(
                color: glowColor,
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
              // 微懸浮底層陰影
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: CustomPaint(
              size: const Size(26, 26),
              painter: const LeafYLogoPainter(
                progress: 1.0,
                leftLeafScale: 1.0,
                rightLeafScale: 1.0,
                shimmerProgress: 0.0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────
  // 成長小語氣泡（含小尾巴 Bubble Tail）
  // ────────────────────────────────────────────────
  Widget _buildBubbleWithTail() {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF3E4C42)
        : const Color(0xFF81C784).withValues(alpha: 0.25);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomRight,
      children: [
        // 氣泡主體
        _buildBubbleBody(isDark, bgColor, borderColor),
        // 右側指向精靈的對話框小尾巴
        Positioned(
          right: -6.5,
          bottom: 14,
          child: CustomPaint(
            size: const Size(7, 12),
            painter: SpeechBubbleTailPainter(
              color: bgColor,
              borderColor: borderColor,
            ),
          ),
        ),
      ],
    );
  }

  // 氣泡卡片內容
  Widget _buildBubbleBody(bool isDark, Color bgColor, Color borderColor) {
    final textColor = isDark
        ? const Color(0xFFEEEEEE)
        : const Color(0xFF2C342E);

    // 淡薄荷綠膠囊標籤配色
    final badgeBgColor = isDark
        ? const Color(0xFF1E3A2B)
        : const Color(0xFFE8F5E9);
    final badgeBorderColor = isDark
        ? const Color(0xFF2E7D32).withValues(alpha: 0.45)
        : const Color(0xFFA5D6A7).withValues(alpha: 0.55);
    final badgeTextColor = isDark
        ? const Color(0xFF81C784)
        : const Color(0xFF2E7D32); // 主題深綠字體

    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.fastOutSlowIn,
      alignment: Alignment.bottomRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240, minWidth: 140),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 260),
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeIn,
          crossFadeState: _isBubbleCollapsed
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          // ── 展開狀態：左上角膠囊標籤 + 右上角微型關閉圖示 + 14dp 內距內文
          firstChild: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 頂部列：左邊淡綠膠囊標籤，右邊微型關閉按鈕
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 淡綠色小膠囊標籤（Badge）
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: badgeBorderColor,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: badgeTextColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '葉棒小語',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: badgeTextColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 右上角微型關閉/收合圖示
                    GestureDetector(
                      onTap: _toggleBubble,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.04),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 11,
                          color: isDark ? Colors.white60 : Colors.black45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 內文小語：左右內距 14dp，適度行距 1.58
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 11),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.12),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    _currentTip,
                    key: ValueKey(_currentTip),
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor,
                      height: 1.58,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // ── 收合狀態：極簡膠囊，點擊展開
          secondChild: GestureDetector(
            onTap: _toggleBubble,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBgColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: badgeBorderColor,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '葉棒小語',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: badgeTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.unfold_more_rounded,
                    size: 12,
                    color: isDark ? Colors.white54 : Colors.black38,
                  ),
                ],
              ),
            ),
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

    // 繪製平滑指向右側的微弧形小三角形
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

    // 僅描繪上下邊緣弧線，保留左側開口以完美融入卡片
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
