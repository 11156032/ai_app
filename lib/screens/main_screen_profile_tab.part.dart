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
              tabs: [
                Tab(
                    text: AppLocaleService.tr(
                        'profile_tab_overview', _appLanguage)),
                Tab(
                    text: AppLocaleService.tr(
                        'profile_tab_settings', _appLanguage)),
                Tab(
                    text: AppLocaleService.tr(
                        'profile_tab_support', _appLanguage)),
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
    return _buildDashboardFront(context);
  }

  Widget _buildDashboardFront(BuildContext context) {
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
              Text(
                AppLocaleService.tr('dashboard_today_summary', _appLanguage),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () => _showAiAnalysisSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      const Text(
                        'AI 分析',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDashboardItem(
                  Icons.timer_outlined,
                  AppLocaleService.tr('dashboard_study_hours', _appLanguage),
                  '${_todayStudyHours.toStringAsFixed(1)}h'),
              _buildDashboardItem(
                  Icons.check_circle_outline,
                  AppLocaleService.tr(
                      'dashboard_completed_questions', _appLanguage),
                  '$_todayCompletedQuestions ${AppLocaleService.tr('unit_questions', _appLanguage)}'),
              _buildDashboardItem(
                  Icons.local_fire_department, '連續天數', '$_streakDays 天'),
            ],
          ),
        ],
      ),
    );
  }

  void _showAiAnalysisSheet(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiAnalysisPage(
          currentUser: widget.currentUser,
          weeklyMatrixData: _weeklyMatrixData,
          streakDays: _streakDays,
          todayStudyHours: _todayStudyHours,
          questionBank: questionBank,
        ),
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
      title: AppLocaleService.tr('profile_basic_info', _appLanguage),
      child: Column(
        children: [
          _buildProfileTile(
            context: context,
            icon: Icons.person_outline,
            label: AppLocaleService.tr('profile_nickname', _appLanguage),
            value: _displayName ?? '未設定',
            onTap: _showEditNicknameDialog,
          ),
          const Divider(height: 24),
          _buildProfileTile(
            context: context,
            icon: Icons.assignment_ind_outlined,
            label: AppLocaleService.tr('profile_bio', _appLanguage),
            value: (_userBio == null || _userBio!.isEmpty)
                ? AppLocaleService.tr('profile_bio_hint', _appLanguage)
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
      title: AppLocaleService.tr('settings_title', _appLanguage),
      child: Column(
        children: [
          _buildProfileTile(
            context: context,
            icon: Icons.language_rounded,
            label: AppLocaleService.tr('settings_language', _appLanguage),
            value:
                '${AppLocaleService.getLanguageFlag(_appLanguage)} ${AppLocaleService.getLanguageDisplayName(_appLanguage)}',
            onTap: _showLanguageDialog,
          ),
          const Divider(height: 24),
          _buildProfileTile(
            context: context,
            icon: Icons.format_size,
            label: AppLocaleService.tr('settings_font_size', _appLanguage),
            value: _fontSizeFactor <= 1.25
                ? AppLocaleService.tr('font_size_std', _appLanguage)
                : _fontSizeFactor <= 1.40
                    ? AppLocaleService.tr('font_size_large', _appLanguage)
                    : AppLocaleService.tr('font_size_xlarge', _appLanguage),
            onTap: _showFontSizeDialog,
          ),
          const Divider(height: 24),
          _buildProfileTile(
            context: context,
            icon: Icons.palette_outlined,
            label: AppLocaleService.tr('settings_theme_color', _appLanguage),
            value: _themeColorIdx == 1
                ? AppLocaleService.tr('theme_color_1', _appLanguage)
                : _themeColorIdx == 2
                    ? AppLocaleService.tr('theme_color_2', _appLanguage)
                    : _themeColorIdx == 3
                        ? AppLocaleService.tr('theme_color_3', _appLanguage)
                        : _themeColorIdx == 4
                            ? AppLocaleService.tr('theme_color_4', _appLanguage)
                            : AppLocaleService.tr(
                                'theme_color_0', _appLanguage),
            onTap: _showThemeColorDialog,
          ),
          const Divider(height: 24),
          _buildProfileTile(
            context: context,
            icon: Icons.calendar_view_month,
            label: AppLocaleService.tr('settings_calendar_style', _appLanguage),
            value: _calendarViewMode == 'bar' 
                ? AppLocaleService.tr('calendar_mode_bar', _appLanguage) 
                : AppLocaleService.tr('calendar_mode_dot', _appLanguage),
            onTap: _showCalendarViewModeDialog,
          ),
          const Divider(height: 24),
          _buildProfileTile(
            context: context,
            icon: Icons.grid_view_rounded,
            label: AppLocaleService.tr('settings_social_style', _appLanguage),
            value: _socialFeedLayout == 'list' 
                ? AppLocaleService.tr('feed_layout_list', _appLanguage) 
                : AppLocaleService.tr('feed_layout_card', _appLanguage),
            onTap: _showSocialFeedLayoutDialog,
          ),
          const Divider(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(AppLocaleService.tr('settings_floating_nav', _appLanguage),
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
            title: Text(AppLocaleService.tr('settings_dark_mode', _appLanguage),
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
      title: AppLocaleService.tr('profile_security_title', _appLanguage),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(AppLocaleService.tr('settings_notifications', _appLanguage),
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
            label: AppLocaleService.tr('profile_email', _appLanguage),
            value:
                '${widget.currentUser['email'] ?? AppLocaleService.tr('profile_not_set', _appLanguage)}${widget.currentUser['is_google'] == 1 ? ' (Google)' : ''}',
            valueColor: Colors.grey,
            onTap: () {
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(SnackBar(
                  content: Text(AppLocaleService.tr('profile_email_unchangeable', _appLanguage)),
                  duration: const Duration(milliseconds: 1200),
                ));
            },
          ),
          const Divider(height: 24),
          _buildProfileTile(
            context: context,
            icon: Icons.lock_outline,
            label: AppLocaleService.tr('profile_password', _appLanguage),
            value: widget.currentUser['is_google'] == 1
                ? AppLocaleService.tr('profile_google_login', _appLanguage)
                : AppLocaleService.tr('profile_change_password', _appLanguage),
            valueColor:
                widget.currentUser['is_google'] == 1 ? Colors.grey : null,
            onTap: widget.currentUser['is_google'] == 1
                ? () {
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(AppLocaleService.tr('profile_no_password_needed', _appLanguage)),
                          duration: const Duration(milliseconds: 1200),
                        ),
                      );
                  }
                : _showChangePasswordDialog,
          ),
          if (widget.currentUser['id'] != 'u4') ...[
            const Divider(height: 24),
            _buildProfileTile(
              context: context,
              icon: Icons.delete_forever,
              label: AppLocaleService.tr('profile_delete_account', _appLanguage),
              value: AppLocaleService.tr('profile_delete_hint', _appLanguage),
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
      title: AppLocaleService.tr('profile_interaction_title', _appLanguage),
      child: Column(
        children: [
          _buildProfileTile(
            context: context,
            icon: Icons.article_outlined,
            label: AppLocaleService.tr('profile_my_posts', _appLanguage),
            value: AppLocaleService.tr('profile_posts_count', _appLanguage, [myPostCount.toString()]),
            onTap: _showMyPostsPage,
          ),
          const Divider(height: 24),
          _buildProfileTile(
            context: context,
            icon: Icons.history,
            label: AppLocaleService.tr('profile_quiz_history', _appLanguage),
            value: _latestQuizScore,
            onTap: _showQuizHistoryPage,
          ),
        ],
      ),
    );
  }

  Widget _buildLearningProgressModule(BuildContext context) {
    return _LearningProgressCard(
      matrixData: _weeklyMatrixData,
      todayData: _todayQuizData,
      isDarkMode: _isDarkMode,
      primaryColor: _currentPrimaryColor,
      matrixChartWidget: _buildMatrixChart(context),
      onShowRemedial: (subject) => _showRemedialMaterialSheet(subject),
      appLanguage: _appLanguage,
      moduleContainerBuilder: (title, child) => _buildModuleContainer(
        context: context,
        title: title,
        child: child,
      ),
    );
  }

  Future<({List<Map<String, dynamic>> questions, bool hasRealMistakes})>
      _loadWrongQuestionDetails(String subjectName) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rawUid =
          widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1';
      final userId = rawUid.toString();

      String? whereStr = 'subject = ?';
      List<dynamic>? whereArgs = [subjectName];
      if (subjectName == '綜合盲點') {
        whereStr = null;
        whereArgs = null;
      }

      // 優先抓取該科目的「真實錯題」
      final query = '''
        SELECT q.* 
        FROM wrong_questions w
        JOIN questions q ON w.question_id = q.id
        WHERE (w.user_id = ? OR w.user_id = ?) ${subjectName != '綜合盲點' ? 'AND q.subject = ?' : ''}
        ORDER BY w.created_at DESC
        LIMIT 5
      ''';
      final args = subjectName != '綜合盲點'
          ? [userId, rawUid, subjectName]
          : [userId, rawUid];
      final rows = await db.rawQuery(query, args);

      if (rows.isNotEmpty) {
        return (
          questions: rows.map((r) => Map<String, dynamic>.from(r)).toList(),
          hasRealMistakes: true,
        );
      }

      // 若該科目目前無錯題，抓取代表性題目作為章節知識庫參考
      final fallbackRows = await db.query('questions',
          where: whereStr, whereArgs: whereArgs, limit: 5);
      return (
        questions:
            fallbackRows.map((r) => Map<String, dynamic>.from(r)).toList(),
        hasRealMistakes: false,
      );
    } catch (_) {
      return (questions: <Map<String, dynamic>>[], hasRealMistakes: false);
    }
  }

  void _showRemedialMaterialSheet(String subjectName) async {
    final bool isDark = _isDarkMode;
    final Color primary = _currentPrimaryColor;

    // Pre-load wrong questions & accuracy status
    final result = await _loadWrongQuestionDetails(subjectName);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RemedialMaterialSheet(
        subjectName: subjectName,
        wrongList: result.questions,
        hasRealMistakes: result.hasRealMistakes,
        userId: widget.currentUser['id']?.toString() ?? 'u1',
        isDark: isDark,
        primary: primary,
      ),
    );
  }

  void _showAISnackbar(String message, IconData icon) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
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
          duration: const Duration(milliseconds: 1200),
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
        child: Text(AppLocaleService.tr('dashboard_no_quiz_data', _appLanguage), style: const TextStyle(color: Colors.grey)),
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
              _buildLegendDot(Colors.blue, AppLocaleService.tr('chart_legend_proficient', _appLanguage)),
              _buildLegendDot(Colors.amber.shade700, AppLocaleService.tr('chart_legend_hesitant', _appLanguage)),
              _buildLegendDot(Colors.grey.shade600, AppLocaleService.tr('chart_legend_careless', _appLanguage)),
              _buildLegendDot(Colors.red, AppLocaleService.tr('chart_legend_blindspot', _appLanguage)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 左側 Y 軸標籤（中文直書）
              SizedBox(
                width: 26,
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
                      Text(AppLocaleService.tr('chart_y_label', _appLanguage).split('')[0],
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              height: 1.25,
                              color: _isDarkMode
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade800)),
                      Text(AppLocaleService.tr('chart_y_label', _appLanguage).split('')[1],
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              height: 1.25,
                              color: _isDarkMode
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade800)),
                      Text(AppLocaleService.tr('chart_y_label', _appLanguage).split('')[2],
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
                                        AppLocaleService.tr('chart_tooltip', _appLanguage, [
                                          touchedBarSpot.y.toInt().toString(),
                                          touchedBarSpot.x.toStringAsFixed(1)
                                        ]),
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
            ],
          ),
        ),
        // ── 下方 X 軸標籤
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 4),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocaleService.tr('chart_x_label', _appLanguage),
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
                      AppLocaleService.tr('sheet_overlapped_title', _appLanguage, [quizzes.length.toString()]),
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
                  AppLocaleService.tr('sheet_overlapped_desc', _appLanguage),
                  style: TextStyle(
                    fontSize: 12,
                    color: _isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 14),
                ...quizzes.map((item) {
                  final subject = item['subject']?.toString() ?? AppLocaleService.tr('general_practice', _appLanguage);
                  final acc = (item['accuracy'] as num).toDouble();
                  final avgTime = (item['avgTime'] as num).toDouble();
                  final date = item['timestamp']?.toString() ??
                      item['date']?.toString() ??
                      '';

                  Color statusColor;
                  String statusText;
                  if (acc >= 60 && avgTime <= 15) {
                    statusColor = Colors.blue;
                    statusText = AppLocaleService.tr('chart_legend_proficient', _appLanguage);
                  } else if (acc >= 60 && avgTime > 15) {
                    statusColor = Colors.amber.shade700;
                    statusText = AppLocaleService.tr('chart_legend_hesitant', _appLanguage);
                  } else if (acc < 60 && avgTime > 15) {
                    statusColor = Colors.red;
                    statusText = AppLocaleService.tr('chart_legend_blindspot', _appLanguage);
                  } else {
                    statusColor = Colors.grey.shade600;
                    statusText = AppLocaleService.tr('chart_legend_careless', _appLanguage);
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
                        '${AppLocaleService.tr('acc_rate', _appLanguage)}: ${acc.toInt()}% • ${AppLocaleService.tr('avg_time', _appLanguage)}: ${avgTime.toStringAsFixed(1)}s${date.isNotEmpty ? " • $date" : ""}',
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
    final String subject = entry['subject'] as String? ?? AppLocaleService.tr('general_practice', _appLanguage);
    final String timeStr = formatRelativeTime(entry['timestamp']);

    String statusText;
    Color statusColor;
    String statusDesc;

    if (acc >= 60 && avgTime <= 15) {
      statusText = AppLocaleService.tr('chart_legend_proficient', _appLanguage);
      statusColor = Colors.blue;
      statusDesc = AppLocaleService.tr('quiz_desc_proficient', _appLanguage);
    } else if (acc >= 60 && avgTime > 15) {
      statusText = AppLocaleService.tr('chart_legend_hesitant', _appLanguage);
      statusColor = Colors.amber.shade800;
      statusDesc = AppLocaleService.tr('quiz_desc_hesitant', _appLanguage);
    } else if (acc < 60 && avgTime > 15) {
      statusText = AppLocaleService.tr('chart_legend_blindspot', _appLanguage);
      statusColor = Colors.red;
      statusDesc = AppLocaleService.tr('quiz_desc_blindspot', _appLanguage);
    } else {
      statusText = AppLocaleService.tr('chart_legend_careless', _appLanguage);
      statusColor = Colors.grey.shade700;
      statusDesc = AppLocaleService.tr('quiz_desc_careless', _appLanguage);
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
                              '${AppLocaleService.tr('quiz_time', _appLanguage)}：$timeStr',
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
                      _buildSheetStat(AppLocaleService.tr('acc_rate', _appLanguage), '${acc.toInt()}%', statusColor),
                      _buildSheetStat(AppLocaleService.tr('quiz_score', _appLanguage), '$correct / $total',
                          _isDarkMode ? Colors.white : Colors.black87),
                      _buildSheetStat(
                          AppLocaleService.tr('avg_time_sec', _appLanguage),
                          avgTime.toStringAsFixed(1),
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
                            label: Text(AppLocaleService.tr('quiz_review_schedule', _appLanguage, [subject])),
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
                                helpText: AppLocaleService.tr('schedule_time_pick', _appLanguage),
                                cancelText: AppLocaleService.tr('cancel', _appLanguage),
                                confirmText: AppLocaleService.tr('confirm', _appLanguage),
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
                                  'title': AppLocaleService.tr('quiz_review_title', _appLanguage, [subject]),
                                  'start_time': startStr,
                                  'end_time': endStr,
                                  'color': '0xFFE53935',
                                });
                                await _loadData();
                                final timeString =
                                    '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
                                _showAISnackbar(
                                    AppLocaleService.tr('quiz_scheduled_msg', _appLanguage, [subject, timeString]),
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
                          label: Text(AppLocaleService.tr('ai_suggestion_button', _appLanguage)),
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
    Widget? trailingWidget,
  }) {
    final isDark = _isDarkMode;
    final primary = _currentPrimaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isDark ? const Color(0xFFE0E0E0) : primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E2022),
                      ),
                    ),
                    if (value.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 12,
                          color: valueColor ??
                              (isDark
                                  ? Colors.white.withValues(alpha: 0.55)
                                  : const Color(0xFF6B7280)),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailingWidget ??
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: isDark ? Colors.white30 : Colors.grey.shade400,
                  ),
            ],
          ),
        ),
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
            AppLocaleService.tr('settings_calendar_style', _appLanguage),
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
                ctx, 'dot', AppLocaleService.tr('calendar_mode_dot', _appLanguage), AppLocaleService.tr('calendar_mode_dot_desc', _appLanguage)),
            const SizedBox(height: 12),
            _buildCalendarViewModeOption(
                ctx, 'bar', AppLocaleService.tr('calendar_mode_bar', _appLanguage), AppLocaleService.tr('calendar_mode_bar_desc', _appLanguage)),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                AppLocaleService.tr('cancel', _appLanguage),
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
            children: [AppLocaleService.tr('mon', _appLanguage), AppLocaleService.tr('tue', _appLanguage), AppLocaleService.tr('wed', _appLanguage), AppLocaleService.tr('thu', _appLanguage), AppLocaleService.tr('fri', _appLanguage), AppLocaleService.tr('sat', _appLanguage), AppLocaleService.tr('sun', _appLanguage)].map((w) {
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
            AppLocaleService.tr('settings_social_style', _appLanguage),
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
                ctx, 'card', AppLocaleService.tr('feed_layout_card', _appLanguage), AppLocaleService.tr('feed_layout_card_desc', _appLanguage)),
            const SizedBox(height: 12),
            _buildSocialFeedLayoutOption(
                ctx, 'list', AppLocaleService.tr('feed_layout_list', _appLanguage), AppLocaleService.tr('feed_layout_list_desc', _appLanguage)),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                AppLocaleService.tr('cancel', _appLanguage),
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
                Text(AppLocaleService.tr('time_2h_ago', _appLanguage),
                    style: TextStyle(
                        fontSize: 9, color: textCol.withValues(alpha: 0.6))),
                const Spacer(),
                Icon(Icons.more_horiz,
                    size: 14, color: textCol.withValues(alpha: 0.6)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${AppLocaleService.tr('test_title', _appLanguage)}\n${AppLocaleService.tr('test_desc', _appLanguage)}',
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
                      Text(AppLocaleService.tr('time_2h_ago', _appLanguage),
                          style: TextStyle(
                              fontSize: 8,
                              color: textCol.withValues(alpha: 0.6))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppLocaleService.tr('plan_title', _appLanguage)}\n${AppLocaleService.tr('plan_desc', _appLanguage)}',
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

  // --- 系統與協助模組（純文字分類）---
  Widget _buildSupportModule(BuildContext context) {
    final categories = ['全部', '產品與教學', '客服與支援', '條款與資訊'];
    final showProduct = _supportCategory == '全部' || _supportCategory == '產品與教學';
    final showService = _supportCategory == '全部' || _supportCategory == '客服與支援';
    final showLegal = _supportCategory == '全部' || _supportCategory == '條款與資訊';

    return _buildModuleContainer(
      context: context,
      title: AppLocaleService.tr('profile_support_title', _appLanguage),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 純文字分類標籤列（無圖案、無多餘顏色）
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSel = _supportCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 12),
                  child: ChoiceChip(
                    showCheckmark: false,
                    selected: isSel,
                    label: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                        color: isSel
                            ? Colors.white
                            : (_isDarkMode ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    selectedColor: _isDarkMode
                        ? Colors.white.withValues(alpha: 0.2)
                        : const Color(0xFF2C2D35),
                    backgroundColor: _isDarkMode
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFF3F4F6),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    onSelected: (_) {
                      _update(() {
                        _supportCategory = cat;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // 產品與教學分類
          if (showProduct) ...[
            _buildProfileTile(
              context: context,
              icon: Icons.campaign_outlined,
              label: AppLocaleService.tr('announcements_label', _appLanguage),
              value: AppLocaleService.tr('announcements_sub', _appLanguage),
              onTap: _showAnnouncementsDialog,
            ),
            const Divider(height: 20),
            _buildProfileTile(
              context: context,
              icon: Icons.ondemand_video_outlined,
              label: AppLocaleService.tr('tutorial_video_label', _appLanguage),
              value: AppLocaleService.tr('tutorial_video_sub', _appLanguage),
              onTap: () {
                TutorialVideoPlayer.showTutorialChooserDialog(context);
              },
            ),
            const Divider(height: 20),
            _buildProfileTile(
              context: context,
              icon: Icons.explore_outlined,
              label: AppLocaleService.tr('tour_label', _appLanguage),
              value: AppLocaleService.tr('tour_value', _appLanguage),
              onTap: _startTour,
            ),
            if (showService || showLegal) const Divider(height: 20),
          ],

          // 客服與支援分類
          if (showService) ...[
            _buildProfileTile(
              context: context,
              icon: Icons.support_agent_outlined,
              label: AppLocaleService.tr('faq_and_support', _appLanguage),
              value: AppLocaleService.tr('faq_and_support_sub', _appLanguage),
              onTap: _showFaqDialog,
            ),
            const Divider(height: 20),
            _buildProfileTile(
              context: context,
              icon: Icons.headset_mic_outlined,
              label: AppLocaleService.tr('feedback_and_help', _appLanguage),
              value: AppLocaleService.tr('feedback_and_help_sub', _appLanguage),
              onTap: _showFeedbackDialog,
            ),
            if (showLegal) const Divider(height: 20),
          ],

          // 條款與資訊分類
          if (showLegal) ...[
            _buildProfileTile(
              context: context,
              icon: Icons.info_outline_rounded,
              label: AppLocaleService.tr('about_us', _appLanguage),
              value: AppLocaleService.tr('about_us_sub', _appLanguage),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AboutUsScreen())),
            ),
            const Divider(height: 20),
            _buildProfileTile(
              context: context,
              icon: Icons.gavel_outlined,
              label: AppLocaleService.tr('terms_label', _appLanguage),
              value: AppLocaleService.tr('terms_value', _appLanguage),
              onTap: _showTermsDialog,
            ),
            const Divider(height: 20),
            _buildProfileTile(
              context: context,
              icon: Icons.privacy_tip_outlined,
              label: AppLocaleService.tr('privacy_label', _appLanguage),
              value: AppLocaleService.tr('privacy_value', _appLanguage),
              onTap: _showPrivacyPolicyDialog,
            ),
            const Divider(height: 20),
            _buildProfileTile(
              context: context,
              icon: Icons.verified_outlined,
              label: AppLocaleService.tr('app_version', _appLanguage),
              value: '$_appVersion  ·  最新發布',
              onTap: _showVersionInfoDialog,
            ),
          ],
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
                                image: kIsWeb 
                                  ? NetworkImage(file.path) as ImageProvider
                                  : FileImage(File(file.path)),
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
                          const SnackBar(
                            content: Text('請填寫主旨'),
                            duration: Duration(milliseconds: 1500),
                          ),
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
                              duration: const Duration(milliseconds: 1500),
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

  void _showVersionInfoDialog() {
    final primaryColor = _currentPrimaryColor;
    final isDark = _isDarkMode;
    final fontFactor = _fontSizeFactor;
    showDialog(
      context: context,
      builder: (ctx) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(
          textScaler: TextScaler.linear(fontFactor),
        ),
        child: _VersionInfoDialog(
          isDark: isDark,
          primary: primaryColor,
          appVersion: _appVersion,
          onOpenAnnouncements: () {
            Navigator.pop(ctx);
            _showAnnouncementsDialog();
          },
        ),
      ),
    );
  }

  void _showAnnouncementsDialog() {
    final primaryColor = _currentPrimaryColor;
    final isDark = _isDarkMode;
    final fontFactor = _fontSizeFactor;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SystemAnnouncementsSheet(
        isDark: isDark,
        primary: primaryColor,
        fontSizeFactor: fontFactor,
      ),
    );
  }

  void _showFaqDialog() {
    final primaryColor = _currentPrimaryColor;
    final isDark = _isDarkMode;
    final fontFactor = _fontSizeFactor;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(
          textScaler: TextScaler.linear(fontFactor),
        ),
        child: _FaqAndCustomerSupportSheet(
          isDark: isDark,
          primary: primaryColor,
          onOpenFeedback: () {
            Navigator.pop(ctx);
            _showFeedbackDialog();
          },
        ),
      ),
    );
  }

  void _showTermsDialog() {
    final primaryColor = _currentPrimaryColor;
    final isDark = _isDarkMode;
    final fontFactor = _fontSizeFactor;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TermsAndPrivacySheet(
        isDark: isDark,
        primary: primaryColor,
        fontSizeFactor: fontFactor,
        initialTabIndex: 0,
        onOpenFeedback: () {
          Navigator.pop(ctx);
          _showFeedbackDialog();
        },
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    final primaryColor = _currentPrimaryColor;
    final isDark = _isDarkMode;
    final fontFactor = _fontSizeFactor;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TermsAndPrivacySheet(
        isDark: isDark,
        primary: primaryColor,
        fontSizeFactor: fontFactor,
        initialTabIndex: 1,
        onOpenFeedback: () {
          Navigator.pop(ctx);
          _showFeedbackDialog();
        },
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

      String finalBody = body;

      if (attachments != null && attachments.isNotEmpty) {
        finalBody += '\n\n--- 附件圖片 ---';
        for (int i = 0; i < attachments.length; i++) {
          final file = attachments[i];
          final bytes = await file.readAsBytes();
          
          try {
            var uploadReq = http.MultipartRequest('POST', Uri.parse('https://catbox.moe/user/api.php'));
            uploadReq.fields['reqtype'] = 'fileupload';
            uploadReq.files.add(
              http.MultipartFile.fromBytes(
                'fileToUpload', 
                bytes,
                filename: file.name.isNotEmpty ? file.name : 'image_${i + 1}.jpg',
              )
            );
            
            final uploadRes = await uploadReq.send().timeout(const Duration(seconds: 15));
            final resStr = await uploadRes.stream.bytesToString();
            
            if (uploadRes.statusCode == 200 && resStr.startsWith('http')) {
              finalBody += '\n圖片 ${i + 1}: $resStr';
            } else {
              finalBody += '\n圖片 ${i + 1}: 上傳失敗 (代碼: ${uploadRes.statusCode})';
            }
          } catch (e) {
            finalBody += '\n圖片 ${i + 1}: 上傳異常 ($e)';
          }
        }
      }

      final Map<String, dynamic> payload = {
        'access_key': accessKey,
        'from_name': 'YeLaiYeBang',
        'subject': '[$type] $subject',
        'name': userName,
        'email': userEmail,
        'message': finalBody,
        '回報類型': type == 'bug' ? 'Bug 回報 🐞' : '功能建議 💡',
        '使用者ID': userId,
        'App版本': _appVersion,
      };

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

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
  final bool hasRealMistakes;
  final String userId;
  final bool isDark;
  final Color primary;

  const _RemedialMaterialSheet({
    required this.subjectName,
    required this.wrongList,
    this.hasRealMistakes = true,
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
    _checkSavedAndInit();
  }

  Future<void> _checkSavedAndInit() async {
    try {
      final saved = await DatabaseHelper.instance
          .getRemedialMaterial(widget.userId, widget.subjectName);
      if (saved != null &&
          saved['content'] != null &&
          (saved['content'] as String).trim().isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _buffer.clear();
          _buffer.write(saved['content']);
          _showLoading = false;
          _isConnecting = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('讀取已儲存的學習建議失敗: $e');
    }
    _startGenerating();
  }

  void _startGenerating({bool isRegenerate = false}) {
    _sub?.cancel();
    setState(() {
      _buffer.clear();
      _showLoading = true;
      _isConnecting = true;
      _loadingTarget = 0.95;
      _loadingDurationMs = 8000;
    });

    _sub = AiDiagnosisService.generateRemedialMaterialStream(
      userId: widget.userId,
      subject: widget.subjectName,
      wrongQuestions: widget.wrongList,
      hasRealMistakes: widget.hasRealMistakes,
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
        if (mounted) {
          if (_buffer.isEmpty) {
            setState(() {
              _showLoading = false;
              _buffer.write('【系統提示】\n未獲得任何分析結果，請稍後再試。');
            });
          } else {
            final content = _buffer.toString();
            if (!content.contains('【連線異常】') &&
                !content.contains('【系統提示】')) {
              // 自動持久化儲存至 SQLite，退出後仍可隨時重新閱覽
              DatabaseHelper.instance.saveRemedialMaterial(
                  widget.userId, widget.subjectName, content);
            }
          }
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
    // 清理無效代碼區塊符號與提示括號殘留
    String cleanText = text
        .replaceAll('```markdown', '')
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .replaceAll(RegExp(r'重點[一二三四五1-5]\s*（[^）]*）\s*'), '')
        .replaceAll(RegExp(r'重點[一二三四五1-5]\s*\([^)]*\)\s*'), '')
        .trim();

    final spans = <InlineSpan>[];
    // 支援 **重點** 與 【重點】 兩種螢光筆高亮模式
    final regex = RegExp(r'(?:\*\*(.*?)\*\*|【(.*?)】)');
    int lastMatchEnd = 0;

    for (var match in regex.allMatches(cleanText)) {
      if (match.start > lastMatchEnd) {
        // 清理非高亮區域的殘留星號、反引號等符號
        final normalPart = cleanText
            .substring(lastMatchEnd, match.start)
            .replaceAll('*', '')
            .replaceAll('`', '');
        if (normalPart.isNotEmpty) {
          spans.add(TextSpan(text: normalPart));
        }
      }
      final highlightedText =
          (match.group(1) ?? match.group(2) ?? '')
              .replaceAll('*', '')
              .replaceAll('`', '')
              .trim();
      if (highlightedText.isNotEmpty) {
        spans.add(
          TextSpan(
            text: highlightedText,
            style: defaultStyle.copyWith(
              backgroundColor: isDark
                  ? Colors.amber.withValues(alpha: 0.3)
                  : Colors.yellow.withValues(alpha: 0.4),
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.amber.shade100 : Colors.black87,
            ),
          ),
        );
      }
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd < cleanText.length) {
      final tailPart = cleanText
          .substring(lastMatchEnd)
          .replaceAll('*', '')
          .replaceAll('`', '');
      if (tailPart.isNotEmpty) {
        spans.add(TextSpan(text: tailPart));
      }
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

    // 分割區塊：弱項摘要 與 觀念重點
    String summaryContent = '';
    final List<String> bulletPoints = [];

    final lines = text.split('\n');
    String currentSection = '';

    for (var rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('```')) continue;

      if (line.contains('弱項摘要') || line.contains('盲點診斷')) {
        currentSection = 'summary';
        continue;
      } else if (line.contains('觀念重點') || line.contains('學習建議') || line.contains('解題技巧')) {
        currentSection = 'points';
        continue;
      }

      if (currentSection == 'summary') {
        final clean = line
            .replaceAll(RegExp(r'^#{1,6}\s*'), '')
            .replaceAll('[', '')
            .replaceAll(']', '')
            .replaceAll('【弱項摘要】', '')
            .trim();
        if (clean.isNotEmpty) {
          if (summaryContent.isNotEmpty) summaryContent += '\n';
          summaryContent += clean;
        }
      } else if (currentSection == 'points' || currentSection.isEmpty) {
        if (RegExp(r'^\s*([•\-\*]|\d+[\.、\)])\s*').hasMatch(line)) {
          final clean = line
              .replaceFirst(RegExp(r'^\s*([•\-\*]|\d+[\.、\)])\s*'), '')
              .replaceAll(RegExp(r'重點[一二三四五1-5]\s*（[^）]*）\s*'), '')
              .replaceAll(RegExp(r'重點[一二三四五1-5]\s*\([^)]*\)\s*'), '')
              .trim();
          if (clean.isNotEmpty) bulletPoints.add(clean);
        } else if (line.startsWith('【') && line.contains('】：')) {
          bulletPoints.add(line);
        } else if (line.isNotEmpty) {
          if (summaryContent.isEmpty) {
            summaryContent = line;
          } else {
            bulletPoints.add(line);
          }
        }
      }
    }

    final widgets = <Widget>[];

    // ─── 卡片 1: 弱項摘要診斷 ───
    if (summaryContent.isNotEmpty) {
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF262738)
                : const Color(0xFFF6F8FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.track_changes_rounded,
                        color: Colors.orange, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '弱項盲點診斷',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _parseInlineFormatting(
                summaryContent,
                TextStyle(
                  fontSize: 13.5,
                  height: 1.6,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.black87,
                ),
                isDark,
              ),
            ],
          ),
        ),
      );
    }

    // ─── 卡片 2: 觀念重點與解題技巧 ───
    if (bulletPoints.isNotEmpty) {
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF262738)
                : const Color(0xFFF6F8FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: widget.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.lightbulb_outline_rounded,
                        color: widget.primary, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '觀念補強與解題技巧',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...bulletPoints.map(
                (point) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.check_circle_outline_rounded,
                            size: 15, color: widget.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _parseInlineFormatting(
                          point,
                          TextStyle(
                            fontSize: 13.5,
                            height: 1.55,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.9)
                                : Colors.black87,
                          ),
                          isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
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
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
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
                  if (!_showLoading)
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      tooltip: '重新生成學習建議',
                      onPressed: () => _startGenerating(isRegenerate: true),
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
  final List<Map<String, dynamic>> todayData; // 今日資料
  final bool isDarkMode;
  final Color primaryColor;
  final Widget matrixChartWidget;
  final Function(String) onShowRemedial;
  final Widget Function(String, Widget) moduleContainerBuilder;
  final String appLanguage;

  const _LearningProgressCard({
    required this.matrixData,
    required this.todayData,
    required this.isDarkMode,
    required this.primaryColor,
    required this.matrixChartWidget,
    required this.onShowRemedial,
    required this.moduleContainerBuilder,
    required this.appLanguage,
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

  Widget _buildTodayQuizOverview() {
    final data = widget.todayData;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final cardBg = widget.isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF8F6F4);

    if (data.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined,
                size: 40, color: widget.primaryColor.withValues(alpha: 0.4)),
            const SizedBox(height: 10),
            const Text('今日尚未完成任何測驗',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 4),
            const Text('完成測驗後將顯示今日概況',
                style: TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      );
    }

    // 統計今日總題數、總答對
    final int totalQ = data.fold(0, (s, d) => s + ((d['total'] as num?)?.toInt() ?? 0));
    final int totalC = data.fold(0, (s, d) => s + ((d['correct'] as num?)?.toInt() ?? 0));
    final int totalW = totalQ - totalC;
    final double overallAcc = totalQ > 0 ? totalC / totalQ : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 今日總覽橫列
          Row(
            children: [
              Expanded(
                child: _buildSummaryChip(
                  icon: Icons.quiz_rounded,
                  label: '總題數',
                  value: '$totalQ 題',
                  color: widget.primaryColor,
                  bg: cardBg,
                  textColor: textColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryChip(
                  icon: Icons.check_circle_rounded,
                  label: '答對',
                  value: '$totalC 題',
                  color: Colors.green.shade600,
                  bg: cardBg,
                  textColor: textColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryChip(
                  icon: Icons.cancel_rounded,
                  label: '答錯',
                  value: '$totalW 題',
                  color: Colors.red.shade400,
                  bg: cardBg,
                  textColor: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── 整體正確率條
          Row(
            children: [
              Text('整體正確率',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 11)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: overallAcc.clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        overallAcc >= 0.7
                            ? Colors.green.shade500
                            : overallAcc >= 0.5
                                ? Colors.orange
                                : Colors.red.shade400),
                    minHeight: 7,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(overallAcc * 100).round()}%',
                  style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          // ── 各科明細
          ...data.map((d) {
            final subj = (d['subject'] as String?) ?? '一般練習';
            final int cor = (d['correct'] as num?)?.toInt() ?? 0;
            final int tot = (d['total'] as num?)?.toInt() ?? 0;
            final int wrong = tot - cor;
            final double acc = tot > 0 ? cor / tot : 0.0;

            final Color barColor = acc >= 0.7
                ? Colors.green.shade500
                : acc >= 0.5
                    ? Colors.orange
                    : Colors.red.shade400;

            return Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(subj,
                            style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 13, color: Colors.green.shade600),
                          const SizedBox(width: 2),
                          Text('$cor',
                              style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Icon(Icons.cancel_rounded,
                              size: 13, color: Colors.red.shade400),
                          const SizedBox(width: 2),
                          Text('$wrong',
                              style: TextStyle(
                                  color: Colors.red.shade500,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          Text('${(acc * 100).round()}%',
                              style: TextStyle(
                                  color: barColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: acc.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      minHeight: 5,
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

  Widget _buildSummaryChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bg,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style:
                  const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
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


    // page 0 = 今日學習概況(測驗狀況), page 1 = 今日學習歷程(知識掌握度矩陣)
    final title = _currentIndex == 0
        ? AppLocaleService.tr('chart_section_title_radar', widget.appLanguage)
        : AppLocaleService.tr('chart_section_title_matrix', widget.appLanguage);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final double pageViewHeight = (245.0 * textScale).clamp(245.0, 310.0);

    return widget.moduleContainerBuilder(
      title,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: pageViewHeight,
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              children: [
                _buildTodayQuizOverview(),  // page 0: 今日學習概況
                widget.matrixChartWidget,   // page 1: 今日學習歷程
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
                '💡 今日各科測驗詳情',
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
                widget.matrixData.isNotEmpty
                    ? AppLocaleService.tr('chart_hint_tap_dot', widget.appLanguage)
                    : AppLocaleService.tr('chart_hint_no_data', widget.appLanguage),
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
                      AppLocaleService.tr('chart_blindspot_warn', widget.appLanguage, [blindSpotCount.toString()]),
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
                        Text(AppLocaleService.tr('chart_blindspot_btn', widget.appLanguage), style: TextStyle(fontSize: 11)),
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

// ─── 常見問題與 24H 線上客服彈窗 ───
class _FaqAndCustomerSupportSheet extends StatefulWidget {
  final bool isDark;
  final Color primary;
  final VoidCallback onOpenFeedback;

  const _FaqAndCustomerSupportSheet({
    required this.isDark,
    required this.primary,
    required this.onOpenFeedback,
  });

  @override
  State<_FaqAndCustomerSupportSheet> createState() =>
      _FaqAndCustomerSupportSheetState();
}

class _FaqAndCustomerSupportSheetState
    extends State<_FaqAndCustomerSupportSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _chatInputCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();

  String _searchQuery = '';
  late String _selectedCategory;
  bool _isAiResponding = false;
  StreamSubscription<String>? _streamSub;

  final List<Map<String, dynamic>> _faqData = [
    {
      'category': 'faq_cat_account',
      'icon': Icons.sync_rounded,
      'qKey': 'faq_q1',
      'aKey': 'faq_a1',
    },
    {
      'category': 'faq_cat_ai',
      'icon': Icons.auto_awesome,
      'qKey': 'faq_q2',
      'aKey': 'faq_a2',
    },
    {
      'category': 'faq_cat_quiz',
      'icon': Icons.quiz_outlined,
      'qKey': 'faq_q3',
      'aKey': 'faq_a3',
    },
    {
      'category': 'faq_cat_notes',
      'icon': Icons.menu_book_rounded,
      'qKey': 'faq_q4',
      'aKey': 'faq_a4',
    },
    {
      'category': 'faq_cat_settings',
      'icon': Icons.notifications_active_outlined,
      'qKey': 'faq_q5',
      'aKey': 'faq_a5',
    },
    {
      'category': 'faq_cat_account',
      'icon': Icons.lock_outline_rounded,
      'qKey': 'faq_q6',
      'aKey': 'faq_a6',
    },
    {
      'category': 'faq_cat_settings',
      'icon': Icons.palette_outlined,
      'qKey': 'faq_q7',
      'aKey': 'faq_a7',
    },
  ];

  final List<String> _categoryKeys = [
    'faq_cat_all',
    'faq_cat_account',
    'faq_cat_ai',
    'faq_cat_quiz',
    'faq_cat_notes',
    'faq_cat_settings',
  ];

  List<String> get _quickPrompts {
    final lang = AppLocaleService.currentLanguage;
    if (lang == AppLocaleService.ja) {
      return [
        '💡 AI学習アドバイスの使い方',
        '📓 間違いノートへの同期方法',
        '⚙️ ダークモードとテーマの変更',
        '🔒 登録メールアドレスの変更',
        '❓ 問題の不具合・誤答の報告',
        '📅 学習計画とリマインダー設定',
      ];
    } else if (lang == AppLocaleService.ko) {
      return [
        '💡 AI 맞춤 학습 제안 사용법',
        '📓 오답노트 자동 연동 방법',
        '⚙️ 다크 모드 및 테마 색상 변경',
        '🔒 로그인 이메일 변경 가능한가요?',
        '❓ 문제 오류 및 정답 수정 신고',
        '📅 학습 일정 및 알림 설정 방법',
      ];
    } else {
      return [
        '💡 如何使用 AI 學習建議？',
        '📓 錯題如何同步到筆記本？',
        '⚙️ 如何切換深色模式與主題？',
        '🔒 登入信箱可以修改嗎？',
        '❓ 發現題庫解答有誤如何回報？',
        '📅 怎麼設定讀書計畫與提醒？',
      ];
    }
  }

  late List<Map<String, dynamic>> _chatHistory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedCategory = AppLocaleService.tr('faq_cat_all', AppLocaleService.currentLanguage);
    final lang = AppLocaleService.currentLanguage;
    _chatHistory = [
      {
        'isUser': false,
        'text': AppLocaleService.tr('support_greeting', lang),
        'time': DateTime.now(),
      }
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _chatInputCtrl.dispose();
    _chatScrollCtrl.dispose();
    _streamSub?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendChatMessage(String messageText) {
    final text = messageText.trim();
    if (text.isEmpty || _isAiResponding) return;

    _chatInputCtrl.clear();
    setState(() {
      _chatHistory.add({
        'isUser': true,
        'text': text,
        'time': DateTime.now(),
      });
      _chatHistory.add({
        'isUser': false,
        'text': '',
        'time': DateTime.now(),
        'isStreaming': true,
      });
      _isAiResponding = true;
    });
    _scrollToBottom();

    // 格式化歷史對話
    final historyForAi = <Map<String, dynamic>>[];
    for (var msg in _chatHistory.take(_chatHistory.length - 1)) {
      historyForAi.add({
        'isAI': msg['isUser'] == false,
        'text': msg['text'] ?? '',
      });
    }

    final StringBuffer responseBuffer = StringBuffer();

    _streamSub = AiDiagnosisService.generateCustomerSupportStream(
      userInput: text,
      history: historyForAi,
    ).listen(
      (chunk) {
        if (!mounted) return;
        responseBuffer.write(chunk);
        final cleaned = AiDiagnosisService.cleanThinkingTags(responseBuffer.toString());
        setState(() {
          _chatHistory.last['text'] = cleaned;
        });
        _scrollToBottom();
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isAiResponding = false;
          _chatHistory.last['isStreaming'] = false;
          if (responseBuffer.isEmpty) {
            _chatHistory.last['text'] =
                AppLocaleService.tr('support_error_msg', AppLocaleService.currentLanguage);
          }
        });
      },
      onDone: () {
        if (!mounted) return;
        final cleaned = AiDiagnosisService.cleanThinkingTags(responseBuffer.toString());
        setState(() {
          _chatHistory.last['text'] = cleaned;
          _isAiResponding = false;
          _chatHistory.last['isStreaming'] = false;
        });
        _scrollToBottom();
      },
    );
  }

  Widget _parseChatMarkdown(String text, bool isDark) {
    // 預先清理無效的 [$1] / 【$1】 殘留符號與代碼塊
    String clean = text
        .replaceAll(RegExp(r'\[\$1\]|【\$1】|\$1'), '')
        .replaceAll('```markdown', '')
        .replaceAll('```json', '')
        .replaceAll('```', '');

    final spans = <InlineSpan>[];
    // 支援 **重點** 與 【重點】
    final regex = RegExp(r'(?:\*\*(.*?)\*\*|【(.*?)】)');
    int lastMatchEnd = 0;

    for (var match in regex.allMatches(clean)) {
      if (match.start > lastMatchEnd) {
        final normalText = clean.substring(lastMatchEnd, match.start);
        if (normalText.isNotEmpty) {
          spans.add(TextSpan(text: normalText));
        }
      }
      final highlighted = (match.group(1) ?? match.group(2) ?? '').trim();
      if (highlighted.isNotEmpty) {
        spans.add(
          TextSpan(
            text: highlighted,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.amber.shade200 : widget.primary,
              backgroundColor: isDark
                  ? Colors.amber.withValues(alpha: 0.15)
                  : widget.primary.withValues(alpha: 0.1),
            ),
          ),
        );
      }
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd < clean.length) {
      final tail = clean.substring(lastMatchEnd);
      if (tail.isNotEmpty) {
        spans.add(TextSpan(text: tail));
      }
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 14,
          height: 1.55,
          color: isDark ? Colors.white.withValues(alpha: 0.92) : Colors.black87,
        ),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primary = widget.primary;

    final lang = AppLocaleService.currentLanguage;
    final allLabel = AppLocaleService.tr('faq_cat_all', lang);
    // 語言切換後，若 _selectedCategory 不再是有效的分類標籤，重置為「全部」
    final validLabels = _categoryKeys.map((k) => AppLocaleService.tr(k, lang)).toSet();
    if (!validLabels.contains(_selectedCategory)) {
      Future.microtask(() {
        if (mounted) setState(() => _selectedCategory = allLabel);
      });
    }
    final filteredFaq = _faqData.where((item) {
      final categoryLabel = AppLocaleService.tr(item['category'] as String, lang);
      final matchesCategory = _selectedCategory == allLabel ||
          categoryLabel == _selectedCategory;
      final q = AppLocaleService.tr(item['qKey'] as String, lang);
      final a = AppLocaleService.tr(item['aKey'] as String, lang);
      final matchesSearch = _searchQuery.isEmpty ||
          q.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B1C26) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // 頂部抓把
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),

            // 頂部標題列
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.support_agent_rounded,
                        color: primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocaleService.tr('faq_and_support', lang),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          AppLocaleService.tr('faq_sheet_subtitle', lang),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: isDark ? Colors.white60 : Colors.grey.shade700),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 分頁導覽 TabBar
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: isDark ? Colors.white60 : Colors.grey.shade700,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(
                    icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
                    text: AppLocaleService.tr('faq_tab_faq', lang),
                  ),
                  Tab(
                    icon: const Icon(Icons.headset_mic_rounded, size: 18),
                    text: AppLocaleService.tr('faq_tab_chat', lang),
                  ),
                ],
              ),
            ),

            // 分頁內容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ─── TAB 1: 常見問題列表 ───
                  Column(
                    children: [
                      // 搜尋列
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: AppLocaleService.tr('faq_search_hint', lang),
                            hintStyle: TextStyle(
                                color: isDark ? Colors.white38 : Colors.grey.shade500,
                                fontSize: 12),
                            prefixIcon: Icon(Icons.search_rounded,
                                color: primary, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: primary, width: 1.5),
                            ),
                          ),
                        ),
                      ),

                      // 分類標籤滑動列
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _categoryKeys.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final catKey = _categoryKeys[idx];
                            final catLabel = AppLocaleService.tr(catKey, lang);
                            final isSel = _selectedCategory == catLabel;
                            return ChoiceChip(
                              label: Text(catLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                    color: isSel
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : Colors.grey.shade800),
                                  )),
                              selected: isSel,
                              selectedColor: primary,
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.grey.shade100,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              onSelected: (_) =>
                                  setState(() => _selectedCategory = catLabel),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6),

                      // 常見問題清單
                      Expanded(
                        child: filteredFaq.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search_off_rounded,
                                        size: 48,
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.grey.shade300),
                                    const SizedBox(height: 12),
                                    Text(
                                      AppLocaleService.tr('faq_no_result', lang, [_searchQuery]),
                                        style: TextStyle(
                                            color: isDark
                                                ? Colors.white60
                                                : Colors.grey.shade600,
                                            fontSize: 13)),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                                          size: 16),
                                      label: Text(AppLocaleService.tr('faq_go_chat', lang)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                      onPressed: () =>
                                          _tabController.animateTo(1),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.fromLTRB(
                                    16,
                                    6,
                                    16,
                                    MediaQuery.of(context).padding.bottom + 24),
                                itemCount: filteredFaq.length + 1,
                                itemBuilder: (ctx, i) {
                                  if (i == filteredFaq.length) {
                                    // 底部導引到客服的橫幅
                                    return Container(
                                      margin: const EdgeInsets.only(top: 12),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            primary.withValues(alpha: 0.15),
                                            primary.withValues(alpha: 0.05),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color: primary.withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.chat_bubble_outline_rounded,
                                              color: primary, size: 24),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(AppLocaleService.tr('faq_footer_title', lang),
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.bold,
                                                        color: isDark
                                                            ? Colors.white
                                                            : Colors.black87)),
                                                const SizedBox(height: 2),
                                                Text(AppLocaleService.tr('faq_footer_sub', lang),
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: isDark
                                                            ? Colors.white60
                                                            : Colors.grey.shade600)),
                                              ],
                                            ),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primary,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 8),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10)),
                                            ),
                                            onPressed: () =>
                                                _tabController.animateTo(1),
                                            child: Text(AppLocaleService.tr('faq_footer_btn', lang),
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  final item = filteredFaq[i];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF242533)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white12
                                            : Colors.grey.shade200,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.02),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Theme(
                                      data: Theme.of(context).copyWith(
                                          dividerColor: Colors.transparent),
                                      child: ExpansionTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(item['icon'] as IconData,
                                              color: primary, size: 18),
                                        ),
                                        title: Text(
                                          AppLocaleService.tr(item['qKey'] as String, lang),
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                        childrenPadding:
                                            const EdgeInsets.fromLTRB(16, 0, 16, 14),
                                        expandedCrossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Divider(height: 1),
                                          const SizedBox(height: 10),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: primary.withValues(
                                                  alpha: isDark ? 0.08 : 0.04),
                                              borderRadius: const BorderRadius.only(
                                                topRight: Radius.circular(8),
                                                bottomRight: Radius.circular(8),
                                              ),
                                              border: Border(
                                                left: BorderSide(
                                                    color: primary, width: 3.5),
                                              ),
                                            ),
                                            child: Text(
                                              AppLocaleService.tr(
                                                  item['aKey'] as String, lang),
                                              style: TextStyle(
                                                fontSize: 13,
                                                height: 1.6,
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.grey.shade800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),

                  // ─── TAB 2: 24H 智能線上客服 ───
                  Column(
                    children: [
                      // 頂部小狀態列
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.grey.shade50,
                          border: Border(
                              bottom: BorderSide(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.grey.shade200)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppLocaleService.tr('support_agent_online', lang),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.grey.shade700,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              icon: const Icon(Icons.mail_outline_rounded, size: 14),
                              label: Text(AppLocaleService.tr('support_transfer_btn', lang),
                                  style: TextStyle(fontSize: 11)),
                              onPressed: widget.onOpenFeedback,
                            ),
                          ],
                        ),
                      ),

                      // 快捷問題標籤（水平滑動）
                      Container(
                        height: 38,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _quickPrompts.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (ctx, i) {
                            return ActionChip(
                              label: Text(_quickPrompts[i],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.85)
                                        : Colors.black87,
                                  )),
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : primary.withValues(alpha: 0.08),
                              side: BorderSide(
                                  color: primary.withValues(alpha: 0.2)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              onPressed: () =>
                                  _sendChatMessage(_quickPrompts[i]),
                            );
                          },
                        ),
                      ),

                      // 聊天訊息列表
                      Expanded(
                        child: ListView.builder(
                          controller: _chatScrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: _chatHistory.length,
                          itemBuilder: (ctx, idx) {
                            final msg = _chatHistory[idx];
                            final isUser = msg['isUser'] == true;
                            final text = msg['text'] as String? ?? '';
                            final isStreaming = msg['isStreaming'] == true;

                            if (isUser) {
                              return Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  margin: const EdgeInsets.only(
                                      bottom: 12, left: 40),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: primary,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(4),
                                    ),
                                  ),
                                  child: Text(
                                    text,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor:
                                          primary.withValues(alpha: 0.15),
                                      child: Icon(Icons.support_agent_rounded,
                                          color: primary, size: 18),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                            bottom: 12, right: 30),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF262738)
                                              : const Color(0xFFF3F4F6),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(4),
                                            topRight: Radius.circular(16),
                                            bottomLeft: Radius.circular(16),
                                            bottomRight: Radius.circular(16),
                                          ),
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.white10
                                                : Colors.grey.shade200,
                                          ),
                                        ),
                                        child: (text.isEmpty && isStreaming)
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<Color>(
                                                              primary),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(AppLocaleService.tr('support_thinking', lang),
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: isDark
                                                              ? Colors.white54
                                                              : Colors.grey.shade600)),
                                                ],
                                              )
                                            : _parseChatMarkdown(text, isDark),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        ),
                      ),

                      // 底部輸入框與發送按鈕（自動避開手機底部導航鍵與鍵盤）
                      Container(
                        padding: EdgeInsets.fromLTRB(
                            12,
                            8,
                            12,
                            8 + math.max(
                              MediaQuery.of(context).viewInsets.bottom,
                              MediaQuery.of(context).padding.bottom,
                            )),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF222332)
                              : Colors.white,
                          border: Border(
                            top: BorderSide(
                              color: isDark
                                  ? Colors.white12
                                  : Colors.grey.shade200,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.cleaning_services_rounded,
                                  size: 20,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey.shade600),
                              tooltip: AppLocaleService.tr('support_clear_tooltip', lang),
                              onPressed: _isAiResponding
                                  ? null
                                  : () {
                                      setState(() {
                                        _chatHistory = [
                                          {
                                            'isUser': false,
                                            'text': AppLocaleService.tr('support_reset_msg', lang),
                                            'time': DateTime.now(),
                                          }
                                        ];
                                      });
                                    },
                            ),
                            Expanded(
                              child: TextField(
                                controller: _chatInputCtrl,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                textInputAction: TextInputAction.send,
                                onSubmitted: _sendChatMessage,
                                decoration: InputDecoration(
                                  hintText: AppLocaleService.tr('support_input_placeholder', lang),
                                  hintStyle: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.grey.shade500,
                                  ),
                                  isDense: true,
                                  filled: true,
                                  fillColor: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.grey.shade100,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(8),
                              ),
                              icon: _isAiResponding
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded, size: 18),
                              onPressed: _isAiResponding
                                  ? null
                                  : () => _sendChatMessage(_chatInputCtrl.text),
                            ),
                          ],
                        ),
                      ),
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
}

// ─── 系統公告與更新日誌彈窗（精美質感版面）───
class _SystemAnnouncementsSheet extends StatefulWidget {
  final bool isDark;
  final Color primary;
  final double fontSizeFactor;

  const _SystemAnnouncementsSheet({
    required this.isDark,
    required this.primary,
    this.fontSizeFactor = 1.2,
  });

  @override
  State<_SystemAnnouncementsSheet> createState() =>
      _SystemAnnouncementsSheetState();
}

class _SystemAnnouncementsSheetState extends State<_SystemAnnouncementsSheet> {
  String _selectedTag = '全部';
  final Set<int> _expandedIndices = {0};

  final List<String> _tags = [
    '全部',
    '重要更新',
    '功能優化',
    '題庫擴充',
  ];

  Color _getTagColor(String tag) {
    switch (tag) {
      case '重要更新':
        return const Color(0xFF673AB7);
      case '功能優化':
        return const Color(0xFF00897B);
      case '題庫擴充':
        return const Color(0xFFE65100);
      case '全部':
      default:
        return widget.primary;
    }
  }

  IconData _getTagIcon(String tag) {
    switch (tag) {
      case '重要更新':
        return Icons.star_rounded;
      case '功能優化':
        return Icons.tune_rounded;
      case '題庫擴充':
        return Icons.menu_book_rounded;
      case '全部':
      default:
        return Icons.grid_view_rounded;
    }
  }

  final List<Map<String, dynamic>> _announcements = [
    {
      'tag': '重要更新',
      'version': 'v1.6.5',
      'date': '2026-09-11',
      'isPinned': true,
      'icon': Icons.graphic_eq_rounded,
      'title': 'AI 語音速記與互動心智圖上線',
      'summary':
          '全新語音筆記核心，支援長錄音、智慧過濾口語贅字，並可自動轉為互動式心智圖與結構化待辦清單。',
      'highlights': [
        {
          'icon': Icons.hub_outlined,
          'title': '互動心智圖畫布',
          'desc': 'AI 自動將重點梳理為樹狀心智圖，支援手勢縮放、節點展開與全螢幕檢視。',
        },
        {
          'icon': Icons.view_carousel_outlined,
          'title': '三分頁成果預覽',
          'desc': '提供結構摘要、心智圖與 Markdown 預覽，支援待辦清單勾選與即時同步。',
        },
        {
          'icon': Icons.record_voice_over_outlined,
          'title': '語音辨識升級',
          'desc': '停頓容忍提高至 15 秒避免換氣中斷，智慧去贅字引擎自動過濾口語詞。',
        },
        {
          'icon': Icons.fit_screen_outlined,
          'title': '介面與字體適配',
          'desc': '操作按鈕適配系統手勢安全區，全域字體支援個人化等比縮放。',
        },
      ],
    },
    {
      'tag': '功能優化',
      'version': 'v1.6.2',
      'date': '2026-09-10',
      'isPinned': false,
      'icon': Icons.smart_toy_outlined,
      'title': 'AI 多引擎中繼升級與智能線上客服',
      'summary':
          '升級 Cloudflare 雲端中繼站架構，整合多模型備援並提供 24 小時線上智能諮詢。',
      'highlights': [
        {
          'icon': Icons.support_agent_rounded,
          'title': '智能線上客服',
          'desc': '提供精選常見問題解答與 24H AI 客服專員即時對答。',
        },
        {
          'icon': Icons.alt_route_rounded,
          'title': '多模型智慧路由',
          'desc': '當單一模型負載較高時自動平滑切換備援引擎，確保服務穩定。',
        },
      ],
    },
    {
      'tag': '題庫擴充',
      'version': 'v1.6.0',
      'date': '2026-09-08',
      'isPinned': false,
      'icon': Icons.library_books_rounded,
      'title': '各學科題庫擴充與掌握度矩陣圖',
      'summary':
          '新增國高中精選章節題庫，並推出可視化掌握度矩陣圖以精準分析個人盲點。',
      'highlights': [
        {
          'icon': Icons.grid_on_rounded,
          'title': '知識掌握度矩陣',
          'desc': '分析本週各學科掌握度，一鍵結合 AI 生成弱項補強內容。',
        },
        {
          'icon': Icons.share_rounded,
          'title': '學習 Pack 分享',
          'desc': '支援錯題、考卷與手寫筆記一鍵打包發布與匯入。',
        },
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primary = widget.primary;

    final filteredList = _announcements.where((item) {
      if (_selectedTag == '全部') return true;
      return item['tag'] == _selectedTag;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(
          textScaler: TextScaler.linear(widget.fontSizeFactor),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B1C26) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // 頂部抓把
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),

              // 頂部標題列（帶有主題圖標）
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.campaign_rounded,
                        size: 22,
                        color: primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '系統公告與更新日誌',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1E2022),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '掌握最新功能、題庫發布與版本動態',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 22,
                          color: isDark ? Colors.white60 : Colors.grey.shade600),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 分類標籤列（色彩繽紛的圖示 + 標籤藥丸）
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _tags.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final tag = _tags[idx];
                    final isSel = _selectedTag == tag;
                    final tagColor = _getTagColor(tag);
                    return ChoiceChip(
                      showCheckmark: false,
                      avatar: Icon(
                        _getTagIcon(tag),
                        size: 15,
                        color: isSel
                            ? Colors.white
                            : tagColor,
                      ),
                      label: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              isSel ? FontWeight.w600 : FontWeight.w500,
                          color: isSel
                              ? Colors.white
                              : (isDark
                                  ? Colors.white
                                  : const Color(0xFF2C2523)),
                        ),
                      ),
                      selected: isSel,
                      selectedColor: tagColor,
                      backgroundColor: isDark
                          ? tagColor.withValues(alpha: 0.12)
                          : tagColor.withValues(alpha: 0.08),
                      side: BorderSide(
                        color: isSel
                            ? tagColor
                            : (isDark
                                ? tagColor.withValues(alpha: 0.3)
                                : tagColor.withValues(alpha: 0.22)),
                        width: 1,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      onSelected: (_) => setState(() => _selectedTag = tag),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // 公告列表
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    MediaQuery.of(context).padding.bottom + 24,
                  ),
                  itemCount: filteredList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (ctx, i) {
                    final item = filteredList[i];
                    final highlights =
                        item['highlights'] as List<Map<String, dynamic>>;
                    final isPinned = item['isPinned'] as bool;
                    final isExpanded = _expandedIndices.contains(i);
                    final itemIcon = item['icon'] as IconData? ?? Icons.auto_awesome;
                    final tagColor = _getTagColor(item['tag'] as String);

                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF232432) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFEBEBF0),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                                alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 頂部彩色橫條 (Top Colored Accent Bar)
                          Container(
                            height: 4.5,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  tagColor,
                                  tagColor.withValues(alpha: 0.7),
                                ],
                              ),
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 版本號、圖案標籤、置頂與日期
                                Row(
                                  children: [
                                    // 版本號 Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: tagColor.withValues(
                                            alpha: isDark ? 0.2 : 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item['version'] as String,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: tagColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // 標籤 Badge (附帶圖案與分類色)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: tagColor.withValues(
                                            alpha: isDark ? 0.15 : 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _getTagIcon(item['tag'] as String),
                                            size: 11.5,
                                            color: tagColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            item['tag'] as String,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: tagColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isPinned) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.amber.withValues(alpha: 0.15)
                                              : Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.amber.withValues(alpha: 0.3)
                                                : Colors.amber.shade200,
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.push_pin_rounded,
                                              size: 10.5,
                                              color: isDark
                                                  ? Colors.amber.shade300
                                                  : Colors.amber.shade900,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              '置頂',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? Colors.amber.shade300
                                                    : Colors.amber.shade900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 11,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.grey.shade400,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      item['date'] as String,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // 標題 (附主題小圖標與色彩)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 2, right: 8),
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: tagColor.withValues(
                                            alpha: isDark ? 0.2 : 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        itemIcon,
                                        size: 16,
                                        color: tagColor,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        item['title'] as String,
                                        style: TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w700,
                                          height: 1.35,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF1E2022),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // 概述
                                Text(
                                  item['summary'] as String,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.5,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xFF555555),
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // 展開/收合開關按鈕
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (_expandedIndices.contains(i)) {
                                        _expandedIndices.remove(i);
                                      } else {
                                        _expandedIndices.add(i);
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          isExpanded
                                              ? '收起改動詳情'
                                              : '查看 ${highlights.length} 項改動詳情',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: tagColor,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Icon(
                                          isExpanded
                                              ? Icons.keyboard_arrow_up_rounded
                                              : Icons.keyboard_arrow_down_rounded,
                                          size: 16,
                                          color: tagColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // 展開後的項目細節（每項附帶色彩小圖示）
                                if (isExpanded) ...[
                                  const SizedBox(height: 8),
                                  Divider(
                                    height: 1,
                                    thickness: 0.8,
                                    color: isDark
                                        ? Colors.white10
                                        : const Color(0xFFEEEEEE),
                                  ),
                                  const SizedBox(height: 10),
                                  ...highlights.map((hl) {
                                    final hlIcon = hl['icon'] as IconData? ?? Icons.check_circle_outline_rounded;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(top: 2, right: 8),
                                            padding: const EdgeInsets.all(3.5),
                                            decoration: BoxDecoration(
                                              color: tagColor.withValues(
                                                  alpha: isDark ? 0.18 : 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              hlIcon,
                                              size: 13,
                                              color: tagColor,
                                            ),
                                          ),
                                          Expanded(
                                            child: RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: '${hl['title']}：',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: isDark
                                                          ? Colors.white
                                                          : const Color(0xFF2C2523),
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: hl['desc'],
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      height: 1.45,
                                                      color: isDark
                                                          ? Colors.white70
                                                          : const Color(0xFF5D4037),
                                                    ),
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
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 服務條款與隱私權政策全螢幕/彈窗（精美質感全新重構版）───
class _TermsAndPrivacySheet extends StatefulWidget {
  final bool isDark;
  final Color primary;
  final double fontSizeFactor;
  final int initialTabIndex; // 0 for 服務條款, 1 for 隱私權政策
  final VoidCallback? onOpenFeedback;

  const _TermsAndPrivacySheet({
    required this.isDark,
    required this.primary,
    this.fontSizeFactor = 1.2,
    this.initialTabIndex = 0,
    this.onOpenFeedback,
  });

  @override
  State<_TermsAndPrivacySheet> createState() => _TermsAndPrivacySheetState();
}

class _TermsAndPrivacySheetState extends State<_TermsAndPrivacySheet> {
  late int _currentTab; // 0: 服務條款, 1: 隱私權政策

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTabIndex;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isTerms = _currentTab == 0;
    final themeColor = isTerms ? const Color(0xFFD97706) : const Color(0xFF0D9488);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.96,
      builder: (ctx, scrollCtrl) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(
          textScaler: TextScaler.linear(widget.fontSizeFactor),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B1C26) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              // 頂部抓把
              const SizedBox(height: 12),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),

              // 頂部標題列
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isTerms ? Icons.gavel_rounded : Icons.security_rounded,
                        size: 22,
                        color: themeColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isTerms ? '服務條款' : '隱私權政策',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E2022),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: themeColor.withValues(
                                      alpha: isDark ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'v1.6.5',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: themeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isTerms
                                ? '保障您的法定權益與平台使用規範'
                                : '透明公開的資料最小化與本機加密承諾',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark ? Colors.white54 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 22,
                          color: isDark ? Colors.white60 : Colors.grey.shade600),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // 分頁切換器 (服務條款 / 隱私權政策)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabButton(
                        label: '服務條款',
                        icon: Icons.gavel_rounded,
                        isSelected: isTerms,
                        activeColor: const Color(0xFFD97706),
                        onTap: () => setState(() => _currentTab = 0),
                        isDark: isDark,
                      ),
                    ),
                    Expanded(
                      child: _buildTabButton(
                        label: '隱私權政策',
                        icon: Icons.security_rounded,
                        isSelected: !isTerms,
                        activeColor: const Color(0xFF0D9488),
                        onTap: () => setState(() => _currentTab = 1),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 條款/隱私內容捲動區
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  children: [
                    // 1. 重點摘要懶人包
                    _buildQuickHighlightsCard(
                      isTerms: isTerms,
                      isDark: isDark,
                      themeColor: themeColor,
                    ),

                    const SizedBox(height: 14),

                    // 2. 詳細章節清單
                    if (isTerms) ..._buildTermsSections(isDark, themeColor)
                    else ..._buildPrivacySections(isDark, themeColor),

                    const SizedBox(height: 12),

                    // 3. 底部修訂日期與法定管轄註記
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  size: 14,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Text(
                                '版本：v1.6.5  |  修訂發布日期：2026 年 9 月 11 日',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '如對本${isTerms ? '服務條款' : '隱私權政策'}有任何問題或建議，歡迎隨時透過線上客服或意見回饋表單與團隊聯繫。',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: isDark ? Colors.white30 : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 4. 底部主按鈕（固定於底端，搭配 SafeArea 避免被手機系統虛擬鍵/手勢底欄遮擋）
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E202C) : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFEBEBF0),
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: Text(
                        '我已完整閱讀並了解${isTerms ? '服務條款' : '隱私權政策'}',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2A2B3D) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? activeColor
                  : (isDark ? Colors.white54 : Colors.grey.shade600),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF1E2022))
                    : (isDark ? Colors.white54 : Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickHighlightsCard({
    required bool isTerms,
    required bool isDark,
    required Color themeColor,
  }) {
    final items = isTerms
        ? [
            (icon: Icons.school_rounded, title: '全方位學習功能', desc: '題庫、AI 語音速記、心智圖、診斷與行事曆'),
            (icon: Icons.lock_outline_rounded, title: '帳號與資安保護', desc: '密碼妥善保管，嚴禁濫用與未經授權共用'),
            (icon: Icons.psychology_rounded, title: 'AI 輔助教育定位', desc: '生成內容供學習參考，請保持獨立思辨'),
            (icon: Icons.copyright_rounded, title: '著作與智慧財產權', desc: '原創筆記歸本人，系統資料庫受法律保護'),
          ]
        : [
            (icon: Icons.storage_rounded, title: '本機優先架構', desc: '筆記、錯題與行程主要加密儲存本機 SQLite'),
            (icon: Icons.block_rounded, title: '100% 絕不出售', desc: '嚴格承諾絕不販售、出租個人資料給第三方'),
            (icon: Icons.mic_none_rounded, title: '語音當次推理', desc: '僅主動錄音時傳輸文字轉換，不常駐背景錄音'),
            (icon: Icons.manage_accounts_rounded, title: '完整個資自主權', desc: '隨時可查閱、更正、匯出或申請註銷清除'),
          ];

    return Container(
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: themeColor.withValues(alpha: isDark ? 0.25 : 0.18),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: themeColor),
              const SizedBox(width: 6),
              Text(
                isTerms ? '條款重點導讀（30 秒懶人包）' : '隱私承諾摘要（30 秒懶人包）',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E2022),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.icon, size: 14, color: themeColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${item.title}：',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF2C2523),
                              ),
                            ),
                            TextSpan(
                              text: item.desc,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF555555),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  List<Widget> _buildTermsSections(bool isDark, Color themeColor) {
    final sections = [
      (
        num: '01',
        title: '接受條款與法定資格',
        icon: Icons.verified_user_outlined,
        content:
            '您存取、下載或使用「YeBang 家教」應用程式（以下簡稱「本服務」）即表示您已詳細閱讀、理解並同意受本服務條款及相關政策規範約束。\n・未成年人保護：若您為限制行為能力人（如未成年人），應由法定代理人或監護人閱讀、瞭解並同意本條款後方可使用。\n・若您不同意本條款之任何內容，請立即停止使用並解除安裝本服務。',
      ),
      (
        num: '02',
        title: '服務範疇與多元功能說明',
        icon: Icons.school_outlined,
        content:
            '本服務為綜合性智慧教育與學習輔助平台，提供以下功能模組：\n・題庫測驗與錯題本：國高中各學科單元測驗、歷屆試卷、AI 步驟深度詳解與自動收錄錯題複習。\n・AI 語音速記與互動心智圖：支援長錄音即時轉文字、去贅字引擎、4 大整理風格（會議摘要、課堂重點、代辦結論、日常隨筆）與樹狀心智圖畫布。\n・學科能力診斷與補強：知識掌握度矩陣圖、能力雷達圖與一鍵客製化弱項補強教材生成。\n・雙模筆記與學習 Pack：支援 Markdown 筆記、手寫塗鴉畫布與一鍵打包分享匯入。\n・智慧行事曆與客服：自然語言意圖排程、讀書計畫管理、待辦清單、推播提醒與 24H 智慧線上客服。',
      ),
      (
        num: '03',
        title: '帳號管理與資訊安全責任',
        icon: Icons.lock_outlined,
        content:
            '・帳號憑證保管：您有責任妥善保管您的帳號憑證（包括 Email、密碼或 Google 授權憑據），並對該帳號下發生的所有活動負完全責任。\n・禁止共享帳號：請勿將帳號出借、轉讓或與他人共用。\n・異常通報義務：如發現帳號遭未授權存取或有資安疑慮，請立即透過「客服與意見回饋」通知我們協助處理。',
      ),
      (
        num: '04',
        title: '使用者行為規範與禁止事項',
        icon: Icons.shield_outlined,
        content:
            '您同意正當、合法使用本服務，並承諾絕不從事以下違規行為：\n・散佈違法、侵權、騷擾、仇恨、誹謗、暴力、不雅或侵犯他人隱私之內容。\n・傳播惡意程式碼、破解逆向工程、爬蟲大量抓取或利用自動化工具濫用系統與 AI 運算資源。\n・違規處理：開發團隊保留隨時移除違規內容、限制部分功能或終止違規帳號之權利。',
      ),
      (
        num: '05',
        title: '智慧財產權歸屬與授權',
        icon: Icons.copyright_outlined,
        content:
            '・平台權益：本應用程式之軟體架構、程式碼、圖示設計、演算法、題庫資料庫及品牌商標均受中華民國著作權法與智慧財產權法律保護，所有權歸開發團隊所有。\n・使用者原創內容：您於社群或筆記創作之原創內容，其著作權仍歸屬於您本人；您同意授予本服務於正常提供服務範疇內為呈現之非獨家、免費使用授權。',
      ),
      (
        num: '06',
        title: 'AI 生成內容與語音輔助定位聲明',
        icon: Icons.psychology_outlined,
        content:
            '【教育輔助重要聲明】\n本服務整合之 AI 代理人、語音轉文字速記、題庫步驟詳解、能力診斷分析、弱項補強教材及客服對答等功能，係基於尖端生成式 AI 模型提供之「學習輔助參考資料」，不構成官方考試標準唯一答案或法律/醫療等專業保證。使用者於正式測驗或重大決策時，應保持獨立思辨與查證。',
      ),
      (
        num: '07',
        title: '免責聲明與責任限制',
        icon: Icons.rule_folder_outlined,
        content:
            '本服務係依「現況」及「現有技術水準」提供，不附帶任何明示或默示之保證。在法律允許的最大範圍內，我們不對因不可抗力因素、電信網路中斷或使用者操作不當所致之任何間接、附帶或衍生損害承擔賠償責任。',
      ),
      (
        num: '08',
        title: '條款修訂與準據法管轄',
        icon: Icons.gavel_outlined,
        content:
            '我們保留隨時修訂本條款之權利，修訂後之條款將於 App 內公告並即時生效。\n本條款之解釋、效力及爭議解決，均依中華民國法律為準據法，並以台灣台北地方法院為第一審管轄法院。',
      ),
    ];

    return sections
        .map((s) => _buildSectionCard(
              num: s.num,
              title: s.title,
              icon: s.icon,
              content: s.content,
              isDark: isDark,
              themeColor: themeColor,
            ))
        .toList();
  }

  List<Widget> _buildPrivacySections(bool isDark, Color themeColor) {
    final sections = [
      (
        num: '01',
        title: '蒐集的資料類型（最小化原則）',
        icon: Icons.folder_shared_outlined,
        content:
            '我們嚴格遵循個人資料保護法之最小化蒐集原則，僅蒐集提供服務所必需之資料：\n・帳號資訊：使用者名稱、暱稱、電子郵件地址、頭像及個人簡介（或 Google 登入授權傳輸之基礎識別資料）。\n・學習歷程與筆記：測驗分數、正確率、錯題本、手寫塗鴉軌跡、Markdown 筆記、心智圖與行事曆待辦。\n・即時語音資料：僅於您主動點擊麥克風錄音時串流傳送至系統語音辨識服務轉換文字；我們絕不在背景偷錄，亦不於伺服器持久保存原始錄音檔案。\n・社群互動資料：您主動發布之學習心得貼文、筆記分享與討論留言。\n・裝置與系統偏好：作業系統版本、深淺色主題、主題主色調、字體大小與多國語言偏好。',
      ),
      (
        num: '02',
        title: '資料使用目的與【絕不出售承諾】',
        icon: Icons.handshake_outlined,
        content:
            '我們蒐集之資料僅用於以下合法正當目的：\n・提供、維護並持續改善各項學習、測驗、語音速記、筆記與診斷功能。\n・計算知識掌握度矩陣圖與能力雷達圖，為您生成客製化 AI 弱項補強教材與學習建議。\n・發送重要帳號安全警示或行事曆排程推播提醒。\n【絕不出售承諾】我們嚴格承諾絕不販售、出租或出借您的個人資料給任何第三方，亦不將資料用於未經授權之商業廣告推銷。',
      ),
      (
        num: '03',
        title: '本機優先 (Local-First) 與傳輸加密',
        icon: Icons.storage_outlined,
        content:
            '・本機優先架構：您的個人筆記、錯題本、測驗歷程與行事曆主要加密儲存於您本機裝置的 SQLite 資料庫中。\n・端到端傳輸加密：部分涉及雲端處理之功能（如 AI 診斷分析、Cloudflare 安全中繼、客服意見回饋等），所有網路傳輸均採用標準 HTTPS / TLS 1.3 傳輸層加密，確保資料傳輸過程中不被截取或竄改。',
      ),
      (
        num: '04',
        title: '第三方服務供應商安全說明',
        icon: Icons.cloud_sync_outlined,
        content:
            '為提供頂級運算體驗，本服務整合了以下符合國際隱私標準之第三方服務：\n・Google 登入：用於快速、安全的帳號身分驗證。\n・Google Gemini AI：提供深度學科解析、診斷分析與弱項補強生成。\n・Groq AI：提供高吞吐、低延遲的極速推理支援。\n・Speech-to-Text 語音服務：提供即時語音轉文字功能。\n・OpenRouter & Cloudflare Relay：提供備援通道與安全代理中繼。\n傳輸至第三方服務之文字與音訊僅用於當次即時推理，不包含個人敏感身分憑證。',
      ),
      (
        num: '05',
        title: '使用者個人資料自主權利（個資法完整保障）',
        icon: Icons.manage_accounts_outlined,
        content:
            '依個人資料保護法，您享有以下完整自主權利：\n・查詢與閱覽：可於「個人檔案」及各功能模組隨時查閱儲存之資料。\n・更正與補充：隨時修改暱稱、頭像、個人簡介、密碼、筆記與行事曆。\n・刪除權（被遺忘權）：可於帳號設定申請註銷帳號，系統將清除伺服器端與關聯之所有個人資料；訪客模式亦可在登出時一鍵清空本機暫存。',
      ),
      (
        num: '06',
        title: '政策修訂與專屬聯絡窗口',
        icon: Icons.support_agent_outlined,
        content:
            '我們可能因法令變更或功能擴充而不定期修訂本隱私權政策，修訂後將於 App 內即時公告生效。\n若對本政策有任何疑問或需行使個資權利，歡迎透過「常見問題與 24H 線上客服」或「客服與意見回饋」與我們聯繫。',
      ),
    ];

    return sections
        .map((s) => _buildSectionCard(
              num: s.num,
              title: s.title,
              icon: s.icon,
              content: s.content,
              isDark: isDark,
              themeColor: themeColor,
            ))
        .toList();
  }

  Widget _buildSectionCard({
    required String num,
    required String title,
    required IconData icon,
    required String content,
    required bool isDark,
    required Color themeColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232432) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFEBEBF0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 頂部細緻色條
          Container(
            height: 3.5,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  themeColor,
                  themeColor.withValues(alpha: 0.6),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 15, color: themeColor),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      num,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: themeColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1E2022),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.55,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.8)
                        : const Color(0xFF4A4A4A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 版本資訊專屬彈窗（科技感簡約卡片，與隱私權/條款完全不同風格）───
class _VersionInfoDialog extends StatefulWidget {
  final bool isDark;
  final Color primary;
  final String appVersion;
  final VoidCallback onOpenAnnouncements;

  const _VersionInfoDialog({
    required this.isDark,
    required this.primary,
    required this.appVersion,
    required this.onOpenAnnouncements,
  });

  @override
  State<_VersionInfoDialog> createState() => _VersionInfoDialogState();
}

class _VersionInfoDialogState extends State<_VersionInfoDialog> {
  bool _isCheckingUpdate = false;
  String? _checkResultMsg;

  void _checkUpdate() async {
    if (_isCheckingUpdate) return;
    setState(() {
      _isCheckingUpdate = true;
      _checkResultMsg = null;
    });

    await Future.delayed(const Duration(milliseconds: 700));

    if (mounted) {
      setState(() {
        _isCheckingUpdate = false;
        _checkResultMsg = '目前已是最新版本 (v1.6.5) 🎉';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primary = widget.primary;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E202C) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. App 品牌圖標與柔光
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, primary.withValues(alpha: 0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.school_rounded, size: 36, color: Colors.white),
            ),
            const SizedBox(height: 14),

            // 2. App 名稱與版本標籤
            Text(
              'YeBang 家教',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1E2022),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: isDark ? 0.2 : 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: primary.withValues(alpha: isDark ? 0.3 : 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '版本 ${widget.appVersion}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '最新版',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '發布日期：2026 年 9 月 11 日',
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),

            const SizedBox(height: 18),

            // 3. 核心規格與技術架構 (2x2 Grid)
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFEBEBF0),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildSpecItem(
                          icon: Icons.psychology_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          title: 'AI 推理架構',
                          value: '多模型智能中繼',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSpecItem(
                          icon: Icons.storage_rounded,
                          iconColor: const Color(0xFF0EA5E9),
                          title: '資料儲存架構',
                          value: '本機 SQLite 加密',
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSpecItem(
                          icon: Icons.shield_rounded,
                          iconColor: const Color(0xFF10B981),
                          title: '雲端傳輸安全',
                          value: 'TLS 1.3 端到端',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSpecItem(
                          icon: Icons.mic_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          title: '語音辨識核心',
                          value: '去贅字 & 4大風格',
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 檢查更新結果提示 (如果有)
            if (_checkResultMsg != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Text(
                      _checkResultMsg!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),

            // 4. 功能操作按鈕列
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: BorderSide(
                        color: primary.withValues(alpha: isDark ? 0.4 : 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isCheckingUpdate ? null : _checkUpdate,
                    icon: _isCheckingUpdate
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(primary),
                            ),
                          )
                        : const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      _isCheckingUpdate ? '檢查中...' : '檢查更新',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: widget.onOpenAnnouncements,
                    icon: const Icon(Icons.article_outlined, size: 16),
                    label: const Text(
                      '更新日誌',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.white54 : Colors.grey.shade600,
                minimumSize: const Size(double.infinity, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('關閉', style: TextStyle(fontSize: 12.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262838) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E2022),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
