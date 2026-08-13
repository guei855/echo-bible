import 'package:echo_bible/core/services/search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchService.containsExactExpression', () {
    test('trouve le mot exact sans tenir compte de la casse', () {
      expect(
        SearchService.containsExactExpression("Dieu est Amour.", 'amour'),
        isTrue,
      );
    });

    test('ne confond pas un mot avec sa forme plurielle ou un mot composé', () {
      expect(
        SearchService.containsExactExpression('Biche des amours', 'amour'),
        isFalse,
      );
      expect(
        SearchService.containsExactExpression('Il était amoureux', 'amour'),
        isFalse,
      );
    });

    test('accepte une expression exacte entourée de ponctuation', () {
      expect(
        SearchService.containsExactExpression(
          'Il dit : Dieu créa les cieux.',
          'Dieu créa',
        ),
        isTrue,
      );
    });
  });
}
