# Tasks — Roadmap de Updates (Lumen Reader)

## Sequência acordada
1. **IA: Pergunte ao livro (RAG) + Explicação de trecho (com citação)**
2. **Metas de leitura + Streak + Tempo restante**
3. **Update in-app Android (com changelog) + Canal Stable/Beta**

---

## 1) IA — Pergunte ao livro (RAG) + Explicação de trecho

### Objetivo
Permitir que o usuário faça perguntas sobre o conteúdo do livro e receba respostas com contexto e referências (capítulo/página/trecho), e que consiga selecionar um trecho e pedir explicação em diferentes níveis.

### Requisitos funcionais
- **RF1**: Botão/ação “Pergunte ao livro” dentro do leitor.
- **RF2**: Campo de pergunta + histórico das últimas perguntas por livro.
- **RF3**: Resposta deve incluir:
  - um texto de resposta (IA)
  - pelo menos 1 citação (trecho do livro) com origem (capítulo/página virtual)
- **RF4**: “Explicar trecho” a partir de seleção (PDF) ou highlight (EPUB/TXT):
  - modos: simples, intermediário, técnico
- **RF5**: Modo offline degradado (sem travar):
  - se não houver conectividade/IA indisponível, mostrar mensagem clara.

### Requisitos não funcionais
- **RNF1**: Não degradar performance de virada de página.
- **RNF2**: Indexação incremental/caching por livro.
- **RNF3**: Respeitar privacidade: conteúdo do livro só é enviado ao modelo em “chunks” mínimos necessários.

### Critérios de aceitação
- **CA1**: Pergunta sobre um capítulo retorna resposta com 1+ citação.
- **CA2**: Selecionar trecho e pedir explicação funciona em PDF e EPUB/TXT (com fallback quando não há seleção nativa).
- **CA3**: Com livros grandes, o app continua responsivo durante indexação.

### Backlog (prioridade)
- **P0**
  - Definir camada de domínio/serviço: `BookContextService` (extração de texto por tipo de leitor)
  - Criar “chunks” por capítulo/página virtual e cachear
  - UI básica: modal/sheet de pergunta e resposta
- **P1**
  - Citações clicáveis (navegar para capítulo/página virtual)
  - Histórico por livro
- **P2**
  - Ajustes de prompt e controles (tamanho do contexto, temperatura, etc.)

---

## 2) Produto — Metas + Streak + Tempo restante

### Objetivo
Criar retenção e hábito de leitura com metas diárias, streak, estatísticas e estimativas realistas.

### Requisitos funcionais
- **RF1**: Meta diária configurável (minutos e/ou páginas).
- **RF2**: Streak (dias consecutivos batendo meta).
- **RF3**: Estatísticas por dia/semana/mês.
- **RF4**: “Tempo restante no capítulo/livro” baseado em velocidade média do usuário.

### Requisitos não funcionais
- **RNF1**: Persistência local (Hive) e opcional sincronização futura.

### Critérios de aceitação
- **CA1**: Meta diária pode ser alterada e é respeitada.
- **CA2**: Streak incrementa e quebra corretamente.
- **CA3**: Tempo restante se ajusta conforme hábitos do usuário.

### Backlog (prioridade)
- **P0**
  - Modelo local: `ReadingSession`, `DailyGoal`, `ReadingStats`
  - Tracking de tempo no leitor (start/stop/foreground/background)
  - Dashboard simples na home/biblioteca
- **P1**
  - Gráficos simples (sem depender de libs pesadas inicialmente)
  - Exportar/backup (mais tarde)

---

## 3) Distribuição — Update in-app Android + Changelog + Canais

### Objetivo
Deixar o update in-app “produto” (modal com changelog, escolha Stable/Beta) e robusto.

### Requisitos funcionais
- **RF1**: Modal de atualização com:
  - versão atual vs nova
  - changelog (texto da release)
- **RF2**: Canal Stable/Beta:
  - Stable: ignora prerelease
  - Beta: permite prerelease
- **RF3**: Android: download + instalação via APK.
- **RF4**: Outras plataformas: abrir URL da release.

### Critérios de aceitação
- **CA1**: Usuário escolhe canal e isso afeta a detecção.
- **CA2**: Changelog aparece no modal.
- **CA3**: Android instala a atualização após download.

### Backlog (prioridade)
- **P0**
  - Ler `body` da release e exibir
  - Persistir canal (Hive)
- **P1**
  - Re-tentar download / verificar checksum (se disponível)

---

## Observações importantes
- Para consultar GitHub Releases sem autenticação, o repositório de releases precisa ser público.
