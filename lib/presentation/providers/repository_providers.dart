import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/record_repository.dart';
import '../../data/repositories/settings_repository.dart';

final recordRepositoryProvider = Provider<RecordRepository>((ref) {
  return RecordRepository();
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

/// 主题模式状态（浅色/深色/跟随系统），供 MaterialApp 与设置页共用。
final themeModeProvider = StateProvider<String>((ref) {
  return ref.read(settingsRepositoryProvider).getThemeMode();
});
