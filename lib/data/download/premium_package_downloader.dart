import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../../domain/entities/puzzle.dart';
import '../datasources/puzzle_asset_source.dart';

enum DownloadPhase { idle, downloading, extracting, importing, done, error }

class DownloadState {
  const DownloadState({
    this.phase = DownloadPhase.idle,
    this.progress = 0,
    this.message = '',
    this.importedCount = 0,
  });

  final DownloadPhase phase;
  final double progress;
  final String message;
  final int importedCount;

  DownloadState copyWith({
    DownloadPhase? phase,
    double? progress,
    String? message,
    int? importedCount,
  }) =>
      DownloadState(
        phase: phase ?? this.phase,
        progress: progress ?? this.progress,
        message: message ?? this.message,
        importedCount: importedCount ?? this.importedCount,
      );
}

class PremiumPackageDownloader {
  PremiumPackageDownloader({
    required this.insertPuzzles,
    this.packageUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const String demoAssetPath = 'assets/data/puzzles_premium_demo.zip';

  final String? packageUrl;
  final http.Client _client;
  final Future<void> Function(List<Puzzle>) insertPuzzles;

  bool _cancelled = false;
  void cancel() => _cancelled = true;

  Stream<DownloadState> run() async* {
    _cancelled = false;
    try {
      Uint8List zipBytes;
      if (packageUrl == null || packageUrl!.isEmpty) {
        yield const DownloadState(
          phase: DownloadPhase.downloading,
          message: 'Pacote demonstracao (modo teste)',
        );
        zipBytes =
            (await rootBundle.load(demoAssetPath)).buffer.asUint8List();
        var i = 0;
        const steps = 12;
        while (i < steps && !_cancelled) {
          i++;
          yield DownloadState(
            phase: DownloadPhase.downloading,
            progress: i / steps,
            message: 'Baixando pacote premium...',
          );
          await Future<void>.delayed(const Duration(milliseconds: 220));
        }
      } else {
        zipBytes = Uint8List(0);
        final request = http.Request('GET', Uri.parse(packageUrl!));
        final response = await _client.send(request);
        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}');
        }
        final total = response.contentLength ?? 0;
        final builder = BytesBuilder(copy: false);
        var received = 0;
        await for (final chunk in response.stream) {
          if (_cancelled) throw Exception('cancelado');
          builder.add(chunk);
          received += chunk.length;
          yield DownloadState(
            phase: DownloadPhase.downloading,
            progress: total > 0 ? received / total : 0,
            message:
                'Baixando... ${(received / (1024 * 1024)).toStringAsFixed(1)} MB',
          );
        }
        zipBytes = builder.takeBytes();
      }

      if (_cancelled) throw Exception('cancelado');

      yield const DownloadState(
        phase: DownloadPhase.extracting,
        progress: 1,
        message: 'Descomprimindo pacote...',
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));

      final archive = ZipDecoder().decodeBytes(zipBytes);
      ArchiveFile? jsonFile;
      for (final file in archive) {
        if (file.name.endsWith('.json')) {
          jsonFile = file;
          break;
        }
      }
      if (jsonFile == null) {
        throw Exception('JSON nao encontrado no pacote');
      }
      final jsonRaw = utf8.decode(jsonFile.content as List<int>);
      final puzzles = PuzzleAssetSource.parseJsonString(jsonRaw)
          .map((pz) => Puzzle(
                id: pz.id,
                fen: pz.fen,
                movesUci: pz.movesUci,
                rating: pz.rating,
                themes: pz.themes,
                primaryTheme: pz.primaryTheme,
                premium: true,
              ))
          .toList();

      const chunkSize = 250;
      var imported = 0;
      for (var start = 0; start < puzzles.length; start += chunkSize) {
        if (_cancelled) throw Exception('cancelado');
        final end = (start + chunkSize).clamp(0, puzzles.length);
        await insertPuzzles(puzzles.sublist(start, end));
        imported = end;
        yield DownloadState(
          phase: DownloadPhase.importing,
          progress: puzzles.isEmpty ? 1 : imported / puzzles.length,
          message: 'Injetando no banco local...',
          importedCount: imported,
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }

      yield DownloadState(
        phase: DownloadPhase.done,
        progress: 1,
        message: 'Base premium ativada',
        importedCount: imported,
      );
    } catch (e) {
      yield DownloadState(
        phase: DownloadPhase.error,
        message: e.toString(),
      );
    }
  }
}
