import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../core/entity_config.dart';
import '../database/database_service.dart';
import '../providers/app_provider.dart';
import '../reports/report_service.dart';
import '../services/file_service.dart';
import '../widgets/entity_list.dart';

class DailyBookingsScreen extends StatelessWidget {
  const DailyBookingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final revision = context.watch<AppProvider>().revision;
    return Column(
      children: [
        FutureBuilder<Map<String, Object?>>(
          key: ValueKey('booking-stats:$revision'),
          future: _stats(),
          builder: (_, snapshot) {
            final data = snapshot.data ?? const {};
            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      title: 'حجوزات اليوم',
                      value: '${data['today_count'] ?? 0}',
                      icon: Icons.today,
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      title: 'إيرادات اليوم',
                      value: '${_money(data['today_total'])} ر.س',
                      icon: Icons.payments,
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      title: 'إيرادات الشهر',
                      value: '${_money(data['month_total'])} ر.س',
                      icon: Icons.calendar_month,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Expanded(
          child: EntityList(
            config: EntityConfigs.booking,
            onOpen: (record) => _receiptActions(context, record),
          ),
        ),
      ],
    );
  }

  Future<Map<String, Object?>> _stats() async {
    final db = DatabaseService.instance.db;
    final today = await db.rawQuery(
      "SELECT COUNT(*) count,COALESCE(SUM(price),0) total FROM daily_bookings WHERE booking_date=date('now','localtime')",
    );
    final month = await db.rawQuery(
      "SELECT COUNT(*) count,COALESCE(SUM(price),0) total FROM daily_bookings WHERE strftime('%Y-%m',booking_date)=strftime('%Y-%m','now','localtime')",
    );
    return {
      'today_count': today.first['count'],
      'today_total': today.first['total'],
      'month_count': month.first['count'],
      'month_total': month.first['total'],
    };
  }

  Future<void> _receiptActions(
    BuildContext context,
    Map<String, Object?> record,
  ) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.print),
              title: const Text('معاينة وطباعة الإيصال'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final bytes = await ReportService.instance.buildDailyReceipt(
                  record,
                );
                await Printing.layoutPdf(
                  onLayout: (_) => bytes,
                  name: 'إيصال سايس الخيل',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('مشاركة الإيصال PDF'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final bytes = await ReportService.instance.buildDailyReceipt(
                  record,
                );
                final dir = Directory(
                  p.join(
                    DatabaseService.instance.appDirectory.path,
                    'receipts',
                  ),
                );
                await dir.create(recursive: true);
                final file = File(
                  p.join(dir.path, 'receipt_${record['id']}.pdf'),
                );
                await file.writeAsBytes(bytes, flush: true);
                await FileService.instance.shareFile(
                  file.path,
                  text: 'إيصال حجز - سايس الخيل',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _money(Object? value) =>
      ((value as num?)?.toDouble() ?? 0).toStringAsFixed(2);
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.title,
    required this.value,
    required this.icon,
  });
  final String title, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    ),
  );
}
