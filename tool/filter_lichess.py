#!/usr/bin/env python3
"""Filtra a base real do Lichess em 20k táticas gratuitas + demo premium.

Verifica legalidade (FEN + 1º lance) com python-chess. Uso:
  python3 tool/filter_lichess.py
Saída: assets/data/puzzles_free.json + assets/data/puzzles_premium_demo.zip
"""
import csv
import io
import json
import os
import random
import subprocess
import sys
import zipfile
from collections import defaultdict

SRC = "/tmp/opencode/lichess_db_puzzle.csv.zst"
OUT_JSON = "assets/data/puzzles_free.json"
OUT_DEMO = "assets/data/puzzles_premium_demo.zip"
COUNT = 20000
DEMO_COUNT = 400

PRIORITY = [
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
THEMES = set(PRIORITY)

import chess

def primary(themes_csv):
    ts = themes_csv.replace(",", " ").split()
    for p in PRIORITY:
        if p in ts:
            return p
    return ""

def legal(fen, moves):
    try:
        board = chess.Board(fen)
    except ValueError:
        return False
    if not moves:
        return False
    try:
        mv = chess.Move.from_uci(moves[0])
    except ValueError:
        return False
    return mv in board.legal_moves

def main():
    random.seed(20260908)
    quota = COUNT // len(PRIORITY)
    buckets = defaultdict(list)
    demo_pool = []
    seen = 0
    kept = 0
    proc = subprocess.Popen(["zstdcat", SRC], stdout=subprocess.PIPE,
                            stderr=subprocess.DEVNULL)
    stream = io.TextIOWrapper(proc.stdout, encoding="utf-8", errors="replace")
    reader = csv.reader(stream)
    header = next(reader)
    idx = {n: i for i, n in enumerate(header)}
    for row in reader:
        seen += 1
        if len(row) < len(header):
            continue
        try:
            rating = int(row[idx["Rating"]])
            pop = int(row[idx["Popularity"]])
            nb = int(row[idx["NbPlays"]])
        except ValueError:
            continue
        if not (600 <= rating <= 2300):
            continue
        if pop < 90 or nb < 50:
            continue
        fen = row[idx["FEN"]]
        moves = row[idx["Moves"]].split()
        if not legal(fen, moves):
            continue
        if 2350 <= rating <= 2800:
            if len(demo_pool) < 4000:
                demo_pool.append({
                    "id": row[idx["PuzzleId"]],
                    "fen": fen,
                    "moves": " ".join(moves),
                    "rating": rating,
                    "themes": ",".join(row[idx["Themes"]].replace(",", " ").split()),
                    "tier": "premium",
                })
                kept += 1
            continue
        if not (600 <= rating <= 2300):
            continue
        theme = primary(row[idx["Themes"]])
        if not theme:
            continue
        b = buckets[theme]
        if len(b) < quota * 2:
            b.append({
                "id": row[idx["PuzzleId"]],
                "fen": fen,
                "moves": " ".join(moves),
                "rating": rating,
                "themes": theme,
            })
            kept += 1
        elif random.random() < 0.05 and b:
            b[random.randrange(len(b))] = {
                "id": row[idx["PuzzleId"]],
                "fen": fen,
                "moves": " ".join(moves),
                "rating": rating,
                "themes": theme,
            }
        if seen % 500000 == 0:
            print(f"[..] {seen:,} vistos, {kept:,} guardados", flush=True)

    print(f"[..] total vistos: {seen:,}, guardados: {kept:,}", flush=True)
    selected = []
    for t in PRIORITY:
        pool = buckets.get(t, [])
        random.shuffle(pool)
        take = pool[:quota]
        print(f"  {t:<18} {len(take):>5} (pool {len(pool)})")
        selected += take
    # completa até COUNT com sobras aleatórias
    if len(selected) < COUNT:
        rest = [p for t in PRIORITY for p in buckets.get(t, [])[quota:]]
        random.shuffle(rest)
        selected += rest[: COUNT - len(selected)]
    random.shuffle(selected)
    selected = selected[:COUNT]
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(selected, f, ensure_ascii=False, separators=(",", ":"))
    print(f"[ok] {len(selected):,} táticas -> {OUT_JSON} "
          f"({os.path.getsize(OUT_JSON)/1048576:.1f} MB)")

    random.shuffle(demo_pool)
    demo = demo_pool[:DEMO_COUNT]
    with zipfile.ZipFile(OUT_DEMO, "w", zipfile.ZIP_DEFLATED,
                          compresslevel=9) as zf:
        zf.writestr("puzzles_premium.json",
                    json.dumps(demo, ensure_ascii=False, separators=(",", ":")))
    print(f"[ok] demo premium ({len(demo)}) -> {OUT_DEMO}")

if __name__ == "__main__":
    if not os.path.exists(SRC):
        sys.exit(f"falta {SRC}")
    main()
