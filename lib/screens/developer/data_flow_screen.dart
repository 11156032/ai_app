import 'package:flutter/material.dart';

class DataFlowScreen extends StatefulWidget {
  const DataFlowScreen({super.key});

  @override
  State<DataFlowScreen> createState() => _DataFlowScreenState();
}

class _DataFlowScreenState extends State<DataFlowScreen> {
  int _selectedExample = 0;

  final List<Map<String, dynamic>> _examples = [
    {
      'title': '1. 語音筆記建立流程',
      'icon': Icons.mic_rounded,
      'steps': [
        {
          'role': 'User',
          'name': '使用者操作',
          'detail': '點擊主頁麥克風按鈕開始錄音說話',
          'icon': Icons.touch_app_rounded,
          'color': Colors.blue,
        },
        {
          'role': 'Widget',
          'name': 'VoiceNoteSheet',
          'question': '「我要顯示即時聲波動畫與錄音計時器」',
          'detail': '呼叫 VoiceRecognitionService 開啟麥克風錄音串流',
          'icon': Icons.widgets_rounded,
          'color': Color(0xFF43A047),
        },
        {
          'role': 'Service',
          'name': 'GladiaService / AiDiagnosisService',
          'question': '「我要如何將音訊轉為逐字稿並提取重點？」',
          'detail': '傳送音訊 Blob 至轉錄 API，並請求 AI 生成重點大綱 JSON',
          'icon': Icons.miscellaneous_services_rounded,
          'color': Color(0xFFE65100),
        },
        {
          'role': 'Database',
          'name': 'DatabaseHelper (SQLite)',
          'question': '「我要將筆記儲存在 notes 資料表」',
          'detail': '執行 db.insert("notes", {title, content, category, created_at})',
          'icon': Icons.storage_rounded,
          'color': Color(0xFF00897B),
        },
        {
          'role': 'UI Update',
          'name': 'NotesScreen / MainScreen',
          'question': '「刷新筆記清單與即時通知」',
          'detail': '觸發 setState() 刷新 UI，並彈出成功儲存 SnackBar',
          'icon': Icons.check_circle_rounded,
          'color': Color(0xFF2E7D32),
        },
      ],
    },
    {
      'title': '2. 測驗結束與 AI 弱點診斷流程',
      'icon': Icons.psychology_rounded,
      'steps': [
        {
          'role': 'User',
          'name': '使用者交卷',
          'detail': '完成 10 題測驗並點擊「交卷看結果」',
          'icon': Icons.touch_app_rounded,
          'color': Colors.blue,
        },
        {
          'role': 'Screen',
          'name': 'QuestionPracticePage',
          'question': '「我要計算分數並整理錯題 ID」',
          'detail': '計算正確率，打包 wrongQuestionIds 傳遞給 AI 診斷',
          'icon': Icons.dashboard_customize_rounded,
          'color': Color(0xFF1E88E5),
        },
        {
          'role': 'Service',
          'name': 'AiDiagnosisService',
          'question': '「我要如何分析學生的錯誤概念？」',
          'detail': '組裝 Prompt 向 AI 模型發送請求，解析建議與複習計畫',
          'icon': Icons.miscellaneous_services_rounded,
          'color': Color(0xFFE65100),
        },
        {
          'role': 'Database',
          'name': 'DatabaseHelper',
          'question': '「記錄本次測驗成績與診斷報告」',
          'detail': '寫入 quiz_results 與 diagnostic_reports 表',
          'icon': Icons.storage_rounded,
          'color': Color(0xFF00897B),
        },
        {
          'role': 'Screen',
          'name': 'ReviewPage / QuizHistoryPage',
          'question': '「呈現雷達圖與錯題複習按鈕」',
          'detail': '導航至結果報告，使用者可一鍵展開「艾賓浩斯複習」',
          'icon': Icons.auto_awesome_rounded,
          'color': Color(0xFF673AB7),
        },
      ],
    },
    {
      'title': '3. 社群貼文與圖片焦點發佈流程',
      'icon': Icons.forum_rounded,
      'steps': [
        {
          'role': 'User',
          'name': '撰寫貼文與選取圖片',
          'detail': '點擊動態牆「發表貼文」，從相簿選取筆記照片',
          'icon': Icons.touch_app_rounded,
          'color': Colors.blue,
        },
        {
          'role': 'Widget',
          'name': 'ImageFocalPointDialog & CreatePostPage',
          'question': '「我要讓使用者微調縮圖顯示焦點 (Alignment)」',
          'detail': '使用者拖曳滑動調整圖片焦點 Offset(x, y)',
          'icon': Icons.widgets_rounded,
          'color': Color(0xFF43A047),
        },
        {
          'role': 'Service',
          'name': 'MembershipService',
          'question': '「驗證發文權限與 VIP 額度」',
          'detail': '檢查發文是否需要消耗代幣點數或符合群組權限',
          'icon': Icons.miscellaneous_services_rounded,
          'color': Color(0xFFE65100),
        },
        {
          'role': 'Database',
          'name': 'DatabaseHelper',
          'question': '「儲存貼文 Blob 與 attached_data JSON」',
          'detail': '執行 db.insert("posts", {media_blob, attached_data, content})',
          'icon': Icons.storage_rounded,
          'color': Color(0xFF00897B),
        },
        {
          'role': 'UI Update',
          'name': 'SocialTab (動態牆)',
          'question': '「即時插入頂部並重新渲染列表」',
          'detail': '呼叫 onPosted() 回調，動態牆以動畫渲染新貼文卡片',
          'icon': Icons.dynamic_feed_rounded,
          'color': Color(0xFF00897B),
        },
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          color: Colors.black87,
          onPressed: () => Navigator.pop(context),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('App 資料流程與呼叫脈絡',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // 頂部核心架構口訣
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1E88E5), const Color(0xFF1565C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E88E5).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.alt_route_rounded,
                        color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      '三層架構核心問答口訣',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildMottoItem('🖥️ Screen / Widget', '「我要顯示什麼？」',
                    '負責 UI 佈局、使用者手勢與元件動畫'),
                const SizedBox(height: 6),
                _buildMottoItem('⚙️ Service', '「我要怎麼完成這個功能？」',
                    '負責演算法、AI 請求、外部 API 與業務規則'),
                const SizedBox(height: 6),
                _buildMottoItem('💾 Database', '「我要去哪裡讀寫資料？」',
                    '負責 SQLite 資料表存取與資料持久化'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 典型情境示範切換器
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '真實情境呼叫鏈演繹 (點擊切換案例)：',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _examples.asMap().entries.map((e) {
                final isSelected = _selectedExample == e.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(e.value['icon'] as IconData,
                            size: 16,
                            color: isSelected ? Colors.white : primaryColor),
                        const SizedBox(width: 6),
                        Text(e.value['title'] as String),
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedExample = e.key);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // 步驟時間軸渲染
          _buildFlowTimeline(_examples[_selectedExample]),
        ],
      ),
    );
  }

  Widget _buildMottoItem(String layer, String question, String desc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(layer,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(question,
                    style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(desc,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildFlowTimeline(Map<String, dynamic> example) {
    final steps =
        (example['steps'] as List).cast<Map<String, dynamic>>();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              Icon(example['icon'] as IconData,
                  color: Theme.of(context).primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  example['title'] as String,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((entry) {
            final idx = entry.key;
            final step = entry.value;
            final isLast = idx == steps.length - 1;
            final Color color = step['color'] as Color;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左側節點與垂直連線
                  Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: 1.5),
                        ),
                        child: Icon(step['icon'] as IconData,
                            size: 16, color: color),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: Colors.grey.shade300,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // 右側詳細卡片
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '步驟 ${idx + 1} · ${step['role']}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  step['name'] as String,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                          if (step['question'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              step['question'] as String,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            step['detail'] as String,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF616161),
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
