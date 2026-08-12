import 'dart:convert';

import '../../domain/entities/work_record.dart';

/// 记账记录的 CSV / JSON 序列化与反序列化。
///
/// CSV 列（均用双引号包裹，内部双引号转义为两个双引号）：
///   id,日期,姓名,车号,班次,作业量,金额,备注,船名
/// 其中「作业量」格式为 `类型A:数量;类型B:数量`（如 `装车:56;卸车:30`）。
///
/// JSON 结构：`{'version':1,'records':[ {...WorkRecord 字段...} ]}`。
class RecordSerialization {
  RecordSerialization._();

  /// 导出为 CSV 文本。金额按当前单价配置实时计算（便于离线核对）。
  static String toCsv(List<WorkRecord> records, Map<String, double> unitPrices) {
    final buf = StringBuffer();
    buf.writeln([
      _csv('id'),
      _csv('日期'),
      _csv('姓名'),
      _csv('车号'),
      _csv('班次'),
      _csv('作业量'),
      _csv('金额'),
      _csv('备注'),
      _csv('船名'),
    ].join(','));

    for (final r in records) {
      final jobStr = r.jobQuantities.entries
          .where((e) => e.value != 0)
          .map((e) => '${e.key}:${e.value}')
          .join(';');
      buf.writeln([
        _csv(r.id),
        _csv(_dateStr(r.date)),
        _csv(r.workerName),
        _csv(r.vehicleNo),
        _csv(r.shift == ShiftType.day ? '白班' : '夜班'),
        _csv(jobStr),
        _csv(r.amount(unitPrices).toStringAsFixed(2)),
        _csv(r.remark ?? ''),
        _csv(r.boatName ?? ''),
      ].join(','));
    }
    return buf.toString();
  }

  /// 从 CSV 文本解析记录。忽略表头与空行。
  static List<WorkRecord> fromCsv(String csv) {
    final lines = csv.replaceAll('\r\n', '\n').split('\n');
    if (lines.isEmpty) return [];

    int start = 0;
    final header = lines[0].toLowerCase();
    if (header.contains('日期') || header.startsWith('"id"') || header.startsWith('id,')) {
      start = 1;
    }

    final records = <WorkRecord>[];
    for (var i = start; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final f = _parseCsvLine(line);
      if (f.length < 6) continue;

      final date = _parseDate(f[1]);
      if (date == null) continue;

      final shift = f[4] == '夜班' ? ShiftType.night : ShiftType.day;
      final jobQuantities = <String, int>{};
      for (final part in f[5].split(';')) {
        final seg = part.trim();
        if (seg.isEmpty) continue;
        final idx = seg.lastIndexOf(':');
        if (idx <= 0) continue;
        final name = seg.substring(0, idx).trim();
        final qty = int.tryParse(seg.substring(idx + 1).trim());
        if (name.isNotEmpty && qty != null) jobQuantities[name] = qty;
      }

      records.add(WorkRecord(
        id: f[0].isNotEmpty ? f[0] : _makeId(date, f[2]),
        date: date,
        workerName: f[2],
        vehicleNo: f[3],
        shift: shift,
        jobQuantities: jobQuantities,
        remark: f.length > 7 ? f[7] : null,
        boatName: f.length > 8 && f[8].isNotEmpty ? f[8] : null,
      ));
    }
    return records;
  }

  /// 导出为 JSON 文本（可读、可经系统分享保存）。
  static String toJson(List<WorkRecord> records) {
    final list = records.map((r) => <String, dynamic>{
      'id': r.id,
      'date': r.date.toIso8601String(),
      'workerName': r.workerName,
      'vehicleNo': r.vehicleNo,
      'shift': r.shift == ShiftType.day ? 'day' : 'night',
      'jobQuantities': r.jobQuantities,
      'remark': r.remark,
      'boatName': r.boatName,
    }).toList();
    return jsonEncode({'version': 1, 'records': list});
  }

  /// 从 JSON 文本解析记录。容错：跳过缺日期的条目。
  static List<WorkRecord> fromJson(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    final raw = decoded is Map ? decoded['records'] : decoded;
    if (raw is! List) return [];

    final records = <WorkRecord>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final date = DateTime.tryParse(m['date']?.toString() ?? '');
      if (date == null) continue;

      final shift = m['shift'] == 'night' ? ShiftType.night : ShiftType.day;
      final jq = <String, int>{};
      final rawJq = m['jobQuantities'];
      if (rawJq is Map) {
        rawJq.forEach((k, v) => jq[k.toString()] = (v as num).toInt());
      }

      records.add(WorkRecord(
        id: m['id']?.toString() ?? _makeId(date, m['workerName']?.toString() ?? ''),
        date: date,
        workerName: m['workerName']?.toString() ?? '',
        vehicleNo: m['vehicleNo']?.toString() ?? '',
        shift: shift,
        jobQuantities: jq,
        remark: m['remark']?.toString(),
        boatName: m['boatName']?.toString(),
      ));
    }
    return records;
  }

  static String _makeId(DateTime date, String name) {
    final d =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return 'imp_${d}_$name';
  }

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(String s) => DateTime.tryParse(s.trim());

  static String _csv(String v) => '"${v.replaceAll('"', '""')}"';

  /// 解析一行 CSV（支持双引号包裹字段、字段内双引号转义、逗号分隔）。
  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final cur = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            cur.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          cur.write(c);
        }
      } else {
        if (c == '"') {
          inQuotes = true;
        } else if (c == ',') {
          result.add(cur.toString());
          cur.clear();
        } else {
          cur.write(c);
        }
      }
    }
    result.add(cur.toString());
    return result;
  }
}
