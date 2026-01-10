# Phase 05 — Deploy & Observabilidade (Release + Atualizações via GitHub)

## Objetivo
Deixar o app **lançável** no GitHub com um fluxo simples de:

- build automático do APK (Android)
- publicação automática de Release
- app conseguindo **verificar atualização** via GitHub Releases

## Estratégia adotada

### 1) CI/CD via GitHub Actions
- Workflow: `.github/workflows/release-android.yml`
- Trigger: `push` de tag `v*` (ex.: `v1.2.4`)
- Saída: gera `app-release.apk` e anexa na Release.

Requisitos:
- Repositório precisa permitir `contents: write` (já configurado no workflow).

### 2) Update checker dentro do app
- Serviço: `lib/core/services/update/github_update_service.dart`
- UI: `Configurações > Sobre > Verificar atualizações`

O app consulta:
- `https://api.github.com/repos/<owner>/<repo>/releases/latest`

Ele compara:
- versão local (`PackageInfo.version`) vs tag da última release (`tag_name`)

Se houver atualização:
- abre o download do `.apk` (se existir asset `.apk` na Release)
- senão, abre a página da Release.

Configuração:
- Ajustar `lib/core/config/app_config.dart` com:
  - `AppConfig.githubOwner`
  - `AppConfig.githubRepo`

## Passo a passo de publicação (Android)

1) Atualize a versão no `pubspec.yaml`
   - Ex.: `version: 1.2.4+5`

2) Commit no GitHub

3) Crie e envie uma tag
   - `git tag v1.2.4`
   - `git push origin v1.2.4`

4) O GitHub Actions vai:
   - buildar o APK release
   - criar a Release
   - anexar o `app-release.apk`

5) No app:
   - `Configurações > Verificar atualizações`
   - se houver versão nova, aparecerá opção de baixar.

## Observabilidade mínima recomendada (próximo passo)
- Crash reporting (ex.: Firebase Crashlytics ou Sentry)
- Logs estruturados (ex.: `logger`) para rastrear falhas de importação/leitura


## Build Manual (Log de Execução)
Data: 2026-01-08
Versão: 1.2.8+9
Artefato: `android/app/build/outputs/flutter-apk/app-release.apk`
Tamanho: 98 MB

**Notas:**
- Build realizado com sucesso após limpeza completa (`flutter clean`).
- Ambiente validado com Kotlin 1.9.10 (aviso de deprecation notado).
- Assinatura de depuração utilizada para validação local.
