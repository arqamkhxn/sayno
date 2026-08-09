import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/uce_api_config.dart';
import '../../identity/domain/identity_configuration.dart';
import '../domain/content_catalog_provider.dart';
import '../domain/content_collection.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Dev Diagnostics (kDebugMode only — zero production impact)
// ─────────────────────────────────────────────────────────────────────────────

/// Classifies the outcome of a [UceContentCatalogProvider.fetchHomeCollections] call.
/// Used only in debug builds to quickly identify which path was taken.
enum _FeedDiagnostic {
  /// ✅ API returned ≥1 collection with real UCE content.
  realContent,

  /// ⚠️ API responded 200 but returned 0 collections (Firestore likely empty).
  emptyRealFeed,

  /// 🔒 Firebase Auth: no current user or token retrieval failed.
  authFailure,

  /// ❌ Feed API returned a non-200/304 HTTP status.
  apiFailure,

  /// 🌐 Network error, timeout, or unexpected exception.
  networkError,

  /// 🔄 Fallback provider is serving content (any of the above triggered it).
  fallbackActive,
}

const _diagnosticIcon = {
  _FeedDiagnostic.realContent: '✅',
  _FeedDiagnostic.emptyRealFeed: '⚠️',
  _FeedDiagnostic.authFailure: '🔒',
  _FeedDiagnostic.apiFailure: '❌',
  _FeedDiagnostic.networkError: '🌐',
  _FeedDiagnostic.fallbackActive: '🔄',
};

void _logDiagnostic(_FeedDiagnostic diagnostic, {String? detail}) {
  if (!kDebugMode) return;
  final icon = _diagnosticIcon[diagnostic] ?? '?';
  final suffix = detail != null ? ': $detail' : '';
  debugPrint('[UCE FEED] $icon ${diagnostic.name}$suffix');
}

// ─────────────────────────────────────────────────────────────────────────────

/// UceContentCatalogProvider — Live UCE Backend Integration (TSK-5.1.2)
///
/// Implements [ContentCatalogProvider] by calling the UCE Feed API:
///
///   `GET {baseUrl}/v1/feed/{userId}`
///   Authorization: Bearer {firebase-id-token}
///
/// Response shape (EIS §11.1):
/// ```json
/// {
///   "collections": [
///     {
///       "id": "...", "title": "...", "type": "curated",
///       "items": [{ "id": "...", "title": "...", ... }]
///     }
///   ],
///   "generatedAt": "...",
///   "feedGenerationId": "..."
/// }
/// ```
///
/// The API response fields map 1-to-1 to [ContentCollection] and [ContentItem]
/// domain models (by design in EIS §11.2 — Feed Response Mapper).
///
/// Fallback Strategy:
/// If the authenticated user cannot be determined, or if the API call fails for
/// any reason (network error, 5xx, etc.), the [_fallback] provider is used so
/// the home feed always shows content rather than an empty error state.
///
/// Authentication:
/// Uses [FirebaseAuth.instance.currentUser.getIdToken()] — this automatically
/// refreshes the token if it has expired (Firebase SDK handles this).
///
/// @see EIS §11 — Feed API Specification
/// @see EIS §12 — Authentication & Authorization
/// @see TTB TSK-5.1.2 — Flutter Integration
class UceContentCatalogProvider implements ContentCatalogProvider {
  final ContentCatalogProvider _fallback;
  final http.Client _httpClient;

  UceContentCatalogProvider({
    required ContentCatalogProvider fallback,
    http.Client? httpClient,
  })  : _fallback = fallback,
        _httpClient = httpClient ?? http.Client();

  @override
  Future<List<ContentCollection>> fetchHomeCollections(
    IdentityConfiguration? activeIdentity,
  ) async {
    try {
      // ── Step 1: Get authenticated Firebase user ─────────────────────────
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _logDiagnostic(_FeedDiagnostic.authFailure,
            detail: 'No authenticated user');
        _logDiagnostic(_FeedDiagnostic.fallbackActive);
        return _fallback.fetchHomeCollections(activeIdentity);
      }

      final userId = currentUser.uid;

      // ── Step 2: Get a fresh Firebase ID token ───────────────────────────
      // getIdToken() uses cached token; Firebase SDK auto-refreshes if expired.
      final idToken = await currentUser.getIdToken();
      if (idToken == null) {
        _logDiagnostic(_FeedDiagnostic.authFailure,
            detail: 'ID token retrieval returned null');
        _logDiagnostic(_FeedDiagnostic.fallbackActive);
        return _fallback.fetchHomeCollections(activeIdentity);
      }

      // ── Step 3: Call the UCE Feed API ────────────────────────────────────
      final url = Uri.parse(UceApiConfig.feedUrl(userId));
      debugPrint('[UCE] Fetching feed from: $url');

      final response = await _httpClient.get(
        url,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('[UCE] Feed API request timed out after 15 seconds');
        },
      );

      // ── Step 4: Validate response ─────────────────────────────────────────
      if (response.statusCode == 200) {
        final collections = _parseCollections(response.body);
        if (collections.isEmpty || collections.every((c) => c.items.isEmpty)) {
          _logDiagnostic(_FeedDiagnostic.emptyRealFeed,
              detail: 'API 200 but 0 items — Firestore may need ingestion');
          _logDiagnostic(_FeedDiagnostic.fallbackActive);
          return _fallback.fetchHomeCollections(activeIdentity);
        }
        _logDiagnostic(_FeedDiagnostic.realContent,
            detail: '${collections.length} collection(s) loaded');
        return collections;
      }

      if (response.statusCode == 304) {
        // ETag match — feed unchanged. Fall through to fallback (no cached copy here).
        _logDiagnostic(_FeedDiagnostic.apiFailure,
            detail: '304 Not Modified — no local cache available');
        _logDiagnostic(_FeedDiagnostic.fallbackActive);
        return _fallback.fetchHomeCollections(activeIdentity);
      }

      // Non-success response: log and fall back
      _logDiagnostic(_FeedDiagnostic.apiFailure,
          detail: 'HTTP ${response.statusCode}');
      _logDiagnostic(_FeedDiagnostic.fallbackActive);
      debugPrint('[UCE] Feed API error ${response.statusCode}: ${response.body}');
      return _fallback.fetchHomeCollections(activeIdentity);
    } catch (e, stack) {
      _logDiagnostic(_FeedDiagnostic.networkError, detail: e.toString());
      _logDiagnostic(_FeedDiagnostic.fallbackActive);
      debugPrint('[UCE] Exception fetching feed: $e');
      debugPrint('[UCE] Stack: $stack');
      return _fallback.fetchHomeCollections(activeIdentity);
    }
  }

  // ---------------------------------------------------------------------------
  // Private — JSON Parsing
  // ---------------------------------------------------------------------------

  /// Parses the Feed API JSON response body into [ContentCollection] domain objects.
  ///
  /// The API response mirrors the Flutter ContentCollection/ContentItem schema
  /// (EIS §11.2), so [ContentCollection.fromJson] can be used directly.
  List<ContentCollection> _parseCollections(String body) {
    try {
      final Map<String, dynamic> json = jsonDecode(body);
      final List<dynamic> rawCollections = json['collections'] as List<dynamic>? ?? [];

      final collections = rawCollections
          .map((raw) => ContentCollection.fromJson(raw as Map<String, dynamic>))
          .toList();

      debugPrint('[UCE] Parsed ${collections.length} collection(s) from Feed API.');
      return collections;
    } catch (e, stack) {
      debugPrint('[UCE] Failed to parse Feed API response: $e');
      debugPrint('[UCE] Parse stack: $stack');
      return [];
    }
  }
}
