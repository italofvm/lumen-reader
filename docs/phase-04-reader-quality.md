# Phase 04 — Testes, Correções e Qualidade (Reader)

## Objetivo
Consolidar qualidade das features de leitura entregues na Phase 03, garantindo:

- estabilidade (sem crashes/leaks)
- consistência de UX entre leitores
- performance aceitável em livros grandes
- critérios claros de validação manual

## Checklist de qualidade (implementado/ajustado)

### Gerenciamento de recursos
- **PDF**: liberar documento usado na busca quando a tela é descartada.
  - `PdfDocument` criado lazy para busca deve ser `dispose()` para evitar vazamento.

### Robustez de UI
- `ReaderSearchSheet` trata:
  - query vazia
  - loading
  - erros
  - lista vazia
- `BookmarksSheet` permite remoção e recarrega lista corretamente.

### Consistência de UX
- Modo foco:
  - PDF/TXT: oculta `AppBar`
  - EPUB: oculta `AppBar` e `Drawer`
- Marcadores:
  - toque: salvar
  - long press: listar/navegar/remover
- Busca:
  - ícone dedicado na `AppBar`
  - resultados clicáveis que navegam

## Plano de testes manuais (recomendado)

### 1) PDF
- Abrir PDF grande (100+ páginas).
- Validar:
  - Tap alterna `AppBar`.
  - Criar marcador na página atual.
  - Long press no bookmark abre lista.
  - Tocar em item navega para página.
  - Remover marcador e confirmar que some da lista.
  - Busca por termo existente retorna hits.
  - Tocar em hit navega para página correta.

### 2) EPUB
- Abrir EPUB com muitos capítulos.
- Validar:
  - Tap alterna UI e permite abrir/fechar sumário.
  - Criar marcador em diferentes pontos.
  - Long press lista marcadores e navega.
  - Busca por termo existente retorna capítulo/snippet.
  - Navegação do hit leva para a página virtual esperada.

### 3) TXT
- Abrir TXT grande.
- Validar:
  - Tap alterna `AppBar`.
  - Marcador salva no offset atual.
  - Abrir lista e navegar para offset.

## Riscos conhecidos e mitigação

### Busca em EPUB (heurística)
Risco:
- O EPUB usa **páginas virtuais** estimadas por tamanho de texto, então o hit pode levar para uma posição aproximada.

Mitigação:
- Mesma heurística usada para paginação e busca, reduzindo divergência.
- Limite de resultados para manter UX fluida.

### Performance de busca em livros grandes
Risco:
- Busca completa varrendo capítulos/páginas pode levar tempo.

Mitigação atual:
- Limite de hits.
- Cache do HTML sanitizado.

Próximas melhorias possíveis:
- Indexação incremental/assíncrona.
- Cache de texto por capítulo (não só HTML).

## Critérios de aceitação de qualidade
- Sem crash em fluxo normal (abrir livro, alternar foco, buscar, marcar).
- Sem vazamentos óbvios (especialmente PDF).
- Experiência consistente e previsível entre leitores.

