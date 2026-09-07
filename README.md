# OCT — Offline Chess Training

App Flutter 100% offline para treino de xadrez: jogar contra bots (Stockfish),
resolver táticas por tema com % de progresso, ELO offline, limite gratuito com
rewarded simulado e upgrade premium (mock) que injeta táticas no SQLite local.

Design: minimalista Preto & Branco (Noir). Arquitetura: Clean separando
`core / domain / data / presentation`.

## Fase 1 — APK testável via GitHub Actions (atual)

1. Push na branch `main` dispara `.github/workflows/android.yml`.
2. A pipeline instala Java 17 + Flutter stable, roda `flutter analyze`,
   `flutter test` e `flutter build apk --release`.
3. Baixe o APK em **Actions → run → Artifacts → oct-release-apk**
   (válido por 30 dias). Instale no Android e teste.

Fluxos para testar no APK:
- **Jogar:** Home → Jogar → escolha o bot → jogue. Vale 1 crédito por partida.
- **Táticas:** Home → Táticas → abra um tema → resolva. A cada 5 táticas,
  consome 1 crédito. Progresso por tema em % + geral em Progresso.
- **Sem créditos:** ao zerar, abre a tela de recompensa simulada
  (`/reward_sim`, botão "ASSISTI O VÍDEO" = mock do AdMob Rewarded de teste)
  e libera +5. Na Play Store isso vira `google_mobile_ads` real.
- **Premium:** Home → Premium → "BAIXAR BASE PREMIUM (DEMO)".
  Baixa o `puzzles_premium_demo.zip` embutido, descompacta e injeta no
  SQLite. Simula o fluxo dos 6M de táticas do Lichess.

## Fase 2 — Publicação na Play Store (próximo passo)

- [ ] Trocar `useRealAds=false` por AdMob real + IDs de produção.
- [ ] Trocar download demo pelo download real (WorkManager + resumable,
      checagem de espaço, licença Google Play).
- [ ] Assinatura release (`key.properties` + `app bundle` via
      `flutter build appbundle`), `applicationId` já definido:
      `br.com.honoravelmacho.oct`.
- [ ] Preencher ficha da loja, política de privacidade, classificação.
- [ ] Cobrança: pagamento único via Google Play Billing.

## Modelo gratuito vs pago

- **Grátis:** 20.000 táticas (todos os temas), 5 créditos por ciclo
  (1 partida = 1 crédito, 5 táticas = 1 crédito). Ad rewarded libera +5.
- **Premium (pagamento único):** remove anúncios + libera download da base
  completa (~6M táticas Lichess) + progresso % até 100%.

## Base de táticas (Lichess Open Database, CC-BY-SA)

Fonte: https://database.lichess.org/#puzzles

- `assets/data/puzzles_free.json` — 20.000 táticas de teste, balanceadas por
  tema (posições legais de lance único para validação imediata).
- `assets/data/puzzles_premium_demo.zip` — 400 táticas demo com
  `tier=premium` para validar download → unzip → SQLite.
- `tool/build_puzzles.py` — script oficial: baixa o CSV.zst do Lichess,
  filtra por rating/popularidade e gera os dois arquivos acima.
  Uso: `python3 tool/build_puzzles.py --count 20000`.

Para a base real de 6M, rode o script com o CSV completo localmente
(não versionar `*.zst`/`*.csv` — já ignorados) e publique o artefato em
hosting próprio; o app baixa via `PremiumPackageDownloader`.

## Dev local

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Estrutura:
`lib/core` (tema, consts, ads mock) · `lib/domain` (Puzzle, BotProfile, ELO,
limite de uso) · `lib/data` (SQLite, assets, Stockfish UCI + fallback local,
downloader) · `lib/presentation` (telas P&B + providers).

- Stockfish: `stockfish_chess_engine` via UCI (`setoption name UCI_Elo`
  por bot). Se o binário não iniciar, cai para `LocalFallbackBot`.
  Licença do motor (GPLv3) isolada em `assets/engine/LICENSE.stockfish`;
  app em MIT (`LICENSE`).
- ELO offline: `EloService` (K=40 provisório / 20 / 10 veterano).
- Limite: `UsageLimitService` (5 por ciclo, reset via reward).

## CI/CD

Workflow em `.github/workflows/android.yml`: checkout → Java 17 (temurin) →
Flutter stable → `pub get` → `analyze --fatal-infos` → `test` →
`build apk --release` → `upload-artifact`.
