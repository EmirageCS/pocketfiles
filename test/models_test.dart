import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketfiles/models/file_model.dart';
import 'package:pocketfiles/models/folder_model.dart';

void main() {
  // ── FileModel ──────────────────────────────────────────────────────────────

  group('FileModel', () {
    final base = FileModel(
      id: 1,
      folderId: 10,
      name: 'report.pdf',
      path: '/docs/report.pdf',
      size: 2048,
      orderIndex: 3,
      createdAt: DateTime(2024, 6, 15),
    );

    test('toMap produces correct keys and values', () {
      final map = base.toMap();
      expect(map['id'],         1);
      expect(map['folderId'],   10);
      expect(map['name'],       'report.pdf');
      expect(map['path'],       '/docs/report.pdf');
      expect(map['size'],       2048);
      expect(map['orderIndex'], 3);
      expect(map['createdAt'],  '2024-06-15T00:00:00.000');
    });

    test('fromMap round-trips through toMap', () {
      final roundTrip = FileModel.fromMap(base.toMap());
      expect(roundTrip.id,         base.id);
      expect(roundTrip.folderId,   base.folderId);
      expect(roundTrip.name,       base.name);
      expect(roundTrip.path,       base.path);
      expect(roundTrip.size,       base.size);
      expect(roundTrip.orderIndex, base.orderIndex);
      expect(roundTrip.createdAt,  base.createdAt);
    });

    test('fromMap uses defaults for missing optional fields', () {
      final map = {
        'id': 2,
        'folderId': 5,
        'name': 'img.png',
        'path': '/img.png',
        'createdAt': '2024-01-01T00:00:00.000',
      };
      final f = FileModel.fromMap(map);
      expect(f.size,       0);
      expect(f.orderIndex, 0);
    });

    test('copyWith overrides only specified fields', () {
      final copy = base.copyWith(name: 'renamed.pdf', size: 4096);
      expect(copy.name,       'renamed.pdf');
      expect(copy.size,       4096);
      expect(copy.folderId,   base.folderId);
      expect(copy.path,       base.path);
      expect(copy.orderIndex, base.orderIndex);
      expect(copy.createdAt,  base.createdAt);
    });

    test('equality is based on id', () {
      final a = base.copyWith(name: 'different.pdf');
      expect(a, equals(base)); // same id
    });

    test('different ids are not equal', () {
      final other = base.copyWith(id: 99);
      expect(other, isNot(equals(base)));
    });

    test('hashCode is based on id', () {
      final copy = base.copyWith(name: 'other.pdf');
      expect(copy.hashCode, base.hashCode);
    });
  });

  // ── FolderModel ────────────────────────────────────────────────────────────

  group('FolderModel', () {
    final base = FolderModel(
      id: 1,
      name: 'Work',
      color: 'ff6c63ff',
      isLocked: false,
      orderIndex: 0,
      createdAt: DateTime(2024, 1, 1),
    );

    test('toMap produces correct keys and values', () {
      final map = base.toMap();
      expect(map['id'],       1);
      expect(map['name'],     'Work');
      expect(map['color'],    'ff6c63ff');
      expect(map['isLocked'], 0);
      expect(map['orderIndex'], 0);
    });

    test('fromMap round-trips through toMap', () {
      final roundTrip = FolderModel.fromMap(base.toMap());
      expect(roundTrip.id,         base.id);
      expect(roundTrip.name,       base.name);
      expect(roundTrip.color,      base.color);
      expect(roundTrip.isLocked,   base.isLocked);
      expect(roundTrip.orderIndex, base.orderIndex);
      expect(roundTrip.createdAt,  base.createdAt);
    });

    test('isLocked round-trips as 1/0 integer', () {
      final locked = base.copyWith(isLocked: true);
      final map = locked.toMap();
      expect(map['isLocked'], 1);
      final restored = FolderModel.fromMap(map);
      expect(restored.isLocked, isTrue);
    });

    test('lastUnlockedAt round-trips (non-null)', () {
      final ts = DateTime(2024, 6, 15, 10, 30);
      final f  = base.copyWith(lastUnlockedAt: ts);
      final restored = FolderModel.fromMap(f.toMap());
      expect(restored.lastUnlockedAt, ts);
    });

    test('lastUnlockedAt round-trips (null)', () {
      final restored = FolderModel.fromMap(base.toMap());
      expect(restored.lastUnlockedAt, isNull);
    });

    test('copyWith overrides non-security fields', () {
      final copy = base.copyWith(name: 'Personal', color: 'ffff5733');
      expect(copy.name,  'Personal');
      expect(copy.color, 'ffff5733');
      expect(copy.id,    base.id);
    });

    test('copyWith preserves security fields unchanged', () {
      final withPin = FolderModel(
        id: 1,
        name: 'Secure',
        color: 'ff6c63ff',
        isLocked: true,
        pin: 'hashed_pin',
        pinHint: 'my hint',
        securityQuestion: 'Q?',
        securityAnswer: 'hashed_answer',
        createdAt: DateTime(2024, 1, 1),
      );
      final copy = withPin.copyWith(name: 'Renamed');
      expect(copy.pin,              withPin.pin);
      expect(copy.pinHint,          withPin.pinHint);
      expect(copy.securityQuestion, withPin.securityQuestion);
      expect(copy.securityAnswer,   withPin.securityAnswer);
    });

    test('equality is based on id', () {
      final other = base.copyWith(name: 'Different');
      expect(other, equals(base));
    });

    test('different ids are not equal', () {
      final other = FolderModel(
        id: 99,
        name: 'Work',
        color: 'ff6c63ff',
        createdAt: DateTime(2024, 1, 1),
      );
      expect(other, isNot(equals(base)));
    });

    test('hashCode matches for same id', () {
      final copy = base.copyWith(name: 'Other');
      expect(copy.hashCode, base.hashCode);
    });

    // ── Color helpers ────────────────────────────────────────────────────────

    test('toColor parses hex string correctly', () {
      // 'ff6c63ff' → alpha=ff, r=6c, g=63, b=ff
      final color = base.toColor();
      expect((color.a * 255.0).round(), 255);
    });

    test('toColor falls back to default for invalid hex', () {
      final bad = FolderModel(
        id: 2,
        name: 'Bad',
        color: 'not_a_color',
        createdAt: DateTime(2024, 1, 1),
      );
      expect(bad.toColor(), const Color(0xFF6C63FF));
    });

    test('colorToHex round-trips', () {
      const original = 'ff6c63ff';
      final folder   = FolderModel(id: 1, name: 'x', color: original, createdAt: DateTime(2024));
      final hex      = FolderModel.colorToHex(folder.toColor());
      expect(hex, original);
    });
  });
}
