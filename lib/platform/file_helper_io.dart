import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';

Widget fileImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  Color? color,
  BlendMode? colorBlendMode,
  Widget? fallback,
}) {
  return Image.file(
    File(path),
    fit: fit,
    width: width,
    height: height,
    color: color,
    colorBlendMode: colorBlendMode,
    errorBuilder: (context, error, stackTrace) =>
        fallback ?? const SizedBox.shrink(),
  );
}

bool fileExists(String path) {
  if (path.isEmpty) return false;
  try {
    return File(path).existsSync();
  } catch (_) {
    return false;
  }
}

Future<bool> saveBytesToGallery(Uint8List bytes, String fileName) async {
  if (Platform.isIOS || Platform.isAndroid) {
    await Gal.putImageBytes(bytes, album: 'RoomCraft AI');
    return true;
  }

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    final location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: [
        const XTypeGroup(label: 'PNG image', extensions: ['png']),
      ],
    );

    if (location == null) return false;

    final file = File(location.path);
    await file.writeAsBytes(bytes);
    return true;
  }

  return false;
}
