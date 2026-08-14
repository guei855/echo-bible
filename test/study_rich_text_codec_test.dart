import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:echo_bible/features/study/services/study_rich_text_codec.dart';
import 'package:flutter/material.dart';
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

  test('insère Jean 3:16 exactement entre AAA et BBB', () {
    final now = DateTime(2026, 8, 14);
    final source = StudyBlock(
      id: 'source',
      type: StudyBlockType.text,
      position: 0,
      payload: const {
        'format': 'quill_delta_v1',
        'delta': [
          {'insert': 'AAA\nBBB\n'},
        ],
      },
      createdAt: now,
      updatedAt: now,
    );

    final result = StudyRichTextCodec.insertAtSelection(
      blocks: [source],
      richBlockId: source.id,
      selection: const TextSelection.collapsed(offset: 4),
      type: StudyBlockType.verse,
      payload: const {'reference': 'Jean 3:16', 'text': 'Car Dieu…'},
      now: now,
      idSeed: 'insert-1',
    );

    expect(result.blocks.map((block) => block.plainText), [
      'AAA',
      'Jean 3:16\nCar Dieu…',
      'BBB',
    ]);
    expect(result.blocks.map((block) => block.position), [0, 1, 2]);
  });

  test('deux insertions conservent ordre, identités et sélection', () {
    final now = DateTime(2026, 8, 14);
    final source = StudyBlock(
      id: 'source',
      type: StudyBlockType.text,
      position: 0,
      payload: const {
        'format': 'quill_delta_v1',
        'delta': [
          {'insert': 'AAA\nBBB\nCCC\n'},
        ],
      },
      createdAt: now,
      updatedAt: now,
    );
    final first = StudyRichTextCodec.insertAtSelection(
      blocks: [source],
      richBlockId: source.id,
      selection: const TextSelection.collapsed(offset: 4),
      type: StudyBlockType.verse,
      payload: const {'reference': 'Genèse 1:1', 'text': 'Au commencement…'},
      now: now,
      idSeed: 'genesis',
    );
    final second = StudyRichTextCodec.insertAtSelection(
      blocks: first.blocks,
      richBlockId: first.continuationBlockId,
      selection: const TextSelection(baseOffset: 0, extentOffset: 4),
      type: StudyBlockType.strong,
      payload: const {
        'code': 'G3056',
        'originalWord': 'λόγος',
        'definition': 'Parole',
      },
      now: now.add(const Duration(seconds: 1)),
      idSeed: 'logos',
    );

    expect(second.blocks.map((block) => block.plainText), [
      'AAA',
      'Genèse 1:1\nAu commencement…',
      'BBB',
      'G3056 λόγος\nParole',
      'CCC',
    ]);
    expect(second.blocks.map((block) => block.id).toSet().length,
        second.blocks.length);
    expect(
      StudyRichTextCodec.documentFromBlock(second.blocks.last).toPlainText(),
      'CCC\n',
    );
  });
}
