# DualQueue Player — Plano e Prompts para Desenvolvimento no Codex

## 1. Visão geral

O **DualQueue Player** é um aplicativo nativo para macOS voltado para reprodução de áudio em eventos, cultos, apresentações e outros cenários de operação ao vivo.

A proposta principal é manter o fluxo simples e previsível:

- duas filas independentes de músicas;
- apenas uma fila principal ativa por vez;
- troca rápida entre Fila A e Fila B;
- modos de reprodução diferentes por fila;
- Sound Pad independente para efeitos, vinhetas, avisos e sons rápidos;
- interface simples e segura para operação ao vivo;
- atalhos de teclado;
- salvamento automático dos projetos.

O aplicativo **não deve se transformar em software de DJ ou DAW**.

---

# 2. Stack recomendada

Utilizar:

- Swift
- SwiftUI
- AVFoundation
- AVAudioEngine
- AVAudioPlayerNode
- AVAudioMixerNode

Arquitetura:

- MVVM
- serviços de áudio isolados;
- lógica fora das Views;
- persistência inicial com Codable + JSON;
- sem bibliotecas externas quando não forem necessárias.

---

# 3. Regras principais

## Filas

Existem inicialmente:

- Queue A
- Queue B

Somente uma fila principal pode estar ativa por vez.

Ao trocar de fila:

1. parar imediatamente a reprodução atual;
2. preservar a seleção da fila anterior;
3. marcar a nova fila como ativa;
4. não iniciar automaticamente nenhuma música.

Selecionar uma fila não significa iniciar a reprodução.

---

# 4. Modos de reprodução

Cada fila possui um modo independente.

## Sequential

Exemplo:

```text
1 -> 2 -> 3 -> 4 -> 5 -> STOP
```

Ao terminar uma faixa, a próxima começa automaticamente.

---

## Shuffle

Deve usar **shuffle bag**, e não simplesmente `randomElement()`.

Exemplo:

```text
Fila:
1 2 3 4 5

Ordem:
4 1 5 2 3
```

Todas as faixas devem ser percorridas antes de repetir uma música.

A última faixa de um ciclo deve, sempre que possível, ser diferente da primeira faixa do ciclo seguinte.

---

## Manual

Modo faixa por faixa.

Exemplo:

```text
Música 1 termina
      ↓
     STOP
```

Nenhuma faixa deve iniciar automaticamente.

O operador deve selecionar a próxima e pressionar Play.

---

# 5. Arquitetura de áudio

As duas filas **não possuem players independentes**.

A arquitetura deve ser:

```text
Queue A ─┐
         ├──> Main Music Player
Queue B ─┘
```

Existe apenas um player principal de músicas.

O Sound Pad utiliza players independentes dentro da mesma `AVAudioEngine`.

```text
                       AVAudioEngine
                            │
                ┌───────────┴───────────┐
                │                       │
          Main Music Player         Sound Pads
                │                       │
           Music Mixer              Pad Mixer
                │                       │
                └───────────┬───────────┘
                            │
                       Main Mixer
                            │
                         Output
```

---

# 6. Estrutura sugerida

```text
DualQueuePlayer/
│
├── App/
│   └── DualQueuePlayerApp.swift
│
├── Models/
│   ├── Track.swift
│   ├── PlaylistQueue.swift
│   ├── PlaybackMode.swift
│   ├── QueueIdentifier.swift
│   ├── SoundPad.swift
│   ├── SoundPadMode.swift
│   └── AppProject.swift
│
├── ViewModels/
│   ├── MainViewModel.swift
│   ├── QueueViewModel.swift
│   └── SoundPadViewModel.swift
│
├── Views/
│   ├── MainView.swift
│   ├── QueueView.swift
│   ├── PlayerControlsView.swift
│   ├── SoundPadView.swift
│   ├── SoundPadEditorView.swift
│   └── SettingsView.swift
│
├── Audio/
│   ├── AudioEngineManager.swift
│   ├── MusicPlayer.swift
│   ├── SoundPadPlayer.swift
│   └── DuckingController.swift
│
├── Services/
│   ├── QueueManager.swift
│   ├── KeyboardShortcutManager.swift
│   └── ProjectStore.swift
│
└── Tests/
```

---

# 7. Interface principal

A interface deve priorizar:

- leitura rápida;
- poucos cliques;
- estado atual evidente;
- botões grandes;
- baixa chance de operação incorreta.

Exemplo:

```text
┌───────────────────────┬───────────────────────┐
│        FILA A         │        FILA B         │
│                       │                       │
│ ● ATIVA               │ ○                     │
│                       │                       │
│ Música 01             │ Música 01             │
│ ▶ Música 02           │ Música 02             │
│ Música 03             │ Música 03             │
│ Música 04             │ Música 04             │
│                       │                       │
│ [+ Adicionar]         │ [+ Adicionar]         │
│                       │                       │
│ Modo                  │ Modo                  │
│ ◉ Sequencial          │ ○ Sequencial          │
│ ○ Aleatório           │ ◉ Aleatório           │
│ ○ Manual              │ ○ Manual              │
└───────────────────────┴───────────────────────┘

              PLAYER PRINCIPAL

       ⏮      ▶ / ⏸      ⏹      ⏭

          Música atual

        03:24 / 05:13

━━━━━━━━━━━━━━━━●━━━━━━━━━━━━━━━━

              SOUND PAD

[ Pad 1 ] [ Pad 2 ] [ Pad 3 ] [ Pad 4 ]

[ Pad 5 ] [ Pad 6 ] [ Pad 7 ] [ Pad 8 ]

[ Pad 9 ] [Pad 10 ] [Pad 11 ] [Pad 12 ]
```

---

# 8. Sound Pad

O Sound Pad deve funcionar independentemente do player principal.

Cada pad terá:

- nome;
- arquivo;
- volume;
- modo;
- atalho opcional;
- opção de loop;
- opção de interromper outros pads.

Modos:

```text
Overlay
Interrupt
Duck
```

---

## Overlay

Toca junto com a música principal.

```text
Música
████████████████████████

          +

Sound Pad
      ███████
```

---

## Interrupt

Ao disparar:

1. parar a música principal;
2. tocar o pad;
3. quando terminar, manter a música parada.

---

## Duck

Exemplo:

```text
Música = 100%

Pad acionado

100%
 ↓
 ↓ 300 ms
 ↓
25%

Pad toca

Pad termina

25%
 ↓
 ↓ 500 ms
 ↓
100%
```

Configuração inicial:

```text
Duck volume: 25%
Fade down: 300 ms
Fade up: 500 ms
```

Se dois pads em Duck estiverem tocando, o volume principal só deve retornar quando ambos terminarem.

---

# 9. Sound Pad por páginas

Exibir 12 pads por página.

Grid:

```text
4 x 3
```

Exemplos de páginas:

- Vinhetas
- Efeitos
- Ambiente
- Avisos
- Culto
- Evento

Permitir:

- criar página;
- renomear;
- reordenar;
- excluir;
- reordenar pads.

---

# 10. Atalhos padrão

```text
SPACE = Play/Pause

ESC = Stop

A = selecionar Fila A

B = selecionar Fila B

← = faixa anterior

→ = próxima faixa

1 = Pad 1
2 = Pad 2
3 = Pad 3
4 = Pad 4
5 = Pad 5
6 = Pad 6
7 = Pad 7
8 = Pad 8
9 = Pad 9
0 = Pad 10
```

Não disparar atalhos quando o usuário estiver digitando em um `TextField`.

---

# 11. Persistência

Salvar inicialmente com:

```text
Codable + JSON
```

Armazenar:

- Queue A;
- Queue B;
- ordem das faixas;
- modos de reprodução;
- faixas selecionadas;
- fila ativa;
- volume;
- Sound Pads;
- páginas;
- configurações;
- atalhos.

Salvar automaticamente em:

```text
~/Library/Application Support/DualQueuePlayer/
```

Criar formato próprio:

```text
.dualqueue
```

Internamente poderá continuar sendo JSON.

---

# 12. Roadmap

## Versão 0.1

- duas filas;
- adicionar músicas;
- reordenar;
- selecionar fila;
- play;
- pause;
- stop;
- next;
- previous;
- sequencial;
- aleatório;
- manual.

---

## Versão 0.2

- Sound Pad;
- 12 pads;
- Overlay;
- volume individual;
- atalhos.

---

## Versão 0.3

- Duck;
- Interrupt;
- fade;
- configurações avançadas do Sound Pad.

---

## Versão 0.5

- projetos;
- autosave;
- páginas de pads;
- atalhos personalizados.

---

## Versão 1.0

- seleção de dispositivo de saída;
- preview/cue;
- múltiplas interfaces;
- histórico;
- repeat;
- fade automático;
- maior robustez.

---

# 13. PROMPTS PARA O CODEX

Use os prompts abaixo na ordem.

---

# Prompt 1 — Estrutura inicial

```text
Quero desenvolver um aplicativo nativo para macOS em Swift + SwiftUI chamado, provisoriamente, "DualQueue Player".

Objetivo do aplicativo:
- possuir duas filas independentes de músicas: Fila A e Fila B;
- apenas uma das filas principais pode estar ativa por vez;
- ao selecionar outra fila, a reprodução atual deve parar;
- selecionar uma fila não deve iniciar automaticamente a reprodução;
- cada fila deve suportar os modos:
  1. sequencial;
  2. aleatório;
  3. manual/faixa por faixa;
- futuramente haverá um Sound Pad independente da reprodução principal.

Quero começar apenas pela arquitetura e interface, sem implementar reprodução de áudio ainda.

Crie uma estrutura de projeto limpa utilizando MVVM e SwiftUI.

Crie inicialmente os seguintes modelos:
- Track
- PlaylistQueue
- PlaybackMode
- QueueIdentifier

Requisitos:
- Track deve possuir UUID, nome, URL do arquivo e duração.
- PlaylistQueue deve possuir UUID, nome, lista de Track, índice/faixa selecionada e PlaybackMode.
- PlaybackMode deve ter sequential, shuffle e manual.
- QueueIdentifier deve identificar queueA e queueB.
- Os modelos que precisarem ser persistidos futuramente devem ser Codable.

Crie também:
- MainView
- QueueView
- PlayerControlsView
- QueueViewModel
- MainViewModel

Na MainView, exiba Fila A e Fila B lado a lado.

Cada QueueView deve mostrar:
- nome da fila;
- indicação visual de fila ativa;
- lista das músicas;
- botão para adicionar arquivos;
- seletor de modo: Sequencial, Aleatório e Manual;
- botões anterior, play/pause, stop e próxima.

Não implemente o áudio ainda.
Não use bibliotecas externas.

Ao final:
1. mostre a estrutura de diretórios criada;
2. explique resumidamente a responsabilidade de cada arquivo;
3. compile o projeto e corrija quaisquer erros encontrados.
```

---

# Prompt 2 — Arquivos e Drag & Drop

```text
Continue o projeto DualQueue Player existente.

Agora implemente gerenciamento de arquivos de áudio nas duas filas.

Requisitos:
- permitir adicionar arquivos usando NSOpenPanel;
- permitir drag & drop diretamente sobre cada QueueView;
- formatos aceitos inicialmente:
  - mp3
  - wav
  - m4a
  - aac
  - aiff;
- ao adicionar um arquivo, crie um Track;
- tente obter automaticamente o título e a duração do áudio;
- se não houver metadado de título, use o nome do arquivo;
- impedir que um arquivo não suportado seja adicionado;
- mostrar mensagem amigável em caso de erro.

Na lista de músicas:
- permitir selecionar uma faixa;
- permitir remover uma faixa;
- permitir reordenar faixas por drag & drop;
- permitir adicionar vários arquivos de uma vez.

A Fila A e a Fila B devem ser completamente independentes.

Não implemente reprodução de áudio ainda.

Mantenha o código organizado e reutilizável, evitando duplicação entre Fila A e Fila B.

Compile e teste os principais fluxos após a implementação.
```

---

# Prompt 3 — Engine de áudio

```text
Continue o DualQueue Player.

Agora implemente a engine principal de reprodução utilizando AVFoundation e AVAudioEngine.

Arquitetura desejada:

AVAudioEngine
  -> AVAudioPlayerNode para música principal
  -> AVAudioMixerNode para música
  -> mainMixerNode
  -> output

Crie um AudioEngineManager responsável exclusivamente pela engine de áudio.

Ele deve possuir:
- play(track:)
- pause()
- resume()
- stop()
- seek(to:)
- volume
- isPlaying
- currentTime
- duration
- callback/evento quando uma faixa terminar.

Requisitos importantes:
- deve existir somente um player principal de música;
- Fila A e Fila B NÃO devem possuir players separados;
- as filas apenas determinam qual Track será enviado para o MusicPlayer;
- preparar corretamente o AVAudioEngine;
- lidar com arquivos incompatíveis sem crash;
- atualizar o progresso da faixa para a interface;
- liberar corretamente recursos ao trocar de música.

Integre com PlayerControlsView.

A interface deve mostrar:
- música atual;
- tempo atual;
- duração total;
- slider para seek;
- volume;
- play/pause;
- stop;
- anterior;
- próxima.

Mantenha toda lógica de AVFoundation fora das Views.

Compile o projeto e corrija possíveis erros.
```

---

# Prompt 4 — Alternância entre filas

```text
Continue o DualQueue Player.

Agora implemente corretamente a alternância entre Fila A e Fila B.

Regra principal:
somente uma fila pode estar ativa por vez.

Comportamento esperado:

Se Fila A estiver tocando e o usuário clicar para selecionar Fila B:
1. parar imediatamente a reprodução da Fila A;
2. manter registrada a faixa selecionada da Fila A;
3. marcar Fila B como ativa;
4. NÃO iniciar automaticamente nenhuma música da Fila B.

Depois, quando o usuário apertar Play:
- iniciar a faixa atualmente selecionada da Fila B;
- se nenhuma estiver selecionada, selecionar a primeira.

O mesmo vale no sentido inverso.

Crie um QueueManager ou lógica equivalente no MainViewModel.

Estados importantes:
- activeQueue
- selectedTrack de cada fila
- currentPlayingTrack
- playbackState

Evite inconsistências como:
- fila marcada ativa enquanto outra toca;
- duas filas consideradas ativas;
- play em uma fila inativa;
- UI exibindo faixa errada.

Adicione testes unitários para esses comportamentos.
```

---

# Prompt 5 — Sequential

```text
Continue o projeto.

Implemente o PlaybackMode.sequential.

Comportamento:

Fila:
1
2
3
4
5

Se começar na faixa 2:

2 -> 3 -> 4 -> 5 -> stop

Quando a faixa atual terminar:
- selecionar automaticamente a próxima;
- iniciar automaticamente a próxima;
- ao chegar ao fim da fila, parar.

O botão Next deve:
- ir para a próxima faixa;
- se estiver tocando, iniciar a próxima imediatamente;
- se estiver parado, apenas selecionar a próxima.

O botão Previous deve ter comportamento equivalente.

Garanta que a lógica esteja no ViewModel/QueueManager e não na View.

Adicione testes unitários.
```

---

# Prompt 6 — Manual

```text
Implemente o PlaybackMode.manual.

Esse modo representa reprodução faixa por faixa.

Quando uma música terminar:
- parar;
- não iniciar automaticamente nenhuma outra faixa.

O usuário deverá:
- selecionar uma faixa;
- pressionar Play.

No modo manual:
- Next apenas seleciona a próxima faixa quando o player estiver parado;
- se o usuário usar Next enquanto estiver tocando, pare a faixa atual e selecione a próxima, mas não toque automaticamente.

O mesmo comportamento deve existir para Previous.

Adicione testes para o modo manual.
```

---

# Prompt 7 — Shuffle

```text
Implemente PlaybackMode.shuffle.

Não utilize simplesmente randomElement(), pois não quero repetições frequentes.

Implemente um shuffle bag.

Exemplo:

Fila original:
1 2 3 4 5

Ordem embaralhada:
4 1 5 2 3

Percorra todas as músicas antes de gerar uma nova ordem aleatória.

Requisitos:
- não repetir música enquanto ainda existirem faixas não reproduzidas no ciclo atual;
- quando todas forem reproduzidas, criar novo ciclo;
- tentar evitar que a última faixa do ciclo anterior seja a primeira do próximo;
- se músicas forem adicionadas/removidas, atualizar o estado de shuffle corretamente;
- trocar de fila deve preservar o estado de shuffle daquela fila.

Next deve seguir a ordem do shuffle.
Previous deve navegar pelo histórico real do shuffle.

Adicione testes unitários cobrindo esses cenários.
```

---

# Prompt 8 — Persistência

```text
Adicione persistência local ao DualQueue Player.

Não use SwiftData/Core Data inicialmente.

Use Codable + JSON.

Crie um ProjectStore.

Persistir:
- Fila A;
- Fila B;
- ordem das músicas;
- nomes;
- modo de reprodução de cada fila;
- faixa selecionada;
- volume;
- fila ativa;
- configurações gerais;
- futuramente Sound Pads.

Salvar em Application Support.

Implemente autosave quando houver mudanças relevantes.

Ao abrir o aplicativo:
- restaurar automaticamente o último projeto;
- verificar se os arquivos de áudio ainda existem;
- marcar visualmente arquivos ausentes;
- não causar crash se um arquivo tiver sido movido/removido.

Também crie os métodos:
- newProject()
- saveProject()
- saveProjectAs()
- openProject()

Use extensão própria de projeto, por exemplo:
.dualqueue

Pode ser internamente JSON.

Compile e teste abertura e fechamento do app.
```

---

# Prompt 9 — Sound Pad básico

```text
Agora adicione o Sound Pad ao DualQueue Player.

O Sound Pad deve ser independente do Music Player.

Arquitetura:

AVAudioEngine
├── MusicPlayerNode
│   └── MusicMixer
│
├── SoundPad Player Nodes
│   └── SoundPadMixer
│
└── MainMixer
    └── Output

Crie:

SoundPad
- id
- name
- fileURL
- volume
- mode
- keyboardShortcut opcional

SoundPadMode:
- overlay
- interrupt
- duck

Primeiramente implemente apenas overlay.

Interface:
- grid 4x3;
- 12 pads por página;
- botão para adicionar/configurar áudio de cada pad;
- botão para apagar pad;
- mostrar nome;
- mostrar indicador enquanto o pad estiver tocando.

Ao clicar:
- tocar o efeito;
- não interromper a música;
- permitir música + efeito simultaneamente.

Permitir também mais de um Sound Pad tocando simultaneamente.

Evite criar AVAudioEngine separado.
Tudo deve usar a mesma engine.

Adicione gerenciamento adequado de AVAudioPlayerNode para os pads.
```

---

# Prompt 10 — Configuração dos pads

```text
Continue o Sound Pad.

Ao clicar com botão direito ou abrir edição de um pad, mostrar um formulário/modal com:

- nome;
- arquivo de áudio;
- volume;
- modo:
  - Overlay
  - Interrupt
  - Duck
- atalho;
- opção "parar outros pads ao tocar";
- opção "loop";
- botão testar;
- botão salvar.

Permitir drag & drop de arquivo diretamente sobre um pad vazio.

Adicionar páginas/categorias de Sound Pad.

Exemplo:
- Vinhetas
- Efeitos
- Ambiente
- Avisos

Cada página possui até 12 pads.

Permitir:
- criar página;
- renomear;
- reordenar;
- excluir.

Persistir tudo no projeto.
```

---

# Prompt 11 — Interrupt

```text
Implemente SoundPadMode.interrupt.

Quando um pad configurado como interrupt for acionado:

1. se a música principal estiver tocando:
   - parar a música;
2. tocar o Sound Pad;
3. ao terminar o Sound Pad:
   - permanecer com a música parada.

Não reinicie automaticamente a música.

Garanta que:
- o estado visual da música seja atualizado;
- o botão Play volte a funcionar normalmente;
- não haja referência incorreta de isPlaying.

Adicione testes.
```

---

# Prompt 12 — Ducking

```text
Implemente SoundPadMode.duck.

Comportamento:

Música tocando a 100%.

Ao tocar um Sound Pad em modo Duck:
- reduzir gradualmente o volume do MusicMixer;
- tocar o Sound Pad;
- quando o pad terminar;
- restaurar gradualmente o volume anterior.

Configuração padrão:

duckVolume = 0.25
fadeDownDuration = 0.3 segundos
fadeUpDuration = 0.5 segundos

Crie um DuckingController.

Requisitos:
- não alterar permanentemente o volume selecionado pelo usuário;
- se dois pads em modo Duck forem reproduzidos simultaneamente, não restaurar o volume até que todos os pads Duck tenham terminado;
- evitar saltos bruscos de volume;
- se um pad for interrompido manualmente, recalcular corretamente o ducking;
- se não houver música tocando, simplesmente tocar o pad.

Adicionar configurações globais:
- volume do ducking;
- fade down;
- fade up.

Persistir as configurações.
```

---

# Prompt 13 — Atalhos

```text
Implemente atalhos globais dentro do aplicativo.

Padrão:

Space = Play/Pause
Esc = Stop
A = selecionar Fila A
B = selecionar Fila B
Seta direita = Next
Seta esquerda = Previous

Sound Pads:
1 = Pad 1
2 = Pad 2
3 = Pad 3
...
0 = Pad 10

Permita que os atalhos dos Sound Pads sejam personalizados posteriormente.

Requisitos:
- não disparar atalhos quando o usuário estiver digitando em TextField;
- evitar conflitos de atalhos;
- mostrar atalhos visualmente nos botões;
- centralizar a lógica em KeyboardShortcutManager ou serviço equivalente.
```

---

# Prompt 14 — UX para operação ao vivo

```text
Faça uma revisão completa da interface pensando em uso ao vivo.

Prioridades:
- poucos cliques;
- informação clara;
- botões grandes;
- estado atual muito evidente;
- evitar acionamentos acidentais.

Na Fila A e Fila B mostrar claramente:
- ATIVA;
- INATIVA;
- TOCANDO;
- PAUSADA.

No player principal mostrar em destaque:
- faixa atual;
- fila atual;
- tempo;
- próxima música.

Adicionar seção:

PRÓXIMA FAIXA

para que o operador saiba antecipadamente o que tocará.

No modo Manual, indicar claramente:
"aguardando comando".

No modo Shuffle, mostrar:
"aleatório".

No modo Sequencial:
"sequencial".

Não exagere em animações.

Use estética nativa de macOS, limpa e profissional.
```

---

# Prompt 15 — Robustez

```text
Faça uma revisão da robustez do player.

Teste e corrija situações como:

- clicar Play várias vezes rapidamente;
- apertar Next rapidamente;
- trocar Fila A/B durante carregamento;
- apagar a faixa que está tocando;
- remover arquivo do disco;
- arquivo corrompido;
- arquivo incompatível;
- fechar o projeto enquanto está tocando;
- fechar o app enquanto pads estão tocando;
- colocar Mac em sleep;
- dispositivo de áudio mudar;
- AVAudioEngine parar inesperadamente.

O aplicativo nunca deve crashar por causa de uma operação normal do usuário.

Adicione tratamento de erro amigável.

Crie logging básico para facilitar debug.

Não mostre mensagens técnicas demais para o usuário final.
```

---

# Prompt 16 — Preview / Cue

```text
Adicione uma primeira arquitetura para Preview / Cue.

Objetivo:
permitir que o operador escute uma música antes de colocá-la na reprodução principal.

Na lista de faixas adicionar botão:

🎧 Preview

Não altere a música que está tocando no Main Output.

Crie PreviewPlayer separado do Main MusicPlayer.

Por enquanto:
- permita selecionar o dispositivo de áudio usado pelo Preview;
- se não for possível fazer routing confiável apenas com AVAudioEngine, investigue Core Audio;
- não comprometa o funcionamento atual do player.

A interface deve permitir:
Main Output: dispositivo X
Preview Output: dispositivo Y

Documente claramente as limitações encontradas.
```

---

# Prompt 17 — Testes

```text
Crie uma suíte de testes para o DualQueue Player.

Priorize lógica de negócio em vez de testes de UI.

Cobrir:

QueueManager:
- troca A -> B;
- troca B -> A;
- fila ativa;
- parar áudio ao trocar.

Playback:
- sequencial;
- manual;
- shuffle;
- final da fila;
- lista vazia;
- uma única música.

Shuffle:
- não repetir antes de percorrer ciclo;
- previous usa histórico;
- alteração da fila.

Sound Pad:
- overlay;
- interrupt;
- duck;
- múltiplos duck simultâneos.

Persistência:
- salvar;
- carregar;
- arquivos inexistentes.

Crie mocks para o serviço de áudio para não depender da saída física de áudio durante testes.
```

---

# Prompt 18 — Auditoria da versão 1.0

```text
Faça uma auditoria completa do projeto DualQueue Player antes da versão 1.0.

Analise:

1. arquitetura;
2. acoplamento;
3. duplicação;
4. possíveis retain cycles;
5. concorrência;
6. uso correto do MainActor;
7. AVAudioEngine;
8. gerenciamento de AVAudioPlayerNode;
9. persistência;
10. tratamento de erros;
11. performance;
12. consumo de memória;
13. comportamento ao trocar de fila;
14. comportamento dos Sound Pads;
15. UX de operação ao vivo.

Não reescreva o projeto inteiro desnecessariamente.

Liste primeiro os problemas encontrados por severidade:
- crítico;
- alto;
- médio;
- baixo.

Depois corrija os problemas críticos e altos.

Compile e execute os testes ao final.
```

---

# 14. AGENTS.md recomendado

Criar na raiz do projeto:

```text
AGENTS.md
```

Conteúdo sugerido:

```markdown
# DualQueue Player

Aplicativo nativo macOS desenvolvido com Swift + SwiftUI.

## Objetivo

Player de áudio voltado para operação ao vivo.

Existem duas filas principais:
- Queue A
- Queue B

Somente uma fila pode estar ativa por vez.

Trocar de fila:
- para a reprodução atual;
- seleciona a nova fila;
- não inicia automaticamente a nova fila.

## Playback modes

Cada fila suporta:

### Sequential
Ao terminar uma faixa, inicia automaticamente a próxima.

### Shuffle
Usa shuffle bag.
Não repetir músicas até percorrer toda a fila.

### Manual
Ao terminar uma faixa, para.
A próxima música nunca deve iniciar automaticamente.

## Main Player

Existe somente UM player principal de músicas.

Não criar um player independente por fila.

As filas são apenas fontes de Tracks.

## Sound Pad

Existe um Sound Pad independente do Music Player.

Modos:

- Overlay
- Interrupt
- Duck

### Overlay
Toca junto com a música.

### Interrupt
Para a música e toca o pad.

### Duck
Reduz temporariamente o volume da música enquanto o pad toca.

## Audio

Usar:
- AVFoundation
- AVAudioEngine
- AVAudioPlayerNode
- AVAudioMixerNode

Evitar bibliotecas externas sem necessidade.

## Interface

Priorizar:
- confiabilidade;
- clareza;
- operação rápida;
- botões grandes;
- pouco risco de erro durante eventos.

Não transformar o aplicativo em software de DJ.

Não implementar:
- BPM;
- beat matching;
- pitch;
- waveform complexo;
- VST;
- DAW.

A aplicação deve continuar simples.

## Arquitetura

Preferir:
- MVVM;
- Views simples;
- lógica fora de SwiftUI Views;
- serviços de áudio isolados;
- código testável.

## Regra principal

Nunca permitir duas filas principais tocando simultaneamente.

Sound Pads podem tocar simultaneamente com a música principal quando o modo permitir.
```

---

# 15. Ordem recomendada de execução

Executar no Codex nesta ordem:

```text
1. Estrutura inicial
2. Arquivos e Drag & Drop
3. Engine de áudio
4. Alternância entre filas
5. Sequential
6. Manual
7. Shuffle
8. Persistência
9. Sound Pad
10. Configuração dos pads
11. Interrupt
12. Duck
13. Atalhos
14. UX
15. Robustez
16. Preview / Cue
17. Testes
18. Auditoria final
```

Evitar pedir ao Codex para desenvolver tudo em um único prompt.

A cada etapa:

1. implementar;
2. compilar;
3. corrigir erros;
4. executar os testes;
5. somente então passar para o próximo prompt.

---

# 16. Princípios do projeto

Priorizar sempre:

```text
CONFIABILIDADE
      ↓
PREVISIBILIDADE
      ↓
FACILIDADE DE USO
      ↓
VELOCIDADE DE OPERAÇÃO
      ↓
ESTÉTICA
```

Este é um aplicativo para operação ao vivo.

Portanto, é melhor ter:

```text
um botão simples que sempre funciona
```

do que:

```text
uma interface sofisticada com comportamento imprevisível
```

O DualQueue Player deve permanecer simples, rápido e confiável.
