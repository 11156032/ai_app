import 'dart:async';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import '../../services/ai_diagnosis_service.dart';

// ── AI 提示與整理進度元件 ──────────────────────────────────────────────
class AiLoadingTipWidget extends StatefulWidget {
  const AiLoadingTipWidget({super.key});

  @override
  State<AiLoadingTipWidget> createState() => _AiLoadingTipWidgetState();
}

class _AiLoadingTipWidgetState extends State<AiLoadingTipWidget> {
  Timer? _timer;
  late String _currentTip;
  int _secondsLeft = 0;

  final List<String> _tips = [
    'AI 整理能幫您快速抓出筆記的核心重點！',
    '整理完後，您可以將摘要直接附加到原筆記中！',
    '有條理的筆記有助於大腦更深層地建立知識連結喔！',
    '利用 AI 摘要後，搭配題目測驗，學習效果會更好！',
    '每隔段時間重新檢視筆記，是克服遺忘曲線的最佳方法！',
  ];

  @override
  void initState() {
    super.initState();
    _currentTip = _tips[DateTime.now().millisecond % _tips.length];
    _updateSecondsLeft();
    if (_secondsLeft > 0) {
      _startTimer();
    }
  }

  void _updateSecondsLeft() {
    final now = DateTime.now();
    if (AiDiagnosisService.nextAvailableTime != null &&
        AiDiagnosisService.nextAvailableTime!.isAfter(now)) {
      _secondsLeft =
          AiDiagnosisService.nextAvailableTime!.difference(now).inSeconds;
    } else {
      _secondsLeft = 0;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _updateSecondsLeft();
        if (_secondsLeft <= 0) {
          _timer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _updateSecondsLeft();
    final bool isRateLimited = _secondsLeft > 0;
    final String icon = isRateLimited ? '⏳' : '💡';
    final String text = isRateLimited
        ? 'AI 目前繁忙，預計於 $_secondsLeft 秒後恢復。將暫以本地算法大綱整理...'
        : _currentTip;

    final Color bgColor =
        isRateLimited ? const Color(0xFFFFF3E0) : const Color(0xFFFFFDE7);
    final Color borderColor =
        isRateLimited ? const Color(0xFFFFE0B2) : const Color(0xFFFFF59D);
    final Color textColor =
        isRateLimited ? const Color(0xFFE65100) : const Color(0xFFF57F17);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI 弱點診斷計算進度條 ──────────────────────────────────────────────
class DiagnosisLoadingProgress extends StatefulWidget {
  const DiagnosisLoadingProgress({super.key});

  @override
  State<DiagnosisLoadingProgress> createState() =>
      _DiagnosisLoadingProgressState();
}

class _DiagnosisLoadingProgressState extends State<DiagnosisLoadingProgress> {
  double _value = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() {
        if (_value < 0.92) {
          _value += 0.015;
          if (_value > 0.92) _value = 0.92;
        } else {
          _value += (0.999 - _value) * 0.03;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int step = (_value * 4).ceil();
    if (step > 4) step = 4;
    if (step < 1) step = 1;

    String loadingText = '';
    switch (step) {
      case 1:
        loadingText = '資料彙整中... (1/4)';
        break;
      case 2:
        loadingText = '分析答錯概念... (2/4)';
        break;
      case 3:
        loadingText = '深度診斷運算中... (3/4)';
        break;
      case 4:
        loadingText = '生成個人化建議... (4/4)';
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: FadeInUp(
          duration: const Duration(milliseconds: 600),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _value.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context)
                                    .primaryColor
                                    .withValues(alpha: 0.3),
                                Theme.of(context).primaryColor
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          loadingText,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4E342E),
                          ),
                        ),
                        Text(
                          '${(_value * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                '系統正在為您量身打造專屬報告，請稍候...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 筆記整理載入泡泡 ──────────────────────────────────────────────
class NoteSummaryLoadingBubble extends StatefulWidget {
  const NoteSummaryLoadingBubble({super.key});

  @override
  State<NoteSummaryLoadingBubble> createState() =>
      _NoteSummaryLoadingBubbleState();
}

class _NoteSummaryLoadingBubbleState extends State<NoteSummaryLoadingBubble> {
  double _value = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() {
        if (_value < 0.90) {
          _value += 0.03;
          if (_value > 0.90) _value = 0.90;
        } else {
          _value += (0.999 - _value) * 0.05;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    '代理人正在為您整理筆記...',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4E342E),
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '${(_value * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _value.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor.withValues(alpha: 0.3),
                        Theme.of(context).primaryColor
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const AiLoadingTipWidget(),
          ],
        ),
      ),
    );
  }
}
