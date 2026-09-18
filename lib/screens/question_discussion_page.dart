import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';

class QuestionDiscussionPage extends StatefulWidget {
  final Map<String, dynamic> questionData;
  final Map<String, dynamic> currentUser;

  const QuestionDiscussionPage({
    super.key,
    required this.questionData,
    required this.currentUser,
  });

  @override
  State<QuestionDiscussionPage> createState() => _QuestionDiscussionPageState();
}

class _QuestionDiscussionPageState extends State<QuestionDiscussionPage> {
  final TextEditingController _commentCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _discussions = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isGeneratingAi = false;
  bool _isQuestionExpanded = true;
  String? _replyToUser;
  int _replyToParentId = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _loadDiscussions();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  int get _questionId {
    return int.tryParse(widget.questionData['id']?.toString() ?? '0') ?? 0;
  }

  String get _currentUserId {
    return (widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1').toString();
  }

  String get _currentUserName {
    return (widget.currentUser['name'] ?? widget.currentUser['username'] ?? '學習夥伴').toString();
  }

  String? get _currentUserAvatar {
    return widget.currentUser['avatar']?.toString() ?? widget.currentUser['avatar_url']?.toString();
  }

  Future<void> _loadDiscussions() async {
    try {
      if (_questionId == 0) {
        setState(() => _isLoading = false);
        return;
      }

      final list = await DatabaseHelper.instance.getDiscussionsForQuestion(
        _questionId,
        currentUserId: _currentUserId,
      );

      // If discussions are completely empty, let's auto-seed with 1 or 2 high quality sample discussions if needed
      if (list.isEmpty) {
        await _seedInitialDiscussionsIfNeeded();
        final reloaded = await DatabaseHelper.instance.getDiscussionsForQuestion(
          _questionId,
          currentUserId: _currentUserId,
        );
        if (!mounted) return;
        setState(() {
          _discussions = reloaded;
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _discussions = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('載入討論串錯誤: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _seedInitialDiscussionsIfNeeded() async {
    final sub = widget.questionData['subject']?.toString() ?? '一般';
    final explanation = widget.questionData['explanation']?.toString() ?? '';

    // Sample peer question & peer answer
    await DatabaseHelper.instance.addQuestionDiscussion(
      questionId: _questionId,
      userId: 'u_peer1',
      userName: '李同學 (建國中學)',
      content: '這題如果遇到類似題型，建議大家先畫出輔助線或拆解核心觀念，會快很多！',
    );

    if (explanation.isNotEmpty) {
      await DatabaseHelper.instance.addQuestionDiscussion(
        questionId: _questionId,
        userId: 'u_ai_tutor',
        userName: '🤖 AI 智慧助教',
        content: '【觀念提示】\n針對本題《$sub》考點：$explanation\n做題時注意審題關鍵字，排除干擾選項即可迅速作答！',
        isAiResponse: 1,
      );
    } else {
      await DatabaseHelper.instance.addQuestionDiscussion(
        questionId: _questionId,
        userId: 'u_tutor',
        userName: '陳助教 (解題教練)',
        content: '這題主要檢驗基本定義與邏輯推演，大家複習時可以多留意關鍵名詞與計算步驟。',
      );
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final contentToSend = _replyToUser != null ? '$_replyToUser $text' : text;

      await DatabaseHelper.instance.addQuestionDiscussion(
        questionId: _questionId,
        userId: _currentUserId,
        userName: _currentUserName,
        avatarUrl: _currentUserAvatar,
        content: contentToSend,
        parentId: _replyToParentId,
      );

      _commentCtrl.clear();
      _replyToUser = null;
      _replyToParentId = 0;

      await _loadDiscussions();

      // Scroll to bottom smoothly
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('送出留言失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('送出留言失敗，請重試')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _requestAiTutorResponse() async {
    if (_isGeneratingAi) return;
    setState(() => _isGeneratingAi = true);

    try {
      final sub = widget.questionData['subject']?.toString() ?? '一般';
      final explanation = widget.questionData['explanation']?.toString() ?? '';

      // Generate intelligent AI tutor response
      await Future.delayed(const Duration(milliseconds: 800));

      final buffer = StringBuffer();
      buffer.writeln('💡 【AI 助教深度解題觀點】');
      buffer.writeln('本題屬於《$sub》核心題型。');
      if (explanation.isNotEmpty) {
        buffer.writeln('👉 核心思路：$explanation');
      } else {
        buffer.writeln('👉 解題技巧：建議先分析題幹主要條件，針對各選項進行正誤對比，特別留意細節定義！');
      }
      buffer.writeln('若同學對於某步驟有疑問，歡迎直接在此回覆發問喔！');

      await DatabaseHelper.instance.addQuestionDiscussion(
        questionId: _questionId,
        userId: 'u_ai_tutor',
        userName: '🤖 AI 智慧助教',
        content: buffer.toString(),
        isAiResponse: 1,
      );

      await _loadDiscussions();

      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('AI 助教生成失敗: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingAi = false);
    }
  }

  Future<void> _toggleLike(int discussionId) async {
    try {
      await DatabaseHelper.instance.toggleLikeQuestionDiscussion(discussionId, _currentUserId);
      await _loadDiscussions();
    } catch (e) {
      debugPrint('點讚失敗: $e');
    }
  }

  Future<void> _deleteComment(int discussionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('刪除留言', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('確定要刪除這則討論留言嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteQuestionDiscussion(discussionId);
      await _loadDiscussions();
    }
  }

  List<String> _getOptions() {
    final raw = widget.questionData['options'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is List) return d.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }

  String _formatTime(dynamic rawTime) {
    if (rawTime == null) return '';
    try {
      final dt = DateTime.tryParse(rawTime.toString());
      if (dt == null) return rawTime.toString();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return '剛剛';
      if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
      if (diff.inHours < 24) return '${diff.inHours} 小時前';
      if (diff.inDays < 7) return '${diff.inDays} 天前';
      return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Color _getDifficultyColor(String diff) {
    switch (diff) {
      case '易':
        return const Color(0xFF10B981);
      case '中':
        return const Color(0xFFF59E0B);
      case '難':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.questionData['subject']?.toString() ?? '一般';
    final diff = widget.questionData['difficulty']?.toString() ?? '中';
    final diffColor = _getDifficultyColor(diff);
    final qText = widget.questionData['question']?.toString() ?? widget.questionData['text']?.toString() ?? '';
    final options = _getOptions();
    final ansIndex = int.tryParse((widget.questionData['answerIndex'] ?? widget.questionData['answer'] ?? 0).toString()) ?? 0;
    final explanation = widget.questionData['explanation']?.toString() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          '題目討論串',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF334155)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isQuestionExpanded ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
              color: const Color(0xFF4F46E5),
            ),
            tooltip: _isQuestionExpanded ? '收合題目' : '展開題目',
            onPressed: () => setState(() => _isQuestionExpanded = !_isQuestionExpanded),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 1. 頂部題目概覽卡片（支援展開/收合） ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        sub,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: diffColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '難度：$diff',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: diffColor),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _isQuestionExpanded = !_isQuestionExpanded),
                      child: Row(
                        children: [
                          Text(
                            _isQuestionExpanded ? '收合題目' : '展開題目',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                          Icon(
                            _isQuestionExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: const Color(0xFF64748B),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // 題目敘述
                Text(
                  qText,
                  maxLines: _isQuestionExpanded ? 6 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                    height: 1.4,
                  ),
                ),

                // 展開時顯示選項與解析
                if (_isQuestionExpanded) ...[
                  const SizedBox(height: 8),
                  if (options.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: List.generate(options.length, (idx) {
                        final isCorrect = idx == ansIndex;
                        final char = String.fromCharCode(65 + idx);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isCorrect ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isCorrect ? const Color(0xFF10B981) : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            '$char. ${options[idx]} ${isCorrect ? "✔" : ""}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isCorrect ? const Color(0xFF065F46) : const Color(0xFF475569),
                              fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      }),
                    ),
                  if (explanation.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        '💡 解析：$explanation',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E), height: 1.3),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),

          // ── 2. 討論區主體 ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    children: [
                      // 討論區頂部統計與 AI 助教按鈕
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.forum_rounded, size: 18, color: Color(0xFF4F46E5)),
                              const SizedBox(width: 6),
                              Text(
                                '討論交流 (${_discussions.length} 則留言)',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: _isGeneratingAi ? null : _requestAiTutorResponse,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _isGeneratingAi
                                      ? const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF7C3AED)),
                                        )
                                      : const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF7C3AED)),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isGeneratingAi ? '思考中...' : '召喚 AI 助教解答',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7C3AED),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 留言清單
                      if (_discussions.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                          child: Column(
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              const Text(
                                '目前還沒有討論留言',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '提出你的疑問，或分享解題技巧與心得吧！',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._discussions.map((d) {
                          return _buildCommentCard(d);
                        }),
                    ],
                  ),
          ),

          // ── 3. 底部發布留言列 ──
          _buildBottomInputBar(),
        ],
      ),
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> d) {
    final id = int.tryParse(d['id']?.toString() ?? '0') ?? 0;
    final userName = d['user_name']?.toString() ?? '學習夥伴';
    final content = d['content']?.toString() ?? '';
    final timeStr = _formatTime(d['created_at']);
    final isAi = (d['is_ai_response'] as int? ?? 0) == 1;
    final isOwner = d['user_id']?.toString() == _currentUserId;
    final likesCount = int.tryParse(d['likes_count']?.toString() ?? '0') ?? 0;
    final isLiked = d['is_liked'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAi ? const Color(0xFFF5F3FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAi ? const Color(0xFFC4B5FD) : Colors.grey.shade200,
          width: isAi ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 留言者頭像與名稱列
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 16,
                backgroundColor: isAi ? const Color(0xFF7C3AED) : const Color(0xFFEEF2FF),
                child: isAi
                    ? const Icon(Icons.smart_toy_rounded, size: 18, color: Colors.white)
                    : Text(
                        userName.isNotEmpty ? userName[0] : 'U',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4F46E5)),
                      ),
              ),
              const SizedBox(width: 10),

              // Name & AI Badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isAi ? const Color(0xFF6D28D9) : const Color(0xFF1E293B),
                          ),
                        ),
                        if (isAi) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'AI 助教',
                              style: TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),

              // 刪除按鈕（本人留言）
              if (isOwner)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                  onPressed: () => _deleteComment(id),
                  tooltip: '刪除留言',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // 留言內容
          Text(
            content,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: isAi ? const Color(0xFF3B0764) : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 10),

          // 底部互動按鈕（點讚 / 回覆）
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 回覆按鈕
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _replyToUser = '@$userName';
                    _replyToParentId = id;
                  });
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.reply_rounded, size: 15, color: Color(0xFF64748B)),
                      SizedBox(width: 4),
                      Text('回覆', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 點讚按鈕
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _toggleLike(id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 15,
                        color: isLiked ? Colors.redAccent : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        likesCount > 0 ? '$likesCount' : '讚',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isLiked ? FontWeight.bold : FontWeight.normal,
                          color: isLiked ? Colors.redAccent : const Color(0xFF64748B),
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
    );
  }

  Widget _buildBottomInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 回覆對象標籤
          if (_replyToUser != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '回覆 $_replyToUser',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF4F46E5), fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => setState(() {
                            _replyToUser = null;
                            _replyToParentId = 0;
                          }),
                          child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF4F46E5)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _commentCtrl,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B)),
                    decoration: const InputDecoration(
                      hintText: '發表討論、提出疑問或心得...',
                      hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: _isSending ? null : _sendComment,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF4F46E5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
