import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import '../services/ai_diagnosis_service.dart';

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
                  const Text('代理人助理',
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
                    if (msg['widgetType'] == 'time_range_picker') {
                      return _buildTimeRangePicker(setModalState);
                    }
                    if (msg['widgetType'] == 'color_picker') {
                      return _buildColorPicker(setModalState);
                    }
                    if (msg['widgetType'] == 'color_style_picker') {
                      return _buildColorStylePicker(setModalState);
                    }
                    if (msg['widgetType'] == 'color_palette') {
                      return _buildColorPalette(
                          msg['colorStyle'] ?? 'light', setModalState);
                    }
                    if (msg['widgetType'] == 'skip_button') {
                      return _buildSkipButton(setModalState);
                    }
                    if (msg['widgetType'] == 'post_type_picker') {
                      return _buildPostTypePicker(setModalState);
                    }
                    if (msg['widgetType'] == 'confirm_post') {
                      return _buildPostConfirmation(
                          msg['pendingData'], setModalState);
                    }
                    if (msg['widgetType'] == 'ai_loading') {
                      return _buildAiLoading(msg);
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
      {
        'i': Icons.calendar_month_outlined,
        'l': '新增日曆行程',
        'v': '新增行程',
        'c': Colors.blueAccent
      },
      {
        'i': Icons.dynamic_feed_outlined,
        'l': '發佈社群貼文',
        'v': '發佈貼文',
        'c': Colors.deepOrange
      },
      {
        'i': Icons.question_answer_outlined,
        'l': '回覆社群留言',
        'v': '回覆哪些留言',
        'c': Colors.green
      },
      {
        'i': Icons.manage_accounts_outlined,
        'l': '修改個人檔案',
        'v': '個人檔案',
        'c': Colors.purple
      },
      {
        'i': Icons.palette_outlined,
        'l': '切換佈景主題',
        'v': '切換主題',
        'c': Colors.pink
      },
      {
        'i': Icons.menu_book_outlined,
        'l': '跳轉題庫測驗',
        'v': '題庫',
        'c': Colors.teal
      },
      {
        'i': Icons.note_alt_outlined,
        'l': '筆記本管理',
        'v': '筆記本管理',
        'c': Colors.brown
      },
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
                                color:
                                    (opt['c'] as Color).withValues(alpha: 0.1),
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
                    color: const Color(0xFF8D6E63).withValues(alpha: 0.3),
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
                widget.onHandleSubmit(
                    dateTimeStr, _modalController, setModalState);
              }
            }
          },
        ));
  }

  /// 深淺色風格選擇器（進階版）
  Widget _buildColorStylePicker(StateSetter setModalState) {
    const lightPreview = [
      Color(0xFFFFB3C1),
      Color(0xFFFFD6A5),
      Color(0xFFCAFFBF),
      Color(0xFFBDE0FE),
      Color(0xFFE2C2FF)
    ];
    const darkPreview = [
      Color(0xFF8B2635),
      Color(0xFF2D6A4F),
      Color(0xFF1B4F72),
      Color(0xFF7D5A00),
      Color(0xFF4A235A)
    ];

    Widget styleBtn({
      required String icon,
      required String label,
      required String sub,
      required List<Color> grad,
      required String value,
      required List<Color> preview,
      bool isDark = false,
    }) {
      final borderColor = isDark
          ? const Color(0xFF4A7C59).withValues(alpha: 0.45)
          : const Color(0xFFFF8FAB).withValues(alpha: 0.9);
      final shadowColor = isDark
          ? Colors.black.withValues(alpha: 0.38)
          : const Color(0xFFFF8FAB).withValues(alpha: 0.32);
      final textColor = isDark ? Colors.white : const Color(0xFF3E2723);
      final subColor = isDark ? Colors.white60 : const Color(0xFF795548);
      final arrowBg = isDark
          ? Colors.white.withValues(alpha: 0.12)
          : const Color(0xFFFF8FAB).withValues(alpha: 0.18);
      final arrowColor = isDark ? Colors.white54 : const Color(0xFFFF4081);

      return Expanded(
          child: GestureDetector(
        onTap: () =>
            widget.onHandleSubmit(value, _modalController, setModalState),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: grad,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: shadowColor,
                  blurRadius: 14,
                  spreadRadius: 0,
                  offset: const Offset(0, 5))
            ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 28)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                    decoration: BoxDecoration(
                        color: arrowBg, borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.arrow_forward_ios_rounded,
                        size: 11, color: arrowColor),
                  ),
                ]),
            const SizedBox(height: 10),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textColor,
                    letterSpacing: 0.3)),
            const SizedBox(height: 3),
            Text(sub, style: TextStyle(fontSize: 11, color: subColor)),
            const SizedBox(height: 12),
            Row(
                children: preview
                    .map((c) => Container(
                          width: 13,
                          height: 13,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: c.withValues(alpha: 0.45),
                                  blurRadius: 3,
                                  offset: const Offset(0, 2))
                            ],
                          ),
                        ))
                    .toList()),
          ]),
        ),
      ));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14, left: 12, right: 12),
      child: Row(children: [
        styleBtn(
            icon: '🌸',
            label: '淺色系',
            sub: '清淡、輕盈、活潑',
            grad: const [Color(0xFFFFCCDA), Color(0xFFBBE1FF)],
            value: '淺色系',
            preview: lightPreview),
        const SizedBox(width: 12),
        styleBtn(
            icon: '🌲',
            label: '深色系',
            sub: '沉穩、質感、低調',
            grad: const [Color(0xFF1A2A3A), Color(0xFF2E4A3E)],
            value: '深色系',
            preview: darkPreview,
            isDark: true),
      ]),
    );
  }

  /// 進階色盤（含精選色磚 + 彩虹滑桿）
  Widget _buildColorPalette(String style, StateSetter setModalState) {
    final isLight = style == 'light';
    final presets = isLight
        ? <Color>[
            const Color(0xFFFFB3C1),
            const Color(0xFFFFD6A5),
            const Color(0xFFCAFFBF),
            const Color(0xFFBDE0FE),
            const Color(0xFFE2C2FF),
            const Color(0xFFFFF3B0),
          ]
        : <Color>[
            const Color(0xFF8B2635),
            const Color(0xFF2D6A4F),
            const Color(0xFF1B4F72),
            const Color(0xFF7D5A00),
            const Color(0xFF4A235A),
            const Color(0xFF2E4057),
          ];
    final double sat = isLight ? 0.70 : 0.55;
    final double lig = isLight ? 0.82 : 0.35;

    Color hslToColor(double h) {
      final double c = (1 - (2 * lig - 1).abs()) * sat;
      final double x = c * (1 - ((h / 60) % 2 - 1).abs());
      final double m = lig - c / 2;
      double r = 0, g = 0, b = 0;
      if (h < 60) {
        r = c;
        g = x;
        b = 0;
      } else if (h < 120) {
        r = x;
        g = c;
        b = 0;
      } else if (h < 180) {
        r = 0;
        g = c;
        b = x;
      } else if (h < 240) {
        r = 0;
        g = x;
        b = c;
      } else if (h < 300) {
        r = x;
        g = 0;
        b = c;
      } else {
        r = c;
        g = 0;
        b = x;
      }
      return Color.fromARGB(255, ((r + m) * 255).round(),
          ((g + m) * 255).round(), ((b + m) * 255).round());
    }

    Color selectedColor = presets[0];
    double selectedHue = 0.0;
    bool isCustom = false;

    return StatefulBuilder(builder: (ctx, setLocal) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16, left: 12, right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF8D6E63).withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 標題
          Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: selectedColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.palette, color: selectedColor, size: 18),
            ),
            const SizedBox(width: 10),
            Text(isLight ? '🌸 淺色系 色盤' : '🌲 深色系 色盤',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF4E342E))),
          ]),
          const SizedBox(height: 14),
          // 精選色磚
          const Text('精選配色',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
              children: presets
                  .map((c) => Expanded(
                          child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: GestureDetector(
                          onTap: () => setLocal(() {
                            selectedColor = c;
                            isCustom = false;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 36,
                            decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(10),
                              border: (selectedColor == c && !isCustom)
                                  ? Border.all(
                                      color: const Color(0xFF4E342E),
                                      width: 2.5)
                                  : Border.all(color: Colors.transparent),
                              boxShadow: (selectedColor == c && !isCustom)
                                  ? [
                                      BoxShadow(
                                          color: c.withValues(alpha: 0.5),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3))
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      )))
                  .toList()),
          const SizedBox(height: 16),
          // 分隔
          Row(children: [
            const Expanded(child: Divider()),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('自訂顏色',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600))),
            const Expanded(child: Divider()),
          ]),
          const SizedBox(height: 12),
          // 彩虹色相滑桿
          LayoutBuilder(builder: (ctx2, constraints) {
            final sw = constraints.maxWidth;
            final thumbLeft =
                ((selectedHue / 360.0) * sw - 13).clamp(0.0, sw - 26);
            return GestureDetector(
              onHorizontalDragUpdate: (d) {
                final hue = ((d.localPosition.dx / sw) * 360).clamp(0.0, 360.0);
                setLocal(() {
                  selectedHue = hue;
                  selectedColor = hslToColor(hue);
                  isCustom = true;
                });
              },
              onTapDown: (d) {
                final hue = ((d.localPosition.dx / sw) * 360).clamp(0.0, 360.0);
                setLocal(() {
                  selectedHue = hue;
                  selectedColor = hslToColor(hue);
                  isCustom = true;
                });
              },
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      gradient: const LinearGradient(colors: [
                        Color(0xFFFF0000),
                        Color(0xFFFFFF00),
                        Color(0xFF00FF00),
                        Color(0xFF00FFFF),
                        Color(0xFF0000FF),
                        Color(0xFFFF00FF),
                        Color(0xFFFF0000),
                      ]),
                    )),
                Positioned(
                    left: thumbLeft,
                    top: -4,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: selectedColor, width: 4),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4)
                        ],
                      ),
                    )),
              ]),
            );
          }),
          const SizedBox(height: 20),
          // 預覽 + 確認
          Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: selectedColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: selectedColor.withValues(alpha: 0.45),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      '#${selectedColor.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0').substring(2)}',
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4E342E))),
                  Text(isCustom ? '自訂顏色' : '精選配色',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ])),
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 16),
              label: const Text('確認'),
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedColor,
                foregroundColor:
                    isLight ? const Color(0xFF4E342E) : Colors.white,
                elevation: 3,
                shadowColor: selectedColor.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: () => widget.onHandleSubmit(
                  '${selectedColor.toARGB32()}',
                  _modalController,
                  setModalState),
            ),
          ]),
        ]),
      );
    });
  }

  /// 滾輪式「一次選擇開始 + 結束時間」元件
  Widget _buildTimeRangePicker(StateSetter setModalState) {
    final now = DateTime.now();
    // 產生未來 60 天的日期列表
    final dates = List.generate(60, (i) => now.add(Duration(days: i)));
    final hours = List.generate(24, (h) => h);
    final minutes = List.generate(12, (m) => m * 5); // 每 5 分鐘一格

    int selDateIdx = 0;
    int selStartHour = now.hour;
    int selStartMin = (now.minute ~/ 5) * 5;
    int selEndHour = (now.hour + 1) % 24;
    int selEndMin = selStartMin;

    String fmt2(int v) => v.toString().padLeft(2, '0');
    String dateLabel(DateTime d) {
      const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
      final wd = weekdays[d.weekday - 1];
      return '${d.month}/${d.day}（$wd）';
    }

    Widget buildWheel({
      required List items,
      required int initialIndex,
      required void Function(int) onSelected,
      required String Function(dynamic) label,
      double width = 64,
    }) {
      final ctrl = FixedExtentScrollController(initialItem: initialIndex);
      return SizedBox(
        width: width,
        height: 140,
        child: ListWheelScrollView.useDelegate(
          controller: ctrl,
          itemExtent: 38,
          perspective: 0.004,
          diameterRatio: 1.5,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: onSelected,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: items.length,
            builder: (ctx, idx) => Center(
              child: Text(
                label(items[idx]),
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      );
    }

    return StatefulBuilder(builder: (ctx, setLocal) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8D6E63).withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 標題列 ──────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8D6E63).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.schedule,
                      color: Color(0xFF8D6E63), size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  '選擇日期與時段',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF4E342E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── 日期滾輪 ───────────────────────────────────────────────
            const Text('日期',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Stack(
              alignment: Alignment.center,
              children: [
                // 中間選中高亮條
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8D6E63).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                buildWheel(
                  items: dates,
                  initialIndex: 0,
                  onSelected: (i) => selDateIdx = i,
                  label: (d) => dateLabel(d as DateTime),
                  width: double.infinity,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── 開始 / 結束時間並排 ────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: Color(0xFF66BB6A),
                                shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        const Text('開始時間',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ]),
                      const SizedBox(height: 6),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF66BB6A)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              buildWheel(
                                items: hours,
                                initialIndex: selStartHour,
                                onSelected: (i) {
                                  selStartHour = hours[i];
                                  // 若開始 >= 結束，自動往後推 1 小時
                                  if (selStartHour > selEndHour ||
                                      (selStartHour == selEndHour &&
                                          selStartMin >= selEndMin)) {
                                    selEndHour = (selStartHour + 1) % 24;
                                    setLocal(() {});
                                  }
                                },
                                label: (h) => fmt2(h as int),
                              ),
                              const Text(':',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18)),
                              buildWheel(
                                items: minutes,
                                initialIndex: minutes.indexOf(selStartMin),
                                onSelected: (i) => selStartMin = minutes[i],
                                label: (m) => fmt2(m as int),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 分隔箭頭
                const Column(
                  children: [
                    SizedBox(height: 22),
                    Icon(Icons.arrow_forward_ios,
                        size: 14, color: Color(0xFFBCAAA4)),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: Color(0xFFEF5350),
                                shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        const Text('結束時間',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ]),
                      const SizedBox(height: 6),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF5350)
                                  .withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              buildWheel(
                                items: hours,
                                initialIndex: selEndHour,
                                onSelected: (i) => selEndHour = hours[i],
                                label: (h) => fmt2(h as int),
                              ),
                              const Text(':',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18)),
                              buildWheel(
                                items: minutes,
                                initialIndex: minutes.indexOf(selEndMin),
                                onSelected: (i) => selEndMin = minutes[i],
                                label: (m) => fmt2(m as int),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── 確認按鈕 ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('確認時段'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8D6E63),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  final date = dates[selDateIdx];
                  final datePrefix =
                      '${date.year}-${fmt2(date.month)}-${fmt2(date.day)}';
                  final startStr =
                      '$datePrefix ${fmt2(selStartHour)}:${fmt2(selStartMin)}';
                  final endStr =
                      '$datePrefix ${fmt2(selEndHour)}:${fmt2(selEndMin)}';

                  // 用 "|||" 分隔開始與結束，讓 main_screen 解析
                  widget.onHandleSubmit(
                    '$startStr|||$endStr',
                    _modalController,
                    setModalState,
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
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
                    avatar:
                        CircleAvatar(backgroundColor: c['color'], radius: 8),
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
    final typeData = [
      {
        'label': '一般',
        'icon': '💬',
        'desc': '日常分享',
        'color': const Color(0xFF78909C),
        'bg': const Color(0xFFECEFF1),
      },
      {
        'label': '學習筆記',
        'icon': '📝',
        'desc': '記錄成長',
        'color': const Color(0xFF43A047),
        'bg': const Color(0xFFE8F5E9),
      },
      {
        'label': '心情文章',
        'icon': '💭',
        'desc': '抒發心情',
        'color': const Color(0xFF7E57C2),
        'bg': const Color(0xFFEDE7F6),
      },
      {
        'label': '分享資料',
        'icon': '📄',
        'desc': '資源共享',
        'color': const Color(0xFF1E88E5),
        'bg': const Color(0xFFE3F2FD),
      },
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 14, left: 40, right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_outlined,
                    size: 15, color: Color(0xFFF9A825)),
                SizedBox(width: 6),
                Text(
                  '請點選下方貼文類型來繼續 👇',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFF57F17),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: typeData.map((t) {
              final color = t['color'] as Color;
              final bg = t['bg'] as Color;
              return GestureDetector(
                onTap: () => widget.onHandleSubmit(
                    t['label'] as String, _modalController, setModalState),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t['icon'] as String,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 7),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t['label'] as String,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: color)),
                          Text(t['desc'] as String,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: color.withValues(alpha: 0.7))),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPostConfirmation(
      Map<String, dynamic> data, StateSetter setModalState) {
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
            Icon(Icons.assignment_turned_in_outlined,
                color: Colors.green, size: 20),
            SizedBox(width: 8),
            Text('確認發佈內容', style: TextStyle(fontWeight: FontWeight.bold))
          ]),
          const SizedBox(height: 10),
          Text('📝 內容：${data['content']}',
              maxLines: 2, overflow: TextOverflow.ellipsis),
          Text('🏷️ 類型：${data['type']}'),
          Text('⏰ 時間：${data['time']}'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                  onPressed: () => widget.onHandleSubmit(
                      '取消發佈', _modalController, setModalState),
                  child:
                      const Text('取消', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8D6E63),
                      foregroundColor: Colors.white),
                  onPressed: () => widget.onHandleSubmit(
                      '確認發佈', _modalController, setModalState),
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

  Widget _buildAiLoading(Map<String, dynamic> msg) {
    return const _NoteSummaryLoadingBubble();
  }

  Widget _buildMessage(Map<String, dynamic> msg, BuildContext context,
      StateSetter setModalState) {
    // 如果是圖卡類型且文字為空，直接跳過 _buildMessage，因為它已經在 itemBuilder 處理過了
    if (msg['widgetType'] != null &&
        (msg['text'] == null || msg['text'].isEmpty)) {
      return const SizedBox();
    }
    if ((msg['text'] == null || msg['text'].isEmpty) &&
        msg['widgetType'] == null) {
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
            child: Focus(
              onKeyEvent: (FocusNode node, KeyEvent event) {
                final isMobile =
                    !kIsWeb && (Platform.isAndroid || Platform.isIOS);
                if (isMobile) {
                  return KeyEventResult.ignored;
                }
                final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter;
                if (event is KeyDownEvent && isEnter) {
                  if (HardwareKeyboard.instance.isShiftPressed) {
                    final text = _modalController.text;
                    final selection = _modalController.selection;
                    if (selection.start >= 0) {
                      final newText = text.replaceRange(
                          selection.start, selection.end, '\n');
                      _modalController.value = TextEditingValue(
                        text: newText,
                        selection: TextSelection.collapsed(
                            offset: selection.start + 1),
                      );
                    } else {
                      _modalController.text = '$text\n';
                    }
                    return KeyEventResult.handled;
                  } else {
                    widget.onHandleSubmit(
                      _modalController.text,
                      _modalController,
                      (fn) {
                        if (mounted) setState(fn);
                      },
                    );
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: _modalController,
                minLines: 1,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: '去題庫 / 看日曆 / 加行程...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
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

class _AiLoadingTipWidget extends StatefulWidget {
  const _AiLoadingTipWidget();

  @override
  State<_AiLoadingTipWidget> createState() => _AiLoadingTipWidgetState();
}

class _AiLoadingTipWidgetState extends State<_AiLoadingTipWidget> {
  Timer? _timer;
  late String _currentTip;
  int _secondsLeft = 0;

  final List<String> _tips = [
    'AI 整理能幫您快速抓出筆記的核心重點！',
    '整理完後，您可以將摘要直接附加到原筆記中！',
    '有條理的筆記有助於大腦更深層地建立知識連結喔！',
    '利用 AI 摘要後，搭配題目測驗，學習效果會更好！',
    '每隔段時間重新檢視筆記，是克服遺忘曲線的最佳方法！',
  ];

  @override
  void initState() {
    super.initState();
    // Choose a random learning tip
    _currentTip = _tips[DateTime.now().millisecond % _tips.length];
    _updateSecondsLeft();
    if (_secondsLeft > 0) {
      _startTimer();
    }
  }

  void _updateSecondsLeft() {
    final now = DateTime.now();
    if (AiDiagnosisService.nextAvailableTime != null &&
        AiDiagnosisService.nextAvailableTime!.isAfter(now)) {
      _secondsLeft =
          AiDiagnosisService.nextAvailableTime!.difference(now).inSeconds;
    } else {
      _secondsLeft = 0;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _updateSecondsLeft();
        if (_secondsLeft <= 0) {
          _timer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _updateSecondsLeft();
    final bool isRateLimited = _secondsLeft > 0;
    final String icon = isRateLimited ? '⏳' : '💡';
    final String text = isRateLimited
        ? 'AI 目前繁忙，預計於 $_secondsLeft 秒後恢復。將暫以本地算法大綱整理...'
        : _currentTip;

    final Color bgColor =
        isRateLimited ? const Color(0xFFFFF3E0) : const Color(0xFFFFFDE7);
    final Color borderColor =
        isRateLimited ? const Color(0xFFFFE0B2) : const Color(0xFFFFF59D);
    final Color textColor =
        isRateLimited ? const Color(0xFFE65100) : const Color(0xFFF57F17);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteSummaryLoadingBubble extends StatefulWidget {
  const _NoteSummaryLoadingBubble();

  @override
  State<_NoteSummaryLoadingBubble> createState() =>
      _NoteSummaryLoadingBubbleState();
}

class _NoteSummaryLoadingBubbleState extends State<_NoteSummaryLoadingBubble> {
  double _value = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() {
        if (_value < 0.90) {
          _value += 0.03;
          if (_value > 0.90) _value = 0.90;
        } else {
          _value += (0.999 - _value) * 0.05;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8D6E63).withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    '代理人正在為您整理筆記...',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4E342E),
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '${(_value * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF8D6E63),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _value.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD7CCC8), Color(0xFF8D6E63)],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _AiLoadingTipWidget(),
          ],
        ),
      ),
    );
  }
}
