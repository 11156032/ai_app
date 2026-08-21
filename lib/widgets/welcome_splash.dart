import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'tutorial_video_player.dart';

// ─────────────────────────────────────────────────────────────────
// WelcomeSplash — 新用戶首次登入全頁歡迎引導（3 slides）
// ─────────────────────────────────────────────────────────────────

class WelcomeSplash extends StatefulWidget {
  /// 點擊「開始探索」後呼叫（接著啟動 Tour）
  final VoidCallback onDone;

  /// 點擊「略過」後呼叫（跳過所有引導）
  final VoidCallback onSkip;

  /// 使用者暱稱，用於個人化歡迎語
  final String? userName;

  const WelcomeSplash({
    super.key,
    required this.onDone,
    required this.onSkip,
    this.userName,
  });

  @override
  State<WelcomeSplash> createState() => _WelcomeSplashState();
}

class _WelcomeSplashState extends State<WelcomeSplash>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  late AnimationController _bgAnim;
  late AnimationController _entryAnim;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;
  late Animation<double> _bgRotate;

  static const _themeColor = Color(0xFF8D6E63);

  final List<_SlideDef> _slides = [
    _SlideDef(
      emoji: '🎉',
      gradient: [Color(0xFF8D6E63), Color(0xFFBCAAA4)],
      title: '歡迎加入！',
      subtitle: '你的智慧學習夥伴',
      body: '這裡集合了 AI 助手、學習題庫、行程規劃與同學社群，讓你的學習更有效率、更有趣。',
      features: [],
    ),
    _SlideDef(
      emoji: '📱',
      gradient: [Color(0xFF5D4037), Color(0xFF8D6E63)],
      title: '底部導覽列操作導覽',
      subtitle: '快速開啟與切換主要功能頁面',
      body: '',
      videoAssetPath: 'assets/nav_bar_tutorial.mp4',
      badgeLabel: '導覽列教學',
      features: [],
    ),
    _SlideDef(
      emoji: '📝',
      gradient: [Color(0xFF4E342E), Color(0xFF795548)],
      title: '題庫測驗與複習導覽',
      subtitle: '題目作答、交卷與錯題診斷操作',
      body: '',
      videoAssetPath: 'assets/demo_tutorial.mp4',
      badgeLabel: '題庫測驗教學',
      features: [],
    ),
    _SlideDef(
      emoji: '📦',
      gradient: [Color(0xFF3E2723), Color(0xFF5D4037)],
      title: '學習 Pack 製作與分享導覽',
      subtitle: '彙整筆記與考卷一鍵發布',
      body: '',
      videoAssetPath: 'assets/learning_pack_tutorial.mp4',
      badgeLabel: '學習 Pack 教學',
      features: [],
    ),
    _SlideDef(
      emoji: '🤖',
      gradient: [Color(0xFF2E1C18), Color(0xFF4E342E)],
      title: 'AI 助手上線了！',
      subtitle: '讓 AI 幫你更聰明地學習',
      body: '',
      features: [
        _FeatureLine('💬', 'AI 排程', '輸入一句話，自動幫你加入行程'),
        _FeatureLine('💡', 'AI 伴學解答', '即時解答學習疑難與解題思路'),
        _FeatureLine('📊', 'AI 診斷', '測驗後自動分析弱點，給出建議'),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();

    _bgAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _bgRotate = Tween<double>(begin: 0, end: 2 * math.pi).animate(_bgAnim);

    _entryAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _entryAnim, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryAnim, curve: Curves.easeOutCubic));

    _entryAnim.forward();
  }

  @override
  void dispose() {
    _bgAnim.dispose();
    _entryAnim.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    } else {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final slide = _slides[_currentPage];
    final gradStart = slide.gradient[0];
    final gradEnd = slide.gradient[1];

    return Material(
      color: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeIn,
        child: SlideTransition(
          position: _slideIn,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [gradStart, gradEnd],
              ),
            ),
            child: Stack(
              children: [
                // ── 背景裝飾圓圈（旋轉動態）──
                _buildBgDecor(size),

                // ── 主要內容 ──
                SafeArea(
                  child: Column(
                    children: [
                      // 頂部列：略過按鈕
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: widget.onSkip,
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    Colors.white.withValues(alpha: 0.7),
                              ),
                              child: const Text('略過',
                                  style: TextStyle(fontSize: 14)),
                            ),
                          ],
                        ),
                      ),

                      // Slides
                      Expanded(
                        child: PageView.builder(
                          controller: _pageCtrl,
                          itemCount: _slides.length,
                          onPageChanged: (i) {
                            setState(() => _currentPage = i);
                          },
                          itemBuilder: (ctx, i) =>
                              _buildSlide(_slides[i], i),
                        ),
                      ),

                      // 底部：dots + 按鈕
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
                        child: Column(
                          children: [
                            // 頁碼點
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_slides.length, (i) {
                                final active = i == _currentPage;
                                return AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  width: active ? 24 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? Colors.white
                                        : Colors.white
                                            .withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 28),

                            // 行動按鈕
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _nextPage,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: _themeColor,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  _currentPage < _slides.length - 1
                                      ? '繼續  →'
                                      : '開始探索  🚀',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlide(_SlideDef slide, int index) {
    if (slide.videoAssetPath != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final maxPhoneHeight = constraints.maxHeight - 20;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 標題與副標題
                Text(
                  slide.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  slide.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),

                // 手機外框介面直接播放元件（最大化顯示）
                Expanded(
                  child: Center(
                    child: TutorialVideoPlayer(
                      assetPath: slide.videoAssetPath!,
                      isActive: _currentPage == index,
                      maxHeight: maxPhoneHeight,
                      badgeLabel: slide.badgeLabel ?? '操作示範',
                      initialMuted: false, // 預設開啟聲音
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 大 Emoji 圖示
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                slide.emoji,
                style: const TextStyle(fontSize: 52),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // 標題
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          // 副標題
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 28),

          // 說明文字 或 功能列表
          if (slide.body.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                slide.body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  height: 1.7,
                ),
              ),
            )
          else if (slide.features.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: slide.features.map((f) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.emoji,
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                f.desc,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBgDecor(Size size) {
    return AnimatedBuilder(
      animation: _bgRotate,
      builder: (_, __) {
        return CustomPaint(
          size: size,
          painter: _BgCirclePainter(angle: _bgRotate.value),
        );
      },
    );
  }
}

// ── 背景裝飾用的幾何圓圈畫筆 ──
class _BgCirclePainter extends CustomPainter {
  final double angle;
  _BgCirclePainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final cx = size.width * 0.5 + math.cos(angle) * 20;
    final cy = size.height * 0.15 + math.sin(angle) * 10;

    for (final r in [60.0, 120.0, 200.0, 290.0]) {
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }

    // 右下角第二組填色圓
    final paint2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width + 30, size.height * 0.8),
      160,
      paint2,
    );
  }

  @override
  bool shouldRepaint(_BgCirclePainter old) => old.angle != angle;
}

// ── 資料模型 ──
class _SlideDef {
  final String emoji;
  final List<Color> gradient;
  final String title;
  final String subtitle;
  final String body;
  final String? videoAssetPath;
  final String? badgeLabel;
  final List<_FeatureLine> features;

  const _SlideDef({
    required this.emoji,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.body,
    this.videoAssetPath,
    this.badgeLabel,
    required this.features,
  });
}

class _FeatureLine {
  final String emoji;
  final String title;
  final String desc;
  const _FeatureLine(this.emoji, this.title, this.desc);
}
