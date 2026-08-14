import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

class StudyRichTextCodec {
  const StudyRichTextCodec._();

  static const format = 'quill_delta_v1';

  static bool isRichText(StudyBlock block) =>
      block.type == StudyBlockType.text && block.payload['format'] == format;

  static bool isLegacyText(StudyBlock block) =>
      block.type == StudyBlockType.text ||
      block.type == StudyBlockType.heading ||
      block.type == StudyBlockType.quote;

  static Document documentFromBlock(StudyBlock block) {
    final raw = block.payload['delta'];
    if (raw is List) {
      try {
        return Document.fromJson(
          raw
              .map((operation) => Map<String, dynamic>.from(operation as Map))
              .toList(),
        );
      } on Object {
        // Continue with the non-destructive V1 conversion below.
      }
    }
    return Document.fromJson(deltaForLegacyBlock(block));
  }

  static Map<String, Object?> payloadFromDocument(Document document) => {
        'format': format,
        'delta': document.toDelta().toJson(),
      };

  /// Inserts a structured block after the real Quill selection. When text is
  /// selected, [selection.end] is deliberately used so selected text is never
  /// deleted. The rich block is split and an empty/remaining rich block after
  /// the resource receives the caret on the next frame.
  static StudyBlockInsertionResult insertAtSelection({
    required List<StudyBlock> blocks,
    required String richBlockId,
    required TextSelection selection,
    required StudyBlockType type,
    required Map<String, Object?> payload,
    required DateTime now,
    required String idSeed,
  }) {
    final sourceIndex = blocks.indexWhere((block) => block.id == richBlockId);
    if (sourceIndex < 0 || !isRichText(blocks[sourceIndex])) {
      final fallback = [...blocks];
      final resource = StudyBlock(
        id: '$idSeed-resource',
        type: type,
        position: fallback.length,
        payload: payload,
        createdAt: now,
        updatedAt: now,
      );
      final continuation = emptyBlock(now, position: fallback.length + 1)
          .copyWith(updatedAt: now);
      fallback.addAll([resource, continuation]);
      return StudyBlockInsertionResult(
        blocks: _withPositions(fallback),
        insertedBlockId: resource.id,
        continuationBlockId: continuation.id,
      );
    }

    final source = blocks[sourceIndex];
    final delta = documentFromBlock(source).toDelta();
    final documentLength = delta.operations.fold<int>(
      0,
      (length, operation) => length + (operation.length ?? 0),
    );
    final maxContentOffset = (documentLength - 1).clamp(0, documentLength);
    final requestedOffset =
        selection.isValid ? selection.end : maxContentOffset;
    final offset = requestedOffset.clamp(0, maxContentOffset);
    final beforeDelta = _validDocumentDelta(delta.slice(0, offset));
    final afterDelta = _validDocumentDelta(delta.slice(offset));

    StudyBlock richPart(String suffix, dynamic part, int position) =>
        StudyBlock(
          id: '$idSeed-$suffix',
          type: StudyBlockType.text,
          position: position,
          payload: {
            'format': format,
            'delta': part.toJson(),
          },
          createdAt: source.createdAt,
          updatedAt: now,
        );

    final before = richPart('before', beforeDelta, sourceIndex);
    final resource = StudyBlock(
      id: '$idSeed-resource',
      type: type,
      position: sourceIndex + 1,
      payload: payload,
      createdAt: now,
      updatedAt: now,
    );
    final continuation = richPart('after', afterDelta, sourceIndex + 2);
    final result = [...blocks]
      ..removeAt(sourceIndex)
      ..insertAll(sourceIndex, [before, resource, continuation]);
    return StudyBlockInsertionResult(
      blocks: _withPositions(result),
      insertedBlockId: resource.id,
      continuationBlockId: continuation.id,
    );
  }

  static dynamic _validDocumentDelta(dynamic delta) {
    final lastData = delta.isEmpty ? null : delta.operations.last.data;
    if (lastData is! String || !lastData.endsWith('\n')) {
      delta.insert('\n');
    }
    return delta;
  }

  static List<StudyBlock> _withPositions(List<StudyBlock> blocks) => [
        for (var index = 0; index < blocks.length; index++)
          blocks[index].copyWith(position: index),
      ];

  static List<Map<String, dynamic>> deltaForLegacyBlock(StudyBlock block) {
    final operations = <Map<String, dynamic>>[];
    final text = block.payload['text'] as String? ?? '';
    final lines = text.split('\n');
    for (final line in lines) {
      final lineAttributes = <String, dynamic>{};
      var content = line;
      if (block.type == StudyBlockType.heading) {
        final level = block.payload['level'] as int? ?? 1;
        lineAttributes['header'] = level.clamp(1, 3);
      } else if (block.type == StudyBlockType.quote ||
          content.startsWith('> ')) {
        lineAttributes['blockquote'] = true;
        if (content.startsWith('> ')) content = content.substring(2);
      } else if (content.startsWith('• ')) {
        lineAttributes['list'] = 'bullet';
        content = content.substring(2);
      } else {
        final numbered = RegExp(r'^\d+\.\s+').firstMatch(content);
        if (numbered != null) {
          lineAttributes['list'] = 'ordered';
          content = content.substring(numbered.end);
        }
      }
      _appendInlineMarkup(operations, content);
      operations.add({
        'insert': '\n',
        if (lineAttributes.isNotEmpty) 'attributes': lineAttributes,
      });
    }
    if (operations.isEmpty || operations.last['insert'] != '\n') {
      operations.add({'insert': '\n'});
    }
    return operations;
  }

  static List<StudyBlock> normalizeBlocks(List<StudyBlock> source) {
    final normalized = <StudyBlock>[];
    var pendingOperations = <Map<String, dynamic>>[];
    StudyBlock? pendingOrigin;

    void flush() {
      if (pendingOrigin == null) return;
      if (pendingOperations.isEmpty ||
          pendingOperations.last['insert'] != '\n') {
        pendingOperations.add({'insert': '\n'});
      }
      normalized.add(pendingOrigin!.copyWith(
        type: StudyBlockType.text,
        position: normalized.length,
        payload: {
          'format': format,
          'delta': pendingOperations,
        },
        updatedAt: DateTime.now(),
      ));
      pendingOperations = <Map<String, dynamic>>[];
      pendingOrigin = null;
    }

    for (final block in source) {
      if (isLegacyText(block)) {
        pendingOrigin ??= block;
        final delta = isRichText(block)
            ? documentFromBlock(block).toDelta().toJson()
            : deltaForLegacyBlock(block);
        pendingOperations.addAll(
          delta.map((operation) => Map<String, dynamic>.from(operation)),
        );
      } else {
        flush();
        normalized.add(block.copyWith(position: normalized.length));
      }
    }
    flush();

    final now = DateTime.now();
    if (normalized.isEmpty || !isRichText(normalized.first)) {
      normalized.insert(0, emptyBlock(now, position: 0));
    }
    if (!isRichText(normalized.last)) {
      normalized.add(emptyBlock(now, position: normalized.length));
    }
    return [
      for (var index = 0; index < normalized.length; index++)
        normalized[index].copyWith(position: index),
    ];
  }

  static StudyBlock emptyBlock(DateTime now, {required int position}) =>
      StudyBlock(
        id: '${now.microsecondsSinceEpoch}-rich-$position',
        type: StudyBlockType.text,
        position: position,
        payload: const {
          'format': format,
          'delta': [
            {'insert': '\n'},
          ],
        },
        createdAt: now,
        updatedAt: now,
      );

  static String plainTextFromPayload(Map<String, Object?> payload) {
    final delta = payload['delta'];
    if (delta is! List) return payload['text'] as String? ?? '';
    final buffer = StringBuffer();
    for (final raw in delta) {
      if (raw is! Map) continue;
      final insert = raw['insert'];
      if (insert is String) buffer.write(insert);
    }
    return buffer.toString().replaceFirst(RegExp(r'\n$'), '').trimRight();
  }

  static void _appendInlineMarkup(
    List<Map<String, dynamic>> operations,
    String source,
  ) {
    final tokens = RegExp(
      r'(\*\*.*?\*\*|~~.*?~~|<u>.*?</u>|<mark>.*?</mark>|<color=#[0-9A-Fa-f]{6}>.*?</color>|(?<!_)_[^_]+_(?!_))',
    );
    var offset = 0;
    for (final match in tokens.allMatches(source)) {
      if (match.start > offset) {
        operations.add({'insert': source.substring(offset, match.start)});
      }
      final token = match.group(0)!;
      final attributes = <String, dynamic>{};
      late String clean;
      if (token.startsWith('**')) {
        clean = token.substring(2, token.length - 2);
        attributes['bold'] = true;
      } else if (token.startsWith('~~')) {
        clean = token.substring(2, token.length - 2);
        attributes['strike'] = true;
      } else if (token.startsWith('<u>')) {
        clean = token.substring(3, token.length - 4);
        attributes['underline'] = true;
      } else if (token.startsWith('<mark>')) {
        clean = token.substring(6, token.length - 7);
        attributes['background'] = '#FFF59D';
      } else if (token.startsWith('<color=')) {
        final close = token.indexOf('>');
        clean = token.substring(close + 1, token.length - 8);
        attributes['color'] = token.substring(7, close);
      } else {
        clean = token.substring(1, token.length - 1);
        attributes['italic'] = true;
      }
      operations.add({'insert': clean, 'attributes': attributes});
      offset = match.end;
    }
    if (offset < source.length) {
      operations.add({'insert': source.substring(offset)});
    }
  }
}

class StudyBlockInsertionResult {
  const StudyBlockInsertionResult({
    required this.blocks,
    required this.insertedBlockId,
    required this.continuationBlockId,
  });

  final List<StudyBlock> blocks;
  final String insertedBlockId;
  final String continuationBlockId;
}
