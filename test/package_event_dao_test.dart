import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:baqati/data/app_database.dart';
import 'package:baqati/data/package_event_dao.dart';
import 'package:baqati/models/event_type.dart';
import 'package:baqati/models/package_event.dart';

PackageEvent _event({
  String title = 'تفعيل باقة جديدة',
  String? sourceHash,
  int timestamp = 1000,
  EventType type = EventType.activation,
}) => PackageEvent(
  type: type,
  timestamp: timestamp,
  title: title,
  description: 'وصف',
  sourceHash: sourceHash,
);

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late PackageEventDao dao;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 1, onCreate: AppDatabase.onCreate),
    );
    dao = PackageEventDao(AppDatabase(database: db));
  });

  tearDown(() async => db.close());

  group('dedupe', () {
    test('a repeated source hash is ignored, not duplicated', () async {
      expect(await dao.insert(_event(sourceHash: 'abc#0')), isNonZero);
      expect(await dao.insert(_event(sourceHash: 'abc#0')), 0);
      expect(await dao.getAllEvents(), hasLength(1));
    });

    test('several manual rows with a null hash coexist', () async {
      // SQLite lets a UNIQUE index hold multiple NULLs, which is what keeps
      // hand-entered events — which have no source message — from colliding.
      await dao.insert(_event(type: EventType.manual, title: 'أولى'));
      await dao.insert(_event(type: EventType.manual, title: 'ثانية'));

      expect(await dao.getAllEvents(), hasLength(2));
    });

    test('events parsed from one message stay distinct', () async {
      await dao.insert(_event(sourceHash: 'abc#0'));
      await dao.insert(_event(sourceHash: 'abc#1'));

      expect(await dao.getAllEvents(), hasLength(2));
    });
  });

  group('insertAllReturningInserted', () {
    test('returns only the new rows, each carrying its id', () async {
      await dao.insert(_event(sourceHash: 'already#0'));

      final List<PackageEvent> inserted = await dao.insertAllReturningInserted(
        <PackageEvent>[
          _event(sourceHash: 'already#0'),
          _event(sourceHash: 'fresh#0'),
        ],
      );

      expect(inserted, hasLength(1));
      expect(inserted.single.sourceHash, 'fresh#0');
      expect(inserted.single.id, isNotNull);
    });

    test('is a no-op on an empty list', () async {
      expect(
        await dao.insertAllReturningInserted(const <PackageEvent>[]),
        isEmpty,
      );
    });

    test('agrees with the count insertAll reports', () async {
      final List<PackageEvent> batch = <PackageEvent>[
        _event(sourceHash: 'a#0'),
        _event(sourceHash: 'b#0'),
        _event(sourceHash: 'a#0'),
      ];

      expect(await dao.insertAll(batch), 2);
      expect(await dao.insertAllReturningInserted(batch), isEmpty);
    });
  });

  group('queries', () {
    test('orders newest first, breaking ties by id', () async {
      // A single SMS can emit several events sharing one timestamp; without
      // the id tiebreak, which one counts as "latest" is left to SQLite.
      final int first = await dao.insert(
        _event(sourceHash: 'x#0', timestamp: 5000, title: 'أقدم'),
      );
      final int second = await dao.insert(
        _event(sourceHash: 'x#1', timestamp: 5000, title: 'أحدث'),
      );

      expect(second, greaterThan(first));
      expect((await dao.getLatestEvent())!.title, 'أحدث');
    });

    test('finds the latest event of a given type', () async {
      await dao.insert(
        _event(sourceHash: 'a#0', timestamp: 1000, type: EventType.activation),
      );
      await dao.insert(
        _event(
          sourceHash: 'b#0',
          timestamp: 2000,
          type: EventType.balanceCheck,
          title: 'فحص الرصيد',
        ),
      );

      expect(
        (await dao.getLatestEventByType(EventType.activation))!.timestamp,
        1000,
      );
      expect(
        (await dao.getLatestEventByType(EventType.balanceCheck))!.title,
        'فحص الرصيد',
      );
    });

    test('active packages exclude expired ones and sort by expiry', () async {
      await db.insert(PackageEvent.tableName, <String, Object?>{
        'type': 'ACTIVATION',
        'timestamp': 1000,
        'expiry_timestamp': 500,
        'title': 'منتهية',
        'description': '',
      });
      await db.insert(PackageEvent.tableName, <String, Object?>{
        'type': 'ACTIVATION',
        'timestamp': 1000,
        'expiry_timestamp': 9000,
        'title': 'لاحقة',
        'description': '',
      });
      await db.insert(PackageEvent.tableName, <String, Object?>{
        'type': 'ACTIVATION',
        'timestamp': 1000,
        'expiry_timestamp': 3000,
        'title': 'أقرب',
        'description': '',
      });

      final List<PackageEvent> active = await dao.getActivePackages(2000);
      expect(active.map((PackageEvent e) => e.title), <String>[
        'أقرب',
        'لاحقة',
      ]);
    });

    test('round-trips every persisted field', () async {
      const PackageEvent original = PackageEvent(
        type: EventType.balanceCheck,
        timestamp: 1234,
        minutes: 300,
        sms: 350,
        megabytes: 247.35,
        expiryTimestamp: 5678,
        cost: 2066.25,
        balance: 1500.5,
        title: 'فحص الرصيد',
        description: 'وصف',
        sourceHash: 'hash#0',
      );

      await dao.insert(original);
      final PackageEvent stored = (await dao.getLatestEvent())!;

      expect(stored.type, original.type);
      expect(stored.minutes, 300);
      expect(stored.sms, 350);
      expect(stored.megabytes, 247.35);
      expect(stored.expiryTimestamp, 5678);
      expect(stored.cost, 2066.25);
      expect(stored.balance, 1500.5);
      expect(stored.sourceHash, 'hash#0');
    });
  });

  test('deleteById and clearAll remove rows', () async {
    final int id = await dao.insert(_event(sourceHash: 'a#0'));
    await dao.insert(_event(sourceHash: 'b#0'));

    await dao.deleteById(id);
    expect(await dao.getAllEvents(), hasLength(1));

    await dao.clearAll();
    expect(await dao.getAllEvents(), isEmpty);
  });
}
