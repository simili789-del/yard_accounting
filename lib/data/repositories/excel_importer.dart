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

  final target = sheetName ?? _defaultSheet;
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

  // 2) 归类列：姓名 / 车号 / 备注 单列标记，其余数值列作为作业类型列
  final headerCells = rows[headerIdx];
  int? nameCol, vehCol, remarkCol, boatCol;
  final jobCols = <int, CleanedColumn>{};
  final rawJobCols = <int, String>{};
  for (int c = 0; c < headerCells.length; c++) {
    final h = _text(headerCells[c]) ?? '';
    if (h.isEmpty) continue;
    if (h == '姓名') {
      nameCol = c;
      continue;
    }
    if (h == '车号') {
      vehCol = c;
      continue;
    }
    if (h == '备注') {
      remarkCol = c;
      continue;
    }
    if (h.contains('船名') || h.contains('船号')) {
      boatCol = c;
      continue;
    }
    jobCols[c] = _cleanColumn(h);
    rawJobCols[c] = h;
  }
  if (nameCol == null) {
    throw Exception('表头中未找到「姓名」列，请检查表头行是否正确');
  }
  // 船名特例：挖掘机绩效表的船名在「表头为空的列」（如 A 列），且数据行多为文本。
  if (boatCol == null) {
    for (int c = 0; c < headerCells.length; c++) {
      final h = _text(headerCells[c]) ?? '';
      if (h.isNotEmpty) continue;
      if (c == nameCol || c == vehCol || c == remarkCol || jobCols.containsKey(c)) {
        continue;
      }
      var texty = false;
      for (int r = headerIdx + 1; r < rows.length; r++) {
        final v = _text(rows[r][c]);
        if (v != null && v.isNotEmpty && !_isNumericLike(v)) {
          texty = true;
          break;
        }
      }
      if (texty) {
        boatCol = c;
        break;
      }
    }
  }

  // 3) 解析班次与日期（取自表头上一行的 meta 行）
  DateTime? date;
  var shift = ShiftType.day;
  if (headerIdx - 1 >= 0) {
    final metaLine = rows[headerIdx - 1].map((c) => _text(c) ?? '').join(' ');
    if (metaLine.contains('夜')) {
      shift = ShiftType.night;
    } else if (metaLine.contains('白')) {
      shift = ShiftType.day;
    }
    final dm =
        RegExp(r'(\d{4})\s*年-?(\d{1,2})/(\d{1,2})').firstMatch(metaLine);
    if (dm != null) {
      date = DateTime(
        int.parse(dm.group(1)!),
        int.parse(dm.group(2)!),
        int.parse(dm.group(3)!),
      );
    }
  }

  // 4) 逐行提取人员车数；空姓名行可能是「合计行/说明行/空行」，需区分
  final result = <ImportedRow>[];
  Map<String, int>? sheetTotals;
  for (int r = headerIdx + 1; r < rows.length; r++) {
    final name = _text(rows[r][nameCol]) ?? '';
    if (name.isEmpty) {
      // 合计行特征：车号列也空 且 至少一个作业列有值（铲车表合计行即如此）
      final hasJob = jobCols.keys.any((c) => (_toInt(rows[r][c]) ?? 0) > 0);
      final vehEmpty = vehCol == null || (_text(rows[r][vehCol])?.isEmpty ?? true);
      if (hasJob && vehEmpty) {
        final totals = <String, int>{};
        for (final e in jobCols.entries) {
          final v = _toInt(rows[r][e.key]);
          if (v != null && v > 0) totals[e.value.name] = v;
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
      if (totals.isNotEmpty) sheetTotals = totals;
      continue;
    }

    final quantities = <String, int>{};
    for (final e in jobCols.entries) {
      final q = _toInt(rows[r][e.key]) ?? 0;
      if (q > 0) quantities[e.value.name] = q;
    }
    if (quantities.isEmpty) continue; // 该行无任何车数

    final rawBoat = boatCol != null ? _text(rows[r][boatCol]) : null;
    result.add(ImportedRow(
      workerName: name,
      vehicleNo: vehCol != null ? (_text(rows[r][vehCol]) ?? '') : '',
      remark: remarkCol != null ? _text(rows[r][remarkCol]) : null,
      boatName: (rawBoat != null && rawBoat.isNotEmpty) ? rawBoat : null,
      quantities: quantities,
    ));
  }

  return ExcelParseResult(
    sheetNames: sheetNames,
    sheetName: target,
    headerRow: headerIdx,
    nameCol: nameCol,
    vehCol: vehCol,
    remarkCol: remarkCol,
    boatCol: boatCol,
    jobColumns: jobCols.values.toList(),
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

/// 是否像数字（用于区分船名文本与「加高12000」之类的说明数字）。
bool _isNumericLike(String s) {
  final cleaned = s.replaceAll(RegExp(r'[，,\s/]'), '');
  return double.tryParse(cleaned) != null;
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
