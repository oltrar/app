import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _automation = MethodChannel('dev.loopmate.loopmate/automation');

enum RepeatAction {
  tap('tap', 'Tap screen'),
  up('swipe_up', 'Swipe up'),
  down('swipe_down', 'Swipe down'),
  left('swipe_left', 'Swipe left'),
  right('swipe_right', 'Swipe right');

  const RepeatAction(this.id, this.label);
  final String id;
  final String label;
}

void main() => runApp(const LoopMateApp());

class LoopMateApp extends StatelessWidget {
  const LoopMateApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'LoopMate',
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
  Timer? _statusTimer;
  bool _running = false;
  bool _accessibilityEnabled = false;
  int _count = 0;
  String? _error;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    if (_isAndroid) _refreshAccessibility();
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _statusTimer?.cancel();
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

  Future<void> _refreshAccessibility() async {
    try {
      final enabled =
          await _automation.invokeMethod<bool>('isAccessibilityEnabled') ??
              false;
      if (mounted) setState(() => _accessibilityEnabled = enabled);
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _start() async {
    FocusScope.of(context).unfocus();
    final interval = _positiveInt(_interval);
    final repeats = int.tryParse(_repeatCount.text.trim());
    final x = _percentage(_x);
    final y = _percentage(_y);

    if (interval == null) {
      _message('Enter an interval of at least 1 second.');
      return;
    }
    if (repeats == null || repeats < 0) {
      _message('Enter 0 for unlimited repeats or a positive repeat count.');
      return;
    }
    if (_action == RepeatAction.tap && (x == null || y == null)) {
      _message('Tap coordinates must be between 0 and 100%.');
      return;
    }

    setState(() {
      _count = 0;
      _error = null;
    });

    if (_isAndroid) {
      try {
        final enabled =
            await _automation.invokeMethod<bool>('isAccessibilityEnabled') ??
                false;
        if (!enabled) {
          await _automation.invokeMethod<bool>('openAccessibilitySettings');
          if (mounted) {
            setState(() => _accessibilityEnabled = false);
            _message('Enable LoopMate in Accessibility, then press Start again.');
          }
          return;
        }

        await _automation.invokeMethod<bool>('startRepeating', {
          'action': _action.id,
          'intervalSeconds': interval,
          'xPercent': x ?? 50.0,
          'yPercent': y ?? 50.0,
          'repeatCount': repeats,
        });
        if (!mounted) return;
        setState(() {
          _running = true;
          _accessibilityEnabled = true;
        });
        _pollAndroidState();
      } on PlatformException catch (error) {
        if (mounted) _message(error.message ?? 'Could not start automation.');
      }
      return;
    }

    // iOS can preview the timer but cannot inject gestures into other apps.
    setState(() => _running = true);
    _previewTick(repeats);
    if (_running) {
      _previewTimer = Timer.periodic(
        Duration(seconds: interval),
        (_) => _previewTick(repeats),
      );
    }
  }

  void _previewTick(int repeatLimit) {
    if (!mounted || !_running) return;
    setState(() => _count++);
    if (repeatLimit > 0 && _count >= repeatLimit) {
      _previewTimer?.cancel();
      setState(() => _running = false);
    }
  }

  void _pollAndroidState() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(milliseconds: 800), (_) async {
      try {
        final state =
            await _automation.invokeMapMethod<String, dynamic>('getRunState');
        if (!mounted || state == null) return;
        final running = state['running'] == true;
        final count = (state['count'] as num?)?.toInt() ?? _count;
        setState(() {
          _running = running;
          _count = count;
          _error = state['error'] as String?;
        });
        if (!running) _statusTimer?.cancel();
      } on PlatformException catch (error) {
        if (mounted) setState(() => _error = error.message);
      }
    });
  }

  Future<void> _stop() async {
    _previewTimer?.cancel();
    _statusTimer?.cancel();
    if (_isAndroid) {
      try {
        await _automation.invokeMethod<bool>('stopRepeating');
      } on PlatformException catch (error) {
        if (mounted) setState(() => _error = error.message);
      }
    }
    if (mounted) setState(() => _running = false);
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isTap = _action == RepeatAction.tap;
    final status = _running
        ? 'Running'
        : _isAndroid
            ? (_accessibilityEnabled ? 'Accessibility enabled' : 'Permission needed')
            : 'In-app preview only';

    return Scaffold(
      appBar: AppBar(title: const Text('LoopMate'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Icon(Icons.repeat_rounded, size: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(status,
                              style: Theme.of(context).textTheme.titleMedium),
                          Text('Actions completed: $_count'),
                        ],
                      ),
                    ),
                    Icon(
                      _running ? Icons.play_circle_fill : Icons.pause_circle,
                      color: _running ? Colors.greenAccent : Colors.white54,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Input action',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<RepeatAction>(
                      initialValue: _action,
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
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: _numberField(_x, 'X position (%)')),
                          const SizedBox(width: 12),
                          Expanded(child: _numberField(_y, 'Y position (%)')),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text('50 / 50 targets the centre of the screen.'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Repeat schedule',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _numberField(_interval, 'Interval (seconds)'),
                    const SizedBox(height: 12),
                    _numberField(_repeatCount, 'Maximum repeats (0 = unlimited)'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _running ? null : _start,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _running ? _stop : null,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Stop'),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            if (_isIOS) ...[
              const SizedBox(height: 18),
              const Text(
                'iOS preview only: Apple does not allow ordinary apps to send taps or swipes to other apps. The timer runs inside LoopMate.',
                textAlign: TextAlign.center,
              ),
            ],
            if (_isAndroid) ...[
              const SizedBox(height: 18),
              const Text(
                'Enable LoopMate under Android Settings → Accessibility to automate gestures in other apps.',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
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
