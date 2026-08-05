import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../database/database_service.dart';
import '../reports/report_service.dart';
import '../services/file_service.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 340,
      mainAxisExtent: 150,
      crossAxisSpacing: 6,
      mainAxisSpacing: 6,
    ),
    itemCount: ReportService.definitions.length + 2,
    itemBuilder: (_, i) {
      final complete = i < 2;
      final subscriberComplete = i == 0;
      final report = complete
          ? ReportDefinition(
              subscriberComplete ? 'subscriber_complete' : 'horse_complete',
              subscriberComplete ? 'الملف الشامل للعضو' : 'الملف الشامل للخيل',
              subscriberComplete
                  ? 'الاشتراكات والدفعات والخيل والسجل المالي وجميع الصور'
                  : 'الصحة والعلاج والإيواء والتحذية والتمارين والمال والصور',
            )
          : ReportService.definitions[i - 2];
      return Card(
        color: complete ? Theme.of(context).colorScheme.primaryContainer : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: complete
              ? () => _openComplete(context, subscriber: subscriberComplete)
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportPreviewScreen(definition: report),
                  ),
                ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  child: Icon(
                    complete ? Icons.auto_awesome : Icons.picture_as_pdf,
                  ),
                ),
                const Spacer(),
                Text(
                  report.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                Text(
                  report.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Future<void> _openComplete(
    BuildContext context, {
    required bool subscriber,
  }) async {
    final table = subscriber ? 'subscribers' : 'horses';
    final rows = await DatabaseService.instance.rows(table, orderBy: 'name');
    if (!context.mounted) return;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            subscriber
                ? 'أضف مشتركًا أولًا لإنشاء ملفه الشامل'
                : 'أضف خيلًا أولًا لإنشاء ملفه الشامل',
          ),
        ),
      );
      return;
    }
    var selectedId = rows.first['id'] as int;
    var period = 'all';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(subscriber ? 'تقرير عضو شامل' : 'تقرير خيل شامل'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedId,
                  decoration: InputDecoration(
                    labelText: subscriber ? 'اختر المشترك' : 'اختر الخيل',
                  ),
                  items: rows
                      .map(
                        (row) => DropdownMenuItem(
                          value: row['id'] as int,
                          child: Text('${row['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) selectedId = value;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: period,
                  decoration: const InputDecoration(labelText: 'نطاق التقرير'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('كامل السجل')),
                    DropdownMenuItem(value: 'week', child: Text('آخر 7 أيام')),
                    DropdownMenuItem(
                      value: 'month',
                      child: Text('آخر 30 يومًا'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => period = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('إنشاء التقرير'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !context.mounted) return;
    final definition = ReportDefinition(
      subscriber ? 'subscriber_complete' : 'horse_complete',
      subscriber ? 'الملف الشامل للعضو' : 'الملف الشامل للخيل',
      '',
    );
    final future = subscriber
        ? ReportService.instance.loadSubscriberComplete(
            selectedId,
            period: period,
          )
        : ReportService.instance.loadHorseComplete(selectedId, period: period);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ReportPreviewScreen(definition: definition, dataFuture: future),
      ),
    );
  }
}

class ReportPreviewScreen extends StatelessWidget {
  const ReportPreviewScreen({
    super.key,
    required this.definition,
    this.dataFuture,
  });
  final ReportDefinition definition;
  final Future<ReportData>? dataFuture;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(definition.title)),
    body: FutureBuilder<ReportData>(
      future: dataFuture ?? ReportService.instance.load(definition.key),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(child: Text('تعذر إنشاء التقرير: ${snapshot.error}'));
        final data = snapshot.data!;
        return Column(
          children: [
            if (data.summary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: data.summary
                      .map(
                        (v) =>
                            Chip(label: Text(v), backgroundColor: Colors.white),
                      )
                      .toList(),
                ),
              ),
            if (data.sections.isNotEmpty || data.images.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...data.sections.map(
                      (section) => Chip(
                        avatar: const Icon(Icons.list_alt, size: 18),
                        label: Text('${section.title}: ${section.rows.length}'),
                      ),
                    ),
                    if (data.images.isNotEmpty)
                      Chip(
                        avatar: const Icon(
                          Icons.photo_library_outlined,
                          size: 18,
                        ),
                        label: Text('الصور: ${data.images.length}'),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: data.rows.isEmpty
                  ? const Center(child: Text('لا توجد بيانات'))
                  : Scrollbar(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: data.columns
                                .map((c) => DataColumn(label: Text(c.value)))
                                .toList(),
                            rows: data.rows
                                .map(
                                  (row) => DataRow(
                                    cells: data.columns
                                        .map(
                                          (c) => DataCell(
                                            Text('${row[c.key] ?? '—'}'),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final bytes = await ReportService.instance.buildPdf(
                          data,
                        );
                        await Printing.layoutPdf(
                          onLayout: (_) => bytes,
                          name: data.title,
                        );
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('معاينة وطباعة'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final file = await ReportService.instance.saveReport(
                          data,
                        );
                        await FileService.instance.shareFile(
                          file.path,
                          text: data.title,
                        );
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('حفظ ومشاركة'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
