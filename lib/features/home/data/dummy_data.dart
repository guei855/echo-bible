import 'package:flutter/material.dart';
import 'package:echo_bible/features/home/models/verse_model.dart';
import 'package:echo_bible/features/home/models/quick_action_model.dart';
import 'package:echo_bible/core/theme/app_colors.dart';

final Verse dailyVerse = const Verse(
  reference: 'Jean 3:16',
  text:
      '"Car Dieu a tant aimé le monde qu\'il a donné son Fils unique, afin que quiconque croit en lui ne périsse point, mais qu\'il ait la vie éternelle."',
);

final List<QuickActionModel> quickActions = [
  QuickActionModel(
    title: 'Lire la Bible',
    icon: Icons.book,
    iconColor: AppColors.primary,
    onTap: () {},
  ),
  QuickActionModel(
    title: 'Plans de lecture',
    icon: Icons.calendar_today,
    iconColor: AppColors.orange,
    onTap: () {},
  ),
  QuickActionModel(
    title: 'Favoris',
    icon: Icons.favorite,
    iconColor: AppColors.red,
    onTap: () {},
  ),
  QuickActionModel(
    title: 'Notes & Méditations',
    icon: Icons.edit_note,
    iconColor: AppColors.purple,
    onTap: () {},
  ),
];
