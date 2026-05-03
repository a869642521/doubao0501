import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 打开他人个人主页（全屏路由 `/u/:userId`）。
void openUserProfileView(BuildContext context, String userId) {
  final id = userId.trim();
  if (id.isEmpty) return;
  context.push('/u/$id');
}
