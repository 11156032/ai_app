part of 'main_screen.dart';

// ignore: library_private_types_in_public_api
extension MainScreenLeaderboardTab on _MainScreenState {
  Widget _buildLeaderboardTab() {
    // 依選定排序方式排序
    final sorted = [..._leaderboardList];
    if (_leaderboardSortType == 'accuracy') {
      sorted.sort((a, b) {
        // 無作答排最後
        if (a['totalAnswered'] == 0 && b['totalAnswered'] == 0) return 0;
        if (a['totalAnswered'] == 0) return 1;
        if (b['totalAnswered'] == 0) return -1;
        return (b['accuracy'] as double).compareTo(a['accuracy'] as double);
      });
    } else {
      sorted.sort((a, b) =>
          (b['totalAnswered'] as int).compareTo(a['totalAnswered'] as int));
    }

    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      color: _isDarkMode ? Colors.black87 : const Color(0xFFF5F3F0),
      child: Column(
        children: [
          // ── Header 漸層卡片 ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor,
                  primaryColor.withValues(alpha: 0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.leaderboard_rounded,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      '排行榜',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '共 ${sorted.length} 人',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '比較所有使用者的測驗表現',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                // 排序切換按鈕列
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      _buildSortToggle('正確率排行', 'accuracy'),
                      _buildSortToggle('答題數排行', 'total'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 排行榜列表 ──
          Expanded(
            child: sorted.isEmpty
                ? _buildEmptyLeaderboard()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final user = sorted[index];
                      if (index == 0 && sorted.length >= 3) {
                        // 前 3 名以 Podium 樣式顯示
                        return _buildTopThreePodium(sorted);
                      } else if (index < 3 && sorted.length >= 3) {
                        return const SizedBox.shrink();
                      }
                      return _buildRankItem(user, index + 1);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortToggle(String label, String type) {
    final bool isSelected = _leaderboardSortType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => _update(() => _leaderboardSortType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopThreePodium(List<Map<String, dynamic>> sorted) {
    // 排名 1, 2, 3
    final rank1 = sorted[0];
    final rank2 = sorted.length > 1 ? sorted[1] : null;
    final rank3 = sorted.length > 2 ? sorted[2] : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 第 2 名
          if (rank2 != null)
            Expanded(child: _buildPodiumItem(rank2, 2, 90))
          else
            const Expanded(child: SizedBox()),
          // 第 1 名（中間最高）
          Expanded(child: _buildPodiumItem(rank1, 1, 120)),
          // 第 3 名
          if (rank3 != null)
            Expanded(child: _buildPodiumItem(rank3, 3, 75))
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(Map<String, dynamic> user, int rank, double height) {
    final bool isMe = user['userId'] == widget.currentUser['id'];
    final Color medalColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFB0BEC5)
            : const Color(0xFFCD7F32);

    final String medalEmoji = rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉';
    final String valueLabel = _leaderboardSortType == 'accuracy'
        ? (user['totalAnswered'] > 0
            ? '${(user['accuracy'] as double).toStringAsFixed(1)}%'
            : '--')
        : '${user['totalAnswered']} 題';

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 名稱與「你」標籤
        if (isMe)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('你',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        // Medal emoji
        Text(medalEmoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        // Avatar
        Stack(
          clipBehavior: Clip.none,
          children: [
            buildAvatar(
              blob: user['avatarBlob'] as Uint8List?,
              colorIdx: user['avatarColor'] as int,
              initial: (user['name'] as String).substring(0, 1),
              radius: rank == 1 ? 30 : 24,
              usePreset: (user['avatarSelected'] as int) == 1 &&
                  user['avatarBlob'] == null,
            ),
            if (isMe)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.person,
                      color: Colors.white, size: 8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          user['name'] as String,
          style: TextStyle(
              fontSize: rank == 1 ? 13.5 : 12,
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? Colors.white : Colors.black87),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          valueLabel,
          style: TextStyle(
              fontSize: rank == 1 ? 13 : 11.5,
              color: medalColor,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        // 底座
        Container(
          height: height,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                medalColor.withValues(alpha: 0.9),
                medalColor.withValues(alpha: 0.5),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankItem(Map<String, dynamic> user, int rank) {
    final bool isMe = user['userId'] == widget.currentUser['id'];
    final String valueLabel = _leaderboardSortType == 'accuracy'
        ? (user['totalAnswered'] > 0
            ? '${(user['accuracy'] as double).toStringAsFixed(1)}%'
            : '暫無資料')
        : '${user['totalAnswered']} 題';

    final String subLabel = _leaderboardSortType == 'accuracy'
        ? '答對 ${user['totalCorrect']} / 共 ${user['totalAnswered']} 題'
        : '正確率 ${user['totalAnswered'] > 0 ? (user['accuracy'] as double).toStringAsFixed(1) : "--"}%';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? (Theme.of(context).primaryColor.withValues(alpha: 0.08))
            : (_isDarkMode ? const Color(0xFF1E1E1E) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: isMe
            ? Border.all(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
                width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isMe ? 0.06 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // 排名數字
          SizedBox(
            width: 36,
            child: Text(
              '#$rank',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: rank <= 10
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade400),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          // 頭像
          buildAvatar(
            blob: user['avatarBlob'] as Uint8List?,
            colorIdx: user['avatarColor'] as int,
            initial: (user['name'] as String).substring(0, 1),
            radius: 20,
            usePreset: (user['avatarSelected'] as int) == 1 &&
                user['avatarBlob'] == null,
          ),
          const SizedBox(width: 12),
          // 名稱與副標題
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user['name'] as String,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _isDarkMode ? Colors.white : Colors.black87),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('你',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subLabel,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: _isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600),
                ),
              ],
            ),
          ),
          // 主要數值
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                valueLabel,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: user['totalAnswered'] == 0
                        ? Colors.grey.shade400
                        : Theme.of(context).primaryColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLeaderboard() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard_outlined,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('尚無排行資料',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text('完成測驗後即可在此查看排名',
              style:
                  TextStyle(fontSize: 13.5, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}
