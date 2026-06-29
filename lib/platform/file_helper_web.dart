import 'dart:typed_data';
import 'package:flutter/widgets.dart';

Widget fileImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  Color? color,
  BlendMode? colorBlendMode,
  Widget? fallback,
}) {
  return fallback ?? const SizedBox.shrink();
}

bool fileExists(String path) => false;

Future<bool> saveBytesToGallery(Uint8List bytes, String fileName) async {
  return false;
}
