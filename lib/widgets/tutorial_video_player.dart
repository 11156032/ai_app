import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class TutorialVideoPlayer extends StatefulWidget {
  final String assetPath;
  final bool autoPlay;
  final bool looping;
  final bool isActive;
  final double? maxHeight;
  final String badgeLabel;
  final bool initialMuted;

  const TutorialVideoPlayer({
    super.key,
    required this.assetPath,
    this.autoPlay = true,
    this.looping = true,
    this.isActive = true,
    this.maxHeight,
    this.badgeLabel = '操作示範',
    this.initialMuted = false, // 預設開啟聲音
  });

  /// 彈出對話框觀看指定教學影片（純白典雅底色，融入 App 介面風格）
  static Future<void> showVideoDialog(
    BuildContext context, {
    required String assetPath,
    required String title,
    String badgeLabel = '操作示範',
  }) async {
    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white, // 純白底色
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFE8DDD5),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 28,
                offset: Offset(0, 8),
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
                    const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF8D6E63), size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF3E2723), // 典雅深咖啡色
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF757575)),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFEFEBE9)),

              // 影片播放主體（大尺寸）
              Padding(
                padding: const EdgeInsets.all(10),
                child: SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.74,
                  child: TutorialVideoPlayer(
                    assetPath: assetPath,
                    autoPlay: true,
                    looping: true,
                    isActive: true,
                    badgeLabel: badgeLabel,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 彈出教學影片總覽清單（純白底色，融入 App 介面風格）
  static Future<void> showTutorialChooserDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white, // 純白底色
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(
            color: Color(0xFFE8DDD5),
            width: 1.2,
          ),
        ),
        title: const Row(
          children: [
            Icon(Icons.ondemand_video_rounded, color: Color(0xFF8D6E63), size: 24),
            SizedBox(width: 10),
            Text(
              '操作教學示範影片',
              style: TextStyle(
                color: Color(0xFF3E2723),
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '請選擇想觀看的介面操作教學影片：',
                style: TextStyle(color: Color(0xFF757575), fontSize: 13),
              ),
              const SizedBox(height: 16),

              // 選項 1：題庫測驗教學
              _buildChooserTile(
                context: context,
                icon: Icons.quiz_rounded,
                title: '📝 題庫測驗與錯題診斷教學',
                desc: '示範題目作答、交卷與錯題弱點分析完整流程',
                assetPath: 'assets/learning_pack_tutorial.mp4',
                videoTitle: '題庫測驗與錯題複習操作示範',
                badgeLabel: '題庫測驗教學',
                onClose: () => Navigator.of(ctx).pop(),
              ),
              const SizedBox(height: 10),

              // 選項 2：學習 Pack 教學
              _buildChooserTile(
                context: context,
                icon: Icons.inventory_2_rounded,
                title: '📦 學習 Pack 製作與分享教學',
                desc: '示範如何彙整重點筆記與考卷，建立與發布學習 Pack',
                assetPath: 'assets/learning_pack_tutorial.mp4',
                videoTitle: '學習 Pack 製作與分享操作教學',
                badgeLabel: '學習 Pack 教學',
                onClose: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              '關閉',
              style: TextStyle(
                color: Color(0xFF8D6E63),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildChooserTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String desc,
    required String assetPath,
    required String videoTitle,
    required String badgeLabel,
    required VoidCallback onClose,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      tileColor: const Color(0xFFF9F7F5), // 柔和純淨暖米白
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE8DDD5)),
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF8D6E63).withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF8D6E63), size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Color(0xFF3E2723), fontSize: 13.5, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        desc,
        style: const TextStyle(color: Color(0xFF8D6E63), fontSize: 11),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF8D6E63), size: 14),
      onTap: () {
        onClose();
        TutorialVideoPlayer.showVideoDialog(
          context,
          assetPath: assetPath,
          title: videoTitle,
          badgeLabel: badgeLabel,
        );
      },
    );
  }

  @override
  State<TutorialVideoPlayer> createState() => _TutorialVideoPlayerState();
}

class _TutorialVideoPlayerState extends State<TutorialVideoPlayer>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  late bool _isMuted;
  double _playbackSpeed = 1.0;
  static const List<double> _speedOptions = [1.0, 1.25, 0.5, 0.75]; // 支援慢放 (0.5x, 0.75x) 與微快 (1.25x)

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.initialMuted;
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _controller = VideoPlayerController.asset(widget.assetPath);
      await _controller.initialize();
      await _controller.setLooping(widget.looping);
      await _controller.setVolume(_isMuted ? 0.0 : 0.65); // 音量適中舒適
      await _controller.setPlaybackSpeed(_playbackSpeed);
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
        if (widget.autoPlay && widget.isActive) {
          _controller.play();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant TutorialVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.assetPath != oldWidget.assetPath) {
      _controller.dispose();
      _isInitialized = false;
      _initPlayer();
    } else if (_isInitialized) {
      if (widget.isActive && !oldWidget.isActive) {
        _controller.play();
      } else if (!widget.isActive && oldWidget.isActive) {
        _controller.pause();
      }
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (!_isInitialized) return;
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _toggleMute() {
    if (!_isInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0.0 : 0.65);
    });
  }

  void _cyclePlaybackSpeed() {
    if (!_isInitialized) return;
    final currentIndex = _speedOptions.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % _speedOptions.length;
    final nextSpeed = _speedOptions[nextIndex];
    setState(() {
      _playbackSpeed = nextSpeed;
    });
    _controller.setPlaybackSpeed(nextSpeed);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: const Color(0xFF2C221E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF8D6E63).withValues(alpha: 0.5)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_outlined, color: Color(0xFFD7CCC8), size: 38),
              const SizedBox(height: 8),
              const Text(
                '無法載入操作導覽影片',
                style: TextStyle(color: Color(0xFFFDFBF7), fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() => _hasError = false);
                  _initPlayer();
                },
                icon: const Icon(Icons.refresh, size: 16, color: Color(0xFFFFB300)),
                label: const Text('重試', style: TextStyle(color: Color(0xFFFFB300), fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        height: 280,
        decoration: BoxDecoration(
          color: const Color(0xFF2C221E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFFFB300), strokeWidth: 2.5),
              SizedBox(height: 12),
              Text(
                '正在準備操作示範影片...',
                style: TextStyle(color: Color(0xFFD7CCC8), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final isPlaying = _controller.value.isPlaying;
    final videoRatio = _controller.value.aspectRatio > 0 ? _controller.value.aspectRatio : 9 / 19.5;

    Widget playerWidget = AspectRatio(
      aspectRatio: videoRatio,
      child: Container(
        // ── 俐落大尺寸擬真外框（最小化邊框厚度以極大化畫面，採用溫暖可可棕調） ──
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6D4C41),
              Color(0xFF2C221E),
              Color(0xFF4E342E),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF8D6E63).withValues(alpha: 0.65),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── 影片畫面 ──
              Container(
                color: Colors.black,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),

              // ── 點擊切換播放/暫停透明層 ──
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _togglePlayPause,
                    splashColor: Colors.white12,
                    highlightColor: Colors.transparent,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),

              // ── 中央大型播放按鈕（播放時完全隱藏，避免遮擋畫面；暫停時呈現） ──
              if (!isPlaying)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (context, child) {
                            final scale = 1.0 + (_pulseCtrl.value * 0.08);
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2C221E).withValues(alpha: 0.85),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFFFB300),
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFFB300).withValues(alpha: 0.4),
                                      blurRadius: 22,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 46,
                                  color: Color(0xFFFFB300),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

              // ── 頂部小標籤與倍速按鈕 ──
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    // 功能標籤
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C221E).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF8D6E63).withValues(alpha: 0.5), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFFFB300), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            widget.badgeLabel,
                            style: const TextStyle(color: Color(0xFFFDFBF7), fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // ⚡ 播放速度調整按鈕 (支援慢放 0.5x, 0.75x 與 1.25x)
                    GestureDetector(
                      onTap: _cyclePlaybackSpeed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: _playbackSpeed != 1.0
                              ? (_playbackSpeed < 1.0 ? const Color(0xFF81D4FA) : const Color(0xFFFFB300))
                              : const Color(0xFF2C221E).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _playbackSpeed != 1.0
                                ? (_playbackSpeed < 1.0 ? const Color(0xFF4FC3F7) : const Color(0xFFFFA000))
                                : const Color(0xFF8D6E63).withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _playbackSpeed < 1.0 ? Icons.slow_motion_video_rounded : Icons.speed_rounded,
                              color: _playbackSpeed != 1.0 ? const Color(0xFF2C221E) : const Color(0xFFFFB300),
                              size: 13,
                            ),
                            const SizedBox(width: 3.5),
                            Text(
                              _playbackSpeed == 1.0
                                  ? '1.0x'
                                  : (_playbackSpeed < 1.0
                                      ? '慢放 ${_playbackSpeed == 0.5 ? '0.5x' : '0.75x'}'
                                      : '1.25x'),
                              style: TextStyle(
                                color: _playbackSpeed != 1.0 ? const Color(0xFF2C221E) : const Color(0xFFFDFBF7),
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── 底部控制條 (進度條、時間、靜音切換) ──
              Positioned(
                bottom: 6,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF1E1714).withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                  child: ValueListenableBuilder(
                    valueListenable: _controller,
                    builder: (context, VideoPlayerValue val, child) {
                      final position = val.position;
                      final duration = val.duration;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          VideoProgressIndicator(
                            _controller,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: Color(0xFFFFB300),
                              bufferedColor: Colors.white38,
                              backgroundColor: Colors.white24,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 3),
                          ),
                          Row(
                            children: [
                              Text(
                                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                style: const TextStyle(
                                  color: Color(0xFFD7CCC8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              // 靜音切換
                              GestureDetector(
                                onTap: _toggleMute,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.maxHeight != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.maxHeight!),
        child: Center(child: playerWidget),
      );
    }

    return Center(child: playerWidget);
  }
}
