/// UCE Feed API Configuration
///
/// Defines the base URL and endpoint helpers for the SAYNO UCE backend
/// hosted on Railway.
///
/// The URL can be overridden at runtime via [UceApiConfig.overrideBaseUrl]
/// to support staging or environment-specific deploys.
abstract final class UceApiConfig {
  /// Production base URL for the UCE Feed API on Railway.
  static const String _defaultBaseUrl = 'https://sayno-ucefunctions-production.up.railway.app';

  /// Runtime override — set this in main.dart or via env for staging.
  static String? _overrideBaseUrl;

  /// The currently active base URL.
  static String get baseUrl => _overrideBaseUrl ?? _defaultBaseUrl;

  /// Override the base URL.
  static void overrideBaseUrl(String url) {
    _overrideBaseUrl = url;
  }

  /// Constructs the full URL for fetching a user's personalized feed.
  ///
  /// `GET {baseUrl}/v1/feed/{userId}`
  static String feedUrl(String userId) => '$baseUrl/v1/feed/$userId';

  /// Constructs the URL for recording user signals (consumed, dismissed, etc).
  ///
  /// `POST {baseUrl}/v1/signals/{userId}`
  static String signalsUrl(String userId) => '$baseUrl/v1/signals/$userId';

  /// Constructs the URL for interacting with the Coach chat AI.
  ///
  /// `POST {baseUrl}/v1/coach/chat`
  static String get coachChatUrl => '$baseUrl/v1/coach/chat';
}
