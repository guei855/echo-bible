import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:echo_bible/features/study/services/study_rich_text_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sérialise et restaure tous les formats V1.1', () {
    final now = DateTime.now();
    const delta = <Map<String, dynamic>>[
      {
        'insert': 'gras',
        'attributes': {'bold': true}
      },
      {
        'insert': ' italique',
        'attributes': {'italic': true}
      },
      {
        'insert': ' souligné',
        'attributes': {'underline': true}
      },
      {
        'insert': ' barré',
        'attributes': {'strike': true}
      },
      {
        'insert': ' grand rouge surligné',
        'attributes': {
          'size': 'large',
          'color': '#B91C1C',
          'background': '#FFF59D',
        }
      },
      {
        'insert': '\n',
        'attributes': {'align': 'center'}
      },
      {
        'insert': 'puce\n',
        'attributes': {'list': 'bullet', 'indent': 1}
      },
      {
        'insert': 'numéro\n',
        'attributes': {'list': 'ordered'}
      },
      {
        'insert': 'citation\n',
        'attributes': {'blockquote': true}
      },
      {
        'insert': 'titre\n',
        'attributes': {'header': 2}
      },
    ];
    final block = StudyBlock(
      id: 'formats',
      type: StudyBlockType.text,
      position: 0,
      payload: const {
        'format': 'quill_delta_v1',
        'delta': delta,
      },
      createdAt: now,
      updatedAt: now,
    );

    final document = StudyRichTextCodec.documentFromBlock(block);
    final persisted = StudyRichTextCodec.payloadFromDocument(document);
    final restored = StudyRichTextCodec.documentFromBlock(
      block.copyWith(payload: persisted),
    );

    expect(restored.toDelta().toJson(), delta);
    expect(restored.toPlainText(), contains('gras italique souligné barré'));
    expect(restored.toPlainText(), isNot(contains('**')));
  });

  test('annuler et rétablir conservent le contenu riche', () {
    final controller = QuillController.basic();
    controller.replaceText(
      0,
      0,
      'foi',
      const TextSelection.collapsed(offset: 3),
    );
    controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 3),
      ChangeSource.local,
    );
    controller.formatSelection(Attribute.bold);
    expect(controller.hasUndo, isTrue);
    controller.undo();
    expect(controller.hasRedo, isTrue);
    controller.redo();
    expect(controller.document.toPlainText(), contains('foi'));
    controller.dispose();
  });
}
