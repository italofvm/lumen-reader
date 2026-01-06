import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Termos de Uso'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: isDark
                    ? cs.surfaceContainerHighest.withOpacity(0.35)
                    : cs.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.primary.withOpacity(isDark ? 0.25 : 0.20),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 48,
                    color: cs.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Termos de Uso',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lumen Reader v1.2.3',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withOpacity(0.78),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Última atualização: 4 de janeiro de 2025',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withOpacity(0.60),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Content
            _buildSection(
              context,
              '1. Aceitação dos Termos',
              'Ao baixar, instalar ou usar o aplicativo Lumen Reader, você concorda em cumprir e estar vinculado a estes Termos de Uso. Se você não concordar com qualquer parte destes termos, não use o Aplicativo.',
            ),

            _buildSection(
              context,
              '2. Descrição do Serviço',
              'O Lumen Reader é um aplicativo de leitura de ebooks que permite:\n\n• Importação e leitura de arquivos PDF, EPUB, MOBI, FB2, TXT e AZW3\n• Sincronização com Google Drive\n• Funcionalidades de IA para explicação de textos via Google Gemini\n• Personalização da experiência de leitura\n• Armazenamento local de livros e progresso de leitura',
            ),

            _buildSection(
              context,
              '3. Licença de Uso',
              'Concedemos a você uma licença limitada, não exclusiva, não transferível e revogável para usar o Aplicativo para fins pessoais e não comerciais.\n\nVocê NÃO pode:\n• Modificar, adaptar ou alterar o Aplicativo\n• Fazer engenharia reversa ou descompilar\n• Usar para fins comerciais sem autorização\n• Distribuir ou sublicenciar o Aplicativo',
            ),

            _buildSection(
              context,
              '4. Conteúdo do Usuário',
              'Você é totalmente responsável por todos os arquivos e conteúdos que importar através do Aplicativo. Você declara que possui todos os direitos necessários sobre o conteúdo e que seu uso não viola direitos de terceiros.',
            ),

            _buildSection(
              context,
              '5. Privacidade e Dados',
              'Seus livros e dados de leitura são armazenados localmente em seu dispositivo. O Aplicativo pode integrar-se com serviços de terceiros (Google Drive, Google Gemini) conforme sua autorização. Consulte nossa Política de Privacidade para mais detalhes.',
            ),

            _buildSection(
              context,
              '6. Propriedade Intelectual',
              'O Aplicativo, incluindo seu código, design e funcionalidades, é protegido por direitos autorais. "Lumen Reader" e logos relacionados são marcas registradas.',
            ),

            _buildSection(
              context,
              '7. Isenção de Garantias',
              'O Aplicativo é fornecido "COMO ESTÁ" e "CONFORME DISPONÍVEL", sem garantias de qualquer tipo. Não garantimos funcionamento ininterrupto ou compatibilidade com todos os dispositivos.',
            ),

            _buildSection(
              context,
              '8. Limitação de Responsabilidade',
              'Em nenhuma circunstância seremos responsáveis por danos indiretos, perda de dados ou lucros. Nossa responsabilidade total não excederá o valor pago pelo Aplicativo nos 12 meses anteriores.',
            ),

            _buildSection(
              context,
              '9. Modificações',
              'Reservamos o direito de modificar estes Termos a qualquer momento. As alterações entrarão em vigor imediatamente após a publicação no Aplicativo.',
            ),

            _buildSection(
              context,
              '10. Lei Aplicável',
              'Estes Termos são regidos pelas leis do Brasil. Qualquer disputa será resolvida nos tribunais competentes do Brasil.',
            ),

            const SizedBox(height: 32),

            // Contact Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(isDark ? 0.45 : 0.30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.contact_support_outlined,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Contato',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Para questões sobre estes Termos de Uso:\n\nEmail: suporte@lumenreader.com\nDesenvolvedor: Lumen Reader Team',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      foregroundColor: cs.primary,
                      side: BorderSide(color: cs.primary.withOpacity(0.55)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Política de Privacidade'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Entendi'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: cs.onSurface.withOpacity(0.86),
            ),
          ),
        ],
      ),
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Política de Privacidade'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: isDark
                    ? cs.surfaceContainerHighest.withOpacity(0.35)
                    : cs.tertiary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.tertiary.withOpacity(isDark ? 0.25 : 0.20),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    size: 48,
                    color: cs.tertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Política de Privacidade',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.tertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Respeitamos sua privacidade',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withOpacity(0.78),
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            _buildSection(
              context,
              'Compromisso com a Privacidade',
              'Respeitamos sua privacidade e estamos comprometidos em proteger seus dados pessoais conforme a Lei Geral de Proteção de Dados (LGPD) e outras leis aplicáveis.',
            ),

            _buildSection(
              context,
              'Dados que Coletamos',
              '• Arquivos de livros que você importa\n• Configurações de leitura e preferências\n• Progresso de leitura e marcadores\n• Informações técnicas do dispositivo\n• Dados de uso do aplicativo',
            ),

            _buildSection(
              context,
              'Como Usamos seus Dados',
              '• Fornecer funcionalidades de leitura\n• Personalizar sua experiência\n• Sincronizar dados entre dispositivos\n• Processar textos para IA (quando autorizado)\n• Melhorar o produto e fornecer suporte',
            ),

            _buildSection(
              context,
              'Armazenamento e Segurança',
              'Seus livros e dados são armazenados localmente em seu dispositivo. Não temos acesso aos arquivos armazenados localmente. Dados em nuvem são processados apenas quando você autoriza explicitamente.',
            ),

            _buildSection(
              context,
              'Seus Direitos (LGPD)',
              '• Acesso aos seus dados\n• Correção de dados incorretos\n• Exclusão de dados\n• Portabilidade de dados\n• Oposição ao processamento\n\nPara exercer seus direitos, entre em contato conosco.',
            ),

            _buildSection(
              context,
              'Compartilhamento de Dados',
              'Nunca compartilhamos seus livros ou conteúdo pessoal. Dados podem ser compartilhados apenas com serviços autorizados (Google Drive, Gemini) ou quando exigido por lei.',
            ),

            const SizedBox(height: 32),

            // Contact
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(isDark ? 0.45 : 0.30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: cs.tertiary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Encarregado de Proteção de Dados',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Email: dpo@lumenreader.com\n\nPara questões sobre privacidade, entre em contato com nosso DPO.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Back Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: cs.tertiary,
                  foregroundColor: cs.onTertiary,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Voltar'),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.tertiary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: cs.onSurface.withOpacity(0.86),
            ),
          ),
        ],
      ),
    );
  }
}
