import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tutorial_video_player.dart';
import 'common_widgets.dart';

// ─────────────────────────────────────────────────────
// WelcomeSplash — 預設暖棕簡約極簡歡迎引導
// ─────────────────────────────────────────────────────

class WelcomeSplash extends StatefulWidget {
  final void Function(List<String> selectedTopicIds) onDone;
  final VoidCallback onSkip;
  final String? userName;
  final List<String>? initialTopicIds;

  const WelcomeSplash({
    super.key,
    required this.onDone,
    required this.onSkip,
    this.userName,
    this.initialTopicIds,
  });

  @override
  State<WelcomeSplash> createState() => _WelcomeSplashState();
}

class _WelcomeSplashState extends State<WelcomeSplash> with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;
  late AnimationController _entryAnim, _pageEntryAnim;
  late Animation<double> _fadeIn, _pageFade;
  late Animation<Offset> _slideIn, _pageSlide;
  late Set<String> _selectedTopicIds;
  String _selectedInterestId = 'interest_exam';

  static const List<Map<String, dynamic>> _learningInterests = [
    {
      'id': 'interest_exam',
      'emoji': '🎯',
      'title': '升學備考',
      'desc': '衝刺 · 弱點突破',
      'color': Color(0xFFFFB74D), // 暖琥珀
      'topics': ['topic_exam', 'topic_math', 'topic_english'],
    },
    {
      'id': 'interest_concept',
      'emoji': '💡',
      'title': '觀念理解',
      'desc': '深入 · 邏輯架構',
      'color': Color(0xFFFFCC80), // 溫潤金棕
      'topics': ['topic_math', 'topic_science', 'topic_social'],
    },
    {
      'id': 'interest_notes',
      'emoji': '📝',
      'title': '筆記整理',
      'desc': '速記 · 心智圖表',
      'color': Color(0xFFD7CCC8), // 柔和米褐
      'topics': ['topic_literature', 'topic_creative', 'topic_daily'],
    },
    {
      'id': 'interest_tech',
      'emoji': '🚀',
      'title': '科技探索',
      'desc': 'AI · 跨域新知',
      'color': Color(0xFFA1887F), // 雅致暖灰褐
      'topics': ['topic_ai', 'topic_english', 'topic_science'],
    },
  ];

  // 預設經典暖棕漸層
  static const List<List<Color>> _pageGradients = [
    [Color(0xFF3E2723), Color(0xFF4E342E), Color(0xFF3E2723)],
    [Color(0xFF4E342E), Color(0xFF5D4037), Color(0xFF4E342E)],
    [Color(0xFF3E2723), Color(0xFF4E342E), Color(0xFF3E2723)],
    [Color(0xFF2E1C18), Color(0xFF3E2723), Color(0xFF2E1C18)],
  ];

  @override
  void initState() {
    super.initState();
    _selectedTopicIds = Set<String>.from(widget.initialTopicIds ?? ['topic_math', 'topic_ai', 'topic_daily']);
    _entryAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeIn = CurvedAnimation(parent: _entryAnim, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(CurvedAnimation(parent: _entryAnim, curve: Curves.easeOutCubic));
    _entryAnim.forward();
    _pageEntryAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _pageFade = CurvedAnimation(parent: _pageEntryAnim, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(CurvedAnimation(parent: _pageEntryAnim, curve: Curves.easeOutCubic));
    _pageEntryAnim.forward();
  }

  @override
  void dispose() {
    _entryAnim.dispose();
    _pageEntryAnim.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < 3) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    } else {
      widget.onDone(_selectedTopicIds.toList());
    }
  }

  void _onPageChanged(int i) {
    setState(() => _currentPage = i);
    _pageEntryAnim.forward(from: 0);
  }

  void _toggleTopic(String id) {
    setState(() {
      if (_selectedTopicIds.contains(id)) {
        _selectedTopicIds.remove(id);
      } else {
        _selectedTopicIds.add(id);
      }
    });
    HapticFeedback.selectionClick();
  }

  String _getTopicFocusTag(String id) {
    const m = {
      'topic_math': '解題 · 推演',
      'topic_science': '探究 · 實作',
      'topic_literature': '素養 · 閱讀',
      'topic_social': '人文 · 思辨',
      'topic_ai': '智慧 · 程式',
      'topic_english': '聽力 · 備考',
      'topic_exam': '試題 · 衝刺',
      'topic_daily': '打卡 · 心得',
      'topic_creative': '圖解 · 美化',
    };
    return m[id] ?? '資源 · 共學';
  }

  String _getCtaLabel() {
    switch (_currentPage) {
      case 0:
        return '探索 AI 伴學特點';
      case 1:
        return '了解學習 Pack';
      case 2:
        return '定制學習領域';
      default:
        if (_selectedTopicIds.isEmpty) {
          return '開始學習旅程 (暫不加入)';
        }
        return '開始學習旅程 (${_selectedTopicIds.length} 個學科)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pg = _pageGradients[_currentPage.clamp(0, 3)];
    return Material(
      color: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeIn,
        child: SlideTransition(
          position: _slideIn,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: pg,
              ),
            ),
            child: Stack(
              children: [
                _buildBgDecor(size),
                SafeArea(
                  child: Column(
                    children: [
                      _buildTopBar(),
                      Expanded(
                        child: PageView(
                          controller: _pageCtrl,
                          onPageChanged: _onPageChanged,
                          children: [
                            _HeroPage(userName: widget.userName, fadeAnim: _pageFade, slideAnim: _pageSlide),
                            _AIFeaturesPage(isActive: _currentPage == 1, fadeAnim: _pageFade, slideAnim: _pageSlide),
                            _PackVideoPage(isActive: _currentPage == 2, fadeAnim: _pageFade, slideAnim: _pageSlide),
                            _TopicPickerPage(
                              selectedInterestId: _selectedInterestId,
                              selectedTopicIds: _selectedTopicIds,
                              learningInterests: _learningInterests,
                              onInterestTap: (id) {
                                setState(() {
                                  _selectedInterestId = id;
                                  final interest = _learningInterests.firstWhere((i) => i['id'] == id);
                                  _selectedTopicIds.addAll((interest['topics'] as List<String>).toSet());
                                });
                                HapticFeedback.selectionClick();
                              },
                              onTopicTap: _toggleTopic,
                              onSelectAll: () {
                                setState(() => _selectedTopicIds = kCommunityTopics.map((t) => t.id).toSet());
                                HapticFeedback.selectionClick();
                              },
                              onClearAll: () {
                                setState(() => _selectedTopicIds.clear());
                                HapticFeedback.selectionClick();
                              },
                              onSelectRecommended: () {
                                setState(() {
                                  final interest = _learningInterests.firstWhere((i) => i['id'] == _selectedInterestId, orElse: () => _learningInterests[0]);
                                  _selectedTopicIds = Set<String>.from(interest['topics'] as List<String>);
                                });
                                HapticFeedback.selectionClick();
                              },
                              getTopicFocusTag: _getTopicFocusTag,
                              fadeAnim: _pageFade,
                              slideAnim: _pageSlide,
                            ),
                          ],
                        ),
                      ),
                      _buildBottomBar(),
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

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
      child: Row(
        children: [
          Row(
            children: List.generate(4, (i) {
              final active = i == _currentPage;
              final passed = i < _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.only(right: 6),
                width: active ? 22 : 6,
                height: 5,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFFFB74D)
                      : passed
                          ? const Color(0xFF8D6E63)
                          : Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const Spacer(),
          TextButton(
            onPressed: widget.onSkip,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD7CCC8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              '略過',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final isLast = _currentPage == 3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: GestureDetector(
        onTap: _nextPage,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF795548), Color(0xFF8D6E63)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3E2723).withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  _getCtaLabel(),
                  key: ValueKey('$_currentPage-${_selectedTopicIds.length}'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isLast ? Icons.check_circle_outline_rounded : Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBgDecor(Size size) {
    return CustomPaint(
      size: size,
      painter: _BgPainter(page: _currentPage),
    );
  }
}

// ── Page 0 Hero ──
class _HeroPage extends StatelessWidget {
  final String? userName;
  final Animation<double> fadeAnim;
  final Animation<Offset> slideAnim;

  const _HeroPage({
    required this.userName,
    required this.fadeAnim,
    required this.slideAnim,
  });

  static const _features = [
    _FL('🤖', 'AI 伴學解題', '自然語言問答，即時引導破題思路'),
    _FL('🎙️', '語音心智圖', '口述錄音秒轉階層樹狀筆記'),
    _FL('📅', '智能讀書排程', '一句話自動規劃並同步行事曆'),
    _FL('📦', '社群共學 Pack', '9 大學科，同儕資源一鍵匯入'),
  ];

  @override
  Widget build(BuildContext context) {
    final greeting = (userName != null && userName!.trim().isNotEmpty) ? '${userName!.trim()}，你好 👋' : '你好，同學 👋';
    return FadeTransition(
      opacity: fadeAnim,
      child: SlideTransition(
        position: slideAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    const _WelcomeLogo(size: 68),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.8),
                      ),
                      child: Text(
                        greeting,
                        style: const TextStyle(
                          color: Color(0xFFEFEBE9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '歡迎使用\nYeBang 家教',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '你的專屬 AI 智慧伴學夥伴',
                style: TextStyle(
                  color: Color(0xFFD7CCC8),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
                ),
                child: Column(
                  children: List.generate(_features.length, (i) {
                    final f = _features[i];
                    final isLast = i == _features.length - 1;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(f.e, style: const TextStyle(fontSize: 17)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      f.t,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      f.d,
                                      style: const TextStyle(
                                        color: Color(0xFFD7CCC8),
                                        fontSize: 11.5,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: Color(0xFFFFB74D),
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.08),
                            indent: 64,
                          ),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  '🔒  隱私優先 · 本地加密保護',
                  style: TextStyle(
                    color: Color(0xFFBCAAA4),
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FL {
  final String e, t, d;
  const _FL(this.e, this.t, this.d);
}

// ── Page 1: AI Features Auto-Cycle ──
class _AIFeaturesPage extends StatefulWidget {
  final bool isActive;
  final Animation<double> fadeAnim;
  final Animation<Offset> slideAnim;

  const _AIFeaturesPage({
    required this.isActive,
    required this.fadeAnim,
    required this.slideAnim,
  });

  @override
  State<_AIFeaturesPage> createState() => _AIFeaturesPageState();
}

class _AIFeaturesPageState extends State<_AIFeaturesPage> with TickerProviderStateMixin {
  int _cur = 0;
  static const _hold = Duration(milliseconds: 3200);
  static const _fdur = Duration(milliseconds: 400);
  late AnimationController _fadeCtrl, _slideCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _sl;

  static const _feats = [
    _AF(
      icon: Icons.calendar_month_rounded,
      emoji: '📅',
      color: Color(0xFFFFB74D), // 暖琥珀
      title: '智能讀書排程',
      headline: '動態排程 · 考前防忘推播',
      desc: '一句話建立複習計畫，自動防衝堂並雙向同步行事曆。考前 30 分鐘準時推播，不再手忙腳亂。',
      tags: ['⚡ 意圖秒解析', '🔔 考前推播', '🔄 雙向同步'],
    ),
    _AF(
      icon: Icons.lightbulb_rounded,
      emoji: '💡',
      color: Color(0xFFFFCC80), // 溫潤金棕
      title: '啟發式解題',
      headline: '蘇格拉底引導 · 培養自主思考',
      desc: '不直接給答案，以循序問答啟發解題思路，串接考點概念，深層解析錯誤原因。',
      tags: ['📐 步驟引導', '🔗 考點串接', '🎯 錯因解析'],
    ),
    _AF(
      icon: Icons.mic_rounded,
      emoji: '🎙️',
      color: Color(0xFFD7CCC8), // 柔和米褐
      title: '語音心智圖',
      headline: '口述錄音 → 結構心智圖',
      desc: '隨口說出課堂心得，AI 自動去除口語贅字，轉化為階層樹狀心智圖與條列大綱。',
      tags: ['15s 換氣容忍', '🧠 去贅字', '🌳 心智樹圖'],
    ),
    _AF(
      icon: Icons.analytics_rounded,
      emoji: '📊',
      color: Color(0xFFA1887F), // 雅致暖灰褐
      title: '盲點雷達診斷',
      headline: '精準追蹤 · 只練不熟題型',
      desc: '動態分析作答弱點，繪製個人掌握矩陣，配合遺忘曲線預警，生成 5 題靶向題庫。',
      tags: ['📈 掌握矩陣', '⏳ 遺忘預警', '🎯 5 題靶練'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: _fdur);
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _slideCtrl = AnimationController(vsync: this, duration: _fdur);
    _sl = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    if (widget.isActive) _startCycle();
  }

  @override
  void didUpdateWidget(_AIFeaturesPage old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _fadeCtrl.value = 1.0;
      _slideCtrl.value = 1.0;
      _startCycle();
    } else if (!widget.isActive && old.isActive) {
      _fadeCtrl.stop();
      _slideCtrl.stop();
    }
  }

  Future<void> _startCycle() async {
    _fadeCtrl.value = 1.0;
    _slideCtrl.value = 1.0;
    while (mounted && widget.isActive) {
      await Future.delayed(_hold);
      if (!mounted || !widget.isActive) break;
      await _fadeCtrl.reverse();
      if (!mounted || !widget.isActive) break;
      if (mounted) setState(() => _cur = (_cur + 1) % _feats.length);
      _slideCtrl.value = 0;
      _fadeCtrl.forward();
      _slideCtrl.forward();
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = _feats[_cur];
    return FadeTransition(
      opacity: widget.fadeAnim,
      child: SlideTransition(
        position: widget.slideAnim,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI 智慧伴學特點',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '以認知科學為核心，打造專屬學習伴助',
                style: TextStyle(
                  color: Color(0xFFD7CCC8),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _sl,
                    child: _buildCard(f),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_feats.length, (i) {
                  final isA = i == _cur;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isA ? 20 : 6,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isA ? const Color(0xFFFFB74D) : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 6),
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    '${f.emoji}  ${f.title}',
                    key: ValueKey(_cur),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFFEFEBE9),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(_AF f) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: f.color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: f.color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: f.color.withValues(alpha: 0.35), width: 0.8),
                      ),
                      child: Icon(f.icon, size: 20, color: f.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            f.headline,
                            style: TextStyle(
                              color: f.color,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  f.desc,
                  style: const TextStyle(
                    color: Color(0xFFEFEBE9),
                    fontSize: 13,
                    height: 1.55,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: f.tags.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
                    ),
                    child: Text(
                      t,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFD7CCC8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AF {
  final IconData icon;
  final String emoji;
  final Color color;
  final String title, headline, desc;
  final List<String> tags;

  const _AF({
    required this.icon,
    required this.emoji,
    required this.color,
    required this.title,
    required this.headline,
    required this.desc,
    required this.tags,
  });
}

// ── Page 2: Pack Video ──
class _PackVideoPage extends StatelessWidget {
  final bool isActive;
  final Animation<double> fadeAnim;
  final Animation<Offset> slideAnim;

  const _PackVideoPage({
    required this.isActive,
    required this.fadeAnim,
    required this.slideAnim,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeAnim,
      child: SlideTransition(
        position: slideAnim,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.8),
                ),
                child: const Text(
                  '📦  學習 Pack 模組',
                  style: TextStyle(
                    color: Color(0xFFFFCC80),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '社群共學 Pack',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '一鍵整合筆記與試卷，輕鬆發布與同儕共學',
                style: TextStyle(
                  color: Color(0xFFD7CCC8),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => Center(
                    child: TutorialVideoPlayer(
                      assetPath: 'assets/learning_pack_tutorial.mp4',
                      isActive: isActive,
                      maxHeight: c.maxHeight,
                      badgeLabel: '學習 Pack 操作示範',
                      initialMuted: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Row(
                children: [
                  _PC('✍️', '建立 Pack'),
                  SizedBox(width: 8),
                  _PC('🔗', '一鍵分享'),
                  SizedBox(width: 8),
                  _PC('📥', '同儕匯入'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PC extends StatelessWidget {
  final String emoji, label;
  const _PC(this.emoji, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFFEFEBE9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Page 3: Topic Picker ──
class _TopicPickerPage extends StatelessWidget {
  final String selectedInterestId;
  final Set<String> selectedTopicIds;
  final List<Map<String, dynamic>> learningInterests;
  final void Function(String) onInterestTap, onTopicTap;
  final VoidCallback onSelectAll, onClearAll, onSelectRecommended;
  final String Function(String) getTopicFocusTag;
  final Animation<double> fadeAnim;
  final Animation<Offset> slideAnim;

  const _TopicPickerPage({
    required this.selectedInterestId,
    required this.selectedTopicIds,
    required this.learningInterests,
    required this.onInterestTap,
    required this.onTopicTap,
    required this.onSelectAll,
    required this.onClearAll,
    required this.onSelectRecommended,
    required this.getTopicFocusTag,
    required this.fadeAnim,
    required this.slideAnim,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeAnim,
      child: SlideTransition(
        position: slideAnim,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '定制你的學習旅程',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '可選擇學習動機與學科，也可隨時略過或不加入',
                style: TextStyle(
                  color: Color(0xFFD7CCC8),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '① 你的主要學習動機',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD7CCC8),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: learningInterests.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final i = learningInterests[index];
                    final isSel = selectedInterestId == i['id'];
                    return GestureDetector(
                      onTap: () => onInterestTap(i['id'] as String),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? Colors.white.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSel ? const Color(0xFFFFB74D) : Colors.white.withValues(alpha: 0.12),
                            width: isSel ? 1.4 : 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(i['emoji'] as String, style: const TextStyle(fontSize: 15)),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  i['title'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                    color: isSel ? Colors.white : const Color(0xFFEFEBE9),
                                  ),
                                ),
                                Text(
                                  i['desc'] as String,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: isSel ? const Color(0xFFFFCC80) : const Color(0xFFBCAAA4),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '② 關注學科 ${selectedTopicIds.isEmpty ? "(未選擇)" : "(${selectedTopicIds.length} 個)"}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD7CCC8),
                      letterSpacing: 0.2,
                    ),
                  ),
                  Row(
                    children: [
                      _QB('✨ 依興趣', onSelectRecommended),
                      const SizedBox(width: 5),
                      _QB('⚡ 全選', onSelectAll),
                      const SizedBox(width: 5),
                      _QB('✕ 暫不加入', onClearAll, isDestructive: true),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.only(bottom: 4),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: kCommunityTopics.length,
                  itemBuilder: (context, index) {
                    final t = kCommunityTopics[index];
                    final isSel = selectedTopicIds.contains(t.id);
                    return GestureDetector(
                      onTap: () => onTopicTap(t.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          color: isSel ? Colors.white.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSel ? const Color(0xFFFFB74D) : Colors.white.withValues(alpha: 0.12),
                            width: isSel ? 1.4 : 0.8,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              children: [
                                Text(t.emoji, style: const TextStyle(fontSize: 20)),
                                if (isSel)
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFFB74D),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check, size: 8, color: Color(0xFF3E2723)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                color: isSel ? Colors.white : const Color(0xFFEFEBE9),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              getTopicFocusTag(t.id),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 8.5,
                                color: isSel ? const Color(0xFFFFCC80) : const Color(0xFFBCAAA4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  '進入 App 後可隨時在「個人檔案」自由調整或退出學科',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFFBCAAA4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QB extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _QB(this.label, this.onTap, {this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDestructive ? Colors.white.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.16),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDestructive ? const Color(0xFFFFCCBC) : const Color(0xFFEFEBE9),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Background Painter ──
class _BgPainter extends CustomPainter {
  final int page;

  _BgPainter({required this.page});

  @override
  void paint(Canvas canvas, Size size) {
    // 溫暖柔和微光，沉穩質感的暖棕層次
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFFFFB74D).withValues(alpha: 0.07), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.2, size.height * 0.15), radius: 200));
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.15), 200, paint1);

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF8D6E63).withValues(alpha: 0.08), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.85, size.height * 0.7), radius: 240));
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.7), 240, paint2);

    // 幾何優雅環紋 (極淡)
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.12), 120, ringPaint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.12), 220, ringPaint);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.page != page;
}

// ── 品牌標誌組件（Leaf Sprout Logo）──
class _WelcomeLogo extends StatelessWidget {
  final double size;
  const _WelcomeLogo({this.size = 68});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.18,
      height: size * 1.18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 旋轉環外圈
          CustomPaint(
            size: Size(size * 1.18, size * 1.18),
            painter: const _WelcomeArcRingPainter(),
          ),
          // 中心圓形白底發光容器
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9CCC65).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: CustomPaint(
                size: Size(size * 0.65, size * 0.65),
                painter: const _WelcomeLeafLogoPainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeArcRingPainter extends CustomPainter {
  const _WelcomeArcRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // 弧段 1: 青藍色
    paint.color = const Color(0xFF4DD0E1).withValues(alpha: 0.9);
    canvas.drawArc(rect, 0, 1.8, false, paint);

    // 弧段 2: 綠色
    paint.color = const Color(0xFF9CCC65).withValues(alpha: 0.75);
    canvas.drawArc(rect, 2.4, 1.2, false, paint);

    // 弧段 3: 淺綠/藍綠色
    paint.color = const Color(0xFF80CBC4).withValues(alpha: 0.55);
    canvas.drawArc(rect, 4.0, 0.6, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WelcomeLeafLogoPainter extends CustomPainter {
  const _WelcomeLeafLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final Rect bounds = Rect.fromLTWH(0, 0, w, h);

    final baseGradient = const LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [
        Color(0xFF9CCC65), // 綠色
        Color(0xFF4DD0E1), // 青色/藍綠色
      ],
    );

    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..shader = baseGradient.createShader(bounds);

    final Paint fillPaint = Paint()..style = PaintingStyle.fill;

    // 繪製 y 的草寫主莖幹
    final yBodyPath = Path();
    yBodyPath.moveTo(w * 0.25, h * 0.42);
    yBodyPath.quadraticBezierTo(w * 0.28, h * 0.62, w * 0.42, h * 0.62);
    yBodyPath.quadraticBezierTo(w * 0.52, h * 0.62, w * 0.55, h * 0.42);
    yBodyPath.cubicTo(
        w * 0.55, h * 0.65, w * 0.50, h * 0.88, w * 0.38, h * 0.88);
    yBodyPath.cubicTo(
        w * 0.24, h * 0.88, w * 0.24, h * 0.70, w * 0.35, h * 0.58);
    yBodyPath.quadraticBezierTo(w * 0.45, h * 0.48, w * 0.65, h * 0.62);
    yBodyPath.quadraticBezierTo(w * 0.72, h * 0.68, w * 0.70, h * 0.55);

    canvas.drawPath(yBodyPath, strokePaint);

    // 繪製左小葉
    final leftLeaf = Path();
    leftLeaf.moveTo(w * 0.25, h * 0.42);
    leftLeaf.cubicTo(
        w * 0.20, h * 0.35, w * 0.12, h * 0.30, w * 0.10, h * 0.32);
    leftLeaf.cubicTo(
        w * 0.14, h * 0.45, w * 0.22, h * 0.48, w * 0.25, h * 0.42);

    fillPaint.shader = LinearGradient(
      begin: Alignment.bottomRight,
      end: Alignment.topLeft,
      colors: [
        const Color(0xFF9CCC65).withValues(alpha: 0.15),
        const Color(0xFF9CCC65).withValues(alpha: 0.4),
      ],
    ).createShader(bounds);
    canvas.drawPath(leftLeaf, fillPaint);
    canvas.drawPath(leftLeaf, strokePaint);

    // 左葉脈
    final leftVein = Path();
    leftVein.moveTo(w * 0.25, h * 0.42);
    leftVein.quadraticBezierTo(w * 0.18, h * 0.37, w * 0.11, h * 0.33);

    final Paint veinPaint = Paint()
      ..shader = strokePaint.shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(leftVein, veinPaint);

    // 繪製右大葉
    final rightLeaf = Path();
    rightLeaf.moveTo(w * 0.55, h * 0.42);
    rightLeaf.cubicTo(
        w * 0.60, h * 0.28, w * 0.72, h * 0.10, w * 0.85, h * 0.15);
    rightLeaf.cubicTo(
        w * 0.78, h * 0.32, w * 0.64, h * 0.45, w * 0.55, h * 0.42);

    fillPaint.shader = LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [
        const Color(0xFF4DD0E1).withValues(alpha: 0.15),
        const Color(0xFF4DD0E1).withValues(alpha: 0.4),
      ],
    ).createShader(bounds);
    canvas.drawPath(rightLeaf, fillPaint);
    canvas.drawPath(rightLeaf, strokePaint);

    // 右葉脈
    final rightVein = Path();
    rightVein.moveTo(w * 0.55, h * 0.42);
    rightVein.quadraticBezierTo(w * 0.68, h * 0.28, w * 0.82, h * 0.17);
    canvas.drawPath(rightVein, veinPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

