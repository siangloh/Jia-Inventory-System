// debouncer_service.dart
import 'dart:async';

class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({required this.delay});

  void run(FutureOr<void> Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, () async {
      try {
        await action();
      } catch (e) {
        print('Debouncer error: $e');
      }
    });
  }

  void cancel() {
    _timer?.cancel();
  }
}
