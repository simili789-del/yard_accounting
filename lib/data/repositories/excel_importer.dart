import 'dart:io';

import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

import '../../domain/entities/work_record.dart';
import '../../domain/models/imported_row.dart';

/// 默认优先解析的 sheet（用户已确认只导「铲车绩效表」）。
const String _defaultSheet = '铲车绩效表';

/// 解析 xlsx 的一次性结果，供导入向导直接使用。
class ExcelParseResult {
  final List<String> sheetNames;
  final String sheetName;
  final int headerRow;
  final int? nameCol;
  final int? vehCol;
  final int? remarkCol;
  final List<CleanedColumn> jobColumns;
  final List<ImportedRow> rows;
  final DateTime? date;
  final ShiftType shift;

  /// 船名列（可选；挖掘机绩效表的船名常在表头为空的 A 列）。
  final int? boatCol;

  /// 清洗前的原始作业类型列名（用于「模板记忆」指纹匹配）。
  final List<String> rawJobColumns;

  /// 表格里的「合计」行（清洗后列名 -> 车数合计），作为导入对账基准。
  /// 没有合计行时为 null。
  final Map<String, int>? sheetTotals;

  ExcelParseResult({
    required this.sheetNames,
    required this.sheetName,
    required this.headerRow,
    this.nameCol,
    this.vehCol,
    this.remarkCol,
    this.boatCol,
    required this.jobColumns,
    required this.rows,
    this.date,
    required this.shift,
    this.rawJobColumns = const [],
    this.sheetTotals,
  });
}

/// 解析 xlsx：定位表头行 → 清洗作业类型列名（剥离「1.8元」单价）→
/// 跳过合计/标题行 → 提取每个人各作业类型车数，并解析班次与日期。
///
/// [sheetName] 不传则默认「铲车绩效表」；[headerRow] 不传则自动扫描含「姓名」的行。
ExcelParseResult parseXlsx(String path, {String? sheetName, int? headerRow}) {
  final bytes = File(path).readAsBytesSync();
  final decoder = SpreadsheetDecoder.decodeBytes(bytes);
  final sheetNames = decoder.tables.keys.toList();

  var target = sheetName ?? _defaultSheet;
  if (!decoder.tables.containsKey(target)) {
    // 默认表不存在时，回退到第一个含「姓名」表头的 sheet
    // （兼容只含挖掘机表的文件，避免硬报错）
    target = sheetNames.firstWhere(
      (s) {
        final t = decoder.tables[s];
        if (t == null) return false;
        return t.rows
            .any((r) => r.any((c) => _text(c)?.contains('姓名') ?? false));
      },
      orElse: () => target,
    );
  }
  final table = decoder.tables[target];
  if (table == null) {
    throw Exception('未找到工作表「$target」，可用：${sheetNames.join('、')}');
  }
  final rows = table.rows;

  // 1) 定位表头行
  int headerIdx;
  if (headerRow != null) {
    headerIdx = headerRow;
  } else {
    headerIdx =
        rows.indexWhere((r) => r.any((c) => _text(c)?.contains('姓名') ?? false));
    if (headerIdx < 0) {
      throw Exception('未找到表头（包含「姓名」的行），请手动指定表头行');
    }
  }
  if (headerIdx >= rows.length) {
    throw Exception('表头行 $headerIdx 超出表格范围');
  }

  // 2) 归类列：姓名 / 车号 / 备注 / 船名 / 日期 / 班次 单列标记；
  //    签字等无用列、米/吨/方等非车次单位列直接忽略；
  //    其余列：铲车表=作业类型列，挖掘机表=车数列（由 boatCol 是否存在决定模式）。
  final headerCells = rows[headerIdx];
  int? nameCol, vehCol, remarkCol, boatCol, dateCol, shiftCol;
  final jobCols = <int, CleanedColumn>{};
  final rawJobCols = <int, String>{};
  for (int c = 0; c < headerCells.length; c++) {
    final h = _text(headerCells[c]) ?? '';
    if (h.isEmpty) continue;
    if (h == '姓名') {
      nameCol = c;
      continue;
    }
    if (h == '车号' || h.contains('车牌') || h.contains('车辆')) {
      vehCol = c;
      continue;
    }
    if (h.contains('备注') || h.contains('说明')) {
      remarkCol = c;
      continue;
    }
    if (h.contains('船名') || h.contains('船号')) {
      boatCol = c;
      continue;
    }
    if (h.contains('日期') || h.contains('时间')) {
      dateCol = c;
      continue;
    }
    if (h.contains('班次') || h.contains('白班') || h.contains('夜班') || h.contains('班别')) {
      shiftCol = c;
      continue;
    }
    // 签字 / 签名 / 复核 / 确认 等列不参与任何识别
    if (h.contains('签字') || h.contains('签名') || h.contains('复核') || h.contains('确认')) {
      continue;
    }
    // 米 / 吨 / 方 等非「车次」单位列（如封跺（米））不计入车数
    if (h.contains('米') || h.contains('吨') || h.contains('方')) {
      continue;
    }
    jobCols[c] = _cleanColumn(h);
    rawJobCols[c] = h;
  }
  if (nameCol == null) {
    throw Exception('表头中未找到「姓名」列，请检查表头行是否正确');
  }
  // 挖掘机模式：存在「船名」列时，船名即作业类型（逐行向上延续填充），
  // 其余数值列（jobCols）作为该车名的车数。
  final isExcavator = boatCol != null;

  // 3) 解析班次与日期（取自表头上一行的 meta 行；逐单元格，支持 Excel 序列日期）
  DateTime? date;
  var shift = ShiftType.day;
  if (headerIdx - 1 >= 0) {
    for (final c in rows[headerIdx - 1]) {
      final t = _text(c) ?? '';
      if (t.contains('夜')) {
        shift = ShiftType.night;
      } else if (t.contains('白')) {
        shift = ShiftType.day;
      }
      final d = _parseDateCell(c);
      if (d != null) date = d;
    }
  }

  // 4) 逐行提取人员车数；空姓名行是「合计行/说明行/空行」，需区分
  final result = <ImportedRow>[];
  final boatJobTypes = <String>{};
  String? lastBoat; // 挖掘机表船名常合并单元格留空，向上延续
  Map<String, int>? sheetTotals;
  for (int r = headerIdx + 1; r < rows.length; r++) {
    final name = _text(rows[r][nameCol]) ?? '';
    final rowBoat = boatCol != null ? _text(rows[r][boatCol]) : null;

    // 日期 / 班次列优先于表头 meta 行（显式列存在时逐行覆盖）
    if (dateCol != null) {
      final d = _parseDateCell(rows[r][dateCol]);
      if (d != null) date = d;
    }
    if (shiftCol != null) {
      final s = _text(rows[r][shiftCol]) ?? '';
      if (s.contains('夜')) {
        shift = ShiftType.night;
      } else if (s.contains('白')) {
        shift = ShiftType.day;
      }
    }

    if (name.isEmpty) {
      // 合计行特征：车号列也空 且（作业列 或 车数列+船名）有值
      final hasJob = jobCols.keys.any((c) => (_toInt(rows[r][c]) ?? 0) > 0) ||
          (boatCol != null &&
              (rowBoat?.isNotEmpty ?? false) &&
              jobCols.keys.any((c) => (_toInt(rows[r][c]) ?? 0) > 0));
      final vehEmpty = vehCol == null || (_text(rows[r][vehCol])?.isEmpty ?? true);
      if (hasJob && vehEmpty) {
        final totals = <String, int>{};
        for (final e in jobCols.entries) {
          final v = _toInt(rows[r][e.key]);
          if (v != null && v > 0) totals[e.value.name] = v;
        }
        if (boatCol != null && (rowBoat?.isNotEmpty ?? false)) {
          final sum = jobCols.keys
              .map((c) => _toInt(rows[r][c]) ?? 0)
              .fold(0, (a, b) => a + b);
          if (sum > 0) totals[rowBoat!] = sum;
        }
        if (totals.isNotEmpty) sheetTotals = totals;
      }
      continue;
    }
    if (name.contains('制表')) continue;
    if (name.contains('合计')) {
      final totals = <String, int>{};
      for (final e in jobCols.entries) {
        final v = _toInt(rows[r][e.key]);
        if (v != null && v > 0) totals[e.value.name] = v;
      }
      if (boatCol != null && (rowBoat?.isNotEmpty ?? false)) {
        final sum = jobCols.keys
            .map((c) => _toInt(rows[r][c]) ?? 0)
            .fold(0, (a, b) => a + b);
        if (sum > 0) totals[rowBoat!] = sum;
      }
      if (totals.isNotEmpty) sheetTotals = totals;
      continue;
    }

    if (isExcavator) {
      // 挖掘机模式：船名=作业类型（向上延续填充），车数=各数值列之和
      if (rowBoat != null && rowBoat.isNotEmpty) lastBoat = rowBoat;
      final bt = (rowBoat != null && rowBoat.isNotEmpty) ? rowBoat : lastBoat;
      if (bt == null) continue;
      var cars = 0;
      for (final c in jobCols.keys) {
        cars += _toInt(rows[r][c]) ?? 0;
      }
      if (cars <= 0) continue;
      boatJobTypes.add(bt);
      result.add(ImportedRow(
        workerName: name,
        vehicleNo: vehCol != null ? (_text(rows[r][vehCol]) ?? '') : '',
        remark: remarkCol != null ? _text(rows[r][remarkCol]) : null,
        boatName: null,
        quantities: {bt: cars},
      ));
    } else {
      // 铲车模式：各作业类型列的车数
      final quantities = <String, int>{};
      for (final e in jobCols.entries) {
        final q = _toInt(rows[r][e.key]) ?? 0;
        if (q > 0) quantities[e.value.name] = q;
      }
      if (quantities.isEmpty) continue;
      result.add(ImportedRow(
        workerName: name,
        vehicleNo: vehCol != null ? (_text(rows[r][vehCol]) ?? '') : '',
        remark: remarkCol != null ? _text(rows[r][remarkCol]) : null,
        boatName: (rowBoat != null && rowBoat.isNotEmpty) ? rowBoat : null,
        quantities: quantities,
      ));
    }
  }

  // 挖掘机表：船名作为作业类型；铲车表：各作业类型列名作为作业类型
  final effectiveJobCols = isExcavator
      ? boatJobTypes.map((n) => CleanedColumn(n, null)).toList()
      : jobCols.values.toList();

  return ExcelParseResult(
    sheetNames: sheetNames,
    sheetName: target,
    headerRow: headerIdx,
    nameCol: nameCol,
    vehCol: vehCol,
    remarkCol: remarkCol,
    boatCol: boatCol,
    jobColumns: effectiveJobCols,
    rows: result,
    date: date,
    shift: shift,
    rawJobColumns: rawJobCols.values.toList(),
    sheetTotals: sheetTotals,
  );
}

/// 取出单元格底层值（文本/数字/公式缓存值）。
/// spreadsheet_decoder 返回的 rows 里每个元素已经是原始值，无需额外 unwrap。
dynamic _raw(dynamic cell) => cell;

String? _text(dynamic cell) {
  final v = _raw(cell);
  if (v == null) return null;
  return v.toString().trim();
}

int? _toInt(dynamic cell) {
  final v = _raw(cell);
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

/// 解析日期单元格：兼容 Excel 序列日期（如 46240）、2026/8/12、
/// 2026-08-12、2026年8月12日、2026年-8/6 等写法。
DateTime? _parseDateCell(dynamic cell) {
  // Excel 序列日期（数字）：基准 1899-12-30
  if (cell is int || cell is double) {
    final n = (cell as num).toDouble();
    if (n > 20000 && n < 80000) {
      return DateTime(1899, 12, 30).add(Duration(days: n.round()));
    }
    return null;
  }
  final v = (cell?.toString() ?? '').trim();
  if (v.isEmpty) return null;
  // 2026-08-12 / 2026/8/12
  final slash = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(v);
  if (slash != null) {
    return DateTime(
      int.parse(slash.group(1)!),
      int.parse(slash.group(2)!),
      int.parse(slash.group(3)!),
    );
  }
  // 2026年8月12日
  final cn =
      RegExp(r'(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日').firstMatch(v);
  if (cn != null) {
    return DateTime(
      int.parse(cn.group(1)!),
      int.parse(cn.group(2)!),
      int.parse(cn.group(3)!),
    );
  }
  // 2026年-8/6 或 2026年8/6（混合分隔符）
  final mix =
      RegExp(r'(\d{4})\s*年[^\d]*(\d{1,2})[^\d]*(\d{1,2})').firstMatch(v);
  if (mix != null) {
    return DateTime(
      int.parse(mix.group(1)!),
      int.parse(mix.group(2)!),
      int.parse(mix.group(3)!),
    );
  }
  return DateTime.tryParse(v.replaceAll('/', '-'));
}

/// 清洗列名：剥离结尾的「(可选逗号) 数字 元」，提取单价。
/// 例：「外倒装车1.8元」→ 外倒装车 + 1.8；「内倒装车，端货1.8元」→ 内倒装车/端货 + 1.8；
/// 「货场归剁」→ 货场归剁 + null。
CleanedColumn _cleanColumn(String raw) {
  final m =
      RegExp(r'^(.*?)(?:[，,]\s*)?(\d+(?:\.\d+)?)\s*元\s*$').firstMatch(raw);
  if (m != null) {
    return CleanedColumn(
      m.group(1)!.trim().replaceAll('，', '/'),
      double.parse(m.group(2)!),
    );
  }
  return CleanedColumn(raw.trim(), null);
}
