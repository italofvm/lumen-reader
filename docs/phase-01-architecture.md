# Phase 1: Arquitetura & Design do Sistema

## Padrão Arquitetural
Utilizaremos **Clean Architecture** para garantir separação de preocupações, testabilidade e escalabilidade.

### Camadas
1.  **Presentation (UI):** Widgets Flutter, State Management (Riverpod), formatadores de UI.
2.  **Domain (Business Rules):** Entidades (`Book`), Casos de Uso (`LoadBook`, `SaveProgress`), Contratos de Repositórios.
3.  **Data (Infra):** Implementações de Repositórios, Fontes de Dados (Hive, File System), Mappers (DTO to Entity).
4.  **Services:** Serviços externos como `GeminiService`.

## Estrutura de Pastas
```text
lib/
  core/           # Utilitários, constantes, temas, erros globais
  features/       # Funcionalidades divididas por feature
    library/
      data/
      domain/
      presentation/
    reader/
      data/
      domain/
      presentation/
    settings/
  services/       # Serviços externos (AI, etc)
  main.dart
```

## Estratégia de Dados (Offline-first)
- **Local DB:** Hive para metadados e progresso.
- **Arquivos:** Gerenciados via `path_provider`, mantendo apenas o caminho do arquivo original.

## Integração de IA
A IA será tratada como um serviço independente na camada de `Services`, acessada via Casos de Uso na camada de `Domain`.

## Backend Proxy de IA (Render) — sem expor a chave
Para uso em produção, o app **não** deve embutir a chave do Gemini. A estratégia é um **proxy backend** (Node.js + Express) implantado no Render.

### Responsabilidade
- Guardar `GEMINI_API_KEY` **apenas no servidor** (env var do Render).
- Expor endpoint HTTP simples para o app.
- Aplicar rate limit (por IP) e validação de payload.

### Endpoints
- `GET /health`
- `POST /v1/ai/ask`

Payload:
```json
{ "question": "...", "contextText": "...", "sourceLabel": "Capítulo 1, página 3" }
```

Resposta:
```json
{ "text": "..." }
```

### Integração no Flutter
- Em produção: o app chama o proxy via `--dart-define=AI_PROXY_URL=https://<seu-servico>.onrender.com`.
- Em desenvolvimento local: é possível usar `--dart-define=GEMINI_API_KEY=...` (opcional), mas não recomendado para releases.
