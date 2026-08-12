import 'dart:io';

import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

import '../../domain/entities/work_record.dart';
import '../../domain/models/imported_row.dart';

/// 解析 xlsx/xls 的一次性结果，供导入向导直接使用。
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

  /// 该表是否为可导入的司机绩效表。false 时 [hint] 说明原因，UI 应提示换表。
  final bool importable;

  /// 不可导入原因（importable 为 false 时非空）。
  final String? hint;

  /// 文件内每个工作表是否可导入（供向导下拉标注）。
  final Map<String, bool>? sheetImportable;

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
    this.importable = true,
    this.hint,
    this.sheetImportable,
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

  // 预扫描每个 sheet 是否可导入（供向导下拉标注，并用于默认 sheet 选择）
  final sheetImportableMap = _scanImportable(decoder);
  // 用户未指定 sheet、或指定的 sheet 不存在时，自动选中首个「看起来像司机
  // 绩效表」的 sheet（含 绩效/铲车/装载机/挖掘机 关键词优先，且非考勤类）。
  var target = sheetName;
  if (target == null || !decoder.tables.containsKey(target)) {
    target = _pickDefaultSheet(decoder) ?? sheetNames.first;
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
    // 找不到精确的「姓名」列：该表大概率不是司机绩效表，温柔返回而非抛异常，
    // 让向导提示用户切换到含「姓名」列的绩效表。
    return ExcelParseResult(
      importable: false,
      hint: '未找到「姓名」列，该表不是司机绩效表（司机绩效表需含「姓名」列）',
      sheetNames: sheetNames,
      sheetName: target,
      headerRow: headerIdx < 0 ? 0 : headerIdx,
      jobColumns: const [],
      rows: const [],
      shift: ShiftType.day,
      sheetImportable: sheetImportableMap,
    );
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
    // 跳过重复表头行（分页处常再写一行『姓名/车号』）
    if (name == '姓名') continue;

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

  // 非绩效表（考勤/工资/汇总/火车明细等）或完全无车数 → 标记为不可导入，
  // 让向导提示用户切换工作表，避免把考勤表当成绩效表污染工资数据。
  if (_isNonPerfSheet(target, headerCells) || result.isEmpty) {
    final reason = _isNonPerfSheet(target, headerCells)
        ? '该表疑似考勤/工资/汇总/火车明细表，不是司机绩效表。请选择含「姓名 + 车数」的绩效表（如铲车/装载机/挖掘机绩效）'
        : '未在该表识别到任何车数数据';
    return ExcelParseResult(
      importable: false,
      hint: reason,
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
      sheetImportable: sheetImportableMap,
    );
  }

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
    sheetImportable: sheetImportableMap,
  );
}

/// 扫描文件内每个工作表是否可导入（轻量结构检查，不解析车数）。
Map<String, bool> _scanImportable(SpreadsheetDecoder decoder) {
  final map = <String, bool>{};
  for (final name in decoder.tables.keys) {
    final t = decoder.tables[name];
    map[name] = t == null ? false : _sheetImportable(t, name);
  }
  return map;
}

/// 单个工作表是否看起来像司机绩效表：含「姓名」表头、非考勤类、且至少有一数值车数。
bool _sheetImportable(SpreadsheetTable table, String name) {
  int? headerIdx;
  for (int r = 0; r < table.rows.length; r++) {
    if (table.rows[r].any((c) => (_text(c) ?? '').contains('姓名'))) {
      headerIdx = r;
      break;
    }
  }
  if (headerIdx == null) return false;
  final header = table.rows[headerIdx];
  if (_isNonPerfSheet(name, header)) return false;
  for (int r = headerIdx + 1; r < table.rows.length; r++) {
    for (final c in table.rows[r]) {
      final v = _raw(c);
      if (v is num && v != 0) return true;
    }
  }
  return false;
}

/// 自动选择默认工作表：优先含 绩效/铲车/装载机/挖掘机 关键词且可导入的，
/// 其次任意可导入的，都没有则返回 null。
String? _pickDefaultSheet(SpreadsheetDecoder decoder) {
  const preferred = ['绩效', '铲车', '装载机', '挖掘机'];
  for (final k in preferred) {
    for (final name in decoder.tables.keys) {
      if (name.contains(k) && _sheetImportable(decoder.tables[name]!, name)) {
        return name;
      }
    }
  }
  for (final name in decoder.tables.keys) {
    if (_sheetImportable(decoder.tables[name]!, name)) return name;
  }
  return null;
}

/// 判断表头/表名是否像「考勤/工资/汇总/火车明细」等非绩效表。
/// 依据：表名含排除关键词、列数过多（>25）、或候选作业列中纯数字/序号列过半
/// （考勤表的 1~31 日列）。作业类型列通常为中文业务词（装车/归垛/倒货/加高）。
bool _isNonPerfSheet(String sheetName, List<dynamic> headerCells) {
  const excluded = [
    '考勤',
    '工资',
    '汇总',
    '报表',
    '火车',
    '明细',
    '56道',
    '班表',
    '作业量',
  ];
  for (final k in excluded) {
    if (sheetName.contains(k)) return true;
  }
  if (headerCells.length > 25) return true;
  int total = 0;
  int numeric = 0;
  for (int c = 0; c < headerCells.length; c++) {
    final h = _text(headerCells[c]) ?? '';
    if (h.isEmpty) continue;
    if (h == '姓名' ||
        h == '车号' ||
        h.contains('车牌') ||
        h.contains('车辆') ||
        h.contains('备注') ||
        h.contains('说明') ||
        h.contains('船名') ||
        h.contains('船号') ||
        h.contains('日期') ||
        h.contains('时间') ||
        h.contains('班次') ||
        h.contains('白班') ||
        h.contains('夜班') ||
        h.contains('班别') ||
        h.contains('签字') ||
        h.contains('签名') ||
        h.contains('复核') ||
        h.contains('确认') ||
        h.contains('米') ||
        h.contains('吨') ||
        h.contains('方')) {
      continue;
    }
    total++;
    if (h == '序号' ||
        RegExp(r'^\d+$').hasMatch(h) ||
        RegExp(r'^\d+\.\d+$').hasMatch(h)) {
      numeric++;
    }
  }
  if (total > 0 && numeric * 2 >= total) return true;
  return false;
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
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return null;
    // 支持『56+49』『5+101』之类的车数表达式：提取所有数字求和取整。
    // 挖掘机绩效表常在「加高（车）」列手写多段合计。
    final nums = RegExp(r'-?\d+(?:\.\d+)?').allMatches(s);
    if (nums.isEmpty) return null;
    var sum = 0;
    for (final m in nums) {
      sum += (double.tryParse(m.group(0)!) ?? 0).round();
    }
    return sum;
  }
  return null;
}

/// 解析日期单元格：兼容 Excel 序列日期（如 46240）、2026/8/12、
/// 2026-08-12、2026年8月12日、2026年-8/6 等写法。
DateTime? _parseDateCell(dynamic cell) {
  // spreadsheet_decoder 可能已把日期单元格转成 DateTime
  if (cell is DateTime) return cell;
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
  // 2026年8月12日 / 2026年08月10号（口语「号」同「日」）
  final cn =
      RegExp(r'(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*[日号]').firstMatch(v);
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
