import 'package:flutter/material.dart';
import 'package:echo_bible/core/theme/app_colors.dart';

class EchoLoading extends StatelessWidget {
  final Color? color;

  const EchoLoading({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(color ?? AppColors.primary),
      ),
    );
  }
}
