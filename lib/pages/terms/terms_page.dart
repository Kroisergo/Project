import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/storage/preferences_service.dart';
import '../welcome/welcome_page.dart';

class TermsPage extends ConsumerStatefulWidget {
  static const routePath = '/terms';
  static const routeName = 'terms';

  const TermsPage({super.key});

  @override
  ConsumerState<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends ConsumerState<TermsPage> {
  bool saving = false;
  bool accepted = false;

  Future<void> _accept() async {
    setState(() => saving = true);
    final prefs = ref.read(preferencesServiceProvider);
    await prefs.setTermsAccepted(true);
    if (!mounted) return;
    context.go(WelcomePage.routePath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Termos de Utilização')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    primary: true,
                    padding: const EdgeInsets.only(right: 12, bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EncryVault é uma aplicação offline para gestão local de dados sensíveis. Antes de continuares, deves ler e aceitar estes Termos de Utilização. Ao usares a aplicação, reconheces que a segurança prática do teu cofre depende também da forma como escolhes, guardas e proteges as tuas credenciais, exportações, backups e dispositivo.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        const _RiskWarningsPanel(),
                        const SizedBox(height: 16),
                        Text(
                          _termsText,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: accepted,
                onChanged: saving
                    ? null
                    : (value) => setState(() => accepted = value ?? false),
                title: const Text('Li e aceito os Termos de Utilização'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: saving || !accepted ? null : _accept,
                child: saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Aceitar e continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _termsText =
    '1. Natureza da aplicação\n'
    'EncryVault foi concebida para funcionar maioritariamente de forma offline, com controlo local dos dados por parte do utilizador. A aplicação não depende de sincronização remota para o funcionamento base do cofre e os dados são geridos no dispositivo e nos ficheiros locais escolhidos pelo utilizador.\n\n'
    '2. Palavra-passe mestra e acesso ao cofre\n'
    'A palavra-passe mestra é essencial para abrir o cofre. És o único responsável por criar uma palavra-passe mestra forte, memorizá-la ou guardá-la de forma segura e impedir o acesso de terceiros. Se a palavra-passe mestra for esquecida, perdida, introduzida incorretamente repetidamente ou comprometida, o acesso ao cofre pode tornar-se impossível ou inseguro. A aplicação não garante recuperação de acesso em caso de perda das credenciais.\n\n'
    '3. Perda de acesso e perda de dados\n'
    'Ao utilizar a aplicação, aceitas que pode existir perda definitiva de acesso ao cofre se esqueceres a palavra-passe mestra, se perderes os ficheiros exportados, se o dispositivo falhar, se o ficheiro do cofre for eliminado, sobrescrito, corrompido ou alterado indevidamente. O utilizador assume integralmente esse risco.\n\n'
    '4. Exportações, backups e cópias\n'
    'Sempre que exportares o cofre ou criares cópias de segurança, és responsável por proteger esses ficheiros. Qualquer exportação ou backup deve ser guardado em local seguro, com controlo de acesso adequado. A existência de backups inseguros, desprotegidos ou mal geridos pode expor os teus dados e essa responsabilidade pertence ao utilizador.\n\n'
    '5. Utilização adequada\n'
    'Compete-te utilizar a aplicação de forma responsável e lícita. Não deves usar EncryVault para fins ilegais, abusivos ou contrários à proteção dos teus próprios dados. Também és responsável pela exatidão dos dados que inseres e pela forma como escolhes organizar, categorizar e manter o conteúdo do teu cofre.\n\n'
    '6. Limitações técnicas e de segurança\n'
    'Embora a aplicação adote mecanismos de proteção adequados ao seu objetivo, não existe garantia absoluta contra todos os riscos, incluindo falhas de hardware, malware, acesso indevido ao dispositivo, capturas de ecrã, cópias locais inseguras, corrupção de ficheiros, erros humanos, configurações incorretas ou outros incidentes fora do controlo direto da aplicação. A segurança final depende também do contexto em que a app é usada.\n\n'
    '7. Integridade e disponibilidade\n'
    'A aplicação pode recusar a abertura de um cofre quando deteta palavra-passe incorreta, corrupção, alteração indevida ou inconsistências no ficheiro. Aceitas que a proteção da integridade pode implicar a impossibilidade de abrir parcialmente ou recuperar automaticamente conteúdos em determinadas situações.\n\n'
    '8. Ausência de garantias absolutas\n'
    'EncryVault é disponibilizada tal como se encontra, sem garantia absoluta de disponibilidade contínua, ausência total de erros, compatibilidade futura com todos os dispositivos, ou proteção integral contra todos os cenários de risco. O uso da aplicação é feito por tua conta e risco.\n\n'
    '9. Alterações futuras\n'
    'Funcionalidades, fluxos, opções visíveis, mecanismos auxiliares de segurança e comportamento geral da aplicação podem ser alterados em versões futuras. Essas alterações podem incluir melhorias, limitações, reformulações de interface ou ajustamentos técnicos necessários ao funcionamento da aplicação.\n\n'
    '10. Aceitação dos Termos\n'
    'Ao assinalares a aceitação e continuares para a utilização da aplicação, confirmas que compreendes estes Termos de Utilização, aceitas a responsabilidade pela proteção das tuas credenciais e dados exportados, e reconheces as limitações e riscos inerentes ao uso local e offline do cofre.\n';

class _RiskWarningsPanel extends StatelessWidget {
  const _RiskWarningsPanel();

  static const _warnings = [
    'Se esqueceres a palavra-passe mestra, o cofre não pode ser recuperado pela app.',
    'Se apagares o ficheiro do cofre, podes perder o acesso aos dados.',
    'Importar por cima substitui o cofre atual pelo ficheiro escolhido.',
    'Se perderes backups ou exportações, podes ficar sem forma de restaurar o cofre.',
    'Se esqueceres um PIN de proteção, algumas ações protegidas podem ficar inacessíveis.',
    'O Lixo não é um backup permanente e exportações devem ser guardadas em local seguro.',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.error.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: colors.error),
              const SizedBox(width: 8),
              Text(
                'Riscos importantes',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._warnings.map(
            (warning) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(warning)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
