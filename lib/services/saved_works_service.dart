import 'dart:convert';
import '../models/project_details.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SavedWork {
  final ProjectDetails? project;
  final String imagePath;

  final String imageBase64;
  final String thumbnailBase64;

  final String style;
  final String mode;
  final String dateLabel;
  final String prompt;
  final String description;
  final String userId;
  final List<Map<String, dynamic>> placedItems;

  const SavedWork({
    required this.imagePath,
    this.project,
    this.imageBase64 = '',
    this.thumbnailBase64 = '',
    required this.style,
    required this.mode,
    required this.dateLabel,
    this.prompt = '',
    this.description = '',
    this.userId = '',
    this.placedItems = const [],
  });

  String get title =>
      project?.title ??
      (style.isNotEmpty
          ? '$style · $mode'
          : mode.isNotEmpty
          ? mode
          : 'Сохранённая работа');
  String get status => project?.status ?? 'ready';
  String get statusLabel => project?.statusLabel ?? 'Концепция готова';
  String get previewBase64 => thumbnailBase64.isNotEmpty
      ? thumbnailBase64
      : imageBase64.isNotEmpty
      ? imageBase64
      : project?.sourceImageBase64 ?? '';

  Map<String, dynamic> toMap({required String currentUserId}) {
    return {
      if (project != null) 'project': project!.toMap(),
      'imagePath': imagePath,
      'imageBase64': imageBase64,
      if (thumbnailBase64.isNotEmpty) 'thumbnailBase64': thumbnailBase64,
      'style': style,
      'mode': mode,
      'dateLabel': dateLabel,
      'prompt': prompt,
      'description': description,
      'userId': currentUserId,
      'placedItems': jsonEncode(_sanitizePlacedItems(placedItems)),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static List<Map<String, dynamic>> _sanitizePlacedItems(
    List<Map<String, dynamic>> items,
  ) {
    return items.map((item) {
      final clean = <String, dynamic>{};
      item.forEach((key, value) {
        if (value == null) return;
        if (key == 'imageBase64') return;
        if (value is num || value is bool || value is String) {
          clean[key] = value;
        } else {
          clean[key] = value.toString();
        }
      });
      return clean;
    }).toList();
  }

  static List<Map<String, dynamic>> _parsePlacedItems(dynamic raw) {
    if (raw == null) return [];

    List<dynamic> list;
    if (raw is String) {
      if (raw.isEmpty) return [];
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) return [];
        list = decoded;
      } catch (_) {
        return [];
      }
    } else if (raw is List) {
      list = raw;
    } else {
      return [];
    }

    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  factory SavedWork.fromMap(Map<String, dynamic> map) {
    return SavedWork(
      project: map['project'] is Map
          ? ProjectDetails.fromMap(
              Map<String, dynamic>.from(map['project'] as Map),
            )
          : null,
      imagePath: map['imagePath'] ?? '',
      imageBase64: map['imageBase64'] ?? '',
      thumbnailBase64: map['thumbnailBase64'] ?? '',
      style: map['style'] ?? '',
      mode: map['mode'] ?? '',
      dateLabel: map['dateLabel'] ?? '',
      prompt: map['prompt'] ?? '',
      description: map['description'] ?? '',
      userId: map['userId'] ?? '',
      placedItems: _parsePlacedItems(map['placedItems']),
    );
  }
}

class SavedWorkWithId {
  final String id;
  final SavedWork work;

  const SavedWorkWithId({required this.id, required this.work});
}

class SavedWorksService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static User? get _user => _auth.currentUser;

  static bool get isRegisteredUser {
    final user = _user;

    if (user == null) return false;
    if (user.isAnonymous) return false;

    return true;
  }

  static String? get _uid {
    if (!isRegisteredUser) return null;
    return _user?.uid;
  }

  static CollectionReference<Map<String, dynamic>>? get _worksRef {
    final uid = _uid;
    if (uid == null) return null;

    return _firestore.collection('users').doc(uid).collection('savedWorks');
  }

  static Future<List<SavedWork>> getWorks() async {
    final ref = _worksRef;
    if (ref == null) return [];

    final snapshot = await ref.orderBy('createdAt', descending: true).get();

    return snapshot.docs.map((doc) {
      return SavedWork.fromMap(doc.data());
    }).toList();
  }

  static Future<List<SavedWorkWithId>> getWorksWithIds() async {
    final ref = _worksRef;
    if (ref == null) return [];

    final snapshot = await ref.orderBy('createdAt', descending: true).get();

    return snapshot.docs.map((doc) {
      return SavedWorkWithId(id: doc.id, work: SavedWork.fromMap(doc.data()));
    }).toList();
  }

  static Stream<List<SavedWorkWithId>> getWorksStream() {
    final ref = _worksRef;

    if (ref == null) {
      return Stream.value([]);
    }

    return ref.orderBy('createdAt', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        return SavedWorkWithId(id: doc.id, work: SavedWork.fromMap(doc.data()));
      }).toList();
    });
  }

  static void _checkSize(Map<String, dynamic> data) {
    final measurable = {...data, 'createdAt': null, 'updatedAt': null};
    if (utf8
            .encode(
              jsonEncode(
                measurable,
                toEncodable: (value) => value is Timestamp
                    ? value.toDate().toIso8601String()
                    : value.toString(),
              ),
            )
            .length >
        850000) {
      throw StateError(
        'Изображение слишком большое для сохранения. Уменьшите фото.',
      );
    }
  }

  static Future<String> createProject(
    SavedWork work, {
    required String expectedUid,
    required String requestId,
  }) async {
    if (_uid != expectedUid) {
      throw StateError('Аккаунт изменился. Войдите снова.');
    }
    final ref = _worksRef;
    if (ref == null) {
      throw StateError('Войдите в аккаунт для сохранения проекта.');
    }
    final data = work.toMap(currentUserId: expectedUid);
    _checkSize(data);
    final doc = ref.doc(requestId);
    // Online transaction avoids indefinitely queued offline saves. A retry from
    // the same wizard keeps its ID and cannot create a duplicate project.
    await _firestore.runTransaction(
      (transaction) async {
        final existing = await transaction.get(doc);
        if (!existing.exists) transaction.set(doc, data);
      },
      timeout: const Duration(seconds: 20),
      maxAttempts: 3,
    );
    return doc.id;
  }

  /// Update only the result fields; keep the original brief, photo and createdAt.
  static Future<void> saveProjectResult(
    String id,
    SavedWork work, {
    required String expectedUid,
  }) async {
    if (_uid != expectedUid) {
      throw StateError('Аккаунт изменился. Войдите снова.');
    }
    final ref = _worksRef;
    if (ref == null) {
      throw StateError('Войдите в аккаунт для сохранения проекта.');
    }
    await _firestore.runTransaction((transaction) async {
      final doc = ref.doc(id);
      final snapshot = await transaction.get(doc);
      if (!snapshot.exists) {
        throw StateError('Проект удалён. Результат не сохранён.');
      }
      final data = projectResultUpdate(snapshot.data()!, work, expectedUid);
      transaction.update(doc, data);
    });
  }

  /// Pure serialization boundary, shared by the transaction and compatibility tests.
  static Map<String, dynamic> projectResultUpdate(
    Map<String, dynamic> previous,
    SavedWork work,
    String owner,
  ) {
    final data = work.toMap(currentUserId: owner)..remove('createdAt');
    data.remove('project');
    data['thumbnailBase64'] = work.thumbnailBase64;
    final metadata = previous['project'];
    if (metadata is Map) {
      data['project'] = {
        ...Map<String, dynamic>.from(metadata),
        'status': 'ready',
      };
    }
    data['updatedAt'] = FieldValue.serverTimestamp();
    _checkSize({...previous, ...data});
    return data;
  }

  static Future<void> saveWork(SavedWork work) async {
    final ref = _worksRef;
    final uid = _uid;

    if (ref == null || uid == null) return;

    final data = work.toMap(currentUserId: uid);
    _checkSize(data);
    await ref.add(data);
  }

  static Future<void> deleteWork(String workId) async {
    final ref = _worksRef;
    if (ref == null) return;

    await ref.doc(workId).delete();
  }

  static Future<void> deleteWorkAt(int index) async {
    final ref = _worksRef;
    if (ref == null) return;

    final snapshot = await ref.orderBy('createdAt', descending: true).get();

    if (index >= 0 && index < snapshot.docs.length) {
      await snapshot.docs[index].reference.delete();
    }
  }
}
