import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starpath/core/constants.dart';

const _kPrefsKey = 'main_partner_v2';

/// 主伙伴信息（持久化到 SharedPreferences）
class MainPartnerState {
  final String agentId;
  final String agentName;
  final String? helloVideo;
  final String? haitVideo;
  final String? breatheVideo;
  final String? downVideo;

  const MainPartnerState({
    required this.agentId,
    required this.agentName,
    this.helloVideo,
    this.haitVideo,
    this.breatheVideo,
    this.downVideo,
  });

  MainPartnerState copyWith({
    String? agentId,
    String? agentName,
    String? helloVideo,
    String? haitVideo,
    String? breatheVideo,
    String? downVideo,
  }) =>
      MainPartnerState(
        agentId:      agentId      ?? this.agentId,
        agentName:    agentName    ?? this.agentName,
        helloVideo:   helloVideo   ?? this.helloVideo,
        haitVideo:    haitVideo    ?? this.haitVideo,
        breatheVideo: breatheVideo ?? this.breatheVideo,
        downVideo:    downVideo    ?? this.downVideo,
      );

  Map<String, dynamic> toJson() => {
        'agentId':      agentId,
        'agentName':    agentName,
        'helloVideo':   helloVideo,
        'haitVideo':    haitVideo,
        'breatheVideo': breatheVideo,
        'downVideo':    downVideo,
      };

  factory MainPartnerState.fromJson(Map<String, dynamic> j) =>
      MainPartnerState(
        agentId:      j['agentId']      as String,
        agentName:    j['agentName']    as String,
        helloVideo:   j['helloVideo']   as String?,
        haitVideo:    j['haitVideo']    as String?,
        breatheVideo: j['breatheVideo'] as String?,
        downVideo:    j['downVideo']    as String?,
      );

  /// 内置默认主伙伴：豆包官方人设（preview-0）
  /// 视频由代码根据平台选择，不写死路径。
  static MainPartnerState get defaults => MainPartnerState(
    agentId:      'preview-0',
    agentName:    '豆包',
    helloVideo:   AppConstants.partnerHeroVideoAsset,
    haitVideo:    AppConstants.partnerHeroVideoAsset,
    breatheVideo: AppConstants.partnerHeroVideoAsset,
    downVideo:    AppConstants.partnerHeroVideoAsset,
  );

  /// 转成路由 query 参数
  Map<String, String> toQueryParams() => {
        'agentName':  agentName,
        if (helloVideo   != null) 'helloVideo':   helloVideo!,
        if (haitVideo    != null) 'haitVideo':    haitVideo!,
        if (breatheVideo != null) 'breatheVideo': breatheVideo!,
        if (downVideo    != null) 'downVideo':    downVideo!,
      };

  String get chatUri {
    final uri = Uri(
      path: '/chat/agent/$agentId',
      queryParameters: toQueryParams(),
    );
    return uri.toString();
  }
}

final mainPartnerProvider =
    NotifierProvider<MainPartnerNotifier, MainPartnerState>(
  MainPartnerNotifier.new,
);

class MainPartnerNotifier extends Notifier<MainPartnerState> {
  @override
  MainPartnerState build() {
    Future.microtask(_hydrate);
    return MainPartnerState.defaults;
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final loaded = MainPartnerState.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
      state = loaded;
    } catch (e, st) {
      debugPrint('[MainPartner] 恢复持久化数据失败，将使用默认值: $e\n$st');
    }
  }

  Future<void> setMainPartner(MainPartnerState s) async {
    state = s;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, jsonEncode(s.toJson()));
  }
}
