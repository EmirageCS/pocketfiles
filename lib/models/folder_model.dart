import 'package:flutter/material.dart';

/// Represents a folder that groups files together.
class FolderModel {
  final int? id;
  final String name;
  final String color;
  final bool isLocked;
  final String? pin;
  final String? pinHint;
  final String? securityQuestion;
  final String? securityAnswer;
  final int orderIndex;
  final DateTime createdAt;
  final DateTime? lastUnlockedAt;

  FolderModel({
    this.id,
    required this.name,
    required this.color,
    this.isLocked = false,
    this.pin,
    this.pinHint,
    this.securityQuestion,
    this.securityAnswer,
    this.orderIndex = 0,
    required this.createdAt,
    this.lastUnlockedAt,
  });

  /// Returns a copy with the given non-security fields replaced.
  /// Security fields (pin, pinHint, securityQuestion, securityAnswer, salts)
  /// are preserved as-is and must be updated via [StorageService.updateFolderLock].
  FolderModel copyWith({
    int? id,
    String? name,
    String? color,
    bool? isLocked,
    int? orderIndex,
    DateTime? createdAt,
    DateTime? lastUnlockedAt,
  }) => FolderModel(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    isLocked: isLocked ?? this.isLocked,
    pin: pin,
    pinHint: pinHint,
    securityQuestion: securityQuestion,
    securityAnswer: securityAnswer,
    orderIndex: orderIndex ?? this.orderIndex,
    createdAt: createdAt ?? this.createdAt,
    lastUnlockedAt: lastUnlockedAt ?? this.lastUnlockedAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FolderModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id?.hashCode ?? Object.hash(name, color, createdAt);

  late final Color _cachedColor = _computeColor();

  Color toColor() => _cachedColor;

  Color _computeColor() {
    try {
      return Color(int.parse(color, radix: 16));
    } catch (e) {
      debugPrint('FolderModel.toColor: invalid hex "$color" — $e');
      return const Color(0xFF6C63FF);
    }
  }

  /// Converts a Flutter [Color] to the `ffrrggbb` hex format stored in the DB.
  static String colorToHex(Color color) {
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return 'ff$r$g$b';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'isLocked': isLocked ? 1 : 0,
      'pin': pin,
      'pinHint': pinHint,
      'securityQuestion': securityQuestion,
      'securityAnswer': securityAnswer,
      'orderIndex': orderIndex,
      'createdAt': createdAt.toIso8601String(),
      'lastUnlockedAt': lastUnlockedAt?.toIso8601String(),
    };
  }

  @override
  String toString() => 'FolderModel(id: $id, name: $name, isLocked: $isLocked)';

  factory FolderModel.fromMap(Map<String, dynamic> map) {
    return FolderModel(
      id: map['id'],
      name: map['name'],
      color: map['color'],
      isLocked: map['isLocked'] == 1,
      pin: map['pin'],
      pinHint: map['pinHint'],
      securityQuestion: map['securityQuestion'],
      securityAnswer: map['securityAnswer'],
      orderIndex: map['orderIndex'] ?? 0,
      createdAt: DateTime.parse(map['createdAt']),
      lastUnlockedAt: map['lastUnlockedAt'] != null
          ? DateTime.parse(map['lastUnlockedAt'] as String)
          : null,
    );
  }
}
