# EncryVault - Documentacao Tecnica (lib/)

## Visao geral
EncryVault e um gestor de palavras-passe/segredos 100% offline. Existe apenas
um cofre fisico (`.vltx`) no armazenamento privado da app; a UI mostra entradas
logicas e documentos sigilosos guardados dentro do cofre v3.

## Fluxo da aplicacao
1. Splash valida termos e existencia de cofre.
2. Termos recolhe a aceitacao obrigatoria.
3. Welcome permite criar, desbloquear ou importar cofre.
4. Criar gera diretamente um cofre v3 vazio.
5. Entrar desbloqueia o cofre em memoria.
6. Cofre mostra entradas, pesquisa, filtros, edicao e lixo.
7. Documentos adiciona, exporta e elimina documentos por chunks.
8. Definicoes agrupam export/import, auto-lock, seguranca e aparencia.

## Ficheiros principais
- `models/vault_container_format.dart`: formato suportado em runtime.
- `models/vault_data.dart`: manifest logico com entradas e metadados de
  documentos.
- `models/vault_document.dart`: metadados dos documentos e lista de chunks.
- `models/vault_footer_v3.dart`: footer fixo de 64 bytes.
- `models/vault_header.dart`: header claro do ficheiro v3.
- `models/vault_manifest_v3.dart`: envelope cifrado do manifest.
- `services/storage/vault_file_service.dart`: paths, import/export, safe write,
  backup e validacao estrutural.
- `services/vault/vault_service.dart`: criacao inicial de cofre v3.
- `services/vault/vault_repository.dart`: fachada runtime apenas v3.
- `services/vault/vault_repository_v3.dart`: leitura/escrita do container v3.
- `services/vault/vault_chunked_file_writer.dart`: escrita por chunks sem
  carregar documentos inteiros em memoria.
- `services/vault/vault_document_service.dart`: add/export/delete de documentos.
- `services/vault/vault_state.dart`: estado Riverpod do cofre aberto.
- `pages/vault_documents/`: UI de Documentos Sigilosos.

## Arquitetura
- UI: `pages/`, `widgets/`, `app.dart`.
- Dominio: `services/crypto`, `services/storage`, `services/vault`.
- Dados: `models/`.
- Config: `config/`.
- Utils: `utils/`.

## State management
- Providers principais: `sodiumProvider`, `vaultProvider`, `bootstrapProvider`.
- `VaultState` guarda header, data, chave, nome do ficheiro e bytes do header
  enquanto o cofre esta desbloqueado.
- A UI observa `vaultProvider`, por isso entradas e documentos atualizam apos
  cada operacao guardada.

## Seguranca e criptografia
- KDF: Argon2id via libsodium.
- Cipher: XChaCha20-Poly1305 AEAD.
- AAD autentica header, footer, manifest e metadados de chunk.
- Nonces sao unicos por manifest e por chunk.
- A chave derivada fica apenas em memoria enquanto o cofre esta desbloqueado.
- Palavra-passe errada, corrupcao ou tampering fazem a abertura falhar.

## Formato do ficheiro do cofre
1. Prefixo de 4 bytes big-endian com tamanho do header.
2. Header JSON claro com `magic`, `formatVersion`, `container`, `cipherId`,
   `kdf`, `subkeyKdf`, parametros KDF, `salt`, `vaultId` e
   `defaultChunkSize`.
3. Chunks de documentos cifrados com XChaCha20-Poly1305.
4. Manifest cifrado com entradas, metadados de documentos e lista de chunks.
5. Footer fixo de 64 bytes com offsets, tamanhos, nonce do manifest e flags.

O manifest contem metadados; o conteudo dos documentos fica apenas nos chunks
cifrados.

## Persistencia e robustez
- Escrita segura com ficheiro temporario, flush e rename.
- Backup automatico best-effort antes de substituir um cofre existente.
- Rollback para o ficheiro anterior se a substituicao falhar.
- Import/export locais e operacoes de documentos por streaming.

## Seguranca operacional
- Sem backend, sincronizacao remota ou logs de segredos.
- Clipboard limpa apos copiar palavra-passe.
- Screen protection configuravel.
- Auto-lock configuravel e integrado com lifecycle da app.
- File picker/export suspendem temporariamente o lock de lifecycle e reiniciam
  o timeout apos a operacao.

## Como executar e testar
- `flutter pub get`
- `flutter run`
- `flutter analyze`
- `flutter test`

Checklist manual:
- Criar cofre, criar entrada, editar e apagar.
- Adicionar, exportar e eliminar documento grande por chunks.
- Exportar/importar cofre local.
- Tentar master errada e confirmar falha segura.
- Corromper 1 byte do `.vltx` e confirmar falha segura.
- Confirmar auto-lock fora do file picker.
