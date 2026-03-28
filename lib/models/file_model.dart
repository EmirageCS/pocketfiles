// Files are physically copied to the app's documents directory on import.
class FileModel {
  final int? id;
  final int folderId;
  final String name;
  final String path; // absolute path on device storage
  final int size; // file size in bytes
  final int orderIndex; // user-defined sort order
  final DateTime createdAt;

  const FileModel({
    this.id,
    required this.folderId,
    required this.name,
    required this.path,
    this.size = 0,
    this.orderIndex = 0,
    required this.createdAt,
  });

  FileModel copyWith({
    int? id,
    int? folderId,
    String? name,
    String? path,
    int? size,
    int? orderIndex,
    DateTime? createdAt,
  }) => FileModel(
    id: id ?? this.id,
    folderId: folderId ?? this.folderId,
    name: name ?? this.name,
    path: path ?? this.path,
    size: size ?? this.size,
    orderIndex: orderIndex ?? this.orderIndex,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'folderId': folderId,
      'name': name,
      'path': path,
      'size': size,
      'orderIndex': orderIndex,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FileModel.fromMap(Map<String, dynamic> map) {
    return FileModel(
      id: map['id'],
      folderId: map['folderId'],
      name: map['name'],
      path: map['path'],
      size: map['size'] ?? 0,
      orderIndex: map['orderIndex'] ?? 0,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}