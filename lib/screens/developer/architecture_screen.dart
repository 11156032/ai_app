import 'package:flutter/material.dart';

class ArchitectureScreen extends StatefulWidget {
  const ArchitectureScreen({super.key});

  @override
  State<ArchitectureScreen> createState() => _ArchitectureScreenState();
}

class _ArchitectureScreenState extends State<ArchitectureScreen> {
  String? _expandedFolder = 'screens';

  final List<Map<String, dynamic>> _folders = [
    {
      'id': 'main',
      'folder': 'lib/main.dart',
      'title': 'App 進入點與全域初始化',
      'icon': Icons.play_circle_filled_rounded,
      'color': Color(0xFF673AB7),
      'description':
          '負責整套 App 的冷啟動、Flutter Engine 與原生通道綁定、.env 環境變數讀取、Firebase 與本地推播通道註冊、語言與主題設定載入，並決定初始畫面。',
      'responsibilities': [
        'WidgetsFlutterBinding.ensureInitialized()',
        '載入 .env 設定檔',
        '初始化 Firebase 與 PushNotificationService',
        '注入全域主題 ThemeData 與 Locale',
        '定義全域 Provider 或全域狀態',
      ],
      'files': [
        {'name': 'main.dart', 'desc': 'App 啟動根入口，決定登入或主頁路由'},
      ],
    },
    {
      'id': 'screens',
      'folder': 'lib/screens/',
      'title': 'Screens 頁面與導航層',
      'icon': Icons.dashboard_customize_rounded,
      'color': Color(0xFF1E88E5),
      'description':
          '負責 App 的各個功能畫面與頁面導航（Routes），處理頁面級別的生命週期、使用者手勢互動、表單輸入，並透過呼叫 Services 獲取數據。',
      'responsibilities': [
        '提供 Scaffold、AppBar 與頁面佈局',
        '處理頁面間 Navigator.push / pop 導航',
        '收集使用者輸入並向 Services 發送請求',
        '管理頁面局部狀態 (StatefulWidget / State)',
      ],
      'files': [
        {'name': 'main_screen.dart', 'desc': '主頁框架、底部導航欄 (4 Tabs)'},
        {'name': 'home_page.dart', 'desc': '首頁快速捷徑與學習概覽'},
        {'name': 'login_screen.dart', 'desc': '登入與註冊頁面'},
        {'name': 'notes_screen.dart', 'desc': '筆記庫管理與心智圖模式'},
        {'name': 'ai_training_page.dart', 'desc': 'AI 弱點專屬特訓題目練習'},
        {'name': 'ai_analysis_page.dart', 'desc': '學習能力雷達圖與成效分析'},
        {'name': 'ai_upload_paper_page.dart', 'desc': '試卷拍照辨識與試題導入'},
        {'name': 'paper_builder_page.dart', 'desc': '組卷神器、自訂題庫試卷'},
        {'name': 'review_page.dart', 'desc': '艾賓浩斯記憶曲線複習'},
        {'name': 'wrong_questions_page.dart', 'desc': '個人錯題本管理'},
        {'name': 'quiz_history_page.dart', 'desc': '個人測驗歷史成績紀錄'},
        {'name': 'create_post_page.dart', 'desc': '社群貼文與 Learning Pack 發佈'},
        {'name': 'post_reply_page.dart', 'desc': '貼文多層留言討論區'},
        {'name': 'membership_center_screen.dart', 'desc': 'VIP 會員特權與點數管理'},
        {'name': 'about_us_screen.dart', 'desc': '關於我們與品牌故事'},
      ],
    },
    {
      'id': 'services',
      'folder': 'lib/services/',
      'title': 'Services 業務與服務邏輯層',
      'icon': Icons.miscellaneous_services_rounded,
      'color': Color(0xFFE65100),
      'description':
          '負責核心業務邏輯、外部 AI API 串接、語音 STT 處理、會員計算等純邏輯功能。完全不含 BuildContext 或 Widget UI，確保高度可測試性與可重複使用性。',
      'responsibilities': [
        '封裝外部 REST API 與 WebSocket 連線',
        'AI Prompt 組裝、JSON 解析與 Fallback 容錯',
        '音訊錄製與語音即時辨識 (Gladia / Groq)',
        '會員資格驗證、點數儲值與扣點機制',
        '推播通道排程與系統通知發送',
      ],
      'files': [
        {'name': 'ai_diagnosis_service.dart', 'desc': 'AI 學習弱點診斷與筆記重點整理'},
        {'name': 'ai_intent_service.dart', 'desc': '自然語言學習意圖分析'},
        {'name': 'voice_recognition_service.dart', 'desc': '本機即時語音辨識服務'},
        {'name': 'voice_note_service.dart', 'desc': '語音筆記資料管理與轉錄'},
        {'name': 'gladia_transcription_service.dart', 'desc': 'Gladia AI 高精度逐字稿 API'},
        {'name': 'groq_whisper_service.dart', 'desc': 'Groq Whisper 極速轉錄 API'},
        {'name': 'membership_service.dart', 'desc': 'VIP 會員機制與代幣點數管理'},
        {'name': 'push_notification_service.dart', 'desc': '本機通知與 Firebase 推播'},
        {'name': 'app_locale_service.dart', 'desc': '多國語系 (繁/簡/英/日) 切換'},
        {'name': 'app_theme_service.dart', 'desc': '深色模式與自訂色系主題服務'},
        {'name': 'mascot_tip_service.dart', 'desc': '吉祥物學習建議與關懷小貼士'},
      ],
    },
    {
      'id': 'database',
      'folder': 'lib/database/',
      'title': 'Database 本地資料存儲層',
      'icon': Icons.storage_rounded,
      'color': Color(0xFF00897B),
      'description':
          '使用 SQLite (sqflite) 提供本機資料庫持久化儲存。包含資料表建立 (Schema)、版本遷移 (Migration)、CRUD 操作封裝。',
      'responsibilities': [
        '管理 SQLite 連線與資料庫初始化',
        '維護 30+ 張資料表（用戶、筆記、貼文、錯題等）',
        '提供高效 SQL 查詢、過濾與排序',
        '離線資料保存與快取管理',
      ],
      'files': [
        {'name': 'database_helper.dart', 'desc': 'SQLite 資料庫單例管理，包含所有資料表操作'},
      ],
    },
    {
      'id': 'widgets',
      'folder': 'lib/widgets/',
      'title': 'Widgets 共用元件層',
      'icon': Icons.widgets_rounded,
      'color': Color(0xFF43A047),
      'description':
          '跨頁面共用的 UI 元件庫。包含通用頭像、按鈕、心智圖畫布、彈出視窗 (Dialogs)、AI 載入進度條等，避免程式碼重複。',
      'responsibilities': [
        '封裝高頻複用 UI（按鈕、頭像、Toast）',
        '提供自訂 CustomPainter 視覺特效',
        '獨立對話框 (Dialog) 與底部抽屜 (Sheet)',
        '提供統一的 AI 生成進度指示器',
      ],
      'files': [
        {'name': 'common_widgets.dart', 'desc': '全域通用 Avatar、AppBar 與小工具'},
        {'name': 'voice_note_sheet.dart', 'desc': '語音筆記底部錄音與即時文字抽屜'},
        {'name': 'ai_assistant_panel.dart', 'desc': 'AI 懸浮對話助理面板'},
        {'name': 'mindmap_canvas.dart', 'desc': '心智圖互動節點畫布'},
        {'name': 'mascot_companion.dart', 'desc': '吉祥物懸浮互動伴讀 Widget'},
        {'name': 'point_recharge_dialog.dart', 'desc': '點數儲值與方案選擇彈窗'},
        {'name': 'tour_overlay.dart', 'desc': '初次使用功能引導新手導覽'},
        {'name': 'dialogs/image_edit_dialogs.dart', 'desc': '頭像裁切、AI 畫質修復、貼文焦點微調'},
        {'name': 'dialogs/note_organize_widgets.dart', 'desc': 'AI 筆記整理選擇器與大綱結果卡片'},
        {'name': 'loading/ai_loading_indicators.dart', 'desc': 'AI 生成動態提示與平滑進度條'},
      ],
    },
    {
      'id': 'utils',
      'folder': 'lib/utils/',
      'title': 'Utils 工具演算法層',
      'icon': Icons.build_circle_rounded,
      'color': Color(0xFF78909C),
      'description':
          '提供純演算法、輔助運算與跨平台檔案處理工具。不依賴特定 UI，提供純粹的計算與數據轉換。',
      'responsibilities': [
        '圖片畫質分析演算法（模糊度、曝光度、對比度計算）',
        '圖片色彩濾鏡與邊緣強化演算法',
        'Raw RGBA 像素處理與格式轉換',
      ],
      'files': [
        {'name': 'image_enhancer.dart', 'desc': '圖片畫質檢測演算法與 AI 視覺強化器'},
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('專案目錄與架構分層',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // 頂部說明卡片
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_tree_rounded,
                        color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'YeBang 架構設計原則',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '本專案嚴格遵循「Screens/Widgets (呈現) → Services (邏輯) → Database/Utils (儲存與計算)」的三層分工架構，保持程式碼清晰與各層低耦合。',
                  style: TextStyle(
                      color: Colors.white, fontSize: 13, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 核心目錄導覽
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '核心資料夾職責詳解 (點擊展開)',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
          ),

          ..._folders.map((f) => _buildFolderCard(f, primaryColor)),
        ],
      ),
    );
  }

  Widget _buildFolderCard(Map<String, dynamic> f, Color primaryColor) {
    final bool isExpanded = _expandedFolder == f['id'];
    final Color folderColor = f['color'] as Color;
    final List<Map<String, String>> files =
        (f['files'] as List).cast<Map<String, String>>();
    final List<String> responsibilities =
        (f['responsibilities'] as List).cast<String>();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? folderColor.withValues(alpha: 0.5)
              : Colors.grey.shade200,
          width: isExpanded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isExpanded ? 0.06 : 0.02),
            blurRadius: isExpanded ? 10 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 標題列
          InkWell(
            onTap: () {
              setState(() {
                _expandedFolder = isExpanded ? null : f['id'];
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: folderColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(f['icon'] as IconData,
                        color: folderColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              f['folder'] as String,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: folderColor,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${files.length} 個主要檔案',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          f['title'] as String,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),

          // 展開細節區
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 說明
                  Text(
                    f['description'] as String,
                    style: const TextStyle(
                        fontSize: 13, height: 1.5, color: Color(0xFF424242)),
                  ),
                  const SizedBox(height: 14),

                  // 主要職責
                  const Text('主要職責：',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const SizedBox(height: 6),
                  ...responsibilities.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ',
                                style: TextStyle(
                                    color: folderColor,
                                    fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(r,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF616161),
                                      height: 1.4)),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 14),

                  // 包含主要檔案列表
                  const Text('包含主要檔案：',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: files.map((file) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: file == files.last
                                    ? Colors.transparent
                                    : Colors.grey.shade200,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file['name']!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF37474F),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  file['desc']!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
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
            ),
          ],
        ],
      ),
    );
  }
}
