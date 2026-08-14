import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:echo_bible/features/study/services/study_rich_text_codec.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  StudyBlock legacy(String text, {StudyBlockType type = StudyBlockType.text}) {
    final now = DateTime.now();
    return StudyBlock(
      id: 'legacy-${text.hashCode}',
      type: type,
      position: 0,
      payload: {'text': text},
      createdAt: now,
      updatedAt: now,
    );
  }

  test('migre les marqueurs V1 vers de vrais attributs Delta', () {
    final document = StudyRichTextCodec.documentFromBlock(
      legacy(
          '**gras** _italique_ <u>souligné</u> ~~barré~~ <mark>lumière</mark>'),
    );
    final operations = document.toDelta().toJson();

    expect(
        operations,
        contains(predicate<Map<String, dynamic>>((operation) =>
            operation['insert'] == 'gras' &&
            (operation['attributes'] as Map)['bold'] == true)));
    expect(
        operations,
        contains(predicate<Map<String, dynamic>>((operation) =>
            operation['insert'] == 'italique' &&
            (operation['attributes'] as Map)['italic'] == true)));
    expect(
        operations,
        contains(predicate<Map<String, dynamic>>((operation) =>
            operation['insert'] == 'souligné' &&
            (operation['attributes'] as Map)['underline'] == true)));
    expect(document.toPlainText(), isNot(contains('**')));
    expect(document.toPlainText(), isNot(contains('<mark>')));
  });

  test('préserve titres, citations, listes et couleurs dans le Delta', () {
    final blocks = StudyRichTextCodec.normalizeBlocks([
      legacy('Grand titre', type: StudyBlockType.heading),
      legacy('> Une citation'),
      legacy('• Premier\n1. Second\n<color=#B91C1C>Rouge</color>'),
    ]);
    final operations =
        StudyRichTextCodec.documentFromBlock(blocks.single).toDelta().toJson();
    final attributes = operations
        .where((operation) => operation['attributes'] != null)
        .map((operation) => operation['attributes'] as Map)
        .toList();

    expect(attributes.any((value) => value['header'] == 1), isTrue);
    expect(attributes.any((value) => value['blockquote'] == true), isTrue);
    expect(attributes.any((value) => value['list'] == 'bullet'), isTrue);
    expect(attributes.any((value) => value['list'] == 'ordered'), isTrue);
    expect(attributes.any((value) => value['color'] == '#B91C1C'), isTrue);
  });

  test('supporte un document de plus de 10 000 mots', () {
    final text = List.generate(10050, (index) => 'mot$index').join(' ');
    final document = Document()..insert(0, text);
    final payload = StudyRichTextCodec.payloadFromDocument(document);
    final restored = StudyRichTextCodec.documentFromBlock(
      legacy('').copyWith(payload: payload),
    );

    expect(restored.toPlainText().split(RegExp(r'\s+')).length,
        greaterThan(10000));
    expect(
        StudyRichTextCodec.plainTextFromPayload(payload), startsWith('mot0 '));
  });
}
