import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'common_widgets.dart';

class AIAssistantPanel extends StatefulWidget {
  final List<Map<String, dynamic>> chatLogs;
  final Function(String, TextEditingController, StateSetter) onHandleSubmit;
  final VoidCallback onScrollToBottom;
  final ScrollController chatScrollController;
  final VoidCallback onClearChat;

  const AIAssistantPanel({
    super.key,
    required this.chatLogs,
    required this.onHandleSubmit,
    required this.onScrollToBottom,
    required this.chatScrollController,
    required this.onClearChat,
  });

  @override
  State<AIAssistantPanel> createState() => _AIAssistantPanelState();
}

class _AIAssistantPanelState extends State<AIAssistantPanel> {
  final TextEditingController _modalController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
          color: Color(0xFFF5F0EE),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      child: SafeArea(
        child: Column(
          children: [
            Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  const Text('AI 代理人助理',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8D6E63),
                          fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.cleaning_services_outlined,
                        size: 20, color: Colors.grey),
                    tooltip: '開啟新對話',
                    onPressed: widget.onClearChat,
                  )
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: StatefulBuilder(builder: (context, setModalState) {
                return ListView.builder(
                  controller: widget.chatScrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.chatLogs.length,
                  itemBuilder: (context, i) {
                    var msg = widget.chatLogs[i];

                    // 這裡簡化邏輯，實際應用中可以再將各個 Message Widget 抽離
                    if (msg['widgetType'] == 'intent_suggestions') {
                      return _buildIntentSuggestions(setModalState);
                    }
                    if (msg['widgetType'] == 'help_options') {
                      return _buildHelpOptions(setModalState);
                    }
                    if (msg['widgetType'] == 'suggestion_action') {
                      return _buildSuggestionAction(msg, setModalState);
                    }

                    // ... 這裡可以放入原本 ListView.builder 裡的複雜邏輯 ...
                    // 為了節省篇幅，我們先實作核心框架
                    return _buildMessage(msg, context, setModalState);
                  },
                );
              }),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildIntentSuggestions(StateSetter setModalState) {
    final suggestions = [
      {'l': '🖼️ 換頭像', 'v': '更換頭像'},
      {'l': '👤 改暱稱', 'v': '修改暱稱'},
      {'l': '🎨 換主題', 'v': '切換主題'},
      {'l': '📏 字體', 'v': '字體大小'},
      {'l': '📧 驗證', 'v': 'Email 驗證'},
      {'l': '🔑 改密碼', 'v': '修改密碼'},
    ];
    return Container(
        margin: const EdgeInsets.only(bottom: 12, left: 40),
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions
              .map((s) => ActionChip(
                    label: Text(s['l']!, style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.white,
                    onPressed: () => widget.onHandleSubmit(
                        s['v']!, _modalController, setModalState),
                  ))
              .toList(),
        ));
  }

  Widget _buildHelpOptions(StateSetter setModalState) {
    final options = [
      {'n': '1', 'l': '新增日曆行程', 'v': '新增行程'},
      {'n': '2', 'l': '發佈社群貼文', 'v': '發佈貼文'},
      {'n': '3', 'l': '回覆社群留言', 'v': '回覆哪些留言'},
      {'n': '4', 'l': '修改個人資料', 'v': '個人檔案'},
      {'n': '5', 'l': '切換佈景主題', 'v': '切換主題'},
      {'n': '6', 'l': '跳轉題庫測驗', 'v': '題庫'},
    ];
    return Container(
        margin: const EdgeInsets.only(bottom: 12, left: 40, right: 10),
        child: Column(
          children: options
              .map((opt) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => widget.onHandleSubmit(
                          opt['v']!, _modalController, setModalState),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFF8D6E63).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                  child: Text(opt['n']!,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF8D6E63),
                                          fontWeight: FontWeight.bold))),
                            ),
                            const SizedBox(width: 12),
                            Text(opt['l']!,
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500)),
                            const Spacer(),
                            Icon(Icons.chevron_right,
                                size: 16, color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ));
  }

  Widget _buildSuggestionAction(
      Map<String, dynamic> msg, StateSetter setModalState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 45, right: 10),
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onHandleSubmit(
              msg['suggestionKeyword'] ?? '', _modalController, setModalState),
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8D6E63), Color(0xFFA1887F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF8D6E63).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.touch_app, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  '點擊執行：「${msg['suggestionLabel']}」',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg, BuildContext context,
      StateSetter setModalState) {
    // 如果是圖卡類型且文字為空，直接跳過 _buildMessage，因為它已經在 itemBuilder 處理過了
    if (msg['widgetType'] != null && (msg['text'] == null || msg['text'].isEmpty)) {
      return const SizedBox();
    }
    if ((msg['text'] == null || msg['text'].isEmpty) && msg['widgetType'] == null) {
      return const SizedBox();
    }

    // 這裡放入原本 main_screen.dart 裡面的 messageWidget 邏輯
    return Align(
      alignment: msg['isAI'] ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: msg['isAI'] ? Colors.white : const Color(0xFF8D6E63),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(msg['text'],
            style:
                TextStyle(color: msg['isAI'] ? Colors.black87 : Colors.white)),
      ),
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _modalController,
              decoration: InputDecoration(
                hintText: '去題庫 / 看日曆 / 加行程...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none),
              ),
              onSubmitted: (v) =>
                  widget.onHandleSubmit(v, _modalController, (fn) {
                if (mounted) setState(fn);
              }),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF8D6E63),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () => widget.onHandleSubmit(
                  _modalController.text, _modalController, (fn) {
                if (mounted) setState(fn);
              }),
            ),
          ),
        ],
      ),
    );
  }
}
