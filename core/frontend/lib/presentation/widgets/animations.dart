import 'package:flutter/material.dart';

/// 动画工具类
class AppAnimations {
  /// 页面过渡动画
  static Route<dynamic> createPageTransition({
    required RouteSettings settings,
    required WidgetBuilder builder,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.3);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        final offsetAnimation = Tween<Offset>(
          begin: begin,
          end: end,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: curve,
        ));

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  /// 淡入动画
  static Widget fadeIn({
    required Widget child,
    required Animation<double> animation,
    Duration delay = Duration.zero,
  }) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: child,
        );
      },
    );
  }

  /// 滑入动画
  static Widget slideIn({
    required Widget child,
    required Animation<double> animation,
    Offset begin = const Offset(0.2, 0),
    Duration delay = Duration.zero,
  }) {
    final slideAnimation = Tween<Offset>(
      begin: begin,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    ));

    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }

  /// 首页进入动画
  static Widget homeEntrance({
    required Widget child,
    required Animation<double> animation,
  }) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.95 + 0.05 * animation.value,
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
    );
  }
}

/// 缩放进入动画组件
class ScaleTransitionWidget extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;

  const ScaleTransitionWidget({
    super.key,
    required this.child,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.9 + 0.1 * animation.value,
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
    );
  }
}

/// 淡入滑入动画组件
class FadeSlideTransition extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final Offset beginOffset;

  const FadeSlideTransition({
    super.key,
    required this.child,
    required this.animation,
    this.beginOffset = const Offset(0, 0.2),
  });

  @override
  Widget build(BuildContext context) {
    final slideAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    ));

    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
}

/// 骨架屏组件
class Skeleton extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const Skeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      width: width,
      height: height,
      duration: const Duration(milliseconds: 1500),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        borderRadius: borderRadius,
      ),
    );
  }
}

/// 加载指示器
class LoadingIndicator extends StatelessWidget {
  final Color? color;
  final double strokeWidth;

  const LoadingIndicator({
    super.key,
    this.color,
    this.strokeWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color?>(
          color ?? Theme.of(context).colorScheme.primary,
        ),
        strokeWidth: strokeWidth,
      ),
    );
  }
}
