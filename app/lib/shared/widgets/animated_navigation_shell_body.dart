import 'package:flutter/material.dart';

const _kTabSwitchDuration = Duration(milliseconds: 380);
const _kTabSwitchCurve = Curves.easeOutCubic;

/// 底部 Tab 切换时的动效：淡入 + 轻微上滑 + 缩放。
/// 与 [StatefulShellRoute] 的 `navigatorContainerBuilder` 配合使用，保留各分支 Navigator 状态。
class AnimatedNavigationShellBody extends StatelessWidget {
  const AnimatedNavigationShellBody({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < children.length; i++)
            _AnimatedBranchLayer(
              active: i == currentIndex,
              child: children[i],
            ),
        ],
      ),
    );
  }
}

class _AnimatedBranchLayer extends StatelessWidget {
  const _AnimatedBranchLayer({
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !active,
      child: AnimatedOpacity(
        opacity: active ? 1 : 0,
        duration: _kTabSwitchDuration,
        curve: _kTabSwitchCurve,
        child: AnimatedSlide(
          offset: active ? Offset.zero : const Offset(0, 0.04),
          duration: _kTabSwitchDuration,
          curve: _kTabSwitchCurve,
          child: AnimatedScale(
            scale: active ? 1 : 0.965,
            duration: _kTabSwitchDuration,
            curve: _kTabSwitchCurve,
            // TickerMode 必须在动画组件内部，否则不活跃分支的淡出动画会因
            // Ticker 被禁用而卡在 opacity:1，导致高索引 Tab 遮住低索引 Tab。
            child: TickerMode(
              enabled: active,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
