import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starpath/features/agent_studio/presentation/partner_background_state.dart';

const _kPrefsKey = 'partner_bg_state_v2';

final partnerBackgroundProvider =
    NotifierProvider<PartnerBackgroundNotifier, PartnerBackgroundState>(
  PartnerBackgroundNotifier.new,
);

class PartnerBackgroundNotifier extends Notifier<PartnerBackgroundState> {
  Timer? _saveDebounce;

  @override
  PartnerBackgroundState build() {
    ref.onDispose(() {
      _saveDebounce?.cancel();
    });
    Future.microtask(_hydrate);
    return PartnerBackgroundState.fromDefaults();
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw == null || raw.isEmpty) return;
    final parsed = partnerBackgroundStateFromJsonString(raw);
    if (parsed != null) {
      state = parsed;
    }
  }

  void replace(PartnerBackgroundState next) {
    state = next;
    _scheduleSave();
  }

  Future<void> resetToDefaults() async {
    state = PartnerBackgroundState.fromDefaults();
    await saveNow();
  }

  Future<void> saveNow() async {
    _saveDebounce?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, partnerBackgroundStateToJsonString(state));
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 450), () {
      // ignore: discarded_futures
      saveNow();
    });
  }
}
