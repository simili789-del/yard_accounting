import 'package:flutter_test/flutter_test.dart';
import 'package:yard_accounting/data/repositories/excel_importer.dart';
import 'package:yard_accounting/domain/models/imported_row.dart';

/// 验证「同一工作表内叠放多张结构不同的子表」时，解析器能按各子表
/// 自身的表头正确映射列，而不是只认首个表头导致后续子表列错位。
///
/// 资源文件 test/fixtures/yard_performance_multi_header.xls 的「铲车司机绩效」
/// sheet 上下叠了两张表：
///   上半（南货场绩效）：车号|姓名|货场装车|货场归垛|倒货1.8元|内倒归垛|备注
///   下半（56道货场绩效表）：车号|姓名|节数|归垛|汽提|倒货1.8|神华归垛|神华装车
void main() {
  const path = 'test/fixtures/yard_performance_multi_header.xls';

  test('多子表头：董景辉/陈登国上下两表均按各自表头正确解析', () {
    final result = parseXlsx(path);
    expect(result.importable, isTrue);

    final byName = <String, List<ImportedRow>>{};
    for (final row in result.rows) {
      byName.putIfAbsent(row.workerName, () => []).add(row);
    }

    // 董景辉：上半 {货场装车:2, 货场归垛:16} + 下半 {火车装车:16}（节数→火车装车）
    final dong = byName['董景辉']!;
    expect(dong.length, 2, reason: '董景辉应解析出上下两表各一条记录');
    final dongAll = <String, int>{};
    for (final r in dong) {
      r.quantities.forEach((k, v) => dongAll[k] = (dongAll[k] ?? 0) + v);
    }
    expect(dongAll, containsPair('货场装车', 2));
    expect(dongAll, containsPair('货场倒货', 16));
    expect(dongAll, containsPair('火车装车', 16));

    // 陈登国：上半无车数（不产生记录），仅下半 {火车装车:1, 神华归垛:50}
    // （神华归垛现为独立作业类型，不再并入货场归剁）
    final chen = byName['陈登国']!;
    expect(chen.length, 1, reason: '陈登国仅下半表有车数');
    expect(chen.single.quantities, containsPair('火车装车', 1));
    expect(chen.single.quantities, containsPair('神华归垛', 50));
  });

  test('多子表合计行累加为整体对账基准（神华系列独立、不污染货场类）', () {
    final result = parseXlsx(path);
    expect(result.sheetTotals, isNotNull);
    // 神华装车/神华归垛现为独立作业类型，不得并入货场装车/货场归剁。
    // 本夹具合计行未填写神华列（合计=0），故合计基准中货场类数值保持不变：
    expect(result.sheetTotals!['货场装车'], 244,
        reason: '神华装车独立后，货场装车合计不应被污染');
    expect(result.sheetTotals!['货场归剁'], 648,
        reason: '神华归垛独立后，货场归剁合计不应被污染');
    expect(result.sheetTotals!['货场倒货'], 191);
    expect(result.sheetTotals!['火车装车'], 105);
    // 实际映射正确性由「陈登国」记录验证（神华归垛:50，见上方测试），
    // 以及 test/fixtures/job_type_mapping.xlsx 的专项映射测试。
  });

  test('挖掘机子表（含船名）按船名模式解析，不受多子表改造影响', () {
    final result = parseXlsx(path, sheetName: '挖掘机绩效');
    expect(result.importable, isTrue);
    // 孙同曦 / 大周 / 加高（车）=96
    final byName = <String, List<ImportedRow>>{};
    for (final row in result.rows) {
      byName.putIfAbsent(row.workerName, () => []).add(row);
    }
    final sun = byName['孙同曦']!;
    expect(sun.single.boatName, '大周');
    expect(sun.single.quantities, containsPair('挖掘机加高', 96));
  });
}
