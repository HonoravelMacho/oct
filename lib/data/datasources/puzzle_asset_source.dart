import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/entities/puzzle.dart';

class PuzzleAssetSource {
  const PuzzleAssetSource();

  static List<Puzzle> parseJsonString(String raw) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw.isEmpty ? '[]' : raw);
    } on FormatException {
      return const [];
    }
    if (decoded is! List) return const [];
    final result = <Puzzle>[];
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        final pz = Puzzle.fromJsonMap(item);
        if (pz != null) result.add(pz);
      }
    }
    return result;
  }

  Future<List<Puzzle>> loadFreePuzzles() async {
    final raw = await rootBundle.loadString('assets/data/puzzles_free.json');
    return parseJsonString(raw);
  }
}
