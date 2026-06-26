import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/utils/app_logger.dart';

void main() {
  // Catch and log any uncaught framework errors so a bug never silently
  // corrupts a sale; a crash-reporting sink is wired in Phase 9.
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.e(
      'Uncaught Flutter error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  AppLogger.i('Starting PSG POS');

  // ProviderScope is the root of Riverpod's dependency injection.
  runApp(const ProviderScope(child: PsgPosApp()));
}
