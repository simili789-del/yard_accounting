import 'package:hive/hive.dart';

import '../../domain/entities/ocr_result.dart';

/// 对账识别草稿（临时存档，供 M2 解析对账读取）。
///
/// 用「非类型化 Hive 盒子」存 JSON，避免注册 Adapter、保持低侵入。
/// M1 负责写，M2 负责读并解析成结构化表格。
class ReconciliationDraftRepository {
  static const String boxName = 'reconciliation_drafts';
  static const String _key = 'latest';

  Box get _box => Hive.box(boxName);

  Future<void> saveLatest({
    required String? imagePath,
    required List<OcrLine> lines,
  }) async {
    await _box.put(_key, {
      'imagePath': imagePath,
      'createdAt': DateTime.now().toIso8601String(),
      'lines': lines.map((l) => l.toJson()).toList(),
    });
  }

  Map<dynamic, dynamic>? loadLatest() => _box.get(_key);
}
