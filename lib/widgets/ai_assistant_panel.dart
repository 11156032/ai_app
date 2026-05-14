import 'package:flutter/material.dart';

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
                    if (msg['widgetType'] == 'help_options') {
                      return _buildHelpOptions(setModalState);
                    }
                    if (msg['widgetType'] == 'suggestion_action') {
                      return _buildSuggestionAction(msg, setModalState);
                    }
                    if (msg['widgetType'] == 'date_picker') {
                      return _buildDatePicker(setModalState);
                    }
                    if (msg['widgetType'] == 'color_picker') {
                      return _buildColorPicker(setModalState);
                    }
                    if (msg['widgetType'] == 'skip_button') {
                      return _buildSkipButton(setModalState);
                    }
                    if (msg['widgetType'] == 'post_type_picker') {
                      return _buildPostTypePicker(setModalState);
                    }
                    if (msg['widgetType'] == 'confirm_post') {
                      return _buildPostConfirmation(msg['pendingData'], setModalState);
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


  Widget _buildHelpOptions(StateSetter setModalState) {
    final options = [
      {'i': Icons.forum, 'l': '社群討論', 'v': '社群', 'c': Colors.blue},
      {'i': Icons.history_edu, 'l': '查看社群動態', 'v': '社群動態', 'c': Colors.orange},
      {'i': Icons.calendar_month_outlined, 'l': '新增日曆行程', 'v': '新增行程', 'c': Colors.blueAccent},
      {'i': Icons.dynamic_feed_outlined, 'l': '發佈社群貼文', 'v': '發佈貼文', 'c': Colors.deepOrange},
      {'i': Icons.question_answer_outlined, 'l': '回覆社群留言', 'v': '回覆哪些留言', 'c': Colors.green},
      {'i': Icons.manage_accounts_outlined, 'l': '修改個人資料', 'v': '個人檔案', 'c': Colors.purple},
      {'i': Icons.palette_outlined, 'l': '切換佈景主題', 'v': '切換主題', 'c': Colors.pink},
      {'i': Icons.menu_book_outlined, 'l': '跳轉題庫測驗', 'v': '題庫', 'c': Colors.teal},
    ];
    return Container(
        margin: const EdgeInsets.only(bottom: 16, left: 40, right: 10),
        child: Column(
          children: options
              .map((opt) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => widget.onHandleSubmit(
                          opt['v'] as String, _modalController, setModalState),
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.grey.shade100),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: (opt['c'] as Color).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(opt['i'] as IconData,
                                  size: 20, color: opt['c'] as Color),
                            ),
                            const SizedBox(width: 14),
                            Text(opt['l'] as String,
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600)),
                            const Spacer(),
                            Icon(Icons.arrow_forward_ios,
                                size: 12, color: Colors.grey.shade300),
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

  Widget _buildDatePicker(StateSetter setModalState) {
    return Container(
        margin: const EdgeInsets.only(bottom: 12, left: 40),
        alignment: Alignment.centerLeft,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 18),
          label: const Text('選擇日期與時間'),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF8D6E63),
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20))),
          onPressed: () async {
            DateTime? date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime(2030),
              locale: const Locale('zh', 'TW'),
            );
            if (date != null && mounted) {
              TimeOfDay? time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (time != null && mounted) {
                String timeStr =
                    "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                String dateTimeStr =
                    "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $timeStr";
                widget.onHandleSubmit(dateTimeStr, _modalController, setModalState);
              }
            }
          },
        ));
  }

  Widget _buildColorPicker(StateSetter setModalState) {
    List<Map<String, dynamic>> colors = [
      {'name': '紅色', 'color': const Color(0xFFE57373)},
      {'name': '藍色', 'color': const Color(0xFF64B5F6)},
      {'name': '綠色', 'color': const Color(0xFF81C784)},
      {'name': '黃色', 'color': const Color(0xFFFFD54F)},
    ];
    return Container(
        margin: const EdgeInsets.only(bottom: 12, left: 40),
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          children: colors
              .map((c) => ActionChip(
                    avatar: CircleAvatar(backgroundColor: c['color'], radius: 8),
                    label: Text(c['name']),
                    backgroundColor: Colors.white,
                    onPressed: () {
                      widget.onHandleSubmit(
                          c['name'], _modalController, setModalState);
                    },
                  ))
              .toList(),
        ));
  }
  Widget _buildPostTypePicker(StateSetter setModalState) {
    final types = ['一般', '學習筆記', '心情文章', '分享資料'];
    return Container(
        margin: const EdgeInsets.only(bottom: 12, left: 40),
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          children: types
              .map((t) => ActionChip(
                    label: Text(t),
                    backgroundColor: Colors.white,
                    onPressed: () {
                      widget.onHandleSubmit(t, _modalController, setModalState);
                    },
                  ))
              .toList(),
        ));
  }

  Widget _buildPostConfirmation(Map<String, dynamic> data, StateSetter setModalState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 40, right: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFF8D6E63), width: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.assignment_turned_in_outlined, color: Colors.green, size: 20),
            SizedBox(width: 8),
            Text('確認發佈內容', style: TextStyle(fontWeight: FontWeight.bold))
          ]),
          const SizedBox(height: 10),
          Text('📝 內容：${data['content']}', maxLines: 2, overflow: TextOverflow.ellipsis),
          Text('🏷️ 類型：${data['type']}'),
          Text('⏰ 時間：${data['time']}'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                  onPressed: () => widget.onHandleSubmit('取消發佈', _modalController, setModalState),
                  child: const Text('取消', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8D6E63),
                      foregroundColor: Colors.white),
                  onPressed: () => widget.onHandleSubmit('確認發佈', _modalController, setModalState),
                  child: const Text('確認發佈'))
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSkipButton(StateSetter setModalState) {
    return Container(
        margin: const EdgeInsets.only(bottom: 12, left: 40),
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.skip_next, size: 18),
          label: const Text('跳過此步驟'),
          style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey,
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20))),
          onPressed: () {
            widget.onHandleSubmit('跳過', _modalController, setModalState);
          },
        ));
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
