import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/record_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/entities/salary_settings.dart';

final recordRepositoryProvider = Provider<RecordRepository>((ref) {
  return RecordRepository();
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

/// 作业类型同义字归一：把「剁/垛」等简繁/形近字视为同一字符，避免一个字写两遍
/// 造成首/首页单价不一致（历史上「内倒归剁」和「内倒归垛」并存就是一例）。
String _canonicalJobKey(String name) {
  return name
      .replaceAll('垛', '剁')
      .replaceAll('堆', '剁')
      .replaceAll('垜', '剁');
}

/// 作业类型相似（归一化后相同）合并组：保留单价较高的那条并保留其原名（用户最后改的
/// 通常更准），清理其他同义字条目。所有监听者（首页/统计页/设置页）自动刷新。
Map<String, double> _mergeSynonyms(Map<String, double> source) {
  final groups = <String, MapEntry<String, double>>{}; // canonical -> (原 key, 价)
  final order = <String>[]; // 首次出现顺序
  for (final entry in source.entries) {
    final canon = _canonicalJobKey(entry.key);
    final existing = groups[canon];
    if (existing == null) {
      groups[canon] = MapEntry(entry.key, entry.value);
      order.add(canon);
    } else if (entry.value > existing.value) {
      // 同义字的多条：保留价格更高的，并记下被合并的旧名（用于清理 Hive）
      groups[canon] = MapEntry(entry.key, entry.value);
    }
  }
  // 保留较优条的「原名」作为最终 key
  return {
    for (final c in order) groups[c]!.key: groups[c]!.value,
  };
}


/// 作业类型单价列表（响应式）：设置页增删改后，首页/统计页自动刷新
final unitPricesProvider =
    StateNotifierProvider<UnitPricesNotifier, Map<String, double>>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return UnitPricesNotifier(repo);
});

class UnitPricesNotifier extends StateNotifier<Map<String, double>> {
  final SettingsRepository _repo;
  UnitPricesNotifier(this._repo) : super(_mergeSynonyms(_repo.getUnitPrices()));

  void refresh() {
    final raw = _repo.getUnitPrices();
    final merged = _mergeSynonyms(raw);
    _persistMerged(merged, sourceKeys: raw.keys);
    state = merged;
  }

  void setPrice(String jobType, double price) {
    final canon = _canonicalJobKey(jobType);
    // 同义字合并：清理其他形近字
    final toDelete = state.keys
        .where((k) => k != jobType && _canonicalJobKey(k) == canon)
        .toList();
    for (final k in toDelete) {
      _repo.removeJobType(k);
    }
    _repo.setUnitPrice(jobType, price);
    final next = Map<String, double>.from(state);
    for (final k in toDelete) {
      next.remove(k);
    }
    next[jobType] = price;
    state = next;
  }

  void remove(String jobType) {
    _repo.removeJobType(jobType);
    state = Map<String, double>.from(state)..remove(jobType);
  }

  /// 重命名作业类型：保留原单价，旧名删除、新名写入。
  /// 如果新名与已存在的某条是同义字，会触发合并（保留较新名称的单价）。
  void rename(String oldName, String newName) {
    if (oldName == newName) return;
    final price = state[oldName] ?? 1.0;
    _repo.setUnitPrice(newName, price);
    _repo.removeJobType(oldName);
    final next = Map<String, double>.from(state);
    next.remove(oldName);
    next[newName] = price;
    state = _mergeSynonyms(next);
  }

  void add(String jobType, double price) {
    _repo.setUnitPrice(jobType, price);
    final next = Map<String, double>.from(state)..[jobType] = price;
    state = _mergeSynonyms(next);
  }

  /// 把合并后的结果写回 Hive：把原 source 中所有不在合并结果里的 key 删掉。
  void _persistMerged(
    Map<String, double> merged, {
    required Iterable<String> sourceKeys,
  }) {
    final mergedKeys = merged.keys.toSet();
    for (final k in sourceKeys) {
      if (!mergedKeys.contains(k)) {
        _repo.removeJobType(k);
      }
    }
  }
}

/// 工资构成设置（响应式）
final salarySettingsProvider =
    StateNotifierProvider<SalarySettingsNotifier, SalarySettings>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return SalarySettingsNotifier(repo);
});

class SalarySettingsNotifier extends StateNotifier<SalarySettings> {
  final SettingsRepository _repo;
  SalarySettingsNotifier(this._repo) : super(_repo.getSalarySettings());

  void update(SalarySettings settings) {
    _repo.saveSalarySettings(settings);
    state = settings;
  }
}

/// 主题模式状态（浅色/深色/跟随系统），供 MaterialApp 与设置页共用。
final themeModeProvider = StateProvider<String>((ref) {
  return ref.read(settingsRepositoryProvider).getThemeMode();
});
