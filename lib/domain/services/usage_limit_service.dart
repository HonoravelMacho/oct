abstract class CounterStore {
  int read(String key);
  void write(String key, int value);
}

class InMemoryCounterStore implements CounterStore {
  final Map<String, int> _data = {};

  @override
  int read(String key) => _data[key] ?? 0;

  @override
  void write(String key, int value) => _data[key] = value;
}

class UsageLimitService {
  UsageLimitService(
    this._store, {
    this.freeCycleLimit = 5,
    this.tacticsPerCredit = 5,
  });

  final CounterStore _store;
  final int freeCycleLimit;
  final int tacticsPerCredit;

  static const String keyCredits = 'usage_credits';
  static const String keySolvedInBlock = 'usage_solved_block';

  int get creditsRemaining => _store.read(keyCredits);

  int get solvedInCurrentBlock => _store.read(keySolvedInBlock);

  bool get canStartActivity => creditsRemaining > 0;

  bool get needsRewardToContinue => creditsRemaining <= 0;

  void initializeIfNeeded() {
    if (_store.read(keyCredits) <= 0 && solvedInCurrentBlock == 0) {
      final raw = _store.read('usage_ever_initialized');
      if (raw == 0) {
        _store.write(keyCredits, freeCycleLimit);
        _store.write('usage_ever_initialized', 1);
      }
    }
  }

  bool consumeForGame() {
    if (creditsRemaining <= 0) return false;
    _store.write(keyCredits, creditsRemaining - 1);
    return true;
  }

  bool onTacticSolved() {
    final solved = solvedInCurrentBlock + 1;
    _store.write(keySolvedInBlock, solved % tacticsPerCredit);
    if (solved % tacticsPerCredit == 0 && creditsRemaining > 0) {
      _store.write(keyCredits, creditsRemaining - 1);
      return true;
    }
    return false;
  }

  void grantRewardCycle() {
    _store.write(keyCredits, freeCycleLimit);
    _store.write(keySolvedInBlock, 0);
  }
}
