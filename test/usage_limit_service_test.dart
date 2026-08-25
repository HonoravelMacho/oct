import 'package:flutter_test/flutter_test.dart';
import 'package:oct/domain/services/usage_limit_service.dart';

void main() {
  late UsageLimitService service;
  late InMemoryCounterStore store;

  setUp(() {
    store = InMemoryCounterStore();
    service = UsageLimitService(store);
  });

  group('UsageLimitService', () {
    test('inicialização primeira vez concede ciclo cheio', () {
      service.initializeIfNeeded();
      expect(service.creditsRemaining, 5);
      expect(service.canStartActivity, isTrue);
    });

    test('segunda inicializacao nao reseta creditos gastos', () {
      service.initializeIfNeeded();
      service.consumeForGame();
      service.consumeForGame();
      service.initializeIfNeeded();
      expect(service.creditsRemaining, 3);
    });

    test('consumeForGame decrementa até zero e bloqueia', () {
      service.initializeIfNeeded();
      for (var i = 5; i > 0; i--) {
        expect(service.canStartActivity, isTrue);
        expect(service.consumeForGame(), isTrue);
      }
      expect(service.creditsRemaining, 0);
      expect(service.needsRewardToContinue, isTrue);
      expect(service.consumeForGame(), isFalse);
    });

    test('grantRewardCycle restaura 5 creditos', () {
      service.initializeIfNeeded();
      while (service.creditsRemaining > 0) {
        service.consumeForGame();
      }
      service.grantRewardCycle();
      expect(service.creditsRemaining, 5);
      expect(service.solvedInCurrentBlock, 0);
    });

    test('a cada 5 taticas resolvidas consome 1 credito', () {
      service.initializeIfNeeded();
      var consumed = false;
      for (var i = 1; i <= 5; i++) {
        consumed = service.onTacticSolved();
      }
      expect(consumed, isTrue);
      expect(service.creditsRemaining, 4);
      expect(service.solvedInCurrentBlock, 0);
    });

    test('taticas soltas acumulam bloco parcial', () {
      service.initializeIfNeeded();
      service.onTacticSolved();
      service.onTacticSolved();
      service.onTacticSolved();
      expect(service.solvedInCurrentBlock, 3);
      expect(service.creditsRemaining, 5);
    });
  });
}
