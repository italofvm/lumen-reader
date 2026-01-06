# Phase 03 — Desenvolvimento: Reader (Modo Foco, Marcadores e Busca)

## Objetivo
Entregar melhorias de experiência de leitura no **Lumen Reader**, com foco em:

- **Modo Foco** (tap para ocultar/mostrar UI) em PDF/EPUB/TXT
- **Marcadores reais** (salvar, listar, navegar e remover) em PDF/EPUB/TXT
- **Busca no livro** (PDF por páginas; EPUB por capítulos/páginas virtuais)

## Escopo entregue

### A) Modo Foco
- **PDF**: toque no conteúdo alterna visibilidade da `AppBar`.
- **EPUB**: toque no conteúdo alterna visibilidade da `AppBar` e do `Drawer` (sumário).
- **TXT**: toque no conteúdo alterna visibilidade da `AppBar`.

Ponto de UX:
- Objetivo é leitura imersiva sem perder acessos (configurações, marcador, busca).

### B) Marcadores reais (persistidos)
Persistência via Hive, por livro.

Requisitos atendidos:
- **Salvar marcador** na posição atual
- **Listar marcadores**
- **Ir para marcador**
- **Remover marcador**

Mapeamento por tipo de leitor:
- **PDF**: marcador por **página** (`targetIndex = pageNumber`).
- **EPUB**: marcador por **índice de página virtual** (`targetIndex = pageIndex`).
- **TXT**: marcador por **scroll offset** (`targetIndex = offset`).

UI:
- Pressão longa no ícone abre a lista de marcadores (`BookmarksSheet`).

### C) Busca no livro
UI comum via bottom sheet (`ReaderSearchSheet`), com:
- input
- botão de buscar
- loading
- lista de resultados (hits)
- callback de navegação

#### Busca em PDF
- Extração de texto por página via `syncfusion_flutter_pdf` (`PdfTextExtractor`).
- Retorna hits por página com snippet.
- Navegação com `SfPdfViewerController.jumpToPage`.

#### Busca em EPUB
- Busca por capítulo, usando HTML sanitizado e texto extraído.
- O resultado é convertido para um **índice de página virtual** (heurística baseada no mesmo cálculo de paginação).
- Navegação com `_pageController.jumpToPage(index)`.

## Principais arquivos impactados

### Telas
- `lib/features/reader/presentation/screens/pdf_reader_screen.dart`
- `lib/features/reader/presentation/screens/epub_reader_screen.dart`
- `lib/features/reader/presentation/screens/txt_reader_screen.dart`

### Widgets
- `lib/features/reader/presentation/widgets/bookmarks_sheet.dart`
- `lib/features/reader/presentation/widgets/reader_search_sheet.dart`

### Serviços / Providers
- `lib/features/reader/services/bookmark_service.dart`
- `lib/features/reader/services/providers.dart`

## Decisões técnicas e trade-offs

### Paginação EPUB (páginas virtuais)
- A paginação real exigiria layout/renderização para medir altura do conteúdo.
- Foi adotada uma **heurística de caracteres por página**, suficiente para:
  - navegação
  - progresso
  - marcadores
  - busca com navegação aproximada

Trade-off:
- A posição do hit é **aproximada** dentro do capítulo. A navegação é estável, mas não é “sub-string highlight”.

### Performance
- Cache de HTML sanitizado (`_sanitizedChapterHtml`) evita trabalho repetido.
- Busca limita quantidade de resultados (ex.: 40 hits) para manter UX responsiva.

## Critérios de aceitação
- Modo foco funciona em PDF/EPUB/TXT sem quebrar seleção/scroll.
- Marcadores:
  - criar, listar, remover e navegar funciona nos 3 leitores.
  - persistência entre aberturas do app.
- Busca:
  - PDF retorna páginas e navega corretamente.
  - EPUB retorna capítulos e navega para a página virtual associada.

## Próximos passos (backlog sugerido)
- Busca com **múltiplas ocorrências por capítulo/página**.
- Destaque do termo encontrado no texto (quando viável).
- Indexação incremental/assíncrona do EPUB para buscas mais rápidas em livros grandes.
- Exportar/importar marcadores (opcional).
