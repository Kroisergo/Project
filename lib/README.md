# EncryVault - Documentacao Tecnica (lib/)

## Visao geral
EncryVault e um gestor de passwords/segredos 100% offline. Existe apenas um cofre fisico (ficheiro `.vltx`) no armazenamento privado da app; os "ficheiros" mostrados na UI sao entradas logicas (registos) dentro do JSON cifrado.

## Fluxo da aplicacao
1) Splash (bootstrap)  
2) Termos (aceitacao obrigatoria)  
3) Welcome (Criar / Entrar / Configurar-Importar)  
4) Criar: cria cofre vazio cifrado  
5) Entrar: desbloqueia o cofre na memoria  
6) Cofre: lista, pesquisa, filtros por tags, criar/editar/apagar  
7) Definicoes: export/import e auto-lock

## Mapa de Ficheiros (Workspace)
- `lib/` codigo Flutter (UI, services, models, utils)  
- `test/` testes unitarios e widget smoke  
- `pubspec.yaml` dependencias e configuracao do Flutter  
- `analysis_options.yaml` lints  
- `README.md` (raiz) guia rapido do projeto  

### lib/ (arvore)
```text
lib/
  app.dart
  main.dart
  README.md
  config/
    router.dart
    theme.dart
  models/
    vault_data.dart
    vault_entry.dart
    vault_header.dart
  pages/
    splash/
      splash_page.dart
    terms/
      terms_page.dart
    welcome/
      welcome_page.dart
      import_vault_page.dart
    create_master/
      create_master_page.dart
    unlock/
      unlock_page.dart
      unlock_form.dart
    vault_home/
      vault_home_page.dart
    vault_entry_view/
      vault_entry_view_page.dart
    vault_entry_edit/
      vault_entry_edit_page.dart
    vault_settings/
      vault_settings_page.dart
  services/
    bootstrap/
      bootstrap_service.dart
    crypto/
      crypto_params.dart
      crypto_service.dart
      sodium_provider.dart
    storage/
      preferences_service.dart
      vault_file_service.dart
    vault/
      vault_repository.dart
      vault_service.dart
      vault_state.dart
  utils/
    constants.dart
    router_paths.dart
  widgets/ (planeado)
```

### lib/ (descricao ficheiro a ficheiro)
- `lib/main.dart` — O que faz: arranque da app e injecao do ProviderScope; Porque existe: ponto de entrada Flutter; Liga-se a: `lib/app.dart`, Riverpod.
- `lib/app.dart` — O que faz: MaterialApp.router com tema e rotas; Porque existe: raiz da UI; Liga-se a: `config/router.dart`, `config/theme.dart`.
- `lib/config/router.dart` — O que faz: define GoRouter e rotas; Porque existe: navegacao centralizada; Liga-se a: pages/*.
- `lib/config/theme.dart` — O que faz: tema e estilos base; Porque existe: consistencia visual; Liga-se a: MaterialApp.
- `lib/models/vault_data.dart` — O que faz: modelo do payload do cofre; Porque existe: serializacao JSON; Liga-se a: vault_service/repository.
- `lib/models/vault_entry.dart` — O que faz: modelo de entrada logica; Porque existe: CRUD e UI; Liga-se a: vault_state/pages.
- `lib/models/vault_header.dart` — O que faz: modelo do header do ficheiro; Porque existe: valida formato e params; Liga-se a: vault_repository.
- `lib/pages/splash/splash_page.dart` — O que faz: bootstrap e redirecao inicial; Porque existe: carregar estado (termos/cofre); Liga-se a: bootstrap_service.
- `lib/pages/terms/terms_page.dart` — O que faz: aceitar termos; Porque existe: fluxo obrigatorio; Liga-se a: preferences_service.
- `lib/pages/welcome/welcome_page.dart` — O que faz: entrada do fluxo (Criar/Entrar/Configurar); Porque existe: UX inicial; Liga-se a: create/unlock/import.
- `lib/pages/welcome/import_vault_page.dart` — O que faz: importar `.vltx` por caminho; Porque existe: restaurar cofre offline; Liga-se a: vault_file_service.
- `lib/pages/create_master/create_master_page.dart` — O que faz: criar master e cofre vazio; Porque existe: primeiro setup; Liga-se a: vault_service.
- `lib/pages/unlock/unlock_page.dart` — O que faz: desbloquear cofre; Porque existe: derivar chave e abrir; Liga-se a: vault_repository/vault_state.
- `lib/pages/unlock/unlock_form.dart` — O que faz: form de master; Porque existe: reutilizacao e validacao; Liga-se a: unlock_page.
- `lib/pages/vault_home/vault_home_page.dart` — O que faz: lista, pesquisa, filtros e auto-lock; Porque existe: UX do cofre; Liga-se a: vault_state, router_paths.
- `lib/pages/vault_entry_view/vault_entry_view_page.dart` — O que faz: ver entrada, copiar e apagar; Porque existe: detalhe da entrada; Liga-se a: vault_state.
- `lib/pages/vault_entry_edit/vault_entry_edit_page.dart` — O que faz: criar/editar entrada e gerar password; Porque existe: CRUD; Liga-se a: vault_state, sodium_provider.
- `lib/pages/vault_settings/vault_settings_page.dart` — O que faz: export/import e timeout; Porque existe: operacao do cofre; Liga-se a: vault_file_service, preferences_service.
- `lib/services/bootstrap/bootstrap_service.dart` — O que faz: verifica termos e existencia do cofre; Porque existe: fluxo splash; Liga-se a: preferences_service, vault_file_service.
- `lib/utils/constants.dart` — O que faz: constantes de formato e prefs; Porque existe: consistencia; Liga-se a: services/pages.
- `lib/utils/router_paths.dart` — O que faz: helpers de rotas; Porque existe: evitar strings repetidas; Liga-se a: pages/vault_*.

### services/ (subseccoes crypto/storage/vault)
- `services/crypto/crypto_service.dart` — O que faz: derivacao Argon2id, AEAD XChaCha20, RNG; Porque existe: encapsular crypto; Liga-se a: sodium_provider, vault_repository.
- `services/crypto/crypto_params.dart` — O que faz: parametros KDF; Porque existe: manter configuracao de derivacao; Liga-se a: crypto_service.
- `services/crypto/sodium_provider.dart` — O que faz: init libsodium (SodiumSumo); Porque existe: fonte de APIs seguras; Liga-se a: crypto_service.
- `services/storage/preferences_service.dart` — O que faz: SharedPreferences (termos, auto-lock); Porque existe: persistir configuracao local; Liga-se a: splash/terms/settings.
- `services/storage/vault_file_service.dart` — O que faz: path do cofre, escrita tmp->rename, import/export; Porque existe: robustez de ficheiro; Liga-se a: vault_service/repository.
- `services/vault/vault_service.dart` — O que faz: criar cofre cifrado inicial; Porque existe: setup seguro; Liga-se a: crypto_service, vault_file_service.
- `services/vault/vault_repository.dart` — O que faz: ler header, derivar chave, decrypt/encrypt e guardar; Porque existe: acesso central ao cofre; Liga-se a: crypto_service, vault_file_service.
- `services/vault/vault_state.dart` — O que faz: estado em memoria e CRUD; Porque existe: state management; Liga-se a: pages/vault_*.

## Arquitetura e Componentes
Camadas claras:
- UI: `pages/` (ecras) e `app.dart` (root).  
- Dominio: `services/` (crypto, storage, vault).  
- Dados: `models/` (VaultData/VaultEntry/VaultHeader).  
- Config: `config/` (rotas/tema).  
- Utils: `utils/` (constantes e helpers).  
Widgets reutilizaveis: `widgets/` (planeado).

## State management (Riverpod)
- Providers principais: `sodiumProvider`, `vaultProvider`, `bootstrapProvider`.  
- Estado do cofre: `VaultState` guarda header, data e chave em memoria; e limpo no lock.  
- UI observa `vaultProvider` para atualizar lista e detalhe imediatamente apos guardar.

## Seguranca e Criptografia
- KDF: Argon2id via libsodium (SodiumSumo).  
- Cipher: XChaCha20-Poly1305 AEAD; header e AAD; tag falha em tampering.  
- Nonce: aleatorio e novo a cada gravacao; nunca reutilizado com a mesma chave.  
- Chave: apenas em memoria enquanto o cofre esta desbloqueado (limpa em lock).

## Formato do ficheiro do cofre
- Prefixo: 4 bytes (big endian) com tamanho do header.  
- Header JSON em claro: `magic`, `formatVersion`, `cipherId`, `kdf`, `memLimit`, `opsLimit`, `parallelism`, `salt`, `nonce`.  
- Payload: JSON (VaultData) cifrado em XChaCha20-Poly1305.  
- Qualquer corrupcao ou password errada -> AEAD falha -> abertura falha.

## Persistencia e robustez
- Escrita segura: `vault.tmp` + flush + rename para `.vltx`.  
- Caminhos: armazenamento privado via `path_provider`.  
- Import/export: copias via caminho manual (sem file picker).

## Seguranca operacional
- Sem logs de segredos no codigo.  
- Clipboard: limpa apos 30s quando copia password (em `vault_entry_view_page.dart`).  
- Screen protection: (planeado).  
- Auto-lock: configuravel (1-10 min) e lock por lifecycle.

## Como executar e testar
- `flutter pub get`  
- `flutter run`  
- `flutter analyze`  
- `flutter test`  

Checklist manual:
- Criar cofre, criar entrada, editar e apagar.  
- Exportar/importar via caminho local.  
- Tentar master errada (falha).  
- Corromper 1 byte do `.vltx` (falha).  
- Confirmar que nonce muda apos gravacao.
