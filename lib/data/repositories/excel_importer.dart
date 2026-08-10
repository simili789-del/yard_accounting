import 'dart:io';

import 'package:excel/excel.dart';

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

  ExcelParseResult({
    required this.sheetNames,
    required this.sheetName,
    required this.headerRow,
    this.nameCol,
    this.vehCol,
    this.remarkCol,
    required this.jobColumns,
    required this.rows,
    this.date,
    required this.shift,
  });
}

/// 解析 xlsx：定位表头行 → 清洗作业类型列名（剥离「1.8元」单价）→
/// 跳过合计/标题行 → 提取每个人各作业类型车数，并解析班次与日期。
///
/// [sheetName] 不传则默认「铲车绩效表」；[headerRow] 不传则自动扫描含「姓名」的行。
ExcelParseResult parseXlsx(String path, {String? sheetName, int? headerRow}) {
  final bytes = File(path).readAsBytesSync();
  final excel = Excel.decodeBytes(bytes);
  final sheetNames = excel.tables.keys.toList();

  final target = sheetName ?? _defaultSheet;
  final sheet = excel.tables[target];
  if (sheet == null) {
    throw Exception('未找到工作表「$target」，可用：${sheetNames.join('、')}');
  }
  final rows = sheet.rows;

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
  int? nameCol, vehCol, remarkCol;
  final jobCols = <int, CleanedColumn>{};
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
    jobCols[c] = _cleanColumn(h);
  }
  if (nameCol == null) {
    throw Exception('表头中未找到「姓名」列，请检查表头行是否正确');
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

  // 4) 逐行提取人员车数，跳过空行/合计行/标题行
  final result = <ImportedRow>[];
  for (int r = headerIdx + 1; r < rows.length; r++) {
    final name = _text(rows[r][nameCol]) ?? '';
    if (name.isEmpty) continue;
    if (name.contains('合计') || name.contains('制表')) continue;

    final quantities = <String, int>{};
    for (final e in jobCols.entries) {
      final q = _toInt(rows[r][e.key]) ?? 0;
      if (q > 0) quantities[e.value.name] = q;
    }
    if (quantities.isEmpty) continue; // 该行无任何车数

    result.add(ImportedRow(
      workerName: name,
      vehicleNo: vehCol != null ? (_text(rows[r][vehCol]) ?? '') : '',
      remark: remarkCol != null ? _text(rows[r][remarkCol]) : null,
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
    jobColumns: jobCols.values.toList(),
    rows: result,
    date: date,
    shift: shift,
  );
}

/// 取出单元格底层值（文本/数字/公式缓存值）。
dynamic _raw(dynamic cell) {
  final cv = cell?.value; // excel 4.x: CellValue?
  if (cv == null) return null;
  return cv.value;
}

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
