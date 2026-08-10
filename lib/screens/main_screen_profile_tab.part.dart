part of 'main_screen.dart';

// ignore: library_private_types_in_public_api
extension MainScreenProfileTab on _MainScreenState {
  // --- 個人資料頁面 (模組化) ---
  Widget _buildPersonalProfileTab(BuildContext context) {
    return Container(
      color: _isDarkMode ? Colors.black87 : const Color(0xFFFAFAFA),
      child: DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TabBar(
              isScrollable: true,
              labelColor: _isDarkMode ? Colors.white : _currentPrimaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: _currentPrimaryColor,
              dividerColor: Colors.transparent,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              tabs: const [
                Tab(text: '概覽'),
                Tab(text: '設定與安全'),
                Tab(text: '系統協助'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: 概覽與基本資料 + 學習互動
                  ListView(
                    controller: _profileScrollController,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                    children: [
                      _buildProfileDashboardHeader(context),
                      const SizedBox(height: 20),
                      _buildPersonalizedDashboard(context),
                      const SizedBox(height: 20),
                      _buildBasicInfoModule(context),
                      const SizedBox(height: 16),
                      _buildLearningProgressModule(context),
                      const SizedBox(height: 16),
                      _buildInteractionModule(context),
                    ],
                  ),
                  // Tab 2: 偏好設定與安全
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                    children: [
                      _buildPersonalizationModule(context),
                      const SizedBox(height: 16),
                      _buildSecurityModule(context),
                    ],
                  ),
                  // Tab 3: 系統與協助
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                    children: [
                      _buildSupportModule(context),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDashboardHeader(BuildContext context) {
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            buildAvatar(
              blob: _userAvatarBlob,
              colorIdx: _userAvatarColor,
              initial: (_displayName ?? '?').substring(0, 1),
              radius: 40,
              usePreset: _userAvatarSelected && _userAvatarBlob == null,
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: GestureDetector(
                onTap: _showUnifiedAvatarPicker,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _currentPrimaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: Colors.white, size: 12),
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
    bool isFlipped = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return GestureDetector(
          onTap: () {
            setState(() {
              isFlipped = !isFlipped;
            });
          },
          child: TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: isFlipped ? 1 : 0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            builder: (context, double value, child) {
              bool showBack = value > 0.5;
              double angle = value * math.pi;

              Widget content =
                  showBack ? _buildDashboardBack() : _buildDashboardFront();

              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // 透視效果
                  ..rotateX(angle), // 沿 X 軸翻轉 (上下)
                alignment: Alignment.center,
                child: showBack
                    ? Transform(
                        transform: Matrix4.identity()..rotateX(math.pi),
                        alignment: Alignment.center,
                        child: content)
                    : content,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDashboardFront() {
    final primaryColor = _currentPrimaryColor;
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '今日學習摘要',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('點擊翻轉',
                    style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ],
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

  Widget _buildDashboardBack() {
    final baseColor = _currentPrimaryColor;
    final primaryColor = HSLColor.fromColor(baseColor)
        .withHue((HSLColor.fromColor(baseColor).hue + 25) % 360)
        .toColor();

    int totalQuestions = 0;
    int totalSeconds = 0;
    for (var d in _weeklyMatrixData) {
      totalQuestions += (d['total'] as num?)?.toInt() ?? 0;
      totalSeconds += (d['duration'] as num?)?.toInt() ?? 0;
    }
    double weeklyHours = totalSeconds / 3600.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '本週學習數據',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('點擊翻轉',
                    style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDashboardItem(Icons.timer_outlined, '本週時數',
                  '${weeklyHours.toStringAsFixed(1)}h'),
              _buildDashboardItem(
                  Icons.library_books_outlined, '本週題目', '$totalQuestions 題'),
              _buildDashboardItem(
                  Icons.bar_chart, '總題數', '$_totalQuestionsAnswered 題'),
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
                      : _currentPrimaryColor)),
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
            value: _fontSizeFactor <= 1.05
                ? '標準 (預設)'
                : _fontSizeFactor <= 1.25
                    ? '放大 (大)'
                    : '特大 (清晰)',
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
                    : _themeColorIdx == 3
                        ? '暮櫻紫'
                        : _themeColorIdx == 4
                            ? '琥珀橙'
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
            activeThumbColor: _currentPrimaryColor,
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
            activeThumbColor: _currentPrimaryColor,
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
      title: '設定與安全',
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('接收系統通知',
                style: TextStyle(
                    fontSize: 14,
                    color: _isDarkMode ? Colors.white70 : Colors.black87)),
            secondary: Icon(Icons.notifications_active_outlined,
                size: 20, color: Colors.grey.shade600),
            value: _pushNotificationsEnabled,
            activeThumbColor: _currentPrimaryColor,
            onChanged: (val) async {
              _update(() => _pushNotificationsEnabled = val);
              await _updatePersonalization();
              await PushNotificationService().setNotificationsEnabled(val);
            },
          ),
          const Divider(height: 24),
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
    return _LearningProgressCard(
      matrixData: _weeklyMatrixData,
      isDarkMode: _isDarkMode,
      primaryColor: _currentPrimaryColor,
      matrixChartWidget: _buildMatrixChart(context),
      onShowRemedial: (subject) => _showRemedialMaterialSheet(subject),
      moduleContainerBuilder: (title, child) => _buildModuleContainer(
        context: context,
        title: title,
        child: child,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadWrongQuestionDetails(
      String subjectName) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final userId = widget.currentUser['id'];

      String? whereStr = 'subject = ?';
      List<dynamic>? whereArgs = [subjectName];
      if (subjectName == '綜合盲點') {
        whereStr = null;
        whereArgs = null;
      }

      // 優先抓取該科目的「錯題」
      final query = '''
        SELECT q.* 
        FROM wrong_questions w
        JOIN questions q ON w.question_id = q.id
        WHERE w.user_id = ? ${subjectName != '綜合盲點' ? 'AND q.subject = ?' : ''}
        ORDER BY w.created_at DESC
        LIMIT 5
      ''';
      final args = subjectName != '綜合盲點' ? [userId, subjectName] : [userId];
      final rows = await db.rawQuery(query, args);

      if (rows.isEmpty) {
        // 如果沒有錯題，至少抓取該科目的隨機題目來當作上下文，避免 AI 產生無關科目的建議
        final fallbackRows = await db.query('questions',
            where: whereStr, whereArgs: whereArgs, limit: 5);
        return fallbackRows.map((r) => Map<String, dynamic>.from(r)).toList();
      }

      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (_) {
      return [];
    }
  }

  void _showRemedialMaterialSheet(String subjectName) async {
    final bool isDark = _isDarkMode;
    final Color primary = _currentPrimaryColor;

    // Pre-load wrong questions
    final wrongList = await _loadWrongQuestionDetails(subjectName);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RemedialMaterialSheet(
        subjectName: subjectName,
        wrongList: wrongList,
        userId: widget.currentUser['id']?.toString() ?? 'u1',
        isDark: isDark,
        primary: primary,
      ),
    );
  }

  void _showAISnackbar(String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static DateTime? _lastScatterTapTime;

  Widget _buildMatrixChart(BuildContext context) {
    if (_weeklyMatrixData.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('暫無測驗資料', style: TextStyle(color: Colors.grey)),
      );
    }

    // 計算 X 軸最大值 (至少 30 秒)
    double maxX = 30;
    for (var d in _weeklyMatrixData) {
      double time = (d['avgTime'] as num).toDouble();
      if (time > maxX) maxX = time + 5;
    }

    // 先做重疊分群
    final List<Map<String, dynamic>> clusters = [];
    for (var d in _weeklyMatrixData) {
      double acc = (d['accuracy'] as num).toDouble();
      double time = (d['avgTime'] as num).toDouble();

      bool added = false;
      for (var cluster in clusters) {
        double cx = cluster['x'];
        double cy = cluster['y'];
        // 分群距離閾值 (加大範圍，避免圓點重疊難以點選)
        if ((cx - time).abs() <= 4.0 && (cy - acc).abs() <= 15.0) {
          (cluster['items'] as List).add(d);
          added = true;
          break;
        }
      }

      if (!added) {
        clusters.add({
          'x': time,
          'y': acc,
          'items': [d],
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 頂部圖例
        Center(
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              _buildLegendDot(Colors.blue, '熟練度高'),
              _buildLegendDot(Colors.amber.shade700, '猶豫期'),
              _buildLegendDot(Colors.grey.shade600, '粗心'),
              _buildLegendDot(Colors.red, '嚴重盲點'),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 左側 Y 軸標籤（中文直書）
            SizedBox(
              width: 26,
              height: 190,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_upward_rounded,
                        size: 11,
                        color: _isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade700),
                    const SizedBox(height: 3),
                    Text('正',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            height: 1.25,
                            color: _isDarkMode
                                ? Colors.grey.shade300
                                : Colors.grey.shade800)),
                    Text('確',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            height: 1.25,
                            color: _isDarkMode
                                ? Colors.grey.shade300
                                : Colors.grey.shade800)),
                    Text('率',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            height: 1.25,
                            color: _isDarkMode
                                ? Colors.grey.shade300
                                : Colors.grey.shade800)),
                    const SizedBox(height: 3),
                    Text(
                      '(%)',
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── 散點圖
            Expanded(
              child: SizedBox(
                height: 195,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 16, 0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          // Chart
                          Positioned.fill(
                            child: ScatterChart(
                              ScatterChartData(
                                scatterSpots: clusters.map((cluster) {
                                  double cx = cluster['x'];
                                  double cy = cluster['y'];
                                  int count = (cluster['items'] as List).length;

                                  Color color;
                                  if (cy >= 60 && cx <= 15) {
                                    color = Colors.blue;
                                  } else if (cy >= 60 && cx > 15) {
                                    color = Colors.amber.shade700;
                                  } else if (cy < 60 && cx > 15) {
                                    color = Colors.red;
                                  } else {
                                    color = Colors.grey.shade600;
                                  }

                                  return ScatterSpot(
                                    cx.clamp(0.5, maxX),
                                    cy.clamp(2.0, 98.0),
                                    dotPainter: _ClusterDotPainter(
                                      color: color,
                                      count: count,
                                    ),
                                  );
                                }).toList(),
                                minX: 0,
                                maxX: maxX,
                                minY: 0,
                                maxY: 100,
                                borderData: FlBorderData(show: false),
                                gridData: FlGridData(
                                  show: true,
                                  drawHorizontalLine: true,
                                  drawVerticalLine: true,
                                  horizontalInterval: 20,
                                  verticalInterval: 5,
                                  getDrawingHorizontalLine: (value) {
                                    if (value == 60) {
                                      return FlLine(
                                          color: Colors.blue
                                              .withValues(alpha: 0.65),
                                          strokeWidth: 2,
                                          dashArray: [5, 5]);
                                    }
                                    return FlLine(
                                        color: _isDarkMode
                                            ? Colors.grey
                                                .withValues(alpha: 0.15)
                                            : Colors.grey
                                                .withValues(alpha: 0.25),
                                        strokeWidth: 1);
                                  },
                                  getDrawingVerticalLine: (value) {
                                    if (value == 15) {
                                      return FlLine(
                                          color: Colors.blue
                                              .withValues(alpha: 0.65),
                                          strokeWidth: 2,
                                          dashArray: [5, 5]);
                                    }
                                    return FlLine(
                                        color: _isDarkMode
                                            ? Colors.grey
                                                .withValues(alpha: 0.15)
                                            : Colors.grey
                                                .withValues(alpha: 0.25),
                                        strokeWidth: 1);
                                  },
                                ),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 22,
                                      interval: 10,
                                      getTitlesWidget: (value, meta) {
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            '${value.toInt()}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: _isDarkMode
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade800,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 28,
                                      interval: 20,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          '${value.toInt()}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: _isDarkMode
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade800,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  rightTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                ),
                                scatterTouchData: ScatterTouchData(
                                  enabled: true,
                                  touchSpotThreshold: 12.0,
                                  touchCallback: (FlTouchEvent event,
                                      ScatterTouchResponse? touchResponse) {
                                    if (touchResponse != null &&
                                        touchResponse.touchedSpot != null &&
                                        (event is FlTapUpEvent ||
                                            event is FlTapDownEvent)) {
                                      final now = DateTime.now();
                                      if (_lastScatterTapTime != null &&
                                          now.difference(_lastScatterTapTime!) <
                                              const Duration(
                                                  milliseconds: 500)) {
                                        return;
                                      }
                                      _lastScatterTapTime = now;

                                      final spotIndex =
                                          touchResponse.touchedSpot!.spotIndex;
                                      if (spotIndex >= 0 &&
                                          spotIndex < clusters.length) {
                                        final cluster = clusters[spotIndex];
                                        final items = cluster['items'] as List;

                                        if (items.length > 1) {
                                          _showOverlappedQuizzesSheet(
                                              context,
                                              List<Map<String, dynamic>>.from(
                                                  items));
                                        } else if (items.isNotEmpty) {
                                          _showQuizDetailSheet(
                                              context, items.first);
                                        }
                                      }
                                    }
                                  },
                                  touchTooltipData: ScatterTouchTooltipData(
                                    getTooltipColor: (_) => _isDarkMode
                                        ? const Color(0xFF2C2C2C)
                                        : const Color(0xFF212121),
                                    getTooltipItems:
                                        (ScatterSpot touchedBarSpot) {
                                      return ScatterTooltipItem(
                                        '正確率約: ${touchedBarSpot.y.toInt()}%\n平均耗時約: ${touchedBarSpot.x.toStringAsFixed(1)}s\n(點擊開啟診斷詳情)',
                                        textStyle: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            height: 1.35,
                                            fontWeight: FontWeight.w500),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        // ── 下方 X 軸標籤
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 4),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '平均作答時間 (秒)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode
                        ? Colors.grey.shade300
                        : Colors.grey.shade800,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.arrow_forward_rounded,
                    size: 11,
                    color: _isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade700),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showOverlappedQuizzesSheet(
      BuildContext context, List<Map<String, dynamic>> quizzes) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _isDarkMode
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.layers_rounded,
                        color: _currentPrimaryColor, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      '此區域包含 ${quizzes.length} 個科目內容',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '請點擊欲查看的科目，以開啟詳細診斷與 AI 補強：',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 14),
                ...quizzes.map((item) {
                  final subject = item['subject']?.toString() ?? '測驗';
                  final acc = (item['accuracy'] as num).toDouble();
                  final avgTime = (item['avgTime'] as num).toDouble();
                  final date = item['timestamp']?.toString() ??
                      item['date']?.toString() ??
                      '';

                  Color statusColor;
                  String statusText;
                  if (acc >= 60 && avgTime <= 15) {
                    statusColor = Colors.blue;
                    statusText = '熟練度高';
                  } else if (acc >= 60 && avgTime > 15) {
                    statusColor = Colors.amber.shade700;
                    statusText = '猶豫期';
                  } else if (acc < 60 && avgTime > 15) {
                    statusColor = Colors.red;
                    statusText = '嚴重盲點';
                  } else {
                    statusColor = Colors.grey.shade600;
                    statusText = '粗心';
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: _isDarkMode
                          ? Colors.grey.shade900
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isDarkMode
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 12),
                      title: Row(
                        children: [
                          Text(
                            subject,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color:
                                  _isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        '正確率: ${acc.toInt()}% • 平均耗時: ${avgTime.toStringAsFixed(1)}s${date.isNotEmpty ? " • $date" : ""}',
                        style: TextStyle(
                            fontSize: 12,
                            color: _isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade600),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showQuizDetailSheet(context, item);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQuizDetailSheet(BuildContext context, Map<String, dynamic> entry) {
    final double acc = (entry['accuracy'] as num).toDouble();
    final double avgTime = (entry['avgTime'] as num).toDouble();
    final int total = (entry['total'] as num).toInt();
    final int correct = (entry['correct'] as num? ?? 0).toInt();
    final String subject = entry['subject'] as String? ?? '一般練習';
    final String timeStr = formatRelativeTime(entry['timestamp']);

    String statusText;
    Color statusColor;
    String statusDesc;

    if (acc >= 60 && avgTime <= 15) {
      statusText = '熟練度高';
      statusColor = Colors.blue;
      statusDesc = '答題又快又準！代表該科目解題邏輯已經融會貫通。';
    } else if (acc >= 60 && avgTime > 15) {
      statusText = '猶豫期';
      statusColor = Colors.amber.shade800;
      statusDesc = '正確率達標，但花費較多時間思考，建議多做類似題目提升速度。';
    } else if (acc < 60 && avgTime > 15) {
      statusText = '嚴重盲點';
      statusColor = Colors.red;
      statusDesc = '花費較長時間但答錯率高，代表觀念可能尚未理解，建議重新複習重點。';
    } else {
      statusText = '粗心作答';
      statusColor = Colors.grey.shade700;
      statusDesc = '答題速度快但正確率偏低，可能審題過快或細節粗心造成。';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _isDarkMode
                            ? Colors.grey.shade700
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.analytics_rounded,
                            color: statusColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject,
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _isDarkMode
                                      ? Colors.white
                                      : Colors.black87),
                            ),
                            Text(
                              '測驗時間：$timeStr',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: _isDarkMode
                                      ? Colors.grey.shade400
                                      : Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(
                      color: _isDarkMode
                          ? Colors.grey.shade800
                          : Colors.grey.shade200),
                  const SizedBox(height: 12),

                  // 數據列
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSheetStat('正確率', '${acc.toInt()}%', statusColor),
                      _buildSheetStat('答對/總數', '$correct / $total 題',
                          _isDarkMode ? Colors.white : Colors.black87),
                      _buildSheetStat(
                          '平均時間',
                          '${avgTime.toStringAsFixed(1)} 秒/題',
                          _isDarkMode ? Colors.white : Colors.black87),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 診斷說明卡片
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(
                          alpha: _isDarkMode ? 0.18 : 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      statusDesc,
                      style: TextStyle(
                          fontSize: 13,
                          color: _isDarkMode
                              ? Colors.grey.shade200
                              : Colors.black87,
                          height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 行動按鈕
                  Column(
                    children: [
                      if (acc < 60 || avgTime > 15) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.calendar_today_rounded,
                                size: 16),
                            label: Text('排入複習行程 ($subject)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: statusColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () async {
                              final pickedTime = await showTimePicker(
                                context: context,
                                initialTime:
                                    const TimeOfDay(hour: 18, minute: 0),
                                helpText: '選擇複習行程時間',
                                cancelText: '取消',
                                confirmText: '確定',
                              );
                              if (pickedTime != null && context.mounted) {
                                Navigator.pop(ctx);
                                final db =
                                    await DatabaseHelper.instance.database;
                                final now = DateTime.now();
                                final dateKey =
                                    "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
                                final startHr =
                                    "${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}:00";
                                final endHour = (pickedTime.hour + 1) % 24;
                                final endHr =
                                    "${endHour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}:00";

                                final startStr = "$dateKey $startHr";
                                final endStr = "$dateKey $endHr";

                                await db.insert(
                                    'calendar_events', <String, Object?>{
                                  'user_id': widget.currentUser['id'],
                                  'title': '複習：$subject',
                                  'start_time': startStr,
                                  'end_time': endStr,
                                  'color': '0xFFE53935',
                                });
                                await _loadData();
                                final timeString =
                                    '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
                                _showAISnackbar(
                                    '已將「複習：$subject」排入今日 $timeString 行程！',
                                    Icons.event_available);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('一鍵 AI 生成學習建議'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _currentPrimaryColor,
                            side: BorderSide(color: _currentPrimaryColor),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showRemedialMaterialSheet(subject);
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color:
                    _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
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
              color:
                  _isDarkMode ? const Color(0xFFD7CCC8) : _currentPrimaryColor),
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
              color: _isDarkMode ? Colors.white : _currentPrimaryColor,
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
                  color: _isDarkMode ? Colors.white70 : _currentPrimaryColor,
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
            color: isSelected ? _currentPrimaryColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? _currentPrimaryColor.withValues(alpha: 0.05)
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
                  color: isSelected ? _currentPrimaryColor : Colors.grey,
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
                  Icon(Icons.check_circle,
                      color: _currentPrimaryColor, size: 18),
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
              color: _isDarkMode ? Colors.white : _currentPrimaryColor,
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
                  color: _isDarkMode ? Colors.white70 : _currentPrimaryColor,
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
    Widget previewWidget = _buildSocialFeedLayoutPreview(mode, isSelected);

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
            color: isSelected ? _currentPrimaryColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? _currentPrimaryColor.withValues(alpha: 0.05)
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
                  color: isSelected ? _currentPrimaryColor : Colors.grey,
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
                  Icon(Icons.check_circle,
                      color: _currentPrimaryColor, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            previewWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildSocialFeedLayoutPreview(String mode, bool isSelected) {
    bool isDark = _isDarkMode;
    Color cellBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    Color textCol = isDark ? Colors.white54 : Colors.black54;
    Color borderCol = isDark ? Colors.white12 : Colors.grey.shade200;
    Color primary = _currentPrimaryColor;

    Color imageBgCol = isSelected
        ? primary.withValues(alpha: 0.15)
        : textCol.withValues(alpha: 0.1);
    Color imageIconCol =
        isSelected ? primary.withValues(alpha: 0.7) : Colors.grey;
    Color titleCol =
        isSelected ? primary : (isDark ? Colors.white : Colors.black87);

    if (mode == 'card') {
      return Container(
        width: 260,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cellBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? primary.withValues(alpha: 0.5) : borderCol),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: primary.withValues(alpha: 0.2),
                  child: Text('A',
                      style: TextStyle(
                          fontSize: 10,
                          color: primary,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 6),
                Text('Aden',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: titleCol)),
                const SizedBox(width: 6),
                Text('2 小時前',
                    style: TextStyle(
                        fontSize: 9, color: textCol.withValues(alpha: 0.6))),
                const Spacer(),
                Icon(Icons.more_horiz,
                    size: 14, color: textCol.withValues(alpha: 0.6)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '打包測試\n這是一段用來展示卡片排版的模擬文字內容。',
              style: TextStyle(fontSize: 11, height: 1.4, color: textCol),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: imageBgCol,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.image, size: 24, color: imageIconCol),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.favorite_border,
                    size: 12, color: textCol.withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Text('12',
                    style: TextStyle(
                        fontSize: 9, color: textCol.withValues(alpha: 0.6))),
                const SizedBox(width: 12),
                Icon(Icons.mode_comment_outlined,
                    size: 12, color: textCol.withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Text('3',
                    style: TextStyle(
                        fontSize: 9, color: textCol.withValues(alpha: 0.6))),
                const Spacer(),
                Icon(Icons.bookmark_border,
                    size: 12, color: textCol.withValues(alpha: 0.6)),
              ],
            ),
          ],
        ),
      );
    } else {
      // mode == 'list'
      return Container(
        width: 260,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cellBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? primary.withValues(alpha: 0.5) : borderCol),
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
                        backgroundColor: primary.withValues(alpha: 0.2),
                        child: Text('A',
                            style: TextStyle(
                                fontSize: 8,
                                color: primary,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 4),
                      Text('Aden',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: titleCol)),
                      const SizedBox(width: 4),
                      Text('2 小時前',
                          style: TextStyle(
                              fontSize: 8,
                              color: textCol.withValues(alpha: 0.6))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '國小生複習計畫\n今天幫小朋友整理的重點，大家可以參考看看！',
                    style: TextStyle(fontSize: 10, height: 1.4, color: textCol),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.favorite_border,
                          size: 10, color: textCol.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Text('12',
                          style: TextStyle(
                              fontSize: 8,
                              color: textCol.withValues(alpha: 0.6))),
                      const SizedBox(width: 8),
                      Icon(Icons.mode_comment_outlined,
                          size: 10, color: textCol.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Text('3',
                          style: TextStyle(
                              fontSize: 8,
                              color: textCol.withValues(alpha: 0.6))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: imageBgCol,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.image, size: 20, color: imageIconCol),
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
            icon: Icons.help_outline_rounded,
            label: '常見問題',
            value: '查看大家常問的問題與解答',
            onTap: _showFaqDialog,
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
                      : _currentPrimaryColor),
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
    List<XFile> selectedImages = [];
    final ImagePicker picker = ImagePicker();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.headset_mic_outlined, color: _currentPrimaryColor),
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
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('附加圖片 (最多 3 張)',
                        style: TextStyle(
                            fontSize: 13,
                            color: _isDarkMode
                                ? Colors.white60
                                : Colors.grey.shade700)),
                    TextButton.icon(
                      onPressed: selectedImages.length >= 3
                          ? null
                          : () async {
                              final List<XFile> images =
                                  await picker.pickMultiImage();
                              if (images.isNotEmpty) {
                                setS(() {
                                  selectedImages.addAll(images);
                                  if (selectedImages.length > 3) {
                                    selectedImages =
                                        selectedImages.sublist(0, 3);
                                  }
                                });
                              }
                            },
                      icon: const Icon(Icons.add_photo_alternate, size: 16),
                      label: const Text('選擇圖片'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                if (selectedImages.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: selectedImages.asMap().entries.map((entry) {
                      final int index = entry.key;
                      final XFile file = entry.value;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                              image: DecorationImage(
                                image: FileImage(File(file.path)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            right: -8,
                            top: -8,
                            child: GestureDetector(
                              onTap: () {
                                setS(() {
                                  selectedImages.removeAt(index);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
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
                backgroundColor: _currentPrimaryColor,
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
                          attachments: selectedImages,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? '已送出，感謝您的回饋！我們會盡快處理。'
                                  : '發送失敗，請稍後再試或確認網路連線。'),
                              backgroundColor:
                                  ok ? _currentPrimaryColor : Colors.redAccent,
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

  void _showFaqDialog() {
    final primaryColor = _currentPrimaryColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.help_outline_rounded, color: primaryColor),
            const SizedBox(width: 10),
            const Text('常見問題 (FAQ)',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTermsSection('Q1: 如何將學習紀錄與進度同步？',
                    '您的學習紀錄會與您的帳號連動，只要確保在有網路的環境下登入，系統會自動在背景將進度與雲端同步。如果使用訪客登入，資料只會保留在當前裝置。'),
                _buildTermsSection('Q2: AI 診斷報告的依據是什麼？',
                    '系統會分析您在「錯題本」與「模擬考卷」中的答題狀況，找出常錯單元，並結合 AI 提供專屬的改善建議與複習方向。'),
                _buildTermsSection('Q3: 如何關閉系統通知或提醒？',
                    '您可以在「個人檔案」>「設定與安全」中，找到「接收系統通知」的選項進行開啟或關閉。如果您想關閉手機本身的推播，請至手機的「設定」中調整。'),
                _buildTermsSection('Q4: 可以修改登入的電子信箱嗎？',
                    '目前為了確保帳號安全，註冊或綁定的電子信箱無法直接修改。如果確有修改需求，請透過「客服與意見回饋」與我們聯繫。'),
                _buildTermsSection('Q5: 發現題庫有錯誤怎麼辦？',
                    '若您發現題目或解答有誤，可以點擊題目右上角的「標記」功能，並透過客服表單將該題的截圖回報給我們，我們會盡快由專人修正。'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('關閉', style: TextStyle(color: primaryColor)),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    final primaryColor = _currentPrimaryColor;
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
                    'AI 智慧功能（含 AI 診斷、AI 伴學、AI 行事曆助手等）由第三方 AI 模型提供支援，其回覆內容僅供參考。使用者應自行判斷 AI 輸出的正確性，如有題可藉由客服與意見回饋功能回報。'),
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
    final primaryColor = _currentPrimaryColor;
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
    List<XFile>? attachments,
  }) async {
    String apiUrl = 'https://api.web3forms.com/submit';
    String accessKey = '84030ade-dd9c-4a22-a16c-dd1a55d6c4d2';
    try {
      if (dotenv.isInitialized) {
        if (dotenv.env['FEEDBACK_API_URL']?.isNotEmpty == true) {
          apiUrl = dotenv.env['FEEDBACK_API_URL']!;
        }
        if (dotenv.env['WEB3FORMS_ACCESS_KEY']?.isNotEmpty == true) {
          accessKey = dotenv.env['WEB3FORMS_ACCESS_KEY']!;
        }
      }
    } catch (_) {}

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

      final Map<String, String> payload = {
        'access_key': accessKey,
        'from_name': 'YeLaiYeBang',
        'subject': '[$type] $subject',
        'name': userName,
        'email': userEmail,
        'message': body, // Web3Forms requires 'message' field
        '回報類型': type == 'bug' ? 'Bug 回報 🐞' : '功能建議 💡',
        '使用者ID': userId,
        'App版本': _appVersion,
      };

      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.fields.addAll(payload);

      if (attachments != null && attachments.isNotEmpty) {
        for (var file in attachments) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'attachment', // Web3Forms accepts 'attachment' or any file field
              file.path,
            ),
          );
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse)
          .timeout(const Duration(seconds: 8));

      debugPrint(
          'Web3Forms 回應碼: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('客服回饋 API 網路例外: $e');
      return false; // 發生例外時應回傳失敗，讓使用者知道未送出成功
    }
  }
}

// ─── 學習建議彈窗（獨立 StatefulWidget）───
class _RemedialMaterialSheet extends StatefulWidget {
  final String subjectName;
  final List<Map<String, dynamic>> wrongList;
  final String userId;
  final bool isDark;
  final Color primary;

  const _RemedialMaterialSheet({
    required this.subjectName,
    required this.wrongList,
    required this.userId,
    required this.isDark,
    required this.primary,
  });

  @override
  State<_RemedialMaterialSheet> createState() => _RemedialMaterialSheetState();
}

class _RemedialMaterialSheetState extends State<_RemedialMaterialSheet> {
  final StringBuffer _buffer = StringBuffer();
  StreamSubscription<String>? _sub;
  final ScrollController _sc = ScrollController();

  bool _isConnecting = true;
  bool _showLoading = true;
  double _loadingTarget = 0.95;
  int _loadingDurationMs = 8000;

  @override
  void initState() {
    super.initState();
    _sub = AiDiagnosisService.generateRemedialMaterialStream(
      userId: widget.userId,
      subject: widget.subjectName,
      wrongQuestions: widget.wrongList,
    ).listen(
      (chunk) {
        if (mounted) {
          _buffer.write(chunk);
          if (_isConnecting) {
            _isConnecting = false;
            setState(() {
              _loadingTarget = 1.0;
              _loadingDurationMs = 400;
            });
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) setState(() => _showLoading = false);
            });
          } else {
            if (!_showLoading) setState(() {});
          }
        }
      },
      onError: (e) {
        debugPrint('學習建議串流嚴重錯誤: $e');
        if (mounted) {
          setState(() {
            _showLoading = false;
            if (_buffer.isEmpty) {
              _buffer.write('【連線異常】\n無法連線至 AI 伺服器，請稍後再試。');
            } else {
              _buffer.write('\n\n(分析中斷，請重試)');
            }
          });
        }
      },
      onDone: () {
        if (mounted && _buffer.isEmpty) {
          setState(() {
            _showLoading = false;
            _buffer.write('【系統提示】\n未獲得任何分析結果，請稍後再試。');
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sc.dispose();
    super.dispose();
  }

  Widget _parseInlineFormatting(
      String text, TextStyle defaultStyle, bool isDark) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastMatchEnd = 0;

    for (var match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: defaultStyle.copyWith(
            backgroundColor: isDark
                ? Colors.amber.withValues(alpha: 0.3)
                : Colors.yellow.withValues(alpha: 0.4),
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.amber.shade100 : Colors.black87,
          ),
        ),
      );
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return RichText(
      text: TextSpan(
        style: defaultStyle,
        children: spans,
      ),
    );
  }

  List<Widget> _buildRichText(String text, bool isDark) {
    if (text.isEmpty) return [];

    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (var line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      if (line.startsWith('【') && line.contains('】')) {
        // Title
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            line,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: widget.primary,
            ),
          ),
        ));
      } else if (line.startsWith('[') && line.contains(']')) {
        // Section Header
        widgets.add(Container(
          margin: const EdgeInsets.only(top: 16, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white10
                : widget.primary.withValues(alpha: 0.08),
            border: Border(left: BorderSide(color: widget.primary, width: 4)),
          ),
          child: Text(
            line,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ));
      } else if (line.startsWith('•') || line.startsWith('-')) {
        // Bullet point
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•',
                  style: TextStyle(
                      color: widget.primary,
                      fontSize: 16,
                      height: 1.4,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: _parseInlineFormatting(
                  line.substring(1).trim(),
                  TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.9)
                        : Colors.black87,
                  ),
                  isDark,
                ),
              ),
            ],
          ),
        ));
      } else {
        // Normal text
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _parseInlineFormatting(
            line,
            TextStyle(
              fontSize: 14,
              height: 1.6,
              color:
                  isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
            ),
            isDark,
          ),
        ));
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final text = _buffer.toString();
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (ctx, sc) => Container(
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1E1E2C) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: widget.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI 專屬學習建議 (${widget.subjectName})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _showLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.memory,
                              size: 48,
                              color: widget.primary.withValues(alpha: 0.7)),
                          const SizedBox(height: 24),
                          TweenAnimationBuilder<double>(
                            tween:
                                Tween<double>(begin: 0.0, end: _loadingTarget),
                            duration:
                                Duration(milliseconds: _loadingDurationMs),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Column(
                                children: [
                                  SizedBox(
                                    width: 200,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: LinearProgressIndicator(
                                        value: value,
                                        backgroundColor: widget.isDark
                                            ? Colors.white12
                                            : Colors.grey.shade200,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                widget.primary),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'AI 正在為您深度分析盲點... ${(value * 100).toInt()}%',
                                    style: TextStyle(
                                      color: widget.isDark
                                          ? Colors.white70
                                          : Colors.grey.shade600,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      controller: sc,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildRichText(text, widget.isDark),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClusterDotPainter extends FlDotPainter {
  final Color color;
  final int count;

  _ClusterDotPainter({required this.color, required this.count});

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double radius = count > 1 ? 14.0 : 10.0;

    canvas.drawCircle(offsetInCanvas, radius, paint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(offsetInCanvas, radius, borderPaint);

    if (count > 1) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        offsetInCanvas - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  Size getSize(FlSpot spot) =>
      count > 1 ? const Size(28, 28) : const Size(20, 20);

  @override
  Color get mainColor => color;

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) => b;

  @override
  List<Object?> get props => [color, count];
}

class _LearningProgressCard extends StatefulWidget {
  final List<Map<String, dynamic>> matrixData;
  final bool isDarkMode;
  final Color primaryColor;
  final Widget matrixChartWidget;
  final Function(String) onShowRemedial;
  final Widget Function(String, Widget) moduleContainerBuilder;

  const _LearningProgressCard({
    required this.matrixData,
    required this.isDarkMode,
    required this.primaryColor,
    required this.matrixChartWidget,
    required this.onShowRemedial,
    required this.moduleContainerBuilder,
  });

  @override
  State<_LearningProgressCard> createState() => _LearningProgressCardState();
}

class _LearningProgressCardState extends State<_LearningProgressCard> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildRadarChart() {
    if (widget.matrixData.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('暫無測驗資料', style: TextStyle(color: Colors.grey)),
      );
    }

    // Extract subjects and accuracy
    List<String> subjects = [];
    List<double> accuracies = [];

    final data = widget.matrixData.take(8).toList();
    for (var d in data) {
      subjects.add(d['subject'].toString());
      accuracies.add((d['accuracy'] as num).toDouble());
    }

    while (subjects.length < 3) {
      subjects.add('維度 ${subjects.length + 1}');
      accuracies.add(0.0);
    }

    return SizedBox(
      height: 235,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: RadarChart(
          RadarChartData(
            dataSets: [
              RadarDataSet(
                fillColor: widget.primaryColor.withValues(alpha: 0.3),
                borderColor: widget.primaryColor,
                entryRadius: 4,
                dataEntries:
                    accuracies.map((e) => RadarEntry(value: e)).toList(),
                borderWidth: 2,
              ),
            ],
            radarBackgroundColor: Colors.transparent,
            borderData: FlBorderData(show: false),
            radarBorderData: const BorderSide(color: Colors.transparent),
            titlePositionPercentageOffset: 0.08,
            titleTextStyle: TextStyle(
              color: widget.isDarkMode
                  ? Colors.grey.shade300
                  : Colors.grey.shade700,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            getTitle: (index, angle) {
              if (index >= subjects.length) {
                return const RadarChartTitle(text: '');
              }
              return RadarChartTitle(text: subjects[index]);
            },
            tickCount: 5,
            ticksTextStyle:
                const TextStyle(color: Colors.transparent, fontSize: 0),
            tickBorderData: BorderSide(
              color: widget.isDarkMode
                  ? Colors.grey.shade700
                  : Colors.grey.shade300,
              width: 1,
            ),
            gridBorderData: BorderSide(
              color: widget.isDarkMode
                  ? Colors.grey.shade700
                  : Colors.grey.shade300,
              width: 1,
            ),
          ),
          duration: const Duration(milliseconds: 250),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int blindSpotCount = 0;
    for (var d in widget.matrixData) {
      double acc = (d['accuracy'] as num).toDouble();
      double time = (d['avgTime'] as num).toDouble();
      if (acc < 60 && time > 15) {
        blindSpotCount++;
      }
    }

    final hasData = widget.matrixData.isNotEmpty;
    final title = _currentIndex == 0 ? '學習歷程 (知識掌握度矩陣)' : '學習歷程 (多維能力分析)';

    return widget.moduleContainerBuilder(
      title,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              children: [
                widget.matrixChartWidget,
                _buildRadarChart(),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Dot Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(2, (index) {
              return GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentIndex == index ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentIndex == index
                        ? widget.primaryColor
                        : Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          if (_currentIndex == 0)
            Center(
              child: Text(
                hasData ? '💡 點擊圓點查看測驗詳情與 AI 學習建議' : '本週尚無作答紀錄，完成練習後將自動繪製掌握度圖表',
                style: TextStyle(
                    color: widget.isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade700,
                    fontSize: 12),
                textAlign: TextAlign.center,
              ),
            )
          else
            Center(
              child: Text(
                hasData ? '💡 透過雷達圖快速掌握各科目能力分佈' : '完成練習後將自動繪製各科能力分佈',
                style: TextStyle(
                    color: widget.isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade700,
                    fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          if (blindSpotCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '本週偵測到 $blindSpotCount 筆嚴重盲點！建議及早複習。',
                      style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      widget.onShowRemedial('綜合盲點');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 0),
                      minimumSize: const Size(0, 30),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child:
                        const Text('AI 學習建議', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}
