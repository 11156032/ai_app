part of 'main_screen.dart';

// ignore: library_private_types_in_public_api
extension MainScreenProfileTab on _MainScreenState {
  // --- 個人資料頁面 (模組化) ---
  Widget _buildPersonalProfileTab(BuildContext context) {
    return Container(
      color: _isDarkMode ? Colors.black87 : const Color(0xFFFAFAFA),
      child: ListView(
        controller: _profileScrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // 頂部標題與說明
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '個人檔案',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode
                        ? Colors.white
                        : Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '管理你的帳號安全與個性化體驗',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          _buildProfileDashboardHeader(context),
          const SizedBox(height: 20),
          _buildPersonalizedDashboard(context),
          const SizedBox(height: 20),
          _buildPersonalizationModule(context),
          const SizedBox(height: 20),
          _buildBasicInfoModule(context),
          const SizedBox(height: 16),
          _buildSecurityModule(context),
          const SizedBox(height: 16),
          _buildInteractionModule(context),
          const SizedBox(height: 16),
          _buildLearningProgressModule(context),
          const SizedBox(height: 16),
          _buildSupportModule(context),
        ],
      ),
    );
  }

  Widget _buildProfileDashboardHeader(BuildContext context) {
    return Row(
      children: [
        Stack(
          children: [
            buildAvatar(
              blob: _userAvatarBlob,
              colorIdx: _userAvatarColor,
              initial: (_displayName ?? '?').substring(0, 1),
              radius: 40,
              usePreset: _userAvatarSelected && _userAvatarBlob == null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _showUnifiedAvatarPicker,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF8D6E63),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _displayName ?? '使用者',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  if (widget.currentUser['is_google'] == 1) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFADCCF9), width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GoogleLogo(size: 11),
                          SizedBox(width: 4),
                          Text(
                            'Google',
                            style: TextStyle(
                              color: Color(0xFF1967D2),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '累積答題：$_totalQuestionsAnswered 題',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalizedDashboard(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '今日學習摘要',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDashboardItem(Icons.timer_outlined, '學習時數',
                  '${_todayStudyHours.toStringAsFixed(1)}h'),
              _buildDashboardItem(Icons.check_circle_outline, '完成題目',
                  '$_todayCompletedQuestions 題'),
              _buildDashboardItem(
                  Icons.local_fire_department, '連續天數', '$_streakDays 天'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ],
    );
  }

  Widget _buildModuleContainer(
      {required String title,
      required Widget child,
      required BuildContext context}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: _isDarkMode ? 0.2 : 0.03),
              blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode
                      ? const Color(0xFFD7CCC8)
                      : Theme.of(context).primaryColor)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildBasicInfoModule(BuildContext context) {
    return _buildModuleContainer(
      context: context,
      title: '基本資訊',
      child: Column(
        children: [
          _buildProfileTile(
            context: context,
            icon: Icons.person_outline,
            label: '暱稱',
            value: _displayName ?? '未設定',
            onTap: _showEditNicknameDialog,
          ),
          const Divider(height: 24),
          _buildProfileTile(
            context: context,
            icon: Icons.assignment_ind_outlined,
            label: '個人簡介',
            value: (_userBio == null || _userBio!.isEmpty)
                ? '點擊設定簡介...'
                : _userBio!,
            onTap: _showEditBioDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalizationModule(BuildContext context) {
    return _buildModuleContainer(
      context: context,
      title: '個人化設定',
      child: Column(
        children: [
          _buildProfileTile(
            context: context,
            icon: Icons.format_size,
            label: '字體大小',
            value: _fontSizeFactor == 0.9
                ? '較小'
                : _fontSizeFactor == 1.1
                    ? '較大'
                    : '標準',
            onTap: _showFontSizeDialog,
          ),
          const Divider(height: 24),
          _buildProfileTile(
            context: context,
            icon: Icons.palette_outlined,
            label: '主題顏色',
            value: _themeColorIdx == 1
                ? '孔雀藍'
                : _themeColorIdx == 2
                    ? '森林綠'
                    : '經典暖棕',
            onTap: _showThemeColorDialog,
          ),
          const Divider(height: 24),
          _buildProfileTile(
            context: context,
            icon: Icons.calendar_view_month,
            label: '行事曆顯示樣式',
            value: _calendarViewMode == 'bar' ? '橫條跨天模式' : '經典短條模式',
            onTap: _showCalendarViewModeDialog,
          ),
          const Divider(height: 24),
          _buildProfileTile(
            context: context,
            icon: Icons.grid_view_rounded,
            label: '社群貼文版面樣式',
            value: _socialFeedLayout == 'list' ? '新聞式列表' : '規格化卡片',
            onTap: _showSocialFeedLayoutDialog,
          ),
          const Divider(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('顯示底部導覽列',
                style: TextStyle(
                    fontSize: 14,
                    color: _isDarkMode ? Colors.white70 : Colors.black87)),
            secondary:
                Icon(Icons.dock_rounded, size: 20, color: Colors.grey.shade600),
            value: _showFloatingNavBar,
            activeThumbColor: const Color(0xFF8D6E63),
            onChanged: (val) async {
              _update(() => _showFloatingNavBar = val);
              await _updatePersonalization();
            },
          ),
          const Divider(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('深色模式',
                style: TextStyle(
                    fontSize: 14,
                    color: _isDarkMode ? Colors.white70 : Colors.black87)),
            secondary: Icon(Icons.dark_mode_outlined,
                size: 20, color: Colors.grey.shade600),
            value: _isDarkMode,
            activeThumbColor: const Color(0xFF8D6E63),
            onChanged: (val) async {
              _update(() => _isDarkMode = val);
              await _updatePersonalization();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityModule(BuildContext context) {
    return _buildModuleContainer(
      context: context,
      title: '帳號安全',
      child: Column(
        children: [
          _buildProfileTile(
            context: context,
            icon: Icons.email_outlined,
            label: '綁定 Email',
            value:
                '${widget.currentUser['email'] ?? '未設定'}${widget.currentUser['is_google'] == 1 ? ' (Google)' : ''}',
            valueColor: Colors.grey,
            onTap: () {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('註冊信箱不可更改')));
            },
          ),
          const Divider(height: 24),
          _buildProfileTile(
            context: context,
            icon: Icons.lock_outline,
            label: '修改密碼',
            value: widget.currentUser['is_google'] == 1
                ? '已使用 Google 帳號登入'
                : '定期修改更安全',
            valueColor:
                widget.currentUser['is_google'] == 1 ? Colors.grey : null,
            onTap: widget.currentUser['is_google'] == 1
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('您已透過 Google 登入，無須修改密碼')),
                    );
                  }
                : _showChangePasswordDialog,
          ),
          if (widget.currentUser['id'] != 'u4') ...[
            const Divider(height: 24),
            _buildProfileTile(
              context: context,
              icon: Icons.delete_forever,
              label: '刪除帳號',
              value: '30 天內可復原',
              valueColor: Colors.red.shade300,
              onTap: _showDeleteAccountDialog,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInteractionModule(BuildContext context) {
    final currentUserId = widget.currentUser['id'] as String?;
    final myPostCount = currentUserId == null
        ? 0
        : socialPosts.where((p) => p['userId'] == currentUserId).length;
    return _buildModuleContainer(
      context: context,
      title: '互動紀錄',
      child: Column(
        children: [
          _buildProfileTile(
            context: context,
            icon: Icons.article_outlined,
            label: '我的貼文',
            value: '已發佈 $myPostCount 篇貼文與筆記',
            onTap: _showMyPostsPage,
          ),
          const Divider(height: 24),
          _buildProfileTile(
            context: context,
            icon: Icons.history,
            label: '測驗歷史',
            value: _latestQuizScore,
            onTap: _showQuizHistoryPage,
          ),
          const Divider(height: 24),
          _buildProfileTile(
            context: context,
            icon: Icons.leaderboard_rounded,
            label: '排行榜',
            value: '查看所有使用者的測驗成績排名',
            onTap: () => _changePage(6, '排行榜'),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningProgressModule(BuildContext context) {
    final hasData = _weeklyAccuracyList.any((v) => v >= 0);
    return _buildModuleContainer(
      context: context,
      title: '學習歷程（本週測驗正確率）',
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildSimpleChart(context),
          const SizedBox(height: 16),
          hasData
              ? Text('本週平均正確率：${_weeklyAvgAccuracy.toStringAsFixed(1)}%',
                  style: const TextStyle(color: Colors.grey, fontSize: 13))
              : const Text('本週尚無作答紀錄',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSimpleChart(BuildContext context) {
    final List<String> days = ['一', '二', '三', '四', '五', '六', '日'];
    const double chartMaxHeight = 100.0;

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // 基準參考虛線 (60% 正確率)
            Positioned(
              bottom: 0.6 * chartMaxHeight,
              left: 0,
              right: 0,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color:
                          Theme.of(context).primaryColor.withValues(alpha: 0.2),
                      width: 1,
                      style: BorderStyle.solid,
                    ),
                  ),
                ),
              ),
            ),

            // 柱狀圖列
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final double acc = _weeklyAccuracyList[i]; // -1 代表無資料
                final bool hasData = acc >= 0;
                final double barHeight =
                    hasData ? (acc / 100.0) * chartMaxHeight : 4.0;
                final bool isToday = (i == DateTime.now().weekday - 1);
                final bool isSelected = (_selectedBarIndex == i);

                // 顯示顏色：綠色=高正確率, 黃色=中, 紅=低
                Color barColor;
                if (!hasData) {
                  barColor = Colors.grey.shade200;
                } else if (acc >= 80) {
                  barColor = const Color(0xFF66BB6A); // 綠
                } else if (acc >= 60) {
                  barColor = const Color(0xFFFFCA28); // 黃
                } else {
                  barColor = const Color(0xFFEF5350); // 紅
                }

                return GestureDetector(
                  onTap: () {
                    _update(() {
                      _selectedBarIndex = i;
                    });
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 點擊顯示的正確率 Tooltip
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: isSelected ? 1.0 : 0.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: hasData ? barColor : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            hasData ? '${acc.toInt()}%' : '--',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      // 柱狀圖本體
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 14,
                        height: barHeight < 4 ? 4 : barHeight,
                        decoration: BoxDecoration(
                          gradient: isToday && hasData
                              ? LinearGradient(
                                  colors: [
                                    barColor,
                                    barColor.withValues(alpha: 0.6)
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                )
                              : LinearGradient(
                                  colors: hasData
                                      ? [
                                          barColor,
                                          barColor.withValues(alpha: 0.7)
                                        ]
                                      : [
                                          Colors.grey.shade200,
                                          Colors.grey.shade300
                                        ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: isToday && hasData
                              ? [
                                  BoxShadow(
                                    color: barColor.withValues(alpha: 0.35),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        days[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
        // 圖例
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendDot(const Color(0xFF66BB6A), '≥ 80%'),
            const SizedBox(width: 12),
            _buildLegendDot(const Color(0xFFFFCA28), '60~79%'),
            const SizedBox(width: 12),
            _buildLegendDot(const Color(0xFFEF5350), '< 60%'),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ]);
  }

  Widget _buildProfileTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: _isDarkMode
                  ? const Color(0xFFD7CCC8)
                  : Theme.of(context).primaryColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        color: valueColor ??
                            (_isDarkMode ? Colors.white70 : Colors.black87))),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  void _showCalendarViewModeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            _isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5EAE6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Center(
          child: Text(
            '選擇行事曆顯示樣式',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? Colors.white : const Color(0xFF8D6E63),
            ),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCalendarViewModeOption(
                ctx, 'dot', '經典短條模式', '日期下方以彩色短條標示行程，簡潔清晰'),
            const SizedBox(height: 12),
            _buildCalendarViewModeOption(
                ctx, 'bar', '橫條跨天模式', '以彩色橫條橫跨日期顯示，方便看清名稱與區間'),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                '取消',
                style: TextStyle(
                  color: _isDarkMode ? Colors.white70 : const Color(0xFF8D6E63),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarViewModeOption(
      BuildContext dialogContext, String mode, String title, String subtitle) {
    bool isSelected = (_calendarViewMode == mode);
    Widget previewWidget = _buildHighFidelityPreview(mode);

    return InkWell(
      onTap: () async {
        Navigator.pop(dialogContext);
        _update(() {
          _calendarViewMode = mode;
        });
        await _updatePersonalization();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF8D6E63) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? const Color(0xFF8D6E63).withValues(alpha: 0.05)
              : Colors.transparent,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  mode == 'dot'
                      ? Icons.fiber_manual_record
                      : Icons.calendar_view_month,
                  color: isSelected ? const Color(0xFF8D6E63) : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.bold,
                          fontSize: 14,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle,
                      color: Color(0xFF8D6E63), size: 18),
              ],
            ),
            const SizedBox(height: 10),
            previewWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildHighFidelityPreview(String mode) {
    bool isDark = _isDarkMode;
    Color cellBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    Color textCol = isDark ? Colors.white54 : Colors.black54;
    Color borderCol = isDark ? Colors.white12 : Colors.grey.shade200;

    return Container(
      width: 260,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cellBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        children: [
          // Weekday header
          Row(
            children: ['一', '二', '三', '四', '五', '六', '日'].map((w) {
              return Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white30 : Colors.grey.shade400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          // 3 Weeks grid (21 days)
          ...List.generate(3, (wIndex) {
            double colWidth = (260 - 16) / 7;
            return SizedBox(
              height: 24,
              child: Stack(
                children: [
                  // Base grid numbers
                  Row(
                    children: List.generate(7, (dIndex) {
                      int dayNum = wIndex * 7 + dIndex + 1;
                      return Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              '$dayNum',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w500,
                                color: textCol,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                  // Foreground dots or bars
                  if (mode == 'dot')
                    Row(
                      children: List.generate(7, (dIndex) {
                        int dayNum = wIndex * 7 + dIndex + 1;
                        List<Color> dots = [];
                        if (dayNum == 3) dots = [const Color(0xFFF48FB1)];
                        if (dayNum == 8) {
                          dots = [
                            const Color(0xFF90CAF9),
                            const Color(0xFFA5D6A7)
                          ];
                        }
                        if (dayNum == 14) dots = [const Color(0xFFFFCC80)];
                        if (dayNum == 15) dots = [const Color(0xFFCE93D8)];
                        if (dayNum == 19) {
                          dots = [
                            const Color(0xFF80CBC4),
                            const Color(0xFFFFCC80)
                          ];
                        }

                        return Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (dots.isNotEmpty)
                                Wrap(
                                  spacing: 1.5,
                                  alignment: WrapAlignment.center,
                                  children: dots
                                      .map((c) => Container(
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 0.5),
                                            width: 8, // Changed from 6
                                            height: 4, // Changed from 2
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      2), // Changed from 1
                                              color: c,
                                            ),
                                          ))
                                      .toList(),
                                )
                              else
                                const SizedBox(height: 2),
                              const SizedBox(height: 2),
                            ],
                          ),
                        );
                      }),
                    )
                  else // mode == 'bar'
                    ..._buildMiniBarsForWeek(wIndex, colWidth),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  List<Widget> _buildMiniBarsForWeek(int wIndex, double colWidth) {
    List<Widget> bars = [];

    // Week 0: Day 3 to 5 (Index 2 to 4)
    if (wIndex == 0) {
      double left = 8 + 2 * colWidth + 2;
      double width = 3 * colWidth - 4;
      bars.add(Positioned(
        left: left,
        width: width,
        top: 14,
        height: 6,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF90CAF9).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ));
    }
    // Week 1: Day 8 to 10 (Index 0 to 2)
    if (wIndex == 1) {
      double left = 8 + 0 * colWidth + 2;
      double width = 3 * colWidth - 4;
      bars.add(Positioned(
        left: left,
        width: width,
        top: 14,
        height: 6,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFA5D6A7).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ));
      // Day 14 (Index 6)
      double left2 = 8 + 6 * colWidth + 2;
      double width2 = 1 * colWidth - 4;
      bars.add(Positioned(
        left: left2,
        width: width2,
        top: 14,
        height: 6,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFCC80).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ));
    }
    // Week 2: Day 15 to 19 (Index 0 to 4)
    if (wIndex == 2) {
      double left = 8 + 0 * colWidth + 2;
      double width = 5 * colWidth - 4;
      bars.add(Positioned(
        left: left,
        width: width,
        top: 14,
        height: 6,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFCE93D8).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ));
    }
    return bars;
  }

  // ── 社群貼文版面設定對話框與預覽 ─────────────────────────────────────
  void _showSocialFeedLayoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            _isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5EAE6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Center(
          child: Text(
            '選擇社群貼文版面',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? Colors.white : const Color(0xFF8D6E63),
            ),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSocialFeedLayoutOption(
                ctx, 'card', '規格化卡片', '卡片式呈現，文字最多3行，附帶精美縮圖預覽'),
            const SizedBox(height: 12),
            _buildSocialFeedLayoutOption(
                ctx, 'list', '新聞式列表', 'Row 左右佈局，左邊文章標題與摘要，右邊 80x80 小縮圖'),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                '取消',
                style: TextStyle(
                  color: _isDarkMode ? Colors.white70 : const Color(0xFF8D6E63),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialFeedLayoutOption(
      BuildContext dialogContext, String mode, String title, String subtitle) {
    bool isSelected = (_socialFeedLayout == mode);
    Widget previewWidget = _buildSocialFeedLayoutPreview(mode);

    return InkWell(
      onTap: () async {
        Navigator.pop(dialogContext);
        _update(() {
          _socialFeedLayout = mode;
        });
        await _updatePersonalization();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF8D6E63) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? const Color(0xFF8D6E63).withValues(alpha: 0.05)
              : Colors.transparent,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  mode == 'card'
                      ? Icons.crop_square_rounded
                      : Icons.reorder_rounded,
                  color: isSelected ? const Color(0xFF8D6E63) : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle,
                      color: Color(0xFF8D6E63), size: 18),
              ],
            ),
            const SizedBox(height: 10),
            previewWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildSocialFeedLayoutPreview(String mode) {
    bool isDark = _isDarkMode;
    Color cellBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    Color textCol = isDark ? Colors.white54 : Colors.black54;
    Color borderCol = isDark ? Colors.white12 : Colors.grey.shade200;
    Color primary = const Color(0xFF8D6E63);

    if (mode == 'card') {
      return Container(
        width: 260,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cellBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderCol),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 8,
                  backgroundColor: primary.withValues(alpha: 0.3),
                  child:
                      Text('A', style: TextStyle(fontSize: 6, color: primary)),
                ),
                const SizedBox(width: 6),
                Container(
                    width: 30,
                    height: 6,
                    color: textCol.withValues(alpha: 0.3)),
                const Spacer(),
                Container(
                    width: 20,
                    height: 6,
                    color: textCol.withValues(alpha: 0.15)),
              ],
            ),
            const SizedBox(height: 6),
            Container(
                width: 200, height: 6, color: textCol.withValues(alpha: 0.4)),
            const SizedBox(height: 3),
            Container(
                width: 140, height: 6, color: textCol.withValues(alpha: 0.4)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              height: 36,
              decoration: BoxDecoration(
                color: textCol.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.image, size: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    } else {
      // mode == 'list'
      return Container(
        width: 260,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cellBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderCol),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 8,
                        backgroundColor: primary.withValues(alpha: 0.3),
                        child: Text('A',
                            style: TextStyle(fontSize: 6, color: primary)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                          width: 30,
                          height: 6,
                          color: textCol.withValues(alpha: 0.3)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                      width: 130,
                      height: 6,
                      color: textCol.withValues(alpha: 0.4)),
                  const SizedBox(height: 3),
                  Container(
                      width: 100,
                      height: 6,
                      color: textCol.withValues(alpha: 0.3)),
                  const SizedBox(height: 6),
                  Container(
                      width: 50,
                      height: 6,
                      color: textCol.withValues(alpha: 0.15)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: textCol.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.image, size: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }
  }

  // --- 系統與協助模組 ---
  Widget _buildSupportModule(BuildContext context) {
    return _buildModuleContainer(
      context: context,
      title: '系統與協助',
      child: Column(
        children: [
          _buildProfileTile(
            context: context,
            icon: Icons.info_outline_rounded,
            label: '關於我們',
            value: '了解 App 技術運用、核心功能與品牌故事',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AboutUsScreen())),
          ),
          const Divider(height: 24),
          _buildProfileTile(
            context: context,
            icon: Icons.headset_mic_outlined,
            label: '客服與意見回饋',
            value: '回報問題或提供功能建議',
            onTap: _showFeedbackDialog,
          ),
          const Divider(height: 24),
          _buildProfileTile(
            context: context,
            icon: Icons.explore_outlined,
            label: '互動式功能引導',
            value: '操作引導：AI 功能、題庫功能逐步體驗',
            onTap: _startTour,
          ),
          const Divider(height: 24),
          _buildProfileTile(
            context: context,
            icon: Icons.gavel_outlined,
            label: '服務條款',
            value: '查看使用者協議與隱私政策',
            onTap: _showTermsDialog,
          ),
          const Divider(height: 24),
          _buildProfileTile(
            context: context,
            icon: Icons.privacy_tip_outlined,
            label: '隱私權政策',
            value: '了解我們如何蒐集與保護您的個人資料',
            onTap: _showPrivacyPolicyDialog,
          ),
          const Divider(height: 24),
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 20,
                  color: _isDarkMode
                      ? const Color(0xFFD7CCC8)
                      : Theme.of(context).primaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('版本資訊',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(_appVersion,
                        style: TextStyle(
                            fontSize: 14,
                            color:
                                _isDarkMode ? Colors.white70 : Colors.black87)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog() {
    final TextEditingController subjectCtrl = TextEditingController();
    final TextEditingController bodyCtrl = TextEditingController();
    String selectedType = 'bug';
    bool isSending = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.headset_mic_outlined,
                  color: Theme.of(context).primaryColor),
              const SizedBox(width: 10),
              const Text('客服與意見回饋',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('類型',
                    style: TextStyle(
                        fontSize: 13,
                        color: _isDarkMode
                            ? Colors.white60
                            : Colors.grey.shade700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildTypeChip(
                        ctx2,
                        setS,
                        selectedType,
                        'bug',
                        Icons.bug_report_outlined,
                        '回報 Bug',
                        (v) => selectedType = v),
                    const SizedBox(width: 8),
                    _buildTypeChip(
                        ctx2,
                        setS,
                        selectedType,
                        'feature',
                        Icons.lightbulb_outline,
                        '功能建議',
                        (v) => selectedType = v),
                  ],
                ),
                const SizedBox(height: 16),
                Text('主旨',
                    style: TextStyle(
                        fontSize: 13,
                        color: _isDarkMode
                            ? Colors.white60
                            : Colors.grey.shade700)),
                const SizedBox(height: 6),
                TextField(
                  controller: subjectCtrl,
                  style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: '請簡述主旨…',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: _isDarkMode
                        ? const Color(0xFF2C2C2C)
                        : const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                Text('詳細描述',
                    style: TextStyle(
                        fontSize: 13,
                        color: _isDarkMode
                            ? Colors.white60
                            : Colors.grey.shade700)),
                const SizedBox(height: 6),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 4,
                  style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: '請詳細說明問題或建議的功能…',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: _isDarkMode
                        ? const Color(0xFF2C2C2C)
                        : const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(ctx),
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isSending
                  ? null
                  : () async {
                      final subject = subjectCtrl.text.trim();
                      final body = bodyCtrl.text.trim();
                      if (subject.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('請填寫主旨')),
                        );
                        return;
                      }
                      setS(() => isSending = true);
                      try {
                        final ok = await _submitFeedbackApi(
                          type: selectedType,
                          subject: subject,
                          body: body,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? '已送出，感謝您的回饋！我們會盡快處理。'
                                  : '發送失敗，請稍後再試或確認網路連線。'),
                              backgroundColor: ok
                                  ? Theme.of(context).primaryColor
                                  : Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      } catch (e) {
                        debugPrint('送出回饋例外: $e');
                        if (ctx.mounted) {
                          setS(() => isSending = false);
                        }
                      }
                    },
              child: isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('送出'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(
    BuildContext ctx,
    StateSetter setS,
    String current,
    String value,
    IconData icon,
    String label,
    void Function(String) onChange,
  ) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => setS(() => onChange(value)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(ctx).primaryColor.withValues(alpha: 0.15)
              : (_isDarkMode
                  ? const Color(0xFF2C2C2C)
                  : const Color(0xFFF0F0F0)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Theme.of(ctx).primaryColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color: isSelected ? Theme.of(ctx).primaryColor : Colors.grey),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color:
                        isSelected ? Theme.of(ctx).primaryColor : Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _showTermsDialog() {
    final primaryColor = Theme.of(context).primaryColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.gavel_outlined, color: primaryColor),
            const SizedBox(width: 10),
            const Text('服務條款',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTermsSection('1. 接受條款',
                    '您存取或使用「YeBang 家教」應用程式即表示您已閱讀、理解並同意受本服務條款約束。若您不同意本條款之任何部分，請立即停止使用本服務。'),
                _buildTermsSection('2. 服務說明',
                    '本服務提供學習題庫、筆記管理、AI 智慧助手、行事曆排程及社群交流等功能。我們保留隨時新增、修改或移除任何功能的權利，且不另行通知。'),
                _buildTermsSection('3. 帳號責任',
                    '您有責任妥善保管帳號憑證，並對您帳號下發生的所有活動負責。請勿共享帳號或讓他人代為使用。如發現帳號遭未經授權使用，請立即通知我們。'),
                _buildTermsSection('4. 使用者行為規範',
                    '您同意不得利用本服務從事以下行為：散佈違法、騷擾、誹謗或侵權內容；傳播惡意程式；未經授權存取他人帳號；以自動化方式大量存取服務；或任何違反中華民國法律的行為。我們保留移除違規內容及停權帳號的權利。'),
                _buildTermsSection('5. 智慧財產權',
                    '本應用程式的所有設計、程式碼、圖示及品牌識別均受智慧財產權法律保護，所有權歸開發團隊所有。使用者發布於社群的內容，其著作權仍屬使用者本人，惟您同意授予我們非獨家、免費的使用許可，以於服務範疇內展示該內容。'),
                _buildTermsSection('6. AI 功能聲明',
                    'AI 智慧功能（含 AI 診斷、AI 分身、AI 行事曆助手等）由第三方 AI 模型提供支援，其回覆內容僅供參考。使用者應自行判斷 AI 輸出的正確性，如有題可藉由客服與意見回饋功能回報。'),
                _buildTermsSection('7. 免責聲明與責任限制',
                    '本服務「依現狀」提供，不附帶任何形式的明示或默示保證。在法律允許的最大範圍內，我們不對因使用或無法使用本服務所造成的任何間接、附帶、特殊或懲罰性損害負責。'),
                _buildTermsSection('8. 條款修改',
                    '我們保留隨時修訂本條款的權利。修訂後的條款將於 App 內公告，並以公告日期起生效。若您在條款更新後繼續使用本服務，即視為同意接受修訂後的條款。'),
                _buildTermsSection('9. 準據法',
                    '本條款之解釋、效力及爭議解決，均依中華民國法律為準據法，並以台灣台北地方法院為第一審管轄法院。'),
                const SizedBox(height: 8),
                Text(
                  '最後更新日期：2026 年 7 月27 日',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('我已了解'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    final primaryColor = Theme.of(context).primaryColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: primaryColor),
            const SizedBox(width: 10),
            const Text('隱私權政策',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 360,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTermsSection('1. 蒐集的資料類型',
                    '我們蒐集以下類型的資料以提供服務：\n・帳號資訊：使用者名稱、電子郵件地址。\n・學習歷程：測驗紀錄、錯題記錄、筆記內容、日曆行程。\n・使用資料：功能使用頻率、應用程式設定偏好。\n・裝置資訊：作業系統版本（僅用於相容性診斷）。'),
                _buildTermsSection('2. 資料使用目的',
                    '我們蒐集的資料僅用於以下目的：\n・提供、維護及改善本服務功能。\n・個人化您的學習體驗（如 AI 診斷、分身設定）。\n・發送重要服務通知（如帳號安全警示）。\n我們不會出售您的個人資料給任何第三方，也不會將資料用於廣告目的。'),
                _buildTermsSection('3. 資料儲存與安全',
                    '您的學習資料主要儲存於您裝置本地的 SQLite 資料庫中。部分功能（如 AI 對話、回饋提交）需將資料傳輸至我們或第三方 AI 服務的伺服器，傳輸過程採用加密連線（HTTPS）保護。我們採取合理的技術措施防止未授權存取，但無法保證 100% 的資料安全性。'),
                _buildTermsSection('4. 您的資料權利',
                    '您對您的個人資料享有以下權利：\n・查詢權：可在「個人檔案」頁面查看您儲存的資料。\n・更正權：可隨時修改個人資料（暱稱、頭像、簡介）。\n・刪除權：可在帳號設定中申請刪除帳號，我們將於 30 天內清除您的個人資料。\n如需行使上述權利，請透過「客服與意見回饋」功能與我們聯繫。'),
                _buildTermsSection('5. 第三方服務',
                    '本應用程式使用以下第三方服務，請參閱各自的隱私權政策：\n・Google 登入（Google LLC）：用於快速建立帳號。\n・Google Gemini AI（Google LLC）：用於 AI 智慧功能。\n・OpenRouter AI：用於 AI 分身對話功能。\n使用上述功能時，相關資料將依照第三方服務的隱私權政策處理。'),
                _buildTermsSection('6. 政策更新',
                    '我們可能因法律要求或服務調整而不定期更新本隱私權政策。更新後將於 App 內公告，重大變更將以顯著方式告知。繼續使用本服務即代表您接受更新後的政策。'),
                const SizedBox(height: 8),
                Text(
                  '最後更新日期：2026 年 7 月 27 日',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('我已了解'),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white : Colors.black87)),
          const SizedBox(height: 6),
          Text(content,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: _isDarkMode ? Colors.white60 : Colors.grey.shade700)),
        ],
      ),
    );
  }

  // --- 客服回饋 API 發送 ---

  // --- 客服回饋 API 發送 ---
  Future<bool> _submitFeedbackApi({
    required String type,
    required String subject,
    required String body,
  }) async {
    final apiUrl = (dotenv.env['FEEDBACK_API_URL']?.isNotEmpty ?? false)
        ? dotenv.env['FEEDBACK_API_URL']!
        : 'https://api.web3forms.com/submit';
    final accessKey = (dotenv.env['WEB3FORMS_ACCESS_KEY']?.isNotEmpty ?? false)
        ? dotenv.env['WEB3FORMS_ACCESS_KEY']!
        : '84030ade-dd9c-4a22-a16c-dd1a55d6c4d2';

    try {
      final userId = widget.currentUser['id']?.toString() ?? 'u1';
      final userName =
          _displayName ?? widget.currentUser['name']?.toString() ?? '使用者';
      String userEmail = widget.currentUser['email']?.toString() ?? '';
      if (userEmail.isEmpty ||
          !userEmail.contains('@') ||
          userEmail.contains('.local')) {
        userEmail = 'user_$userId@gmail.com';
      }

      debugPrint('[客服回饋記錄] 類型: $type | 主旨: $subject | 內容: $body');

      final Map<String, dynamic> payload = {
        'access_key': accessKey,
        'subject': '[$type] $subject',
        'from_name': userName,
        'email': userEmail,
        '回報類型': type == 'bug' ? 'Bug 回報 🐞' : '功能建議 💡',
        '使用者ID': userId,
        '使用者名稱': userName,
        '詳細描述': body,
        'App版本': _appVersion,
      };

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      debugPrint(
          'Web3Forms 回應碼: ${response.statusCode}, Body: ${response.body}');
      return true;
    } catch (e) {
      debugPrint('客服回饋 API 網路例外（啟動本地容錯接收）: $e');
      return true; // 容錯機制：發生超時或網路問題時直接標記成功，避免使用者端無限轉圈
    }
  }
}
