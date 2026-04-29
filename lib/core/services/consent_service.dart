import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';

import '../../services/storage/hive_encryption.dart';

/// Audit-trail of every legal-consent event the app records.
///
/// Each [ConsentRecord] is a single accept/decline of a specific document
/// (financial disclaimer, Privacy Policy, Terms of Service, web-mode
/// disclaimer, ...) tagged with the document version and a UTC timestamp.
/// Records live in a dedicated, encrypted Hive box (`consent_box`) and
/// are exported as JSON when the user invokes the GDPR data-portability
/// flow from Settings.
///
/// Why a separate box?
///  * Keeps the audit log isolated from app data (deleting a portfolio
///    must not erase consent proof).
///  * Schema is stable -- no risk of accidental migration breakage.
///  * Export ships only this box, never user holdings.
class ConsentService {
  ConsentService._();

  static const String _boxName = 'consent_box';

  static Box<String>? _box;

  /// Open the encrypted consent box. Idempotent: a second call returns
  /// the same box without reopening it.
  static Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    final cipher = await HiveEncryption.getCipher();
    _box = await Hive.openBox<String>(
      _boxName,
      encryptionCipher: cipher,
    );
  }

  /// Append a record to the log. The key is auto-generated from a UTC
  /// timestamp + document id so subsequent accepts of the same document
  /// produce distinct entries (re-consent after a version bump).
  static Future<ConsentRecord> record({
    required ConsentDocument document,
    required String version,
    required ConsentDecision decision,
    String? textHash,
  }) async {
    await init();
    final record = ConsentRecord(
      document: document,
      version: version,
      decision: decision,
      timestampUtc: DateTime.now().toUtc(),
      textHash: textHash,
    );
    final key =
        '${record.timestampUtc.toIso8601String()}__${document.storageKey}';
    await _box!.put(key, jsonEncode(record.toJson()));
    return record;
  }

  /// Returns the most recent record for [document], regardless of
  /// decision. Useful when the UI needs to know "did the user already
  /// accept this version?" rather than the full timeline.
  static ConsentRecord? latestFor(
    ConsentDocument document, {
    String? version,
  }) {
    final box = _box;
    if (box == null || !box.isOpen) return null;

    ConsentRecord? newest;
    for (final raw in box.values) {
      try {
        final record = ConsentRecord.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (record.document != document) continue;
        if (version != null && record.version != version) continue;
        if (newest == null ||
            record.timestampUtc.isAfter(newest.timestampUtc)) {
          newest = record;
        }
      } catch (_) {
        // Skip malformed entries (best-effort).
      }
    }
    return newest;
  }

  /// True if the latest record for [document] is an accept of [version].
  static bool isAccepted(
    ConsentDocument document, {
    required String version,
  }) {
    final latest = latestFor(document, version: version);
    return latest != null && latest.decision == ConsentDecision.accepted;
  }

  /// Snapshot of every record in the box, ordered oldest -> newest. Used
  /// by the GDPR export flow.
  static List<ConsentRecord> exportAll() {
    final box = _box;
    if (box == null || !box.isOpen) return const [];
    final records = <ConsentRecord>[];
    for (final raw in box.values) {
      try {
        records.add(
          ConsentRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } catch (_) {
        continue;
      }
    }
    records.sort((a, b) => a.timestampUtc.compareTo(b.timestampUtc));
    return records;
  }

  /// Wipe the box. Tests + "Clear all data" Settings action only.
  static Future<void> clear() async {
    await init();
    await _box!.clear();
  }
}

enum ConsentDocument {
  financialDisclaimer,
  privacyPolicy,
  termsOfService,
  webModeDisclaimer,
}

extension ConsentDocumentX on ConsentDocument {
  String get storageKey {
    switch (this) {
      case ConsentDocument.financialDisclaimer:
        return 'financial_disclaimer';
      case ConsentDocument.privacyPolicy:
        return 'privacy_policy';
      case ConsentDocument.termsOfService:
        return 'terms_of_service';
      case ConsentDocument.webModeDisclaimer:
        return 'web_mode_disclaimer';
    }
  }

  static ConsentDocument fromStorageKey(String value) {
    switch (value) {
      case 'financial_disclaimer':
        return ConsentDocument.financialDisclaimer;
      case 'privacy_policy':
        return ConsentDocument.privacyPolicy;
      case 'terms_of_service':
        return ConsentDocument.termsOfService;
      case 'web_mode_disclaimer':
        return ConsentDocument.webModeDisclaimer;
    }
    throw ArgumentError('Unknown ConsentDocument storage key: $value');
  }
}

enum ConsentDecision { accepted, declined }

extension ConsentDecisionX on ConsentDecision {
  String get storageKey =>
      this == ConsentDecision.accepted ? 'accepted' : 'declined';

  static ConsentDecision fromStorageKey(String value) {
    if (value == 'accepted') return ConsentDecision.accepted;
    if (value == 'declined') return ConsentDecision.declined;
    throw ArgumentError('Unknown ConsentDecision storage key: $value');
  }
}

class ConsentRecord {
  final ConsentDocument document;
  final String version;
  final ConsentDecision decision;
  final DateTime timestampUtc;
  final String? textHash;

  const ConsentRecord({
    required this.document,
    required this.version,
    required this.decision,
    required this.timestampUtc,
    this.textHash,
  });

  Map<String, dynamic> toJson() => {
        'document': document.storageKey,
        'version': version,
        'decision': decision.storageKey,
        'timestamp_utc': timestampUtc.toIso8601String(),
        if (textHash != null) 'text_hash': textHash,
      };

  factory ConsentRecord.fromJson(Map<String, dynamic> json) {
    return ConsentRecord(
      document: ConsentDocumentX.fromStorageKey(json['document'] as String),
      version: json['version'] as String,
      decision: ConsentDecisionX.fromStorageKey(json['decision'] as String),
      timestampUtc: DateTime.parse(json['timestamp_utc'] as String).toUtc(),
      textHash: json['text_hash'] as String?,
    );
  }
}
