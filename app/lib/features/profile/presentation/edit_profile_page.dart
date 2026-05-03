import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/profile/data/profile_providers.dart';
import 'package:starpath/features/profile/domain/user_profile_model.dart';

class EditProfilePage extends ConsumerWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(currentUserProfileProvider);
    return async.when(
      loading: () => Scaffold(
        backgroundColor: StarpathColors.surface,
        appBar: AppBar(title: const Text('编辑资料')),
        body: const Center(
          child: CircularProgressIndicator(color: StarpathColors.accentViolet),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: StarpathColors.surface,
        appBar: AppBar(title: const Text('编辑资料')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: StarpathColors.onSurfaceVariant),
            ),
          ),
        ),
      ),
      data: (p) {
        if (p == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.pop();
          });
          return const Scaffold(
            backgroundColor: StarpathColors.surface,
            body: SizedBox.shrink(),
          );
        }
        return _EditProfileBody(profile: p);
      },
    );
  }
}

class _EditProfileBody extends ConsumerStatefulWidget {
  final UserProfile profile;

  const _EditProfileBody({required this.profile});

  @override
  ConsumerState<_EditProfileBody> createState() => _EditProfileBodyState();
}

class _EditProfileBodyState extends ConsumerState<_EditProfileBody> {
  late final TextEditingController _nickname;
  late final TextEditingController _avatarUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nickname = TextEditingController(text: widget.profile.nickname);
    _avatarUrl = TextEditingController(text: widget.profile.avatarUrl ?? '');
  }

  @override
  void dispose() {
    _nickname.dispose();
    _avatarUrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);
    final repo = ref.read(profileRepositoryProvider);
    final nick = _nickname.text.trim();
    final url = _avatarUrl.text.trim();
    try {
      await repo.updateProfile(
        widget.profile.id,
        nickname: nick.isEmpty ? widget.profile.nickname : nick,
        avatarUrl: url.isEmpty ? null : url,
      );
      ref.invalidate(currentUserProfileProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败：$e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StarpathColors.surface,
      appBar: AppBar(
        title: const Text('编辑资料'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _nickname,
            decoration: const InputDecoration(
              labelText: '昵称',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _avatarUrl,
            decoration: const InputDecoration(
              labelText: '头像 URL（可选）',
              border: OutlineInputBorder(),
              hintText: 'https://…',
            ),
            keyboardType: TextInputType.url,
            minLines: 1,
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: const Text('保存修改'),
          ),
        ],
      ),
    );
  }
}
