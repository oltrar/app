import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loopmate/repeat_runner.dart';

void main() {
  testWidgets('runs immediately and stops after the configured limit',
      (tester) async {
    var performed = 0;
    var reported = 0;
    var stopped = false;
    final runner = RepeatRunner(
      interval: const Duration(seconds: 10),
      repeatLimit: 3,
      perform: () async { performed++; },
      onSuccess: (count) => reported = count,
      onStop: () => stopped = true,
      onError: (error) => fail('Unexpected error: $error'),
    );

    runner.start();
    await tester.pump();
    expect(performed, 1);
    expect(reported, 1);

    await tester.pump(const Duration(seconds: 10));
    expect(performed, 2);
    await tester.pump(const Duration(seconds: 10));
    expect(performed, 3);
    expect(reported, 3);
    expect(stopped, true);
    expect(runner.isRunning, false);

    await tester.pump(const Duration(seconds: 30));
    expect(performed, 3);
  });

  testWidgets('never overlaps an unfinished action', (tester) async {
    final pending = Completer<void>();
    var performed = 0;
    final runner = RepeatRunner(
      interval: const Duration(seconds: 1),
      repeatLimit: 0,
      perform: () {
        performed++;
        return pending.future;
      },
      onSuccess: (_) {},
      onStop: () {},
      onError: (error) => fail('Unexpected error: $error'),
    );

    runner.start();
    await tester.pump(const Duration(seconds: 5));
    expect(performed, 1);
    pending.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(performed, 2);
    runner.stop();
  });

  testWidgets('stopping cancels scheduled actions', (tester) async {
    var performed = 0;
    final runner = RepeatRunner(
      interval: const Duration(seconds: 3),
      repeatLimit: 0,
      perform: () async { performed++; },
      onSuccess: (_) {},
      onStop: () {},
      onError: (error) => fail('Unexpected error: $error'),
    );
    runner.start();
    await tester.pump();
    runner.stop();
    await tester.pump(const Duration(seconds: 12));
    expect(performed, 1);
  });
}
