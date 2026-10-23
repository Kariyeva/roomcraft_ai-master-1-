import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:roomcraft_ai/models/project_details.dart';
import 'package:roomcraft_ai/services/project_photo_service.dart';
import 'package:roomcraft_ai/services/saved_works_service.dart';

void main() {
  test('Legacy works and JSON overlays remain readable', () {
    final work = SavedWork.fromMap({
      'imagePath': 'old.png',
      'style': 'Modern',
      'mode': 'Ручной режим',
      'placedItems': '[{"title":"Стол","x":0.2}]',
    });
    expect(work.project, isNull);
    expect(work.status, 'ready');
    expect(work.placedItems.single['title'], 'Стол');
    final serialized = work.toMap(currentUserId: 'owner');
    expect(serialized.containsKey('project'), false);
    expect(serialized['userId'], 'owner');
    expect(SavedWork.fromMap(serialized).placedItems.single['x'], 0.2);
  });
  test('New project metadata round trips through existing SavedWork', () {
    final work = SavedWork(
      imagePath: '',
      style: 'Zen',
      mode: 'Проект',
      dateLabel: '18.10.2026',
      project: const ProjectDetails(
        title: 'Дом',
        roomType: 'Кабинет',
        area: 23.5,
        budget: 100000,
        palette: 'Ivory',
        sourceImageBase64: 'cGhvdG8=',
      ),
    );
    final restored = SavedWork.fromMap(work.toMap(currentUserId: 'owner'));
    expect(restored.title, 'Дом');
    expect(restored.status, 'draft');
    expect(restored.project!.budget, 100000);
    expect(restored.previewBase64, 'cGhvdG8=');
    expect(restored.project!.toMap()['currency'], 'KZT');
  });
  test(
    'Saving a result retains source, title and createdAt; does not create another project',
    () {
      const source = ProjectDetails(
        title: 'Дом',
        interiorStyle: 'Modern',
        roomType: 'Кухня',
        area: 18,
        sourceImageBase64: 'cGhvdG8=',
      );
      final previous = <String, dynamic>{
        'project': source.toMap(),
        'createdAt': 'original-date',
        'userId': 'owner',
      };
      const result = SavedWork(
        imagePath: 'https://example.com/result.jpg',
        imageBase64: 'cmVzdWx0',
        style: 'Ручной режим',
        mode: 'Ручной режим',
        dateLabel: 'today',
      );
      final update = SavedWorksService.projectResultUpdate(
        previous,
        result,
        'owner',
      );
      final merged = {...previous, ...update};
      expect(merged['createdAt'], 'original-date');
      final metadata = ProjectDetails.fromMap(
        merged['project'] as Map<String, dynamic>,
      );
      expect(metadata.title, 'Дом');
      expect(metadata.interiorStyle, 'Modern');
      expect(metadata.sourceImageBase64, 'cGhvdG8=');
      expect(metadata.status, 'ready');
      expect(update['imagePath'], result.imagePath);
      expect(update.containsKey('createdAt'), false);
    },
  );
  test('Oversize documents are rejected before Firestore write', () {
    final result = SavedWork(
      imagePath: '',
      imageBase64: 'a' * 900000,
      style: '',
      mode: '',
      dateLabel: '',
    );
    expect(
      () => SavedWorksService.projectResultUpdate({}, result, 'owner'),
      throwsStateError,
    );
  });
  test('Photo validates file content and bounds', () async {
    await expectLater(
      ProjectPhotoService.prepare(Uint8List.fromList([1, 2]), 'room.jpg'),
      throwsFormatException,
    );
    await expectLater(
      ProjectPhotoService.prepare(Uint8List(0), 'room.png'),
      throwsFormatException,
    );
    await expectLater(
      ProjectPhotoService.prepare(
        Uint8List(ProjectPhotoService.maxInputBytes + 1),
        'room.jpg',
      ),
      throwsFormatException,
    );
    await expectLater(
      ProjectPhotoService.prepare(Uint8List.fromList([1]), 'room.gif'),
      throwsFormatException,
    );
    final bytes = img.encodePng(img.Image(width: 1800, height: 100));
    final normalized = await ProjectPhotoService.prepare(bytes, 'room.png');
    final decoded = img.decodeJpg(normalized)!;
    expect(decoded.width, 1600);
    expect(normalized.length, lessThanOrEqualTo(220000));
    expect(base64Decode(base64Encode(normalized)), normalized);
  });
}
