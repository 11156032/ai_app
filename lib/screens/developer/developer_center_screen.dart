import 'package:flutter/material.dart';
import 'architecture_screen.dart';
import 'data_storage_screen.dart';
import 'data_flow_screen.dart';
import 'architecture_qa_screen.dart';
import 'large_files_screen.dart';

class DeveloperCenterScreen extends StatelessWidget {
  const DeveloperCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          color: Colors.black87,
          onPressed: () => Navigator.pop(context),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Row(
          children: [
            Text('🧑‍💻 ', style: TextStyle(fontSize: 18)),
            Text(
              '開發者中心 · App 架構助手',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
        children: [
          // 頂部歡迎與專案狀態橫幅
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor,
                  primaryColor.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
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
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.code_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YeBang 家教 · 架構導覽儀表板',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '專為開發者與維護者打造的架構地圖',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '架構分層：Screens/Widgets (UI) → Services (邏輯) → Database (存儲)',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 核心功能導航模組
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '架構探索與開發工具',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
          ),

          // 1. 專案架構
          _buildFeatureCard(
            context: context,
            title: '📁 專案架構與目錄分層',
            subtitle: '檢視 lib/ 底下 main, screens, services, widgets, database 等各層職責',
            badge: '目錄樹 / 職責',
            badgeColor: const Color(0xFF1E88E5),
            icon: Icons.account_tree_rounded,
            color: const Color(0xFF1E88E5),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ArchitectureScreen()),
            ),
          ),

          // 2. 資料存儲
          _buildFeatureCard(
            context: context,
            title: '💾 資料存儲架構 (SQLite / Firebase)',
            subtitle: '解析本機 SQLite 30+ 張資料表、離線快取機制與 Firebase 雲端推播定位',
            badge: '本機優先 / DDL',
            badgeColor: const Color(0xFF00897B),
            icon: Icons.storage_rounded,
            color: const Color(0xFF00897B),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DataStorageScreen()),
            ),
          ),

          // 3. 資料流程
          _buildFeatureCard(
            context: context,
            title: '🔄 資料流程與呼叫脈絡',
            subtitle: '互動演繹 Screen → Service → Database 脈絡，含語音、診斷與社群案例',
            badge: '呼叫鏈 / 案例',
            badgeColor: const Color(0xFFE65100),
            icon: Icons.alt_route_rounded,
            color: const Color(0xFFE65100),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DataFlowScreen()),
            ),
          ),

          // 4. 架構問答
          _buildFeatureCard(
            context: context,
            title: '💬 架構問答與常見 FAQ',
            subtitle: '輸入問題即時查詢「如何改登入？」、「Service 是什麼？」並預留 AI 問答介面',
            badge: 'FAQ / 智慧問答',
            badgeColor: const Color(0xFF673AB7),
            icon: Icons.chat_bubble_outline_rounded,
            color: const Color(0xFF673AB7),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ArchitectureQaScreen()),
            ),
          ),

          // 5. 大型檔案監控
          _buildFeatureCard(
            context: context,
            title: '📊 大型檔案盤點與監控',
            subtitle: '盤點 >3,000 行超大檔案（main_screen 等）之職責混雜度與重構建議',
            badge: '行數監控 / 重構建議',
            badgeColor: const Color(0xFFD32F2F),
            icon: Icons.analytics_outlined,
            color: const Color(0xFFD32F2F),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LargeFilesScreen()),
            ),
          ),

          const SizedBox(height: 16),

          // 底部版本資訊
          Center(
            child: Text(
              'YeBang Architecture Assistant · v1.0.0 (Offline Mode)',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: badgeColor,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.grey.shade400, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
