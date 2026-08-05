import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../core/entity_config.dart';
import '../database/database_service.dart';
import '../providers/app_provider.dart';
import '../reports/report_service.dart';
import '../services/file_service.dart';
import '../widgets/entity_editor.dart';

class FinancialLedgerScreen extends StatefulWidget {
  const FinancialLedgerScreen({super.key});
  @override
  State<FinancialLedgerScreen> createState() => _FinancialLedgerScreenState();
}

class _FinancialLedgerScreenState extends State<FinancialLedgerScreen> {
  String _search = '', _type = 'all';
  Future<List<Map<String, Object?>>> _load() =>
      DatabaseService.instance.financialTransactions(
        type: _type == 'all' ? null : _type,
        search: _search,
      );
  @override
  Widget build(BuildContext context) {
    final revision = context.watch<AppProvider>().revision;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'بحث في السجل...',
                  ),
                ),
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('الكل')),
                  ButtonSegment(value: 'income', label: Text('وارد')),
                  ButtonSegment(value: 'expense', label: Text('مصروف')),
                ],
                selected: {_type},
                onSelectionChanged: (v) => setState(() => _type = v.first),
              ),
              ElevatedButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('عملية يدوية'),
              ),
              OutlinedButton.icon(
                onPressed: _export,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('تصدير PDF'),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, Object?>>>(
            key: ValueKey('ledger:$revision:$_search:$_type'),
            future: _load(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return Center(child: Text('${snapshot.error}'));
              final rows = snapshot.data ?? const [];
              if (rows.isEmpty)
                return const Center(child: Text('لا توجد عمليات مالية'));
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: rows.length,
                itemBuilder: (_, i) {
                  final row = rows[i];
                  final income = row['type'] == 'income';
                  final manual =
                      row['ref_type'] == null || row['ref_type'] == 'manual';
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: (income ? Colors.green : Colors.red)
                            .withValues(alpha: .12),
                        child: Icon(
                          income ? Icons.arrow_downward : Icons.arrow_upward,
                          color: income
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                      title: Text(
                        '${row['title']}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${row['transaction_date']} • ${row['category']} • ${row['subscriber_name'] ?? row['horse_name'] ?? row['source_type']}\n${row['affects_budget'] == 0 ? 'مسجل دون خصم من الميزانية' : 'داخل حساب الميزانية'}${row['is_subscriber_debt'] == 1 ? ' • دين على المشترك ${row['debt_settled'] == 1 ? '(مسدد)' : '(مستحق)'}' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${row['amount']} ر.س',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: income
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                          if (manual)
                            PopupMenuButton<String>(
                              color: Colors.white,
                              onSelected: (v) =>
                                  v == 'edit' ? _edit(row) : _delete(row),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('تعديل'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('حذف'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _add() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final changed = await EntityEditorDialog.show(
      context,
      config: EntityConfigs.manualTransaction,
      forcedValues: {
        'source_type': 'manual',
        'ref_type': 'manual',
        'transaction_date': today,
      },
    );
    if (changed && mounted) await context.read<AppProvider>().dataChanged();
  }

  Future<void> _edit(Map<String, Object?> row) async {
    final changed = await EntityEditorDialog.show(
      context,
      config: EntityConfigs.manualTransaction,
      record: row,
      forcedValues: const {'source_type': 'manual', 'ref_type': 'manual'},
    );
    if (changed && mounted) await context.read<AppProvider>().dataChanged();
  }

  Future<void> _delete(Map<String, Object?> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('حذف العملية'),
        content: Text('حذف العملية «${row['title']}»؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DatabaseService.instance.deleteRecord(
        'financial_transactions',
        row['id'] as int,
      );
      if (mounted) await context.read<AppProvider>().dataChanged();
    }
  }

  Future<void> _export() async {
    final rows = await _load();
    final data = ReportData(
      title: 'السجل المالي',
      columns: const [
        MapEntry('transaction_date', 'التاريخ'),
        MapEntry('type', 'النوع'),
        MapEntry('title', 'البيان'),
        MapEntry('category', 'الفئة'),
        MapEntry('affects_budget', 'يدخل الميزانية'),
        MapEntry('is_subscriber_debt', 'دين مشترك'),
        MapEntry('debt_settled', 'مسدد'),
        MapEntry('amount', 'المبلغ'),
      ],
      rows: rows,
    );
    final bytes = await ReportService.instance.buildPdf(data);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (sheet) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.print),
              title: const Text('معاينة وطباعة'),
              onTap: () async {
                Navigator.pop(sheet);
                await Printing.layoutPdf(
                  onLayout: (_) => bytes,
                  name: 'السجل المالي',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('حفظ ومشاركة'),
              onTap: () async {
                Navigator.pop(sheet);
                final file = await ReportService.instance.saveReport(data);
                await FileService.instance.shareFile(file.path);
              },
            ),
          ],
        ),
      ),
    );
  }
}
