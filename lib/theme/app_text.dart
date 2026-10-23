import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppText {
  static const display = TextStyle(
    fontFamily: 'Lora',
    fontSize: 64,
    height: 1.12,
    letterSpacing: -2.5,
    fontWeight: FontWeight.w400,
    color: AppColors.charcoal,
  );
  static const heading = TextStyle(
    fontFamily: 'Lora',
    fontSize: 38,
    height: 1.2,
    letterSpacing: -1,
    color: AppColors.charcoal,
  );
  static const label = TextStyle(
    fontSize: 10,
    letterSpacing: 2.2,
    height: 1.6,
    fontWeight: FontWeight.w600,
    color: AppColors.stone,
  );
  static const body = TextStyle(
    fontSize: 15,
    height: 1.65,
    color: AppColors.stone,
  );
}
