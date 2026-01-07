import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const OnboardingScreen({
    super.key,
    required this.onFinish,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const _steps = <_OnboardingStepData>[
    _OnboardingStepData(
      title: 'Importe seus livros',
      body: '''Toque em “Arquivo” para escolher um PDF/EPUB/TXT.

Se preferir, use “Google Drive” para buscar na nuvem.

Dica: você também pode “Escanear” pastas comuns no aparelho.''',
      icon: Icons.file_open,
    ),
    _OnboardingStepData(
      title: 'Leitura prática',
      body: '''No TXT:

- Toque no centro para mostrar/ocultar a interface.
- Toque nas bordas para avançar/voltar rapidamente.

No EPUB/PDF:

- Use a barra superior para acessar configurações e ferramentas.''',
      icon: Icons.menu_book,
    ),
    _OnboardingStepData(
      title: 'Fontes e tamanho',
      body: '''Abra “Configurações” > “Texto” para escolher fonte e tamanho.

Padrão recomendado: 14px.

Dica: ajuste também altura de linha e zoom no painel do leitor.''',
      icon: Icons.text_fields,
    ),
    _OnboardingStepData(
      title: 'Temas e conforto visual',
      body: '''Escolha entre Claro, Escuro, Sépia e Meia-noite.

Dica: Meia-noite é ótimo para leitura noturna; Sépia dá sensação de papel.''',
      icon: Icons.palette_outlined,
    ),
    _OnboardingStepData(
      title: 'IA: pergunte ao livro',
      body: '''Dentro do leitor, você pode:

- Pedir um resumo
- Pedir explicação de um trecho
- Fazer uma pergunta com base no conteúdo

Dica: quanto mais específico o trecho/pergunta, melhor a resposta.''',
      icon: Icons.auto_awesome,
    ),
  ];

  void _goNext() {
    if (_index >= _steps.length - 1) {
      widget.onFinish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _goBack() {
    if (_index <= 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final isLast = _index == _steps.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Primeiros passos'),
        actions: [
          TextButton(
            onPressed: widget.onFinish,
            child: const Text('Pular'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final step = _steps[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            color: cs.primary.withAlpha((0.12 * 255).round()),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            step.icon,
                            size: 38,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          step.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Text(
                              step.body,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(height: 1.45),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: List.generate(
                        _steps.length,
                        (i) {
                          final active = i == _index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(right: 6),
                            height: 8,
                            width: active ? 18 : 8,
                            decoration: BoxDecoration(
                              color: active
                                  ? cs.primary
                                  : cs.onSurface.withAlpha((0.22 * 255).round()),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _index == 0 ? null : _goBack,
                    child: const Text('Voltar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _goNext,
                    child: Text(isLast ? 'Concluir' : 'Próximo'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingStepData {
  final String title;
  final String body;
  final IconData icon;

  const _OnboardingStepData({
    required this.title,
    required this.body,
    required this.icon,
  });
}
