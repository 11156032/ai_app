import 'package:flutter/material.dart';

class DataStorageScreen extends StatelessWidget {
  const DataStorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('資料儲存架構 (SQLite / Firebase)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // 頂部核心架構概覽
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF00695C), const Color(0xFF00897B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00897B).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.storage_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Local-First 本機優先儲存架構',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '本專案以「本機 SQLite 資料庫」為核心主體，實現極速秒開與 100% 離線可用；外部雲端服務（Firebase / AI API）則負責推播通知與即時 AI 生成。',
                  style: TextStyle(
                      color: Colors.white, fontSize: 13, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 本機儲存 (SQLite)
          _buildStorageCard(
            context: context,
            title: '1. 本機資料庫 (SQLite)',
            tag: '已完整實作 / 核心主體',
            tagColor: const Color(0xFF2E7D32),
            icon: Icons.folder_special_rounded,
            color: const Color(0xFF00897B),
            description:
                '使用 `sqflite` 套件在本機裝置沙盒中建立 `app_database.db`，由 `DatabaseHelper` 統一管理連線。',
            points: [
              '儲存位置：使用者本機手機/模擬器內部儲存空間。',
              '適用場景：個人筆記、錯題紀錄、測驗成績、學習排程、自訂題庫、使用者個人設定。',
              '優點：完全離線可用、查詢速度極快（毫秒級）、不消耗網路流量、保障個人隱私。',
            ],
            extraWidget: _buildSqliteTablesPreview(),
          ),
          const SizedBox(height: 16),

          // 雲端服務 (Firebase 與外部 API)
          _buildStorageCard(
            context: context,
            title: '2. 雲端與推播服務 (Firebase)',
            tag: '推播已接入 / 遠端資料庫待確認',
            tagColor: Colors.orange.shade800,
            icon: Icons.cloud_done_rounded,
            color: const Color(0xFFE65100),
            description:
                '目前專案實際接入 Firebase Cloud Messaging (FCM) 作為推播通道，其餘社群與共享資料現階段透過本機 SQLite 模擬與紀錄。',
            points: [
              '已接入：`firebase_core` (初始化) 與 `firebase_messaging` (推播通知通道)。',
              '待確認 / 未來規劃：Cloud Firestore / Supabase 雲端資料庫同步（目前社群貼文暫由本機 SQLite 儲存）。',
              '外部 API 服務：AI 診斷使用 REST API 端點，語音轉錄使用 Gladia / Groq Whisper 服務。',
            ],
            extraWidget: Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFE0B2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFFE65100)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '注意：不要假設所有資料都在雲端。若要在多台實體機共享貼文或筆記，後續需規劃雲端 DB 同步機制。',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF5D4037),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 兩者對比表格
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'SQLite vs Firebase 分工對照表',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
          ),
          _buildComparisonTable(primaryColor),
        ],
      ),
    );
  }

  Widget _buildStorageCard({
    required BuildContext context,
    required String title,
    required String tag,
    required Color tagColor,
    required IconData icon,
    required Color color,
    required String description,
    required List<String> points,
    Widget? extraWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: tagColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                      fontSize: 10,
                      color: tagColor,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(description,
              style: const TextStyle(
                  fontSize: 13, height: 1.45, color: Color(0xFF424242))),
          const SizedBox(height: 10),
          ...points.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ',
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(p,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF616161),
                              height: 1.4)),
                    ),
                  ],
                ),
              )),
          if (extraWidget != null) extraWidget,
        ],
      ),
    );
  }

  Widget _buildSqliteTablesPreview() {
    final tables = [
      {'name': 'users', 'desc': '帳號、頭像 Blob、代幣點數、VIP'},
      {'name': 'notes', 'desc': '筆記庫標題、Markdown 內容、分類'},
      {'name': 'posts & comments', 'desc': '動態貼文、多層回覆、媒體附件'},
      {'name': 'quiz_results', 'desc': '測驗得分、耗時、錯題清單 JSON'},
      {'name': 'calendar_events', 'desc': '學習排程、每日代辦、番茄鐘'},
      {'name': 'groups & members', 'desc': '讀書會群組、成員角色、邀請碼'},
    ];

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCEDC8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SQLite 主要資料表一覽 (共 30+ 張表)：',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF33691E)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tables.map((t) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t['name']!,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace')),
                    const SizedBox(width: 4),
                    Text('(${t['desc']!})',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade600)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable(Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Table(
          border: TableBorder.symmetric(
              inside: BorderSide(color: Colors.grey.shade200)),
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(2.0),
            2: FlexColumnWidth(2.0),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade100),
              children: const [
                Padding(
                  padding: EdgeInsets.all(10),
                  child: Text('維度',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(10),
                  child: Text('SQLite (本機)',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00897B))),
                ),
                Padding(
                  padding: EdgeInsets.all(10),
                  child: Text('Firebase / 雲端',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE65100))),
                ),
              ],
            ),
            _buildTableRow('儲存位置', '使用者本機裝置內部', 'Google Cloud 雲端伺服器'),
            _buildTableRow('網路需求', '100% 離線可用，無延遲', '需網路連線'),
            _buildTableRow('主要用途', '個人筆記、錯題、歷史成績、排程', '推播通知 (FCM)、多端同步 (規劃中)'),
            _buildTableRow('隱私安全', '資料不出手機，安全性高', '需登入認證與安全規則'),
            _buildTableRow('目前狀態', '✅ 已完整實現並上線運作', '⚠️ FCM 已串接，雲端資料庫待確認'),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableRow(String c1, String c2, String c3) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(c1,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(c2,
              style: const TextStyle(fontSize: 11, color: Color(0xFF424242))),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(c3,
              style: const TextStyle(fontSize: 11, color: Color(0xFF424242))),
        ),
      ],
    );
  }
}
