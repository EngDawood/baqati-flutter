/// The kind of event a [PackageEvent] row records.
///
/// Persisted as the uppercase [wireName] to match the Kotlin reference's Room
/// enum storage, so a database created by either implementation stays readable.
enum EventType {
  activation('ACTIVATION'),
  balanceCheck('BALANCE_CHECK'),
  deduction('DEDUCTION'),
  payment('PAYMENT'),

  /// PORT-FIX: the Kotlin stored manually-entered reminders as [activation]
  /// with `timestamp = now`, so every manual entry permanently masked the most
  /// recent real SMS activation in "latest activation" queries.
  manual('MANUAL');

  const EventType(this.wireName);

  /// The string form written to the database.
  final String wireName;

  /// Parses a persisted [wireName] back into an [EventType].
  ///
  /// Throws [FormatException] on an unrecognized value rather than silently
  /// defaulting — an unknown type in the database means a schema mismatch, not
  /// a recoverable condition.
  static EventType fromWireName(String value) {
    for (final EventType type in EventType.values) {
      if (type.wireName == value) return type;
    }
    throw FormatException('Unknown EventType: $value');
  }
}
