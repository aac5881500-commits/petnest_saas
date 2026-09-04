// lib/core/models/pre_arrival_guide_model.dart
// 入住前準備：店家公告圖文，不是法律條款。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';

class PreArrivalGuideServiceType {
  PreArrivalGuideServiceType._();

  static const String accommodation = 'accommodation';
  static const String daycare = 'daycare';

  static bool isValid(String value) {
    return value == accommodation || value == daycare;
  }
}

class PreArrivalGuideBlockType {
  PreArrivalGuideBlockType._();

  static const String heading = 'heading';
  static const String text = 'text';
  static const String image = 'image';

  static bool isValid(String value) {
    return value == heading || value == text || value == image;
  }
}

class PreArrivalGuideBlock {
  const PreArrivalGuideBlock({
    required this.id,
    required this.type,
    this.text = '',
    this.imageUrl = '',
    this.storagePath = '',
    this.caption = '',
    this.sortOrder = 0,
  });

  final String id;
  final String type;
  final String text;
  final String imageUrl;
  final String storagePath;
  final String caption;
  final int sortOrder;

  bool get hasVisibleContent {
    if (type == PreArrivalGuideBlockType.image) {
      return imageUrl.trim().isNotEmpty || storagePath.trim().isNotEmpty;
    }
    return text.trim().isNotEmpty;
  }

  factory PreArrivalGuideBlock.fromMap(dynamic raw, {int fallbackOrder = 0}) {
    final Map<String, dynamic> map = SafeParse.parseMap(raw);
    final String type = SafeParse.parseString(map['type']);
    return PreArrivalGuideBlock(
      id: SafeParse.parseString(map['id']),
      type: PreArrivalGuideBlockType.isValid(type)
          ? type
          : PreArrivalGuideBlockType.text,
      text: SafeParse.parseString(map['text']),
      imageUrl: SafeParse.parseString(map['imageUrl']),
      storagePath: SafeParse.parseString(map['storagePath']),
      caption: SafeParse.parseString(map['caption']),
      sortOrder: SafeParse.parseMoney(
        map['sortOrder'],
        fallback: fallbackOrder,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'type': type,
      'text': text,
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'caption': caption,
      'sortOrder': sortOrder,
    };
  }

  PreArrivalGuideBlock copyWith({
    String? id,
    String? type,
    String? text,
    String? imageUrl,
    String? storagePath,
    String? caption,
    int? sortOrder,
  }) {
    return PreArrivalGuideBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      storagePath: storagePath ?? this.storagePath,
      caption: caption ?? this.caption,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class PreArrivalGuideModel {
  const PreArrivalGuideModel({
    required this.shopId,
    required this.serviceType,
    this.enabled = false,
    this.title = '入住前請準備',
    this.blocks = const <PreArrivalGuideBlock>[],
    this.inheritAccommodation = false,
    this.updatedAt,
    this.updatedBy = '',
  });

  final String shopId;
  final String serviceType;
  final bool enabled;
  final String title;
  final List<PreArrivalGuideBlock> blocks;
  final bool inheritAccommodation;
  final DateTime? updatedAt;
  final String updatedBy;

  String get displayTitle {
    final String value = title.trim();
    return value.isEmpty ? '入住前請準備' : value;
  }

  List<PreArrivalGuideBlock> get visibleBlocks {
    final List<PreArrivalGuideBlock> sorted =
        List<PreArrivalGuideBlock>.from(blocks)..sort(
          (PreArrivalGuideBlock a, PreArrivalGuideBlock b) =>
              a.sortOrder.compareTo(b.sortOrder),
        );
    return sorted
        .where((PreArrivalGuideBlock block) => block.hasVisibleContent)
        .toList();
  }

  bool get hasCustomerContent => enabled && visibleBlocks.isNotEmpty;

  factory PreArrivalGuideModel.empty({
    required String shopId,
    required String serviceType,
  }) {
    return PreArrivalGuideModel(
      shopId: shopId.trim(),
      serviceType: serviceType,
      title: '入住前請準備',
    );
  }

  factory PreArrivalGuideModel.fromMap({
    required String shopId,
    required String serviceType,
    Map<String, dynamic>? data,
  }) {
    final Map<String, dynamic> map = SafeParse.parseMap(data);
    final List<PreArrivalGuideBlock> blocks = <PreArrivalGuideBlock>[];
    final List<dynamic> rawBlocks = SafeParse.parseList(map['blocks']);
    for (int i = 0; i < rawBlocks.length; i++) {
      blocks.add(PreArrivalGuideBlock.fromMap(rawBlocks[i], fallbackOrder: i));
    }
    return PreArrivalGuideModel(
      shopId: shopId.trim(),
      serviceType: serviceType,
      enabled: SafeParse.parseBool(map['enabled']),
      title: SafeParse.parseString(map['title'], fallback: '入住前請準備'),
      blocks: blocks,
      inheritAccommodation: SafeParse.parseBool(map['inheritAccommodation']),
      updatedAt: SafeParse.parseDate(map['updatedAt']),
      updatedBy: SafeParse.parseString(map['updatedBy']),
    );
  }

  Map<String, dynamic> toMap({required String updatedBy}) {
    final List<PreArrivalGuideBlock> ordered = List<PreArrivalGuideBlock>.from(
      blocks,
    );
    for (int i = 0; i < ordered.length; i++) {
      ordered[i] = ordered[i].copyWith(sortOrder: i);
    }
    return <String, dynamic>{
      'shopId': shopId.trim(),
      'serviceType': serviceType,
      'enabled': enabled,
      'title': displayTitle,
      'blocks': ordered
          .map((PreArrivalGuideBlock block) => block.toMap())
          .toList(),
      'inheritAccommodation': inheritAccommodation,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
  }

  PreArrivalGuideModel copyWith({
    bool? enabled,
    String? title,
    List<PreArrivalGuideBlock>? blocks,
    bool? inheritAccommodation,
  }) {
    return PreArrivalGuideModel(
      shopId: shopId,
      serviceType: serviceType,
      enabled: enabled ?? this.enabled,
      title: title ?? this.title,
      blocks: blocks ?? this.blocks,
      inheritAccommodation: inheritAccommodation ?? this.inheritAccommodation,
      updatedAt: updatedAt,
      updatedBy: updatedBy,
    );
  }
}
