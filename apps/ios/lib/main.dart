import 'dart:async';

import 'package:flutter/material.dart';

enum RepeatAction {
  tap('Tap screen'),
  up('Swipe up'),
  down('Swipe down'),
  left('Swipe left'),
  right('Swipe right');

  const RepeatAction(this.label);
  final String label;
}

void main() => runApp(const LoopMateApp());

class LoopMateApp extends StatelessWidget {
  const LoopMateApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'LoopMate iOS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7488F5),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF101522),
        ),
        home: const RepeaterScreen(),
      );
}

class RepeaterScreen extends StatefulWidget {
  const RepeaterScreen({super.key});

  @override
  State<RepeaterScreen> createState() => _RepeaterScreenState();
}

class _RepeaterScreenState extends State<RepeaterScreen> {
  final _interval = TextEditingController(text: '10');
  final _x = TextEditingController(text: '50');
  final _y = TextEditingController(text: '50');
  final _repeatCount = TextEditingController(text: '0');

  RepeatAction _action = RepeatAction.up;
  Timer? _previewTimer;
  bool _running = false;
  int _count = 0;

  @override
  void dispose() {
    _previewTimer?.cancel();
    _interval.dispose();
    _x.dispose();
    _y.dispose();
    _repeatCount.dispose();
    super.dispose();
  }

  int? _positiveInt(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim());
    return value != null && value >= 1 ? value : null;
  }

  double? _percentage(TextEditingController controller) {
    final value = double.tryParse(controller.text.trim());
    return value != null && value >= 0 && value <= 100 ? value : null;
  }

  void _start() {
    final interval = _positiveInt(_interval);
    final repeats = int.tryParse(_repeatCount.text.trim());
    if (interval == null || repeats == null || repeats < 0) {
      _message('Enter a valid interval and repeat limit (0 = unlimited).');
      return;
    }
    if (_action == RepeatAction.tap &&
        (_percentage(_x) == null || _percentage(_y) == null)) {
      _message('Tap coordinates must be between 0 and 100%.');
      return;
    }
    setState(() {
      _running = true;
      _count = 0;
    });
    _tick(repeats);
    if (_running) {
      _previewTimer = Timer.periodic(
        Duration(seconds: interval),
        (_) => _tick(repeats),
      );
    }
  }

  void _tick(int repeatLimit) {
    if (!mounted || !_running) return;
    setState(() => _count++);
    if (repeatLimit > 0 && _count >= repeatLimit) {
      _previewTimer?.cancel();
      setState(() => _running = false);
    }
  }

  void _stop() {
    _previewTimer?.cancel();
    setState(() => _running = false);
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isTap = _action == RepeatAction.tap;
    return Scaffold(
      appBar: AppBar(title: const Text('LoopMate iOS')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_running ? 'Preview running' : 'In-app preview only',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text('Preview ticks: $_count'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<RepeatAction>(
                      value: _action,
                      isExpanded: true,
                      items: RepeatAction.values
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(item.label),
                              ))
                          .toList(),
                      onChanged: _running
                          ? null
                          : (value) =>
                              setState(() => _action = value ?? _action),
                    ),
                    if (isTap) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _field(_x, 'X (%)')),
                          const SizedBox(width: 12),
                          Expanded(child: _field(_y, 'Y (%)')),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    _field(_interval, 'Interval (seconds)'),
                    const SizedBox(height: 12),
                    _field(_repeatCount, 'Maximum repeats (0 = unlimited)'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _running ? null : _start,
                    child: const Text('Start preview'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _running ? _stop : null,
                    child: const Text('Stop'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'iOS does not allow third-party apps to inject taps or swipes into other apps. This separate iOS app demonstrates the repeat schedule inside LoopMate only.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      enabled: !_running,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
