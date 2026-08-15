import 'dart:convert';
import 'dart:developer' as developer;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One carrier message, exactly as it arrived.
@immutable
class RawSmsMessage {
  const RawSmsMessage({required this.body, required this.dateMillis});

  final String body;
  final int dateMillis;

  factory RawSmsMessage.fromMap(Map<Object?, Object?> map) => RawSmsMessage(
    body: map['body'] as String? ?? '',
    dateMillis: (map['date'] as num?)?.toInt() ?? 0,
  );
}

/// Reads Yemen Mobile messages from the device, via the native bridge.
///
/// Android-only by nature: iOS exposes no equivalent API. Every call degrades
/// to a safe no-op elsewhere rather than throwing.
class SmsService {
  SmsService({MethodChannel? methodChannel, EventChannel? eventChannel})
    : _method = methodChannel ?? const MethodChannel(_methodChannelName),
      _events = eventChannel ?? const EventChannel(_eventChannelName);

  static const String _methodChannelName = 'baqati/sms';
  static const String _eventChannelName = 'baqati/sms_stream';

  final MethodChannel _method;
  final EventChannel _events;

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// Messages arriving while the app is running.
  ///
  /// Anything that arrives while the process is dead is not lost — it is picked
  /// up by [readInbox] at the next launch.
  Stream<RawSmsMessage> get incoming {
    if (!_isAndroid) return const Stream<RawSmsMessage>.empty();
    return _events.receiveBroadcastStream().map(
      (Object? event) => RawSmsMessage.fromMap(event! as Map<Object?, Object?>),
    );
  }

  /// Re-reads recent carrier messages from the device inbox.
  ///
  /// Safe to call repeatedly: events are deduplicated on insert by
  /// [sourceHashFor].
  Future<List<RawSmsMessage>> readInbox() async {
    if (!_isAndroid) return const <RawSmsMessage>[];
    try {
      final List<Object?>? rows = await _method.invokeMethod<List<Object?>>(
        'readInbox',
      );
      if (rows == null) return const <RawSmsMessage>[];
      return rows
          .whereType<Map<Object?, Object?>>()
          .map(RawSmsMessage.fromMap)
          .toList();
    } on PlatformException catch (e) {
      developer.log('readInbox failed: ${e.message}', name: 'SmsService');
      return const <RawSmsMessage>[];
    }
  }

  Future<bool> hasSmsPermission() async {
    if (!_isAndroid) return false;
    try {
      return await _method.invokeMethod<bool>('hasSmsPermission') ?? false;
    } on PlatformException catch (e) {
      developer.log(
        'hasSmsPermission failed: ${e.message}',
        name: 'SmsService',
      );
      return false;
    }
  }

  /// Prompts for READ_SMS and RECEIVE_SMS, resolving once the user answers.
  ///
  /// Handled by the native bridge rather than a permission plugin: the only
  /// permissions this app needs are the SMS pair, and `permission_handler`'s
  /// current Android implementation requires a newer AGP and Kotlin toolchain
  /// than this project builds with.
  Future<bool> requestSmsPermission() async {
    if (!_isAndroid) return false;
    try {
      return await _method.invokeMethod<bool>('requestSmsPermission') ?? false;
    } on PlatformException catch (e) {
      developer.log(
        'requestSmsPermission failed: ${e.message}',
        name: 'SmsService',
      );
      return false;
    }
  }

  /// The dedupe key for one event parsed out of a carrier message.
  ///
  /// PORT-FIX: the Kotlin had no dedupe of any kind, so every inbox sync
  /// re-inserted the same messages and history duplicated without bound.
  ///
  /// [eventIndex] is part of the key because one message can parse into several
  /// events. Without it they would share a hash and the unique index would keep
  /// only the first, silently discarding the rest.
  static String sourceHashFor({
    required String body,
    required int dateMillis,
    required int eventIndex,
  }) {
    final Digest digest = sha256.convert(utf8.encode('$body|$dateMillis'));
    return '$digest#$eventIndex';
  }
}
