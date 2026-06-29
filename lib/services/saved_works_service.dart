import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SavedWork {
  final String imagePath;

  final String imageBase64;

  final String style;
  final String mode;
  final String dateLabel;
  final String prompt;
  final String description;
  final String userId;
  final List<Map<String, dynamic>> placedItems;

  const SavedWork({
    required this.imagePath,
    this.imageBase64 = '',
    required this.style,
    required this.mode,
    required this.dateLabel,
    this.prompt = '',
    this.description = '',
    this.userId = '',
    this.placedItems = const [],
  });

  Map<String, dynamic> toMap({required String currentUserId}) {
    return {
      'imagePath': imagePath,
      'imageBase64': imageBase64,
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

    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  factory SavedWork.fromMap(Map<String, dynamic> map) {
    return SavedWork(
      imagePath: map['imagePath'] ?? '',
      imageBase64: map['imageBase64'] ?? '',
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

  static Future<void> saveWork(SavedWork work) async {
    final ref = _worksRef;
    final uid = _uid;

    if (ref == null || uid == null) return;

    await ref.add(work.toMap(currentUserId: uid));
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
