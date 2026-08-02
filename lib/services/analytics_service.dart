import 'app_logger.dart';

/// Lightweight funnel-event tracking.
///
/// There's no real analytics backend wired up — that needs a project/API
/// key from a service (Firebase Analytics, PostHog, Amplitude, ...) this
/// agent can't create an account for. Every event still flows through
/// here and gets logged via [AppLogger] today, so wiring a real backend
/// later is a one-line change to [onEvent] instead of hunting down call
/// sites across the app.
class AnalyticsService {
  AnalyticsService._();

  static void Function(String name, Map<String, Object?>? params)? onEvent;

  static void logEvent(String name, {Map<String, Object?>? params}) {
    AppLogger.debug('event: $name ${params ?? const {}}', tag: 'Analytics');
    onEvent?.call(name, params);
  }
}
