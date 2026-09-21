import 'package:flutter/material.dart';

class LargeFilesScreen extends StatelessWidget {
  const LargeFilesScreen({super.key});

  final List<Map<String, dynamic>> _largeFiles = const [
    {
      'name': 'main_screen.dart',
      'path': 'lib/screens/main_screen.dart',
      'lines': 14754,
      'category': 'Screen 容器',
      'color': Color(0xFFD32F2F),
      'responsibilities': [
        'BottomNavigationBar 4 個主要 Tab 路由切換',
        '行事曆網格與每日日記渲染 (_buildCalendarTab)',
        '排程建立與空檔時間轉換對話框',
        'AI 懸浮對話助理彈窗 (_openChatModal)',
        '主題進階調色盤與深色模式控制',
        '全域大數據與統計載入 (_loadData)',
      ],
      'refactorAdvice': '建議將「行事曆分頁」與「排程對話框」獨立為 tabs/calendar_tab.dart 與 dialogs/。',
    },
    {
      'name': 'main_screen_profile_tab.part.dart',
      'path': 'lib/screens/main_screen_profile_tab.part.dart',
      'lines': 9172,
      'category': 'Part 分片',
      'color': Color(0xFFE64A19),
      'responsibilities': [
        '個人檔案頭像、暱稱與帳號管理',
        '學習成效 FlChart 多維度統計圖表',
        'VIP 會員權益、點數儲值與代幣記錄',
        '系統設定、語系、通知偏好開關',
      ],
      'refactorAdvice': '可將 FlChart 統計圖表區塊與設定選單拆為獨立子 Widget。',
    },
    {
      'name': 'main_screen_social_tab.part.dart',
      'path': 'lib/screens/main_screen_social_tab.part.dart',
      'lines': 5023,
      'category': 'Part 分片',
      'color': Color(0xFFF57C00),
      'responsibilities': [
        '社群動態牆渲染、貼文卡片、標籤分類',
        '讀書會/學習群組清單與加入機制',
        '貼文點讚、收藏、分享互動邏輯',
      ],
      'refactorAdvice': '可將貼文卡片與群組列表抽為獨立元件。',
    },
    {
      'name': 'database_helper.dart',
      'path': 'lib/database/database_helper.dart',
      'lines': 3839,
      'category': 'Database 層',
      'color': Color(0xFF00897B),
      'responsibilities': [
        'SQLite app_database.db 初始化與連線',
        '30+ 張資料表 Schema 建立 (DDL)',
        '資料庫版本升級與 Migration 邏輯',
        '用戶、筆記、社群、錯題等所有 CRUD 函式',
      ],
      'refactorAdvice': '可依功能拆分為 user_tables.dart, note_tables.dart 等 Schema 分檔。',
    },
    {
      'name': 'voice_note_sheet.dart',
      'path': 'lib/widgets/voice_note_sheet.dart',
      'lines': 3610,
      'category': 'Widget 抽屜',
      'color': Color(0xFF388E3C),
      'responsibilities': [
        '即時麥克風音波動畫 CustomPainter',
        '錄音時長計時器與多段音訊快取',
        '即時逐字稿顯示與 AI 重點大綱預覽',
      ],
      'refactorAdvice': '可將音波繪圖器與逐字稿串流分頁抽離。',
    },
    {
      'name': 'notes_screen.dart',
      'path': 'lib/screens/notes_screen.dart',
      'lines': 3296,
      'category': 'Screen 頁面',
      'color': Color(0xFF1976D2),
      'responsibilities': [
        '筆記庫清單、搜尋、分類過濾',
        '心智圖模式節點佈局與縮放',
        'Markdown 筆記即時編輯與儲存',
      ],
      'refactorAdvice': '可將心智圖畫布與筆記卡片獨立封裝。',
    },
    {
      'name': 'group_detail_page.dart',
      'path': 'lib/screens/tabs/group_detail_page.dart',
      'lines': 2750,
      'category': 'Screen 頁面',
      'color': Color(0xFF512DA8),
      'responsibilities': [
        '群組專屬動態牆、置頂公告',
        '群成員角色 (管理員/組員) 權限管理',
        '邀請連結生成與群組設定',
      ],
      'refactorAdvice': '可將成員清單抽屜與群組動態抽離。',
    },
    {
      'name': 'ai_diagnosis_service.dart',
      'path': 'lib/services/ai_diagnosis_service.dart',
      'lines': 2099,
      'category': 'Service 服務',
      'color': Color(0xFFC2185B),
      'responsibilities': [
        'AI 弱點診斷 Prompt 組裝與模型 API 呼叫',
        '測驗錯題分析與雷達圖能力數值計算',
        'Rate Limit 與 Local Fallback 降級演算法',
      ],
      'refactorAdvice': '可將 Prompt 模板與診斷演算法分檔。',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          color: Colors.black87,
          onPressed: () => Navigator.pop(context),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('專案大型檔案盤點與監控',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // 重要提醒 Banner (符合用戶指定要求)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFE082)),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_rounded,
                    color: Color(0xFFF57F17), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '開發者架構核心心法',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '「檔案很大不代表一定有問題，應該進一步確認它負責了多少不同職責。」',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4E342E),
                            height: 1.4),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '重構的精髓在於「低風險、只拆分、不改功能」，拆分前需先釐清狀態傳遞與生命週期。',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF795548),
                            height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 檔案統計概覽
          Row(
            children: [
              _buildMetricCard(
                  '超大型檔案 (>3,000行)', '5 個', const Color(0xFFD32F2F)),
              const SizedBox(width: 10),
              _buildMetricCard(
                  '大型檔案 (1,000-3,000行)', '11 個', const Color(0xFFF57C00)),
              const SizedBox(width: 10),
              _buildMetricCard(
                  '中小型檔案 (<1,000行)', '40+ 個', const Color(0xFF388E3C)),
            ],
          ),
          const SizedBox(height: 20),

          // 大型檔案清單
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '重點關注大型檔案清單：',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
          ),
          ..._largeFiles.map((f) => _buildLargeFileCard(f)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeFileCard(Map<String, dynamic> f) {
    final Color color = f['color'] as Color;
    final responsibilities =
        (f['responsibilities'] as List).cast<String>();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 檔名與行數 Badge
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f['name'] as String,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: Colors.black87),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        f['path'] as String,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '約 ${(f['lines'] as int).toString()} 行',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // 承擔職責
            const Text('涵蓋核心職責：',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 6),
            ...responsibilities.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ',
                          style: TextStyle(
                              color: color, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(r,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF616161),
                                height: 1.35)),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 10),

            // 重構建議
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tips_and_updates_rounded,
                      size: 15, color: Color(0xFF5D4037)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '建議：${f['refactorAdvice']}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF4E342E),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
