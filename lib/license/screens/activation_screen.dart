import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../license_models.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({
    required this.installationId,
    required this.onActivate,
    this.initialMessage,
    super.key,
  });

  final String installationId;
  final String? initialMessage;
  final Future<ActivationAttempt> Function(String code) onActivate;

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _controller = TextEditingController();
  String? _message;
  bool _activating = false;

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage;
  }

  @override
  void didUpdateWidget(covariant ActivationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMessage != oldWidget.initialMessage) {
      _message = widget.initialMessage;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copyDeviceId() async {
    await Clipboard.setData(ClipboardData(text: widget.installationId));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم نسخ رقم الجهاز')));
  }

  Future<void> _openWhatsApp() async {
    final url = Uri.https('wa.me', '/966501894192', {
      'text':
          'طلب تفعيل تطبيق سايس الخيل\nInstallation ID: '
          '${widget.installationId}',
    });
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح واتساب على هذا الجهاز')),
      );
    }
  }

  Future<void> _activate() async {
    if (_activating || _controller.text.trim().isEmpty) return;
    setState(() {
      _activating = true;
      _message = null;
    });
    final result = await widget.onActivate(_controller.text);
    if (!mounted) return;
    setState(() {
      _activating = false;
      _message = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final storageAvailable = widget.installationId != 'غير متاح';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'انتهت الفترة التجريبية',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'لطلب التفعيل والتواصل واتساب فقط',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextButton.icon(
                        onPressed: _openWhatsApp,
                        icon: const Icon(Icons.chat),
                        label: const Text('0501894192'),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Device ID / Installation ID',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        widget.installationId,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: storageAvailable ? _copyDeviceId : null,
                        icon: const Icon(Icons.copy),
                        label: const Text('نسخ رقم الجهاز'),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _controller,
                        enabled: storageAvailable && !_activating,
                        textDirection: TextDirection.ltr,
                        autocorrect: false,
                        enableSuggestions: false,
                        maxLines: 3,
                        minLines: 1,
                        maxLength: 4096,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9._-]'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Serial Number / Activation Code',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _activate(),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _message!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: storageAvailable && !_activating
                            ? _activate
                            : null,
                        child: _activating
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('تفعيل'),
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
}
