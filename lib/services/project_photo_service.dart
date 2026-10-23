import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

abstract final class ProjectPhotoService {
  static const maxInputBytes = 10 * 1024 * 1024;
  static Future<Uint8List> prepare(Uint8List bytes, String filename) async {
    final extension = filename.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png'].contains(extension)) {
      throw const FormatException('Выберите фотографию JPG или PNG.');
    }
    if (bytes.isEmpty || bytes.length > maxInputBytes) {
      throw const FormatException('Фотография должна быть не больше 10 МБ.');
    }
    try {
      return await compute(_compressPhoto, bytes);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Фотография повреждена или имеет неподдерживаемый формат.',
      );
    }
  }
}

Uint8List _compressPhoto(Uint8List bytes) {
  final decoder = img.findDecoderForData(bytes);
  if (decoder is! img.JpegDecoder && decoder is! img.PngDecoder) {
    throw const FormatException('Содержимое файла должно быть JPG или PNG.');
  }
  final info = decoder!.startDecode(bytes);
  if (info == null || info.width * info.height > 24000000) {
    throw const FormatException(
      'Не удалось прочитать фото или разрешение больше 24 Мп.',
    );
  }
  final decoded = decoder.decodeFrame(0);
  if (decoded == null) throw const FormatException('Фотография повреждена.');
  var photo = img.bakeOrientation(decoded);
  if (photo.width > 1600 || photo.height > 1600) {
    photo = img.copyResize(
      photo,
      width: photo.width >= photo.height ? 1600 : null,
      height: photo.height > photo.width ? 1600 : null,
    );
  }
  for (final quality in [85, 72, 58]) {
    final result = img.encodeJpg(photo, quality: quality);
    if (result.length <= 220000) return result;
  }
  photo = img.copyResize(
    photo,
    width: photo.width >= photo.height ? 900 : null,
    height: photo.height > photo.width ? 900 : null,
  );
  final result = img.encodeJpg(photo, quality: 65);
  if (result.length > 220000) {
    throw const FormatException(
      'Фото слишком детализированное. Выберите изображение меньшего размера.',
    );
  }
  return result;
}
