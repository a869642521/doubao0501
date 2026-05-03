import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/discovery/domain/card_model.dart';

/// 用户头像组件。
///
/// - [useRandomAvatar] = false（默认）：优先用 [user.avatarUrl]，无则首字母占位。
/// - [useRandomAvatar] = true：DiceBear `adventurer` 彩色卡通风格，
///   底色从 [StarpathColors.avatarAccents] 按 userId 哈希确定，形状为圆角方块。
/// - [cornerRatio] 控制圆角幅度（默认 0.30 × size）。
class UserAvatar extends StatelessWidget {
  final UserBrief user;
  final double size;
  final bool useRandomAvatar;

  /// 圆角比例（相对于 size）。0 = 正圆，0.30 ≈ 参考图圆角方块。
  final double cornerRatio;

  /// 例如跳转个人主页；为 null 时不包裹点击区域。
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    required this.user,
    this.size = 24,
    this.useRandomAvatar = false,
    this.cornerRatio = 0.30,
    this.onTap,
  });

  // 9 种发色，与 avatarAccents 色板互补，让头像更缤纷
  static const _hairColors = [
    '0d0d0d', 'f5c030', 'e84848', '9040cc',
    '7ec040', 'f07830', '30b8d0', 'c050d8', 'e85890',
  ];

  int get _hash =>
      user.id.codeUnits.fold<int>(0, (h, c) => h * 31 + c).abs();

  Color get _accent => StarpathColors.avatarAccentFor(user.id);

  String get _dicebearUrl {
    final seed = Uri.encodeComponent('${user.id}|${user.nickname}');
    final c = _accent;
    final bg =
        '${c.r.round().toRadixString(16).padLeft(2, '0')}'
        '${c.g.round().toRadixString(16).padLeft(2, '0')}'
        '${c.b.round().toRadixString(16).padLeft(2, '0')}';
    final hair = _hairColors[_hash % _hairColors.length];
    return 'https://api.dicebear.com/9.x/adventurer/png'
        '?seed=$seed'
        '&size=160'
        '&backgroundColor=$bg'
        '&hairColor=$hair';
  }

  String? get _networkUrl {
    if (useRandomAvatar) return _dicebearUrl;
    final u = user.avatarUrl;
    if (u != null && u.isNotEmpty) return u;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final url = _networkUrl;
    final radius = BorderRadius.circular(size * cornerRatio);

    late final Widget avatar;
    if (!useRandomAvatar) {
      if (url != null) {
        avatar = ClipOval(
          child: CachedNetworkImage(
            imageUrl: url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _placeholder(isCircle: true),
          ),
        );
      } else {
        avatar = _placeholder(isCircle: true);
      }
    } else {
      avatar = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: radius,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: CachedNetworkImage(
            imageUrl: url!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _placeholder(isCircle: false),
          ),
        ),
      );
    }

    final cb = onTap;
    if (cb == null) return avatar;

    if (!useRandomAvatar) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: cb,
          customBorder: const CircleBorder(),
          child: avatar,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: cb,
        borderRadius: radius,
        child: avatar,
      ),
    );
  }

  Widget _placeholder({required bool isCircle}) {
    final initial =
        user.nickname.isNotEmpty ? user.nickname[0].toUpperCase() : '?';
    final bg = useRandomAvatar ? _accent : null;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        gradient: bg == null ? StarpathColors.primaryGradient : null,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(size * cornerRatio),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.46,
          color: isCircle ? StarpathColors.onPrimary : Colors.white,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
