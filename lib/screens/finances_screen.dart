import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/entity_config.dart';
import '../database/database_service.dart';
import '../providers/app_provider.dart';
import '../widgets/entity_list.dart';

class FinancesScreen extends StatelessWidget {
  const FinancesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final revision = context.watch<AppProvider>().revision;
    return DefaultTabController(
      length: 7,
      child: Column(
        children: [
          FutureBuilder<Map<String, Object?>>(
            key: ValueKey('finance-summary:$revision'),
            future: _summary(),
            builder: (_, snapshot) {
              final data = snapshot.data ?? const {};
              return Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    _FinanceStat(
                      label: 'الوارد',
                      value: data['income'],
                      color: Colors.green.shade700,
                    ),
                    _FinanceStat(
                      label: 'المخصوم',
                      value: data['expense'],
                      color: Colors.red.shade700,
                    ),
                    _FinanceStat(
                      label: 'غير المخصوم',
                      value: data['excluded'],
                      color: Colors.orange.shade800,
                    ),
                    _FinanceStat(
                      label: 'ديون المشتركين',
                      value: data['debt'],
                      color: Colors.purple.shade700,
                    ),
                    _FinanceStat(
                      label: 'الصافي',
                      value: data['net'],
                      color: Colors.blue.shade800,
                    ),
                  ],
                ),
              );
            },
          ),
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'الميزانية', icon: Icon(Icons.account_balance)),
              Tab(text: 'دفعات الإيواء', icon: Icon(Icons.home_work)),
              Tab(text: 'العلاجات', icon: Icon(Icons.medication)),
              Tab(text: 'مدفوعات أخرى', icon: Icon(Icons.folder_copy)),
              Tab(text: 'مصاريف عامة', icon: Icon(Icons.construction)),
              Tab(text: 'الوارد', icon: Icon(Icons.savings)),
              Tab(text: 'سجل المصروفات', icon: Icon(Icons.receipt_long)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _BudgetOverview(revision: revision),
                EntityList(
                  config: EntityConfigs.boardingPayment,
                  compact: true,
                ),
                EntityList(config: EntityConfigs.treatment, compact: true),
                EntityList(
                  config: EntityConfigs.expense,
                  where: 'category IN (?,?,?,?,?,?,?,?)',
                  whereArgs: const [
                    'رسوم تدريب',
                    'رسوم سباق',
                    'رسوم تسجيل',
                    'تحذية',
                    'تصوير وتوثيق',
                    'خدمات متنوعة',
                    'غرامات',
                    'أخرى',
                  ],
                  compact: true,
                ),
                EntityList(config: EntityConfigs.generalExpense, compact: true),
                EntityList(config: EntityConfigs.income, compact: true),
                EntityList(config: EntityConfigs.expense, compact: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, Object?>> _summary() async {
    final rows = await DatabaseService.instance.db.rawQuery("""SELECT
      COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE 0 END),0) income,
      COALESCE(SUM(CASE WHEN type='expense' AND COALESCE(affects_budget,1)=1 THEN amount ELSE 0 END),0) expense,
      COALESCE(SUM(CASE WHEN type='expense' AND COALESCE(affects_budget,1)=0 THEN amount ELSE 0 END),0) excluded,
      COALESCE(SUM(CASE WHEN COALESCE(is_subscriber_debt,0)=1 AND COALESCE(debt_settled,0)=0 THEN amount ELSE 0 END),0) debt
      FROM financial_transactions""");
    final income = (rows.first['income'] as num?)?.toDouble() ?? 0;
    final expense = (rows.first['expense'] as num?)?.toDouble() ?? 0;
    return {
      'income': income,
      'expense': expense,
      'excluded': rows.first['excluded'] ?? 0,
      'debt': rows.first['debt'] ?? 0,
      'net': income - expense,
    };
  }
}

class _FinanceStat extends StatelessWidget {
  const _FinanceStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final Object? value;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Text(label),
            FittedBox(
              child: Text(
                '${((value as num?)?.toDouble() ?? 0).toStringAsFixed(2)} ر.س',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: color,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BudgetOverview extends StatelessWidget {
  const _BudgetOverview({required this.revision});

  final int revision;

  Future<List<Map<String, Object?>>> _load() =>
      DatabaseService.instance.db.rawQuery(
        """SELECT type, category, COALESCE(affects_budget,1) affects_budget,
    COUNT(*) count, COALESCE(SUM(amount),0) total
    FROM financial_transactions
    GROUP BY type, category, COALESCE(affects_budget,1)
    ORDER BY type DESC, total DESC""",
      );

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, Object?>>>(
    key: ValueKey('budget:$revision'),
    future: _load(),
    builder: (_, snapshot) {
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      final rows = snapshot.data!;
      if (rows.isEmpty)
        return const Center(child: Text('لا توجد عمليات مالية بعد'));
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text(
                'حساب واضح دون خلط',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                'دفعة الإيواء الواحدة تظهر تلقائيًا في ملف الخيل والمشترك وتُحتسب مرة واحدة فقط. مصاريف خيل الإيواء لا تدخل ميزانية النادي إلا إذا دفعها النادي، ويمكن تسجيلها دينًا على المشترك.',
              ),
            ),
          ),
          ...rows.map((row) {
            final income = row['type'] == 'income';
            final affects = row['affects_budget'] == 1;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      (income
                              ? Colors.green
                              : affects
                              ? Colors.red
                              : Colors.orange)
                          .withValues(alpha: .12),
                  child: Icon(
                    income
                        ? Icons.arrow_downward
                        : affects
                        ? Icons.arrow_upward
                        : Icons.remove_circle_outline,
                  ),
                ),
                title: Text(
                  '${row['category'] ?? 'أخرى'}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '${row['count']} عملية • ${income
                      ? 'وارد'
                      : affects
                      ? 'مصروف من الميزانية'
                      : 'مسجل دون خصم'}',
                ),
                trailing: Text(
                  '${((row['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} ر.س',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            );
          }),
        ],
      );
    },
  );
}
