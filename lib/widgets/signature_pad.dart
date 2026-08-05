import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;

import '../database/database_service.dart';

class SignatureDialog extends StatefulWidget {
  const SignatureDialog({super.key, required this.contractText});
  final String contractText;

  static Future<String?> show(BuildContext context, String contractText) =>
      showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SignatureDialog(contractText: contractText),
      );

  @override
  State<SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<SignatureDialog> {
  final _boundaryKey = GlobalKey();
  final _points = <Offset?>[];
  bool _accepted = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    backgroundColor: const Color(0xFFF8F5EE),
    child: SafeArea(
      child: Column(
        children: [
          AppBar(
            automaticallyImplyLeading: false,
            title: const Text('التوقيع الإلكتروني على عقد الإيواء'),
            actions: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(widget.contractText),
                  ),
                ),
                CheckboxListTile(
                  value: _accepted,
                  onChanged: (value) =>
                      setState(() => _accepted = value ?? false),
                  title: const Text(
                    'أتعهد بأنني قرأت جميع بنود العقد وأوافق عليها',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 8),
                const Text(
                  'وقّع داخل المساحة البيضاء باستخدام الإصبع أو القلم:',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                RepaintBoundary(
                  key: _boundaryKey,
                  child: GestureDetector(
                    onPanStart: (details) => _addPoint(details.localPosition),
                    onPanUpdate: (details) => _addPoint(details.localPosition),
                    onPanEnd: (_) => setState(() => _points.add(null)),
                    child: CustomPaint(
                      painter: _SignaturePainter(_points),
                      child: const SizedBox(
                        height: 260,
                        width: double.infinity,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(_points.clear),
                        icon: const Icon(Icons.delete_sweep),
                        label: const Text('مسح التوقيع'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: const Text('حفظ التوقيع'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  void _addPoint(Offset point) => setState(() => _points.add(point));

  Future<void> _save() async {
    if (!_accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب الموافقة على بنود العقد أولًا')),
      );
      return;
    }
    if (_points.whereType<Offset>().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى التوقيع داخل المساحة البيضاء')),
      );
      return;
    }
    setState(() => _saving = true);
    final boundary =
        _boundaryKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(
      p.join(DatabaseService.instance.appDirectory.path, 'signatures'),
    );
    await dir.create(recursive: true);
    final file = File(
      p.join(
        dir.path,
        'signature_${DateTime.now().millisecondsSinceEpoch}.png',
      ),
    );
    await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    if (mounted) Navigator.pop(context, file.path);
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.points);
  final List<Offset?> points;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final paint = Paint()
      ..color = const Color(0xFF10233F)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var index = 0; index < points.length - 1; index++) {
      final current = points[index];
      final next = points[index + 1];
      if (current != null && next != null)
        canvas.drawLine(current, next, paint);
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = const Color(0xFFC9A56A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
