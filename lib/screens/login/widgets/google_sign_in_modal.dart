import 'package:flutter/material.dart';
import '../../../database/database_helper.dart';

// ── Google 專屬模擬登入視窗組件 ──────────────────────────────────────────────────

class GoogleSpinner extends StatefulWidget {
  const GoogleSpinner({super.key});
  @override
  State<GoogleSpinner> createState() => _GoogleSpinnerState();
}

class _GoogleSpinnerState extends State<GoogleSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: SizedBox(
        width: 45,
        height: 45,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            Color color;
            if (_controller.value < 0.25) {
              color = const Color(0xFF4285F4); // Blue
            } else if (_controller.value < 0.5) {
              color = const Color(0xFFEA4335); // Red
            } else if (_controller.value < 0.75) {
              color = const Color(0xFFFBBC05); // Yellow
            } else {
              color = const Color(0xFF34A853); // Green
            }
            return CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            );
          },
        ),
      ),
    );
  }
}

class GoogleSignInModal extends StatefulWidget {
  final Function(String email, String name) onAccountSelected;
  const GoogleSignInModal({super.key, required this.onAccountSelected});

  @override
  State<GoogleSignInModal> createState() => _GoogleSignInModalState();
}

class _GoogleSignInModalState extends State<GoogleSignInModal> {
  bool _isLoading = false;
  bool _isAddingAccount = false;
  bool _isRemovingMode = false;

  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<Map<String, String>> _presetAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadExistingAccounts();
  }

  Future<void> _loadExistingAccounts() async {
    try {
      final db = await DatabaseHelper.instance.database;
      // 查詢 SQLite 中所有曾以 Google 登入 (is_google = 1) 的使用者
      final res = await db.query(
        'users',
        where: 'is_google = 1',
      );
      if (!mounted) return;
      setState(() {
        _presetAccounts = res.map((row) {
          final name =
              (row['display_name'] ?? row['username'] ?? '').toString();
          final email = (row['email'] ?? '').toString();
          final initial = name.isNotEmpty ? name.substring(0, 1) : '?';
          return {
            'name': name,
            'email': email,
            'initial': initial,
          };
        }).toList();

        // 若無任何已登入的 Google 帳號，直接進入輸入畫面
        if (_presetAccounts.isEmpty) {
          _isAddingAccount = true;
          _isRemovingMode = false;
        }
      });
    } catch (e) {
      debugPrint('載入 Google 帳號清單失敗: $e');
    }
  }

  Future<void> _removeAccount(String email) async {
    try {
      final db = await DatabaseHelper.instance.database;
      // 方案一：僅將 is_google 設為 0
      await db.update(
        'users',
        <String, Object?>{'is_google': 0},
        where: 'email = ?',
        whereArgs: [email],
      );
      await _loadExistingAccounts();
    } catch (e) {
      debugPrint('移除 Google 帳號連結失敗: $e');
    }
  }

  Future<void> _confirmRemoveAccount(String email, String name) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移除帳號？'),
        content: Text('這會將「$name ($email)」從此裝置的登入清單中移除。\n\n您在此APP所有資料仍會妥善保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('確認移除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _removeAccount(email);
    }
  }

  void _selectAccount(String email, String name) {
    setState(() {
      _isLoading = true;
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        widget.onAccountSelected(email, name);
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Widget _buildGoogleLogoText() {
    final styles = [
      const TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.bold),
      const TextStyle(color: Color(0xFFEA4335), fontWeight: FontWeight.bold),
      const TextStyle(color: Color(0xFFFBBC05), fontWeight: FontWeight.bold),
      const TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.bold),
      const TextStyle(color: Color(0xFF34A853), fontWeight: FontWeight.bold),
      const TextStyle(color: Color(0xFFEA4335), fontWeight: FontWeight.bold),
    ];
    final letters = ['G', 'o', 'o', 'g', 'l', 'e'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(6, (i) {
        return Text(
          letters[i],
          style: styles[i].copyWith(fontSize: 22, letterSpacing: 0.5),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double modalWidth =
        MediaQuery.of(context).size.width.clamp(300.0, 420.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: modalWidth,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _isLoading
              ? _buildLoadingState()
              : (_isAddingAccount
                  ? _buildAddAccountState()
                  : _buildAccountSelectorState()),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        const GoogleSpinner(),
        const SizedBox(height: 24),
        Text(
          '正在透過 Google 安全驗證...',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildAccountSelectorState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildGoogleLogoText(),
        const SizedBox(height: 16),
        const Text(
          '選取帳號',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFF202124),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '以繼續前往 YeBang 家教',
          style: TextStyle(
            fontSize: 13.5,
            color: Color(0xFF5F6368),
          ),
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: _presetAccounts.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFF1F3F4)),
            itemBuilder: (ctx, i) {
              final acc = _presetAccounts[i];
              return InkWell(
                onTap: _isRemovingMode
                    ? () => _confirmRemoveAccount(acc['email']!, acc['name']!)
                    : () => _selectAccount(acc['email']!, acc['name']!),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Row(
                    children: [
                      _buildAccountAvatar(acc['initial']!, i),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              acc['name']!,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3C4043),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              acc['email']!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF5F6368),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _isRemovingMode
                          ? const Icon(Icons.remove_circle_outline_rounded,
                              size: 20, color: Colors.redAccent)
                          : const Icon(Icons.chevron_right_rounded,
                              size: 18, color: Color(0xFF747775)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF1F3F4)),
        if (!_isRemovingMode) ...[
          InkWell(
            onTap: () => setState(() => _isAddingAccount = true),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Row(
                children: [
                  Icon(Icons.person_add_alt_1_rounded,
                      size: 20, color: Color(0xFF1A73E8)),
                  SizedBox(width: 14),
                  Text(
                    '使用其他帳號',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A73E8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F3F4)),
          InkWell(
            onTap: () => setState(() => _isRemovingMode = true),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Row(
                children: [
                  Icon(Icons.remove_circle_outline_rounded,
                      size: 20, color: Color(0xFF5F6368)),
                  SizedBox(width: 14),
                  Text(
                    '移除帳號',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5F6368),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          InkWell(
            onTap: () => setState(() => _isRemovingMode = false),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 20, color: Color(0xFF1A73E8)),
                  SizedBox(width: 8),
                  Text(
                    '完成',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A73E8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          '若要繼續，Google 會將您的姓名、電子郵件地址和個人資料相片與 YeBang 家教共用。請務必詳閱 YeBang 家教的服務條款和隱私權政策。',
          textAlign: TextAlign.start,
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF70757A),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildAddAccountState() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildGoogleLogoText(),
          const SizedBox(height: 16),
          const Text(
            '新增 Google 帳號',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Color(0xFF202124),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: '電子郵件地址 (Google 帳號)',
              hintText: 'user@gmail.com',
              labelStyle: const TextStyle(fontSize: 14),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF1A73E8), width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return '請輸入電子郵件';
              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(val.trim())) return '電子郵件格式不正確';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: '您的姓名',
              hintText: '如：小明',
              labelStyle: const TextStyle(fontSize: 14),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF1A73E8), width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return '請輸入姓名';
              return null;
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => setState(() => _isAddingAccount = false),
                child: const Text('返回',
                    style: TextStyle(
                        color: Color(0xFF1A73E8), fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _selectAccount(
                        _emailCtrl.text.trim(), _nameCtrl.text.trim());
                  }
                },
                child: const Text('下一步',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountAvatar(String initial, int index) {
    final colors = [
      const Color(0xFF4285F4), // Blue
      const Color(0xFFEA4335), // Red
      const Color(0xFFFBBC05), // Yellow
      const Color(0xFF34A853), // Green
      Colors.purple,
    ];
    final color = colors[index % colors.length];
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
