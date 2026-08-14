import 'package:flutter/material.dart';

class AgreementScreen extends StatefulWidget {
  const AgreementScreen({required this.onAccepted, super.key});

  final Future<void> Function() onAccepted;

  @override
  State<AgreementScreen> createState() => _AgreementScreenState();
}

class _AgreementScreenState extends State<AgreementScreen> {
  bool _accepted = false;
  bool _saving = false;

  Future<void> _continue() async {
    if (!_accepted || _saving) return;
    setState(() => _saving = true);
    await widget.onAccepted();
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'إقرار وتعهد',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'أتعهد باستخدام التطبيق بشكل نظامي، وعدم اختراقه أو العبث بملفاته أو محاولة تجاوز الحماية أو نظام الترخيص والتفعيل بأي وسيلة، وعدم استخدام أو مشاركة أي تفعيل غير مصرح به.',
                      textAlign: TextAlign.start,
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: _accepted,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'قرأت وأوافق على التعهد',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onChanged: _saving
                          ? null
                          : (value) =>
                                setState(() => _accepted = value ?? false),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _accepted && !_saving ? _continue : null,
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('أوافق وأتابع'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
