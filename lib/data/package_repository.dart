import 'package:flutter/foundation.dart';

import 'package:baqati/data/package_event_dao.dart';
import 'package:baqati/models/event_type.dart';
import 'package:baqati/models/package_event.dart';

/// The app's single source of package events.
///
/// The Kotlin exposed Room `Flow`s that the UI collected directly. This stack
/// uses ChangeNotifier MVVM instead, so the repository signals that something
/// changed and the view model re-queries. Reads stay plain futures, which keeps
/// the query surface identical to the DAO.
class PackageRepository extends ChangeNotifier {
  PackageRepository(this._dao);

  final PackageEventDao _dao;

  Future<List<PackageEvent>> getAllEvents() => _dao.getAllEvents();

  Future<PackageEvent?> getLatestEvent() => _dao.getLatestEvent();

  Future<PackageEvent?> getLatestEventByType(EventType type) =>
      _dao.getLatestEventByType(type);

  Future<List<PackageEvent>> getActivePackages(int nowMillis) =>
      _dao.getActivePackages(nowMillis);

  /// Returns the new row id, or 0 if the event was a duplicate.
  Future<int> insert(PackageEvent event) async {
    final int id = await _dao.insert(event);
    if (id != 0) notifyListeners();
    return id;
  }

  /// Returns how many of [events] were newly written, ignoring duplicates.
  Future<int> insertAll(List<PackageEvent> events) async {
    final int inserted = await _dao.insertAll(events);
    if (inserted > 0) notifyListeners();
    return inserted;
  }

  /// Returns the newly-written events with their row ids, skipping duplicates.
  Future<List<PackageEvent>> insertAllReturningInserted(
    List<PackageEvent> events,
  ) async {
    final List<PackageEvent> inserted = await _dao.insertAllReturningInserted(
      events,
    );
    if (inserted.isNotEmpty) notifyListeners();
    return inserted;
  }

  Future<void> deleteById(int id) async {
    await _dao.deleteById(id);
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _dao.clearAll();
    notifyListeners();
  }
}
