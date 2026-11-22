import 'dart:async';

/// Repeats an asynchronous operation without overlapping invocations.
/// Executes once immediately, then at the configured interval.
class RepeatRunner {
  RepeatRunner({
    required this.interval,
    required this.repeatLimit,
    required this.perform,
    required this.onSuccess,
    required this.onStop,
    required this.onError,
  }) : assert(interval > Duration.zero),
       assert(repeatLimit >= 0);

  final Duration interval;
  final int repeatLimit;
  final Future<void> Function() perform;
  final void Function(int count) onSuccess;
  final void Function() onStop;
  final void Function(Object error) onError;

  Timer? _timer;
  bool _running = false;
  bool _busy = false;
  int _count = 0;

  bool get isRunning => _running;
  int get count => _count;

  void start() {
    if (_running) return;
    _running = true;
    _count = 0;
    _runOnce();
    if (_running) {
      _timer = Timer.periodic(interval, (_) => _runOnce());
    }
  }

  Future<void> _runOnce() async {
    if (!_running || _busy) return;
    _busy = true;
    try {
      await perform();
      if (!_running) return;
      _count++;
      onSuccess(_count);
      if (repeatLimit != 0 && _count >= repeatLimit) stop();
    } catch (error) {
      if (_running) {
        onError(error);
        stop();
      }
    } finally {
      _busy = false;
    }
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _timer?.cancel();
    _timer = null;
    onStop();
  }
}
