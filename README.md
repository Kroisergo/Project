# EncryVault 2.0

EncryVault e um gestor de palavras-passe e segredos 100% offline feito em Flutter.
O cofre e guardado num ficheiro local `.vltx`, cifrado com Argon2id e
XChaCha20-Poly1305. Nao existe backend, sincronizacao remota ou base de dados
externa.

## Funcionalidades

- Cofre offline em ficheiro `.vltx`.
- Criacao de palavra-passe mestra com requisitos obrigatorios.
- Desbloqueio com penalizacao por tentativas falhadas.
- Criacao, edicao, visualizacao e eliminacao de entradas.
- Pesquisa, ordenacao e filtros por tags.
- Lixo com restauracao, selecao multipla e eliminacao definitiva.
- Retencao de entradas no Lixo durante 30 dias.
- Gerador de palavras-passe fortes.
- Indicador de forca e feedback textual para palavras-passe.
- Historico de palavras-passe por entrada.
- Datas de criacao, atualizacao, abertura e alteracao de palavra-passe.
- Recomendacao de mudanca com base na forca da palavra-passe.
- Dashboard de saude das palavras-passe.
- Alertas para palavras-passe fracas, reutilizadas ou antigas.
- Auto-lock configuravel, incluindo opcao Nunca.
- Bloqueio por inatividade e por eventos de ciclo de vida da app.
- Exportacao e importacao local do cofre.
- Tema claro, escuro e sistema.

## Como correr

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

## Fluxo da app

1. Splash valida termos e existencia de cofre.
2. Welcome permite criar, desbloquear ou importar cofre.
3. Criacao define a palavra-passe mestra e cria um cofre vazio cifrado.
4. Unlock deriva a chave e valida/desencripta o cofre.
5. Home mostra entradas ativas, pesquisa, filtros, ordenacao e alertas.
6. Configuracoes agrupam dados/backup, saude, lixo, sessao e aparencia.

## Seguranca

- KDF: Argon2id via libsodium.
- Cipher: XChaCha20-Poly1305 AEAD.
- Header usado como AAD para autenticar parametros do ficheiro.
- Nonce aleatorio novo a cada gravacao.
- Escrita com ficheiro temporario, flush e rename.
- Chave derivada mantida apenas em memoria enquanto o cofre esta desbloqueado.
- Chave descartada no lock/logout.
- Corrupcao, tampering ou palavra-passe errada impedem abertura do cofre.

## Palavra-passe mestra

A palavra-passe mestra e obrigatoriamente validada com:

- minimo 12 caracteres
- pelo menos 1 letra maiuscula
- pelo menos 1 letra minuscula
- pelo menos 1 numero
- pelo menos 1 caracter especial permitido

O ecra de criacao mostra barra de forca, requisitos cumpridos/por cumprir e
bloqueia a criacao enquanto a policy nao estiver completa.

## Palavras-passe das entradas

As palavras-passe das entradas podem ser guardadas mesmo que sejam fracas. A app
informa e recomenda, mas nao bloqueia.

O ecra de criar/editar entrada mostra:

- indicador de forca
- feedback textual concreto
- aviso de reutilizacao quando aplicavel
- gerador de palavra-passe forte

## Saude das palavras-passe

A area de Saude fica nas configuracoes do cofre e mostra:

- total de entradas
- palavras-passe fracas
- palavras-passe reutilizadas
- grupos com palavra-passe repetida
- palavras-passe a mudar pela recomendacao
- entradas sem palavra-passe
- entradas sem categoria/tag

Quando existem alertas, a home mostra um indicador visual para chamar a atencao.

## Historico de palavras-passe

Cada entrada guarda historico de palavras-passe dentro do proprio cofre cifrado.

- Ao criar uma entrada, e guardada a palavra-passe inicial.
- Ao editar uma entrada, se a palavra-passe mudar, e adicionado um novo item ao
  historico.
- Cofres antigos sem historico recebem fallback com a palavra-passe atual.
- O historico nao e guardado em SharedPreferences, logs ou ficheiros auxiliares.

## Lixo

Ao apagar uma entrada, ela vai para o Lixo em vez de ser eliminada
definitivamente.

No Lixo e possivel:

- listar entradas eliminadas
- selecionar varias entradas
- restaurar entradas
- eliminar uma ou varias definitivamente
- esvaziar o Lixo
- ver detalhes seguros sobre a retencao

No Lixo nao sao apresentados dados sensiveis como palavra-passe, notas ou
conteudo completo da entrada.

## Auto-lock

O auto-lock usa o tempo configurado e tambem reage a estados de ciclo de vida da
app:

- `inactive`
- `paused`
- `hidden`
- `detached`

Quando o cofre bloqueia, o estado em memoria e limpo e a chave e descartada.

## Formato do ficheiro `.vltx`

Estrutura:

1. 4 bytes big-endian com o tamanho do header.
2. Header JSON em claro com magic, versao, cipher, KDF, salt e nonce.
3. Payload JSON cifrado e autenticado com XChaCha20-Poly1305.

O payload contem as entradas, entradas no Lixo, historico de palavras-passe e
metadados do cofre.

## Dependencias principais

- `flutter_riverpod`
- `go_router`
- `sodium`
- `shared_preferences`
- `path_provider`
- `path`
- `uuid`
- `password_strength_checker`
- `flutter_localizations`

## Testes

O projeto inclui testes para:

- policy da palavra-passe mestra
- gerador de palavras-passe
- compatibilidade com JSON antigo
- Lixo e separacao entre entradas ativas/eliminadas
- visibilidade de filtros
- recomendacao de mudanca
- saude das palavras-passe
- feedback textual
- cifra/decifra
- deteccao de tampering
- rotacao de nonce
- smoke test da app

## Testes manuais recomendados

- Criar cofre novo e validar requisitos da palavra-passe mestra.
- Criar entrada com palavra-passe fraca e confirmar que deixa guardar.
- Gerar palavra-passe e confirmar que tem 12 ou mais caracteres.
- Criar duas entradas com a mesma palavra-passe e verificar alertas de saude.
- Editar palavra-passe e confirmar historico.
- Apagar entrada, restaurar do Lixo e eliminar definitivamente.
- Confirmar que filtros so aparecem com entradas ativas.
- Exportar e importar cofre local.
- Corromper um byte do `.vltx` e confirmar falha segura.
- Confirmar bloqueio por inatividade e ao mandar a app para background.

## Limitacoes conhecidas

- Em Dart/Flutter nao e possivel garantir zeroizacao completa de `String`.
- Enquanto o cofre esta desbloqueado, as entradas existem em memoria em texto
  claro dentro do estado da app.
- A importacao valida estrutura/header, mas a validacao criptografica completa
  acontece ao desbloquear com a palavra-passe mestra.
- O evento de ecra desligado depende do ciclo de vida exposto pelo Flutter na
  plataforma.
- O historico de palavras-passe ainda nao tem limite maximo de tamanho.
