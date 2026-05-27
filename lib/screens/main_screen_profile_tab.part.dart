part of 'main_screen.dart';

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
              Text(
                _displayName ?? '使用者',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
              _buildDashboardItem(Icons.timer_outlined, '學習時數', '${_todayStudyHours.toStringAsFixed(1)}h'),
              _buildDashboardItem(Icons.check_circle_outline, '完成題目', '$_todayCompletedQuestions 題'),
              _buildDashboardItem(Icons.local_fire_department, '連續天數', '$_streakDays 天'),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor)),
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('深色模式',
                style: TextStyle(fontSize: 14, color: Colors.black87)),
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
            value: widget.currentUser['email'] ?? '未設定',
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
            value: '定期修改更安全',
            onTap: _showChangePasswordDialog,
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
    return _buildModuleContainer(
      context: context,
      title: '互動紀錄',
      child: Column(
        children: [
          _buildProfileTile(
            context: context,
            icon: Icons.article_outlined,
            label: '我的貼文',
            value: '查看已發佈的社群文章與筆記',
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
        ],
      ),
    );
  }

  Widget _buildLearningProgressModule(BuildContext context) {
    return _buildModuleContainer(
      context: context,
      title: '學習歷程 (本週時數)',
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildSimpleChart(context),
          const SizedBox(height: 16),
          Text('本週累計：$_weeklyTotalHours 小時',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSimpleChart(BuildContext context) {
    final List<String> days = ['一', '二', '三', '四', '五', '六', '日'];
    
    // 找出本週最高時數，作為比例尺分母（最低為 3.0，防止分母為 0 或過小）
    double maxHour = _weeklyHoursList.reduce((a, b) => a > b ? a : b);
    if (maxHour < 3.0) maxHour = 3.0;

    const double chartMaxHeight = 100.0; // 圖表最大高度

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // 基準參考虛線 (例如：每日學習目標 1.5h)
            Positioned(
              bottom: (1.5 / maxHour) * chartMaxHeight,
              left: 0,
              right: 0,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).primaryColor.withOpacity(0.2),
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
                final double hours = _weeklyHoursList[i];
                final double barHeight = (hours / maxHour) * chartMaxHeight;
                final bool isToday = (i == DateTime.now().weekday - 1);
                final bool isSelected = (_selectedBarIndex == i);

                return GestureDetector(
                  onTap: () {
                    _update(() {
                      _selectedBarIndex = i;
                    });
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 點擊顯示的時數泡泡 Tooltip
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: isSelected ? 1.0 : 0.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${hours.toStringAsFixed(1)}h',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      
                      // 柱狀圖本體
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 14,
                        height: barHeight < 4 ? 4 : barHeight,
                        decoration: BoxDecoration(
                          gradient: isToday
                              ? LinearGradient(
                                  colors: [Theme.of(context).primaryColor, const Color(0xFFFFB74D)],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                )
                              : LinearGradient(
                                  colors: [Colors.grey.shade300, Colors.grey.shade400],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: isToday
                              ? [
                                  BoxShadow(
                                    color: Theme.of(context).primaryColor.withOpacity(0.3),
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
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday ? Theme.of(context).primaryColor : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ],
    );
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
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
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
                        fontSize: 14, color: valueColor ?? Colors.black87)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
        ],
      ),
    );
  }
}
