import 'dart:io';

import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum StudyExportFormat { pdf, docx, text, share }

class StudyExportService {
  const StudyExportService._();

  static bool isAvailable(StudyExportFormat format) =>
      format == StudyExportFormat.text || format == StudyExportFormat.share;

  static String renderText(PersonalStudy study) {
    final buffer = StringBuffer()
      ..writeln(study.title.toUpperCase())
      ..writeln(study.type.label);
    if (study.primaryReference?.trim().isNotEmpty ?? false) {
      buffer.writeln('Texte : ${study.primaryReference}');
    }
    if (study.tags.isNotEmpty) {
      buffer.writeln('Tags : ${study.tags.join(', ')}');
    }
    buffer.writeln();
    for (final block in study.blocks) {
      if (block.type == StudyBlockType.heading) {
        buffer.writeln(block.plainText.toUpperCase());
      } else {
        buffer.writeln(block.plainText);
      }
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  static Future<File> exportText(PersonalStudy study) async {
    final directory = await getApplicationDocumentsDirectory();
    final safeTitle = study.title
        .replaceAll(RegExp(r'[^a-zA-Z0-9À-ÿ _-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final file = File(path.join(
      directory.path,
      '${safeTitle.isEmpty ? 'echo_etude' : safeTitle}.txt',
    ));
    return file.writeAsString(renderText(study), flush: true);
  }

  static Future<void> share(PersonalStudy study) async {
    await Share.share(renderText(study), subject: study.title);
  }
}
