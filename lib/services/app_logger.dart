import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Centralized logging + crash-reporting hook.
///
/// The app previously had ~60 raw `print()` calls scattered across
/// services and no way to see any of them once shipped (no Crashlytics,
/// no Sentry, nothing). This doesn't add a crash reporting backend itself
/// — that needs a real account/project this agent can't create — but it
/// gives every call site a single choke point to log through, so wiring
/// one in later is a one-line change to [onError] instead of a
/// find-and-replace across the codebase.
class AppLogger {
  AppLogger._();

  /// Set this to forward warnings/errors to a real crash reporter
  /// (Crashlytics.recordError, Sentry.captureException, etc.) once one is
  /// configured. Left null today — errors still show in `flutter run`
  /// debug output via [debug]/[developer.log], they just aren't captured
  /// anywhere in release builds yet.
  static void Function(Object error, StackTrace? stackTrace, {String? reason})? onError;

  static void debug(String message, {String? tag}) => _log(message, tag: tag, level: 500);

  static void info(String message, {String? tag}) => _log(message, tag: tag, level: 800);

  static void warning(String message, {String? tag}) => _log(message, tag: tag, level: 900);

  static void error(String message, {Object? error, StackTrace? stackTrace, String? tag}) {
    _log(message, tag: tag, level: 1000);
    onError?.call(error ?? message, stackTrace, reason: message);
  }

  static void _log(String message, {String? tag, required int level}) {
    if (kDebugMode) {
      developer.log(message, name: tag ?? 'takt', level: level);
    }
  }
}
