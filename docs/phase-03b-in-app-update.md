# Fase 03b — Atualização In-App (Android)

## Objetivo
Implementar verificação de novas versões via GitHub Releases e, quando disponível, exibir um modal perguntando se o usuário deseja atualizar.

## Regras e Limitações por Plataforma
- Android: suporte a download do APK no próprio app e abertura do instalador do sistema.
- iOS: sideload não é suportado; deve abrir a página da release.
- macOS/Windows: fluxo padrão é abrir a página da release (o formato de distribuição pode variar).

## Fluxo
1. App inicia e faz checagem (1x por sessão) em background.
2. Se houver versão nova, exibe modal.
3. Usuário confirma:
   - Android: baixa APK com progresso, salva em diretório temporário e chama instalação via FileProvider.
   - Outras plataformas: abre a página da release.

## Componentes
- Flutter:
  - `AppUpdateService`: consulta GitHub, compara versão, exibe modal, faz download e chama `MethodChannel`.
- Android nativo:
  - `FileProvider`: expõe o arquivo baixado do cache.
  - `MethodChannel` `lumen_reader/update`: método `installApk` para abrir o instalador.

## Observações
- Para o app conseguir consultar releases sem autenticação, o repositório de releases precisa ser público (GitHub retorna 404 para repositórios privados quando não autenticado).
