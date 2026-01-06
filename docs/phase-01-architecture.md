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
