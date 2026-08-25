import 'package:stockfish/stockfish.dart';

import 'chess_engine.dart';

Future<dynamic> createStockfishInstance() async {
  return stockfishAsync();
}

ChessEngine createStockfishEngine() {
  final engine = StockfishUciEngine();
  engine.bindFactory(createStockfishInstance);
  return engine;
}

ChessEngine createFallbackEngine() => LocalFallbackBot();
