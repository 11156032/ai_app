/// 架構問答與 FAQ 資料模型
class QaItem {
  final String id;
  final String question;
  final String summary;
  final String answer;
  final String category;
  final List<String> tags;
  final List<String> relatedFiles;

  const QaItem({
    required this.id,
    required this.question,
    required this.summary,
    required this.answer,
    required this.category,
    required this.tags,
    this.relatedFiles = const [],
  });
}

/// 開發者架構問答服務
/// 目前採用本地知識庫與關鍵字加權演算法，已預留 Future 介面便於未來接入 AI API
class ArchitectureQaService {
  static final List<QaItem> presetFaqs = [
    const QaItem(
      id: 'service_role',
      category: '架構概念',
      question: 'Service 是什麼？在專案中扮演什麼角色？',
      summary: 'Service 負責封裝與 UI 無關的業務邏輯、外部 API 請求與硬體功能',
      answer: '''
在 YeBang 家教專案中，**Services** 位於 `lib/services/` 目錄。

其主要核心原則：
1. **與 UI 解耦**：Service 不包含任何 `BuildContext` 或 Widget 渲染代碼。
2. **單一職責**：每個 Service 專注於一項核心能力，例如：
   • `ai_diagnosis_service.dart`：負責 AI 弱點診斷與 Prompt 組裝。
   • `gladia_transcription_service.dart` / `groq_whisper_service.dart`：負責語音轉逐字稿 API。
   • `membership_service.dart`：負責會員權限、點數計費與扣點檢查。
   • `push_notification_service.dart`：負責本機通知與 Firebase 推播。
3. **資料中介**：Screen 透過呼叫 Service 取得運算結果或呼叫 API，再由 Service 將資料持久化至 Database。''',
      tags: ['service', '架構', '業務邏輯', 'API'],
      relatedFiles: [
        'lib/services/ai_diagnosis_service.dart',
        'lib/services/membership_service.dart',
        'lib/services/voice_note_service.dart',
      ],
    ),
    const QaItem(
      id: 'database_role',
      category: '資料存儲',
      question: 'Database 是什麼？App 如何儲存與讀取資料？',
      summary: '採用 SQLite (sqflite) 作為本機關聯式資料庫，由 DatabaseHelper 統一管理',
      answer: '''
本專案的本地資料核心位於 `lib/database/database_helper.dart`。

1. **技術實現**：使用 Flutter 的 `sqflite` 套件，在使用者裝置本機建立 `app_database.db` 檔案。
2. **單例模式 (Singleton)**：透過 `DatabaseHelper.instance` 存取唯一的資料庫連線實例，避免多重開啟鎖死。
3. **主要資料表**：
   • `users`：用戶個人資料、頭像 Blob、代幣、會員層級。
   • `notes`：筆記標題、Markdown 內容、分類、標籤、關聯錯題。
   • `posts` / `comments`：社群貼文、多層級回覆、附件。
   • `quiz_results`：測驗成績、答題歷史、錯題 ID 陣列 (JSON)。
   • `calendar_events`：學習排程與行事曆代辦。''',
      tags: ['database', 'sqlite', 'database_helper', '儲存'],
      relatedFiles: [
        'lib/database/database_helper.dart',
      ],
    ),
    const QaItem(
      id: 'sqlite_vs_firebase',
      category: '資料存儲',
      question: 'SQLite 和 Firebase 在本專案有什麼差別與分工？',
      summary: 'SQLite 負責本機快速存取與離線資料；Firebase 負責雲端認證與推播',
      answer: '''
本專案採用 **「本機優先 (Local-First) + 雲端服務輔助」** 的架構：

1. **SQLite (本機本機儲存)**：
   • **用途**：個人筆記、學習紀錄、測驗錯題、離線題庫、本地快取。
   • **優點**：不需網路連線即可秒開讀取，保障個人隱私與離線可用性。
   • **儲存位置**：使用者本機沙盒空間。

2. **Firebase (雲端服務)**：
   • **用途**：`firebase_messaging` (推播通知) 與 `firebase_core`。
   • **用途**：未來雲端資料同步、多裝置備份與跨用戶社群廣場。
   • **狀態標示**：目前核心業務以本機 SQLite 為主，Firebase 專注於通知與雲端擴充介面。''',
      tags: ['sqlite', 'firebase', '雲端', '離線'],
      relatedFiles: [
        'lib/database/database_helper.dart',
        'lib/services/push_notification_service.dart',
      ],
    ),
    const QaItem(
      id: 'main_dart_role',
      category: '架構概念',
      question: 'main.dart 是做什麼的？App 的啟動流程為何？',
      summary: 'main.dart 是 App 的進入點，負責全域初始化、環境變數載入與主題注入',
      answer: '''
`lib/main.dart` 是整個 Flutter App 的進入點 (Entrypoint)：

啟動流程（Sequential Startup）：
1. **WidgetsFlutterBinding.ensureInitialized()**：確保 Flutter 引擎與原生平台 Channel 連線完成。
2. **環境設定載入**：讀取 `.env` 檔案取得 API 金鑰與後端端點。
3. **Service 初始化**：
   • 初始化 Firebase 與推播通道 (`PushNotificationService`)。
   • 檢查本機 SQLite 版本與資料表 (`DatabaseHelper`)。
   • 載入使用者偏好語言 (`AppLocaleService`) 與色彩主題 (`AppThemeService`)。
4. **runApp(const MyApp())**：啟動根 Widget，決定 initialRoute（登入頁 `LoginScreen` 或主頁 `MainScreen`）。''',
      tags: ['main.dart', '啟動流程', '初始化', '進入點'],
      relatedFiles: [
        'lib/main.dart',
      ],
    ),
    const QaItem(
      id: 'screen_vs_widget',
      category: 'UI 開發',
      question: 'Screen 和 Widget 有什麼差別？檔案該放在哪裡？',
      summary: 'Screen 代表完整的頁面路由；Widget 代表可重複使用的局部元件',
      answer: '''
在專案中區分 `screens/` 與 `widgets/` 的準則：

1. **Screens (`lib/screens/`)**：
   • **定義**：代表一個「完整頁面」或「路由導航目的地 (Route)」，通常有自己的 `Scaffold`、`AppBar` 與頁面生命週期。
   • **例如**：`login_screen.dart`、`notes_screen.dart`、`ai_training_page.dart`。

2. **Widgets (`lib/widgets/`)**：
   • **定義**：可在多個 Screen 間「重複使用」的組件，或複雜頁面抽出的獨立子模組。
   • **例如**：
     - `common_widgets.dart` (通用 Avatar、按鈕)
     - `ai_assistant_panel.dart` (懸浮對話面板)
     - `dialogs/` (頭像裁切、圖片修復視窗)
     - `loading/` (AI 生成中旋轉動畫與進度條)''',
      tags: ['screen', 'widget', '路由', '元件'],
      relatedFiles: [
        'lib/widgets/common_widgets.dart',
        'lib/screens/notes_screen.dart',
      ],
    ),
    const QaItem(
      id: 'main_screen_size',
      category: '程式維護',
      question: 'main_screen.dart 為什麼行數很多？目前如何組織？',
      summary: '歷史累計整合了首頁、社群、個人中心與行事曆，目前已採用 Part 分片與模組抽離',
      answer: '''
`lib/screens/main_screen.dart` 是 App 最核心的主畫面容器：

1. **為什麼龐大？**
   它負責管理 BottomNavigationBar 的 4 個核心 Tab、AI 對話彈窗、行事曆網格、排程對話框與全域狀態同步。
2. **目前的模組化結構**：
   • 透過 Dart 的 `part` 關鍵字將頁籤分檔：
     - `main_screen_profile_tab.part.dart` (個人中心)
     - `main_screen_social_tab.part.dart` (社群互動)
     - `main_screen_activity_tab.part.dart` (活動中心)
   • 已將獨立子頁面抽離成獨立檔案：
     - `quiz_history_page.dart` (測驗歷史)
     - `create_post_page.dart` (發佈貼文)
     - `post_reply_page.dart` (留言回覆)
     - `ai_loading_indicators.dart` & `image_edit_dialogs.dart`。
3. **維護建議**：新功能優先寫在 `lib/widgets/` 或 `lib/screens/` 獨立檔案，避免向 main_screen 注入過多私人邏輯。''',
      tags: ['main_screen', '大型檔案', 'part', '重構'],
      relatedFiles: [
        'lib/screens/main_screen.dart',
        'lib/screens/main_screen_profile_tab.part.dart',
        'lib/screens/main_screen_social_tab.part.dart',
      ],
    ),
    const QaItem(
      id: 'how_to_modify_login',
      category: '開發指引',
      question: '如果我要修改登入/註冊功能，要先看哪些檔案？',
      summary: '登入功能涵蓋畫面、Google 登入彈窗、背景動畫與使用者 SQLite 記錄',
      answer: '''
修改登入流程的導引地圖：

1. **主畫面與表單驗證**：
   • `lib/screens/login_screen.dart`：登入/註冊切換、帳號密碼輸入、訪客登入按鈕。
2. **Google 登入彈窗**：
   • `lib/screens/login/widgets/google_sign_in_modal.dart`：Google 登入動畫與帳號選擇模擬。
3. **品牌視覺與背景動畫**：
   • `lib/screens/login/widgets/login_brand_logo.dart`：YeBang 品牌幾何葉片動畫。
   • `lib/screens/login/widgets/login_flow_background.dart`：流體漸層背景。
   • `lib/screens/login/widgets/login_success_overlay.dart`：登入成功落葉特效。
4. **資料庫讀寫**：
   • `lib/database/database_helper.dart` 的 `users` 表操作（`query('users')`, `insert('users')`）。''',
      tags: ['登入', 'auth', 'login_screen', '使用者'],
      relatedFiles: [
        'lib/screens/login_screen.dart',
        'lib/screens/login/widgets/google_sign_in_modal.dart',
        'lib/database/database_helper.dart',
      ],
    ),
    const QaItem(
      id: 'how_to_modify_social',
      category: '開發指引',
      question: '如果我要修改社群動態牆或群組功能，要看哪些地方？',
      summary: '社群功能由 Social Tab 分片、群組內頁、貼文發佈頁與留言回覆頁共同組成',
      answer: '''
社群與群組功能模組架構：

1. **動態牆主畫面**：
   • `lib/screens/main_screen_social_tab.part.dart`：社群動態牆、標籤篩選、貼文卡片渲染、按讚與分享。
2. **發文與留言**：
   • `lib/screens/create_post_page.dart`：發佈貼文、附加圖片焦點微調、學習 Pack 打包。
   • `lib/screens/post_reply_page.dart`：多層級回覆留言樹、即時留言發送。
3. **群組討論專區**：
   • `lib/screens/tabs/group_detail_page.dart`：群組內頁動態與群成員。
   • `lib/screens/tabs/create_group_dialog.dart`：建立讀書會/學習群組。
   • `lib/screens/tabs/group_invite_page.dart`：邀請好友加入群組。
4. **資料庫儲存**：
   • SQLite 中的 `posts`, `comments`, `groups`, `group_members` 表。''',
      tags: ['社群', '貼文', '群組', '留言', 'social'],
      relatedFiles: [
        'lib/screens/main_screen_social_tab.part.dart',
        'lib/screens/create_post_page.dart',
        'lib/screens/post_reply_page.dart',
        'lib/screens/tabs/group_detail_page.dart',
      ],
    ),
    const QaItem(
      id: 'how_to_add_ai_feature',
      category: '開發指引',
      question: '如果我要新增一個 AI 智慧功能，標準的實作流程是什麼？',
      summary: '遵循「Service 封裝 API → Database 存快取 → Widget 渲染狀態」三層流程',
      answer: '''
新增 AI 功能的標準推薦路徑：

1. **第一步：建立 Service (`lib/services/my_ai_service.dart`)**
   • 建立 API Client（呼叫 Google Gemini、Groq 或自建端點）。
   • 定義請求 Prompt 模板與 JSON 回傳解析 Data Model。
   • 處理網路超時、Rate Limit 與 Local Fallback 降級機制。
2. **第二步：持久化儲存 (`lib/database/database_helper.dart`)**
   • 若 AI 生成結果需離線檢視（如 AI 診斷報告、摘要），在 SQLite 建立快取欄位。
3. **第三步：UI 狀態與動態呈現 (`lib/widgets/loading/` & `lib/screens/`)**
   • 使用 `ai_loading_indicators.dart` 的進度條提示用戶「AI 運算中」。
   • 生成完成後以卡片或 Markdown 方式渲染結果。''',
      tags: ['ai', '開發流程', 'gemini', 'service'],
      relatedFiles: [
        'lib/services/ai_diagnosis_service.dart',
        'lib/widgets/loading/ai_loading_indicators.dart',
      ],
    ),
  ];

  /// 依搜尋關鍵字進行智慧比對
  static List<QaItem> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return presetFaqs;

    return presetFaqs.where((item) {
      final inQuestion = item.question.toLowerCase().contains(q);
      final inSummary = item.summary.toLowerCase().contains(q);
      final inAnswer = item.answer.toLowerCase().contains(q);
      final inTags = item.tags.any((t) => t.toLowerCase().contains(q));
      final inCategory = item.category.toLowerCase().contains(q);
      return inQuestion || inSummary || inAnswer || inTags || inCategory;
    }).toList();
  }

  /// 依分類過濾
  static List<QaItem> getByCategory(String category) {
    if (category == '全部') return presetFaqs;
    return presetFaqs.where((i) => i.category == category).toList();
  }

  /// 取得所有分類列表
  static List<String> getCategories() {
    final set = <String>{'全部'};
    for (var item in presetFaqs) {
      set.add(item.category);
    }
    return set.toList();
  }

  /// 模擬或未來對接 AI 智慧即時問答 (保留 Future 介面)
  static Future<String> askAiAssistant(String userQuestion) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final matched = search(userQuestion);
    if (matched.isNotEmpty) {
      return '【為您找到最相關的架構說明】\n\n📌 **${matched.first.question}**\n\n${matched.first.answer}';
    }
    return '抱歉，目前在本地架構知識庫中找不到與「$userQuestion」精確匹配的項目。\n\n建議您可以查看「專案架構」或「資料流程」分頁，或嘗試輸入關鍵字如：Service、Database、SQLite、main.dart、登入、社群。';
  }
}
