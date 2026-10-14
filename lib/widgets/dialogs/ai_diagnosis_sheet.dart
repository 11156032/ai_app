import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

import '../../services/ai_diagnosis_service.dart';
import '../loading/ai_loading_indicators.dart';

/// AI 學習診斷報告 BottomSheet
class AiDiagnosisSheet extends StatelessWidget {
  final bool isDiagnosing;
  final DiagnosisResult? diagnosisResult;
  final String streamedDiagnosisText;
  final List<dynamic> lastQuizWrongIds;
  final Map<String, dynamic> currentUser;
  final VoidCallback? onClose;
  final void Function(List<dynamic> wrongIds)? onReviewWrongQuestions;
  final void Function(int pageIndex, String title)? onNavigateToPage;

  const AiDiagnosisSheet({
    super.key,
    required this.isDiagnosing,
    required this.diagnosisResult,
    this.streamedDiagnosisText = '',
    this.lastQuizWrongIds = const [],
    required this.currentUser,
    this.onClose,
    this.onReviewWrongQuestions,
    this.onNavigateToPage,
  });

  /// Helper function to display the AI diagnosis modal bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required bool isDiagnosing,
    required DiagnosisResult? diagnosisResult,
    String streamedDiagnosisText = '',
    List<dynamic> lastQuizWrongIds = const [],
    required Map<String, dynamic> currentUser,
    VoidCallback? onClose,
    void Function(List<dynamic> wrongIds)? onReviewWrongQuestions,
    void Function(int pageIndex, String title)? onNavigateToPage,
    void Function(StateSetter setter)? onSetSheetState,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          onSetSheetState?.call(setSheetState);
          return AiDiagnosisSheet(
            isDiagnosing: isDiagnosing,
            diagnosisResult: diagnosisResult,
            streamedDiagnosisText: streamedDiagnosisText,
            lastQuizWrongIds: lastQuizWrongIds,
            currentUser: currentUser,
            onClose: () {
              if (onClose != null) {
                onClose();
              } else {
                Navigator.pop(context);
              }
            },
            onReviewWrongQuestions: (wrongIds) {
              Navigator.pop(context);
              onReviewWrongQuestions?.call(wrongIds);
            },
            onNavigateToPage: (pageIndex, title) {
              Navigator.pop(context);
              onNavigateToPage?.call(pageIndex, title);
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, sc) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFAF8F6), // Warm background
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Title Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor,
                            const Color(0xFFD7CCC8)
                          ],
                        ).createShader(bounds),
                        child: const Icon(
                          Icons.analytics_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'AI 學習診斷報告',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4E342E),
                        ),
                      ),
                    ],
                  ),
                  if (!isDiagnosing && diagnosisResult != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: diagnosisResult!.isAiGenerated
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFEFEBE9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: diagnosisResult!.isAiGenerated
                              ? const Color(0xFFA5D6A7)
                              : const Color(0xFFD7CCC8),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            diagnosisResult!.isAiGenerated
                                ? Icons.bolt
                                : Icons.settings_applications,
                            size: 14,
                            color: diagnosisResult!.isAiGenerated
                                ? Colors.green.shade700
                                : Colors.brown,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            diagnosisResult!.isAiGenerated
                                ? 'AI 智慧生成'
                                : '本地規則分析',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: diagnosisResult!.isAiGenerated
                                  ? Colors.green.shade700
                                  : Colors.brown,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),

            // Body
            Expanded(
              child: isDiagnosing
                  ? (streamedDiagnosisText.isEmpty
                      ? _buildLoadingState() // 第一個 chunk 還沒來：轉圈
                      : _buildStreamingState(context)) // 逐字顯示串流文字
                  : (diagnosisResult == null
                      ? _buildErrorState()
                      : _buildReportContent(context, sc)),
            ),

            // Bottom Actions
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                            color: Theme.of(context).primaryColor),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (onClose != null) {
                          onClose!();
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      child: Text(
                        '關閉',
                        style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (!isDiagnosing && lastQuizWrongIds.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          if (onReviewWrongQuestions != null) {
                            onReviewWrongQuestions!(lastQuizWrongIds);
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        child: Text(
                          '開始複習錯題 (${lastQuizWrongIds.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 第一個 chunk 還沒來：顯示具體進度條動畫 (非卡死 95% 版本)
  Widget _buildLoadingState() {
    return const DiagnosisLoadingProgress();
  }

  /// 串流進行中：逐字顯示已到達的文字（ListView.builder + 打字機效果）
  Widget _buildStreamingState(BuildContext context) {
    // 將累積文字依行展開
    final lines = streamedDiagnosisText.split('\n');
    return Column(
      children: [
        // 頂部轉圈提示列
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFFFFF8F5),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'AI 導師正在產出診斷內容...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.brown.shade400,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        // 逐行顯示串流文字
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            itemCount: lines.length,
            itemBuilder: (ctx, i) {
              final line = lines[i];
              final isHeader = line.startsWith('[') && line.endsWith(']');
              final isBullet = line.trimLeft().startsWith('•');
              return Padding(
                padding: EdgeInsets.only(
                  bottom: isHeader ? 4 : 3,
                  top: isHeader && i > 0 ? 12 : 0,
                ),
                child: Text(
                  line,
                  style: TextStyle(
                    fontSize: isHeader ? 13.5 : 13,
                    fontWeight: isHeader ? FontWeight.w700 : FontWeight.normal,
                    color: isHeader
                        ? const Color(0xFF6D4C41)
                        : (isBullet ? Colors.black87 : Colors.grey.shade700),
                    height: 1.55,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            const Text(
              '無法生成診斷報告',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              '可能因為未取得有效的測驗資訊。請嘗試重新測驗。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent(BuildContext context, ScrollController sc) {
    final report = diagnosisResult!;

    return ListView(
      controller: sc,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        if (!report.isAiGenerated)
          FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: Builder(builder: (context) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: currentUser['id'] == 'u4'
                      ? const Color(0xFFFFF3E0)
                      : const Color(0xFFFFFDE7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: currentUser['id'] == 'u4'
                        ? const Color(0xFFFFE0B2)
                        : const Color(0xFFFFF59D),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      currentUser['id'] == 'u4'
                          ? Icons.lock_outline
                          : Icons.info_outline,
                      color: currentUser['id'] == 'u4'
                          ? const Color(0xFFF57C00)
                          : const Color(0xFFFBC02D),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUser['id'] == 'u4'
                                ? '登入解鎖 AI 智慧報告'
                                : '目前內建 AI 額度已達上限',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: currentUser['id'] == 'u4'
                                  ? const Color(0xFFE65100)
                                  : const Color(0xFFF57F17),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentUser['id'] == 'u4'
                                ? '訪客帳戶目前不支援 AI 智慧診斷功能。立即註冊或登入正式帳號，即可啟用由代理人助理生成的客製化學習診斷與複習建議！'
                                : '目前測試金鑰為所有使用者共享，今日免費額度已耗盡。系統已自動切換為「本地規則分析」報告，造成不便敬請見諒！',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF5D4037),
                                height: 1.4),
                          ),
                          if (currentUser['id'] == 'u4') ...[
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () {
                                if (onNavigateToPage != null) {
                                  onNavigateToPage!(4, '個人檔案');
                                } else {
                                  Navigator.pop(context);
                                }
                              },
                              child: const Text(
                                '立即去登入/註冊 ➔',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFE65100)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),

        // 1. 本次摘要
        FadeInUp(
          duration: const Duration(milliseconds: 500),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    const Color(0xFF795548)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color:
                        Theme.of(context).primaryColor.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '學習診斷摘要',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  report.summary,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. 待加強單元 (弱項)
        FadeInUp(
          duration: const Duration(milliseconds: 600),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_outlined,
                        color: Colors.orange.shade800, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '待加強單元 (弱項)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.orange.shade900),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (report.weaknesses.isEmpty)
                  Text('無特別明顯弱項',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500))
                else
                  ...report.weaknesses.map((weak) => Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ',
                                style: TextStyle(
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                weak,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade800,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 3. AI 學習建議
        FadeInUp(
          duration: const Duration(milliseconds: 700),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb, color: Color(0xFFFBC02D), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'AI 導師複習建議',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF4E342E)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  report.suggestion,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade800, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 4. 溫馨鼓勵
        FadeInUp(
          duration: const Duration(milliseconds: 800),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFEBE9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD7CCC8)),
            ),
            child: Row(
              children: [
                const Text(
                  '💬',
                  style: TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '"${report.encouragement}"',
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D4037),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
