import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'repeat_runner.dart';

enum RepeatAction {
  tap('Tap at position'),
  up('Swipe up / scroll down'),
  down('Swipe down / scroll up'),
  left('Swipe left / scroll right'),
  right('Swipe right / scroll left');

  const RepeatAction(this.label);
  final String label;
}

const String _demoHtml = r'''
<!doctype html><html><head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body{font:17px -apple-system,sans-serif;background:#f5f7ff;color:#152139;margin:0;padding:20px}
h1{font-size:26px}button{background:#435ce4;color:white;border:0;border-radius:12px;
padding:18px 30px;font-size:20px}p{line-height:1.5}
.tile{margin:20px 0;padding:32px 18px;border-radius:16px;background:white;
box-shadow:0 2px 9px #cbd2e650}
</style></head><body>
<h1>LoopMate demo</h1>
<p>This page works offline. Pick Tap and target the button, or select Swipe up to scroll.</p>
<button onclick="document.getElementById('total').textContent=Number(document.getElementById('total').textContent)+1">Tap me</button>
<p>Button taps: <strong id="total">0</strong></p>
<div class="tile">Section 1 — Scroll down to see more</div>
<div class="tile">Section 2</div>
<div class="tile">Section 3</div>
<div class="tile">Section 4</div>
<div class="tile">Section 5</div>
<div class="tile">Section 6</div>
<div class="tile">Section 7</div>
<div class="tile">Section 8</div>
<div class="tile">End of page</div>
</body></html>
''';

void main() => runApp(const LoopMateApp());

class LoopMateApp extends StatelessWidget {
  const LoopMateApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'LoopMate iOS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7488F5),
            brightness: Brightness.dark,
          ),
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

class _RepeaterScreenState extends State<RepeaterScreen>
    with WidgetsBindingObserver {
  final _url = TextEditingController();
  final _interval = TextEditingController(text: '10');
  final _x = TextEditingController(text: '50');
  final _y = TextEditingController(text: '50');
  final _repeatCount = TextEditingController(text: '0');

  late final WebViewController _browser;
  RepeatRunner? _runner;
  RepeatAction _action = RepeatAction.up;
  bool _running = false;
  bool _disposing = false;
  bool _pageReady = false;
  bool _picking = false;
  int _count = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _browser = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            _runner?.stop();
            if (mounted) setState(() => _pageReady = false);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _pageReady = true);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              _runner?.stop();
              setState(() {
                _pageReady = false;
                _error = error.description;
              });
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            if (uri.scheme == 'https' ||
                uri.scheme == 'about' ||
                uri.scheme == 'data') {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadHtmlString(_demoHtml);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // iOS only allows this automation while LoopMate is in the foreground.
    if (state != AppLifecycleState.resumed) _runner?.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposing = true;
    _runner?.stop();
    _url.dispose();
    _interval.dispose();
    _x.dispose();
    _y.dispose();
    _repeatCount.dispose();
    super.dispose();
  }

  int? _positiveInt(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim());
    return value != null && value > 0 ? value : null;
  }

  double? _percent(TextEditingController controller) {
    final value = double.tryParse(controller.text.trim());
    return value != null && value.isFinite && value >= 0 && value <= 100
        ? value
        : null;
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadDemo() async {
    _runner?.stop();
    setState(() {
      _picking = false;
      _pageReady = false;
      _error = null;
    });
    try {
      await _browser.loadHtmlString(_demoHtml);
    } catch (error) {
      _message('Could not load demo: $error');
    }
  }

  Future<void> _loadUrl() async {
    FocusScope.of(context).unfocus();
    final entered = _url.text.trim();
    final normalized = entered.contains('://') ? entered : 'https://$entered';
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      _message('Enter a valid HTTPS website.');
      return;
    }
    _runner?.stop();
    setState(() {
      _picking = false;
      _pageReady = false;
      _error = null;
      _url.text = normalized;
    });
    try {
      await _browser.loadRequest(uri);
    } catch (error) {
      _message('Could not open website: $error');
    }
  }

  Future<void> _performAction() async {
    final x = _percent(_x) ?? 50;
    final y = _percent(_y) ?? 50;

    if (_action == RepeatAction.tap) {
      // DOM click inside this WKWebView only; not a system-wide touch.
      final result = await _browser.runJavaScriptReturningResult('''
(function () {
  var target = document.elementFromPoint(
    window.innerWidth * ${x / 100},
    window.innerHeight * ${y / 100}
  );
  if (!target) return false;
  target.click();
  return true;
})()
''');
      if (result != true && result != 'true') {
        throw StateError('No tappable element at this position.');
      }
      return;
    }

    // A swipe moves the content in the opposite direction.
    final dx = _action == RepeatAction.left
        ? 0.75
        : _action == RepeatAction.right
            ? -0.75
            : 0.0;
    final dy = _action == RepeatAction.up
        ? 0.75
        : _action == RepeatAction.down
            ? -0.75
            : 0.0;
    await _browser.runJavaScript('''
(function () {
  var dx = window.innerWidth * $dx;
  var dy = window.innerHeight * $dy;
  var element = document.elementFromPoint(window.innerWidth / 2, window.innerHeight / 2);
  while (element && element !== document.body && element !== document.documentElement) {
    var vertical = dy !== 0 && element.scrollHeight > element.clientHeight + 2;
    var horizontal = dx !== 0 && element.scrollWidth > element.clientWidth + 2;
    if (vertical || horizontal) {
      element.scrollBy(dx, dy);
      return;
    }
    element = element.parentElement;
  }
  window.scrollBy(dx, dy);
})()
''');
  }

  void _start() {
    FocusScope.of(context).unfocus();
    final interval = _positiveInt(_interval);
    final limit = int.tryParse(_repeatCount.text.trim());
    if (interval == null || limit == null || limit < 0) {
      _message('Use an interval of at least 1 second and a repeat limit >= 0.');
      return;
    }
    if (_action == RepeatAction.tap &&
        (_percent(_x) == null || _percent(_y) == null)) {
      _message('Tap coordinates must be between 0% and 100%.');
      return;
    }
    if (!_pageReady) {
      _message('Open a page before starting.');
      return;
    }
    _runner?.stop();
    final runner = RepeatRunner(
      interval: Duration(seconds: interval),
      repeatLimit: limit,
      perform: _performAction,
      onSuccess: (count) {
        if (mounted) setState(() => _count = count);
      },
      onStop: () {
        if (mounted && !_disposing) setState(() => _running = false);
      },
      onError: (error) {
        if (mounted) {
          setState(() => _error = error.toString());
          _message('Action stopped: $error');
        }
      },
    );
    _runner = runner;
    setState(() {
      _running = true;
      _picking = false;
      _error = null;
      _count = 0;
    });
    runner.start();
  }

  void _stop() => _runner?.stop();

  Widget _numberField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      enabled: !_running,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTap = _action == RepeatAction.tap;
    return Scaffold(
      appBar: AppBar(title: const Text('LoopMate iOS')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_running ? 'Running inside browser' : 'Browser automation',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text('Actions completed: $_count'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _url,
                            enabled: !_running,
                            keyboardType: TextInputType.url,
                            onSubmitted: (_) => _loadUrl(),
                            decoration: const InputDecoration(
                              labelText: 'Website (HTTPS)',
                              hintText: 'https://example.org',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _running ? null : _loadUrl,
                          child: const Text('Go'),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: _running ? null : _loadDemo,
                      child: const Text('Open offline demo page'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 360,
                child: Stack(
                  children: [
                    Positioned.fill(child: WebViewWidget(controller: _browser)),
                    if (_picking)
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, constraints) => GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (details) {
                              final x = (details.localPosition.dx /
                                      constraints.maxWidth *
                                      100)
                                  .clamp(0.0, 100.0);
                              final y = (details.localPosition.dy /
                                      constraints.maxHeight *
                                      100)
                                  .clamp(0.0, 100.0);
                              setState(() {
                                _x.text = x.toStringAsFixed(1);
                                _y.text = y.toStringAsFixed(1);
                                _picking = false;
                              });
                            },
                            child: Container(
                              color: const Color(0x553F5FCA),
                              alignment: Alignment.center,
                              child: const Text(
                                'Tap a position to repeat',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!_pageReady)
                      const Positioned(
                        right: 10,
                        top: 10,
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Loading…'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<RepeatAction>(
                      initialValue: _action,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Action',
                        border: OutlineInputBorder(),
                      ),
                      items: RepeatAction.values
                          .map((action) => DropdownMenuItem(
                                value: action,
                                child: Text(action.label),
                              ))
                          .toList(),
                      onChanged: _running
                          ? null
                          : (action) =>
                              setState(() => _action = action ?? _action),
                    ),
                    if (isTap) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _running
                            ? null
                            : () => setState(() => _picking = !_picking),
                        icon: const Icon(Icons.touch_app),
                        label: Text(_picking ? 'Cancel picking' : 'Pick point on page'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _numberField(_x, 'X (%)')),
                          const SizedBox(width: 10),
                          Expanded(child: _numberField(_y, 'Y (%)')),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    _numberField(_interval, 'Every N seconds'),
                    const SizedBox(height: 10),
                    _numberField(_repeatCount, 'Repeat limit (0 = unlimited)'),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _running ? null : _start,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _running ? _stop : null,
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.redAccent)),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'iOS can repeat clicks and scrolling on pages shown here while this app is open. It cannot tap other apps or run this loop in the background. Some websites require real user gestures.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
