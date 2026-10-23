import 'package:firebase_auth/firebase_auth.dart';
import 'saved_works_service.dart';

/// One persistence boundary, backed by the existing savedWorks service.
abstract class WorkspaceRepository {
  String? get userId;
  String get userLabel;
  Stream<String?> get userChanges;
  Stream<List<SavedWorkWithId>> watchWorks();
  Future<String> create(SavedWork work, {required String requestId});
  Future<void> delete(String id);
}

class FirebaseWorkspaceRepository implements WorkspaceRepository {
  final FirebaseAuth _auth;
  final String? _ownerId;
  FirebaseWorkspaceRepository()
    : _auth = FirebaseAuth.instance,
      _ownerId = FirebaseAuth.instance.currentUser?.uid;

  @override
  String? get userId {
    final user = _auth.currentUser;
    return user == null || user.isAnonymous ? null : user.uid;
  }

  @override
  String get userLabel =>
      _auth.currentUser?.email?.split('@').first ?? 'Дизайнер';
  @override
  Stream<String?> get userChanges => _auth.authStateChanges().map(
    (user) => user == null || user.isAnonymous ? null : user.uid,
  );
  void _checkOwner() {
    if (userId == null || userId != _ownerId) {
      throw StateError('Войдите в аккаунт снова.');
    }
  }

  @override
  Stream<List<SavedWorkWithId>> watchWorks() {
    _checkOwner();
    return SavedWorksService.getWorksStream();
  }

  @override
  Future<String> create(SavedWork work, {required String requestId}) async {
    _checkOwner();
    return SavedWorksService.createProject(
      work,
      expectedUid: _ownerId!,
      requestId: requestId,
    );
  }

  @override
  Future<void> delete(String id) async {
    _checkOwner();
    await SavedWorksService.deleteWork(id);
  }
}
