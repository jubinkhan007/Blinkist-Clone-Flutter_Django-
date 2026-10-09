import '../../explore/domain/catalog_models.dart';

class UserReadingListItem {
  final int id;
  final Book book;
  final int order;
  final String note;
  final DateTime? addedAt;

  const UserReadingListItem({
    required this.id,
    required this.book,
    required this.order,
    this.note = '',
    this.addedAt,
  });

  factory UserReadingListItem.fromJson(Map<String, dynamic> json) {
    return UserReadingListItem(
      id: json['id'] as int,
      book: Book.fromJson(json['book'] as Map<String, dynamic>),
      order: json['order'] as int? ?? 0,
      note: json['note'] as String? ?? '',
      addedAt: json['added_at'] != null
          ? DateTime.tryParse(json['added_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book': book.toJson(),
      'order': order,
      'note': note,
      'added_at': addedAt?.toIso8601String(),
    };
  }
}

class UserReadingList {
  final int id;
  final String title;
  final String description;
  final String emoji;
  final String colorHex;
  final bool isPublic;
  final String shareToken;
  final int? ownerId;
  final String? ownerName;
  final bool isOwner;
  final int itemsCount;
  final int totalEstimatedMinutes;
  final List<String> previewCovers;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<UserReadingListItem> items;

  const UserReadingList({
    required this.id,
    required this.title,
    this.description = '',
    this.emoji = '📚',
    this.colorHex = '#3B82F6',
    this.isPublic = false,
    required this.shareToken,
    this.ownerId,
    this.ownerName,
    this.isOwner = true,
    this.itemsCount = 0,
    this.totalEstimatedMinutes = 0,
    this.previewCovers = const [],
    this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  factory UserReadingList.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>?;
    final items = rawItems != null
        ? rawItems
            .map((item) =>
                UserReadingListItem.fromJson(item as Map<String, dynamic>))
            .toList()
        : <UserReadingListItem>[];

    final rawCovers = json['preview_covers'] as List<dynamic>?;
    final covers = rawCovers != null
        ? rawCovers.map((c) => c.toString()).toList()
        : <String>[];

    return UserReadingList(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Untitled Space',
      description: json['description'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '📚',
      colorHex: json['color_hex'] as String? ?? '#3B82F6',
      isPublic: json['is_public'] as bool? ?? false,
      shareToken: json['share_token'] as String? ?? '',
      ownerId: json['owner_id'] as int?,
      ownerName: json['owner_name'] as String?,
      isOwner: json['is_owner'] as bool? ?? true,
      itemsCount: json['items_count'] as int? ?? items.length,
      totalEstimatedMinutes: json['total_estimated_minutes'] as int? ?? 0,
      previewCovers: covers,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      items: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'emoji': emoji,
      'color_hex': colorHex,
      'is_public': isPublic,
      'share_token': shareToken,
      'owner_id': ownerId,
      'owner_name': ownerName,
      'is_owner': isOwner,
      'items_count': itemsCount,
      'total_estimated_minutes': totalEstimatedMinutes,
      'preview_covers': previewCovers,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'items': items.map((i) => i.toJson()).toList(),
    };
  }

  UserReadingList copyWith({
    int? id,
    String? title,
    String? description,
    String? emoji,
    String? colorHex,
    bool? isPublic,
    String? shareToken,
    int? ownerId,
    String? ownerName,
    bool? isOwner,
    int? itemsCount,
    int? totalEstimatedMinutes,
    List<String>? previewCovers,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<UserReadingListItem>? items,
  }) {
    return UserReadingList(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      colorHex: colorHex ?? this.colorHex,
      isPublic: isPublic ?? this.isPublic,
      shareToken: shareToken ?? this.shareToken,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      isOwner: isOwner ?? this.isOwner,
      itemsCount: itemsCount ?? this.itemsCount,
      totalEstimatedMinutes:
          totalEstimatedMinutes ?? this.totalEstimatedMinutes,
      previewCovers: previewCovers ?? this.previewCovers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }
}

class ReadingListMembership {
  final String bookSlug;
  final List<int> listIds;

  const ReadingListMembership({
    required this.bookSlug,
    required this.listIds,
  });

  factory ReadingListMembership.fromJson(Map<String, dynamic> json) {
    final rawIds = json['list_ids'] as List<dynamic>? ?? [];
    return ReadingListMembership(
      bookSlug: json['book_slug'] as String? ?? '',
      listIds: rawIds.map((id) => id as int).toList(),
    );
  }

  bool containsList(int listId) => listIds.contains(listId);
}
