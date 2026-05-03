import 'package:flutter/material.dart';
import 'package:starpath/core/theme.dart';

/// 设置入口占位，后续可接通知、隐私、账号等。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StarpathColors.surface,
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.tune_rounded,
                color: StarpathColors.onSurfaceVariant),
            title: const Text('通用'),
            subtitle: const Text('即将开放'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('功能开发中'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_none_rounded,
                color: StarpathColors.onSurfaceVariant),
            title: const Text('通知'),
            subtitle: const Text('即将开放'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('功能开发中'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
