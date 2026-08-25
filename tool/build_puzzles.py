#!/usr/bin/env python3
"""
OCT - Gerador de base de taticas a partir da database publica do Lichess.

Baixa (ou le localmente) lichess_db_puzzle.csv.zst, filtra por rating,
popularidade e temas, e produz:
  1. assets/data/puzzles_free.json        (~20k taticas gratuitas balanceadas por tema)
  2. assets/data/puzzles_premium_demo.zip (amostra demonstrativa para testar o fluxo premium)

Uso:
  python3 tool/build_puzzles.py
  python3 tool/build_puzzles.py --csv /tmp/lichess_db_puzzle.csv.zst --count 20000

Fonte oficial: https://database.lichess.org/#puzzles (licenca CC-BY-SA)
"""

import argparse
import csv
import io
import json
import os
import random
import subprocess
import sys
import zipfile
from collections import defaultdict

LICHESS_URL = "https://database.lichess.org/lichess_db_puzzle.csv.zst"

PRIORITY_THEMES = [
    "underPromotion", "smotheredMate", "backRankMate",
    "mateIn1", "mateIn2", "mateIn3", "mateIn4", "mateIn5",
    "doubleCheck", "discoveredAttack", "fork", "pin", "skewer",
    "hangingPiece", "sacrifice", "deflection", "attraction",
    "trappingPiece", "quietMove", "interception", "clearance",
    "promotion", "advancedPawn", "kingsideAttack", "queensideAttack",
    "enPassant", "castling", "zugzwang", "stalemate",
    "rookEndgame", "pawnEndgame", "bishopEndgame", "queenEndgame",
    "knightEndgame", "crushing", "endgame", "middlegame", "opening", "master",
]

THEME_LABELS_PT = {
    "underPromotion": "Sub-promocao", "smotheredMate": "Mate sufocado",
    "backRankMate": "Mate ultima fileira", "mateIn1": "Mate em 1",
    "mateIn2": "Mate em 2", "mateIn3": "Mate em 3", "mateIn4": "Mate em 4",
    "mateIn5": "Mate em 5", "doubleCheck": "Xeque duplo",
    "discoveredAttack": "Ataque a descoberta", "fork": "Garfo",
    "pin": "Cravada", "skewer": "Espeto", "hangingPiece": "Peca pendurada",
    "sacrifice": "Sacrificio", "deflection": "Desvio", "attraction": "Atracao",
    "trappingPiece": "Peca presa", "quietMove": "Lance silencioso",
    "interception": "Interceptacao", "clearance": "Liberacao de casa",
    "promotion": "Promocao", "advancedPawn": "Peao avancado",
    "kingsideAttack": "Ataque no rei", "queensideAttack": "Ataque na dama",
    "enPassant": "En passant", "castling": "Roque", "zugzwang": "Zugzwang",
    "stalemate": "Afogamento", "rookEndgame": "Finais de torre",
    "pawnEndgame": "Finais de peao", "bishopEndgame": "Finais de bispo",
    "queenEndgame": "Finais de dama", "knightEndgame": "Finais de cavalo",
    "crushing": "Vantagem decisiva", "endgame": "Finais",
    "middlegame": "Meio-jogo", "opening": "Aberturas", "master": "Mestres",
}


def primary_theme(themes_csv):
    themes = themes_csv.split(",")
    for p in PRIORITY_THEMES:
        if p in themes:
            return p
    return themes[0] if themes else "misc"


def open_stream(csv_path):
    if csv_path.endswith(".zst"):
        proc = subprocess.Popen(
            ["zstdcat", csv_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        return io.TextIOWrapper(proc.stdout, encoding="utf-8", errors="replace")
    return open(csv_path, encoding="utf-8", errors="replace")


def ensure_csv(path):
    if path and os.path.exists(path):
        print(f"[ok] usando arquivo local: {path}")
        return path
    dest = path or "/tmp/opencode/lichess_db_puzzle.csv.zst"
    if os.path.exists(dest) and os.path.getsize(dest) > 300_000_000:
        print(f"[ok] download anterior completo: {dest}")
        return dest
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    print(f"[..] baixando base Lichess -> {dest}")
    rc = subprocess.call(["curl", "-sL", "--retry", "3", "-o", dest, LICHESS_URL])
    if rc != 0:
        sys.exit(f"ERRO: falha ao baixar {LICHESS_URL}")
    return dest


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default=None)
    ap.add_argument("--count", type=int, default=20000)
    ap.add_argument("--demo-count", type=int, default=400)
    ap.add_argument("--min-rating", type=int, default=600)
    ap.add_argument("--max-rating", type=int, default=2300)
    ap.add_argument("--min-popularity", type=int, default=90)
    ap.add_argument(
        "--out-json", default="assets/data/puzzles_free.json")
    ap.add_argument(
        "--out-demo-zip", default="assets/data/puzzles_premium_demo.zip")
    args = ap.parse_args()

    random.seed(20260825)

    csv_path = ensure_csv(args.csv)
    quota_per_theme = max(1, args.count // len(PRIORITY_THEMES))

    buckets = defaultdict(list)
    demo_pool = []

    total_seen = 0
    with open_stream(csv_path) as stream:
        reader = csv.reader(stream)
        header = next(reader)
        idx = {name: i for i, name in enumerate(header)}
        for row in reader:
            total_seen += 1
            if len(row) < len(header):
                continue
            try:
                rating = int(row[idx["Rating"]])
                popularity = int(row[idx["Popularity"]])
                nbplays = int(row[idx["NbPlays"]])
            except ValueError:
                continue
            if not (args.min_rating <= rating <= args.max_rating):
                continue
            if popularity < args.min_popularity or nbplays < 50:
                continue

            fen = row[idx["FEN"]]
            moves = row[idx["Moves"]]
            puzzle_id = row[idx["PuzzleId"]]
            themes = row[idx["Themes"]]
            theme = primary_theme(themes)
            bucket = buckets[theme]

            if len(bucket) < quota_per_theme * 3:
                bucket.append({
                    "id": puzzle_id,
                    "fen": fen,
                    "moves": moves,
                    "rating": rating,
                    "popularity": popularity,
                    "themes": themes,
                })
            elif random.random() < 0.02:
                bucket[random.randrange(len(bucket))] = {
                    "id": puzzle_id,
                    "fen": fen,
                    "moves": moves,
                    "rating": rating,
                    "popularity": popularity,
                    "themes": themes,
                }

            if rating >= 2350 and len(demo_pool) < 4000:
                demo_pool.append({
                    "id": puzzle_id,
                    "fen": fen,
                    "moves": moves,
                    "rating": rating,
                    "themes": themes,
                    "tier": "premium",
                })

            if total_seen % 500_000 == 0:
                print(f"[..] processados {total_seen:,} puzzles...")

    selected = []
    stats = {}
    for theme in PRIORITY_THEMES:
        pool = buckets.get(theme, [])
        random.shuffle(pool)
        take = pool[:quota_per_theme]
        stats[theme] = len(take)
        for item in take:
            selected.append({
                "id": item["id"],
                "fen": item["fen"],
                "moves": item["moves"],
                "rating": item["rating"],
                "themes": item["themes"].split(","),
            })

    if len(selected) > args.count:
        random.shuffle(selected)
        selected = selected[: args.count]

    print("\n=== DISTRIBUICAO POR TEMA ===")
    for theme, n in sorted(stats.items(), key=lambda x: -x[1]):
        label = THEME_LABELS_PT.get(theme, theme)
        print(f"  {label:<24} {n:>6}")

    os.makedirs(os.path.dirname(args.out_json) or ".", exist_ok=True)
    with open(args.out_json, "w", encoding="utf-8") as f:
        json.dump(selected, f, ensure_ascii=False, separators=(",", ":"))
    size_mb = os.path.getsize(args.out_json) / (1024 * 1024)
    print(f"\n[ok] {len(selected):,} taticas -> {args.out_json} ({size_mb:.1f} MB)")

    random.shuffle(demo_pool)
    demo = demo_pool[: args.demo_count]
    os.makedirs(os.path.dirname(args.out_demo_zip) or ".", exist_ok=True)
    with zipfile.ZipFile(args.out_demo_zip, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        zf.writestr("puzzles_premium.json",
                    json.dumps(demo, ensure_ascii=False, separators=(",", ":")))
    size_kb = os.path.getsize(args.out_demo_zip) / 1024
    print(f"[ok] demo premium ({len(demo)} taticas) -> {args.out_demo_zip} ({size_kb:.1f} KB)")
    print("[ok] concluido.")


if __name__ == "__main__":
    main()
