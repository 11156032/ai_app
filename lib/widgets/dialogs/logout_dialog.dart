import 'package:flutter/material.dart';

void showLogoutDialog({
  required BuildContext context,
  required Color primaryColor,
  required VoidCallback onLogout,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('系統提示'),
      content: const Text('確定要登出並切換至其他帳號嗎？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(ctx);
            onLogout();
          },
          child: const Text('確定登出'),
        ),
      ],
    ),
  );
}
