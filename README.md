# EncryVault
Gestor de passwords/segredos 100% offline em Flutter. Um único ficheiro `.vltx` cifrado com Argon2id + XChaCha20-Poly1305; qualquer corrupção ou master errada falha a abertura.

## Como correr
- `flutter pub get`
- `flutter test`
- `flutter run`

## Fluxo
1) Splash → Termos → Welcome (Criar / Entrar / Importar)  
2) Criar: define master e gera cofre cifrado (header com magic, version, kdf params, cipher, salt, nonce)  
3) Entrar: deriva chave Argon2id, valida header, descifra payload JSON  
4) Vault: lista com pesquisa e filtros por tags, criar/editar/apagar entradas, auto-lock configurável  
5) Configurações: export/import via caminho local, ajustar timeout do auto-lock

## Segurança
- KDF: Argon2id (memLimit=Sensitive, opsLimit=Moderate, parallelism=1), salt no header  
- Cipher: XChaCha20-Poly1305 AEAD, header usado como AAD, nonce aleatório novo a cada gravação  
- Escrita segura: `.tmp` + flush + rename; validação de magic/version/kdf/cipher/nonce ao abrir  
- Chave derivada vive apenas em memória enquanto desbloqueado; auto-lock por inatividade/app lifecycle

## Testar manualmente
- Criar cofre, adicionar entradas, fechar/abrir com master correta  
- Tentar master errada → falha  
- Exportar para caminho local, importar por cima e desbloquear  
- Corromper 1 byte do `.vltx` → abertura falha  
- Verificar que nonce muda após editar entradas

## Migração de formato
- Header inclui `magic`, `formatVersion`, `cipherId`, `kdf` + parâmetros, salt, nonce; payload é JSON.  
- Futuras versões: ler payload antigo e regravar com novos parâmetros/cifra mantendo entradas.

## Checklist
- Pronto: fluxo completo, Argon2id + XChaCha20, nonce novo a cada gravação, tmp→rename, validação de header, auto-lock configurável, CRUD com pesquisa/tags, export/import offline, testes de cripto/tamper/nonce.  
- V2 sugerido: gerador de passwords configurável, biometria opcional, múltiplos backups, datas mais amigáveis e UI refinada de copy/timeouts.
