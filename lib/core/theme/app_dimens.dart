import 'package:flutter/material.dart';

/// 全局间距令牌（Design Tokens）。
///
/// 目的：把散落在各页面里的 12 / 16 / 8 等魔法数字收敛成一套命名尺度，
/// 后续统一调整视觉密度（如做平板适配）时只需改这一处。
/// 这是纯新增文件，不改动任何现有类型/字段，接入零风险。
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// 圆角令牌：统一卡片/按钮/输入框的圆角规范，避免同一层级出现
/// 12/16/20 混用导致的视觉不一致。
class AppRadius {
  AppRadius._();

  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;

  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get control => BorderRadius.circular(md);
  static BorderRadius get chip => BorderRadius.circular(sm);
  static BorderRadius get pill => BorderRadius.circular(999);
}

/// 动效令牌：统一交互动画的时长与曲线，保证全 App 手感一致。
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
}
