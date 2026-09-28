# Plano de implementação — Modo Performance

> Status: plano técnico. Nenhuma funcionalidade deste documento está implementada.

## Objetivo

Adicionar ao DualQueue Player um modo para operar músicas, efeitos, vozes e sons em apresentações, danças, teatros e esquetes.

O recurso deve permitir:

- criar e selecionar espetáculos;
- organizar cada espetáculo em cenas;
- manter uma lista sequencial de itens em cada cena;
- disparar itens imediatamente;
- pausar, retomar e parar itens individuais;
- tocar vários itens simultaneamente quando configurado;
- controlar o tempo da cena separadamente do tempo do áudio;
- visualizar a mesma lista como sequência única ou como cues agrupadas por classificação;
- preservar as regras atuais do Player, das filas A/B e do Sound Pad.

## Decisão de domínio

A cena terá uma única fonte de verdade: uma lista ordenada de itens.

```text
Espetáculo
└── Cena
    └── items: [PerformanceItem]
```

As classificações (`Trilha`, `Efeito`, `Voz`, `Ambiente` etc.) serão metadados dos itens. A visualização por grupos será derivada dessa lista, e não armazenada como grupos independentes.

Isso evita que a ordem fique diferente entre a visualização em lista e a visualização agrupada.

## Limites da primeira versão

### Incluído

- espetáculos e cenas;
- lista sequencial ordenável;
- classificação por item;
- visualização `Lista`;
- visualização `Cues agrupadas` derivada da lista;
- disparo manual imediato;
- pausa, retomada e parada individuais;
- pausar/retomar tudo;
- parar todos os sons do modo Performance;
- loops;
- sobreposição de áudios;
- relógio de cena com iniciar, pausar, retomar, zerar e progresso manual;
- indicação de tempo atual e duração do item em execução;
- arquivos ausentes identificados antes da execução;
- atalhos contextuais;
- persistência no arquivo `.dualqueue`;
- operação integrada à atual arquitetura MVVM.

### Fora da primeira versão

- disparo automático por timecode;
- agendamento de itens por offset de tempo;
- timeline de edição;
- sincronização com iluminação ou vídeo;
- roteamento multicanal avançado;
- crossfade obrigatório;
- edição complexa de áudio;
- waveform complexo;
- BPM, beat matching, pitch, VST ou recursos de DAW.

O relógio da cena será um controle operacional e uma referência visual. Ele não deve iniciar automaticamente os áudios na primeira versão.

## Modelo de dados

Criar modelos em `DualQueuePlayer/Models/`.

### `PerformanceProject`

Representa um espetáculo salvo dentro do projeto `.dualqueue`.

Campos sugeridos:

```swift
struct PerformanceProject: Identifiable, Codable {
    let id: UUID
    var name: String
    var kind: PerformanceProjectKind
    var scenes: [PerformanceScene]
    var selectedSceneID: UUID?
    var defaultDisplayMode: PerformanceDisplayMode
    var stopAllScope: PerformanceStopScope
    var keepActiveItemsOnSceneChange: Bool
}
```

`kind` pode começar como `theater`, `dance`, `sketch` e `other`, apenas para identificação. Não deve alterar a lógica de reprodução.

### `PerformanceScene`

Representa um momento do espetáculo.

```swift
struct PerformanceScene: Identifiable, Codable {
    let id: UUID
    var name: String
    var items: [PerformanceItem]
    var expectedDuration: TimeInterval?
}
```

`items` é a sequência oficial da cena. A ordenação deve ser alterada apenas nessa coleção.

`expectedDuration` é opcional porque a duração total pode não ser a soma das durações dos arquivos quando existem sobreposições ou loops.

### `PerformanceItem`

Representa uma faixa, efeito, voz ou ambiente disparável.

```swift
struct PerformanceItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var classification: PerformanceClassification
    var fileURL: URL?
    var volume: Double
    var playback: PerformancePlayback
    var transition: PerformanceTransition
    var keyboardShortcut: String?
    var isMissing: Bool
}
```

Enums sugeridos:

```swift
enum PerformanceClassification: String, Codable, CaseIterable {
    case track
    case effect
    case voice
    case ambience
    case transition
    case other
}

enum PerformancePlayback: String, Codable, CaseIterable {
    case once
    case loop
}

enum PerformanceTransition: String, Codable, CaseIterable {
    case stopOnSceneChange
    case keepOnSceneChange
}
```

O comportamento de mixagem (`overlay`, `interrupt`, `duck`) deve ser avaliado em conjunto com `SoundPadMode`. Se o mesmo comportamento for necessário nos dois módulos, extrair um enum comum em vez de duplicar a regra.

### Estado somente de execução

Não persistir estados temporários como `isPlaying` ou `currentTime` no projeto. Eles devem existir no ViewModel:

```swift
struct ActivePerformanceItem {
    let itemID: UUID
    var state: PerformanceItemState
    var currentTime: TimeInterval
    var duration: TimeInterval
}
```

O projeto salva configuração; a sessão salva apenas estado transitório em memória.

## Persistência e compatibilidade

Adicionar ao `AppProject`:

```swift
var performanceProjects: [PerformanceProject]
var selectedPerformanceProjectID: UUID?
```

Como o projeto atual usa `Codable` sintetizado, será necessário implementar `init(from:)` manual em `AppProject` ou usar `decodeIfPresent` para que arquivos `.dualqueue` antigos continuem abrindo:

```swift
performanceProjects = try values.decodeIfPresent(
    [PerformanceProject].self,
    forKey: .performanceProjects
) ?? []
```

Também definir valores padrão para:

- nenhum espetáculo selecionado;
- lista vazia de cenas quando o módulo ainda não foi usado;
- visualização padrão `list`;
- escopo de parada `performanceOnly`;
- manter sons na troca de cena desativado ou explicitamente escolhido pelo usuário.

Ao criar um novo `AppProject.empty`, não é necessário criar um espetáculo automaticamente. A tela inicial do módulo pode oferecer `Novo espetáculo`.

## Arquitetura de ViewModel

Criar `PerformanceViewModel` em `DualQueuePlayer/ViewModels/PerformanceViewModel.swift`.

Responsabilidades:

- gerenciar espetáculos e cena selecionados;
- criar, renomear, remover e reordenar cenas;
- criar, editar, remover e reordenar itens;
- trocar a visualização entre lista e cues agrupadas;
- controlar o relógio da cena;
- manter os itens ativos;
- encaminhar comandos ao serviço de áudio;
- publicar mensagens de erro e estados operacionais;
- solicitar persistência ao `MainViewModel` ou a um callback de alteração.

API conceitual:

```swift
func selectProject(_ id: UUID)
func selectScene(_ id: UUID)
func addScene(named name: String)
func renameScene(_ id: UUID, to name: String)
func removeScene(_ id: UUID)
func moveScene(_ id: UUID, before targetID: UUID)

func addItem(to sceneID: UUID)
func updateItem(_ item: PerformanceItem)
func removeItem(_ id: UUID, from sceneID: UUID)
func moveItem(_ id: UUID, before targetID: UUID, in sceneID: UUID)

func trigger(_ itemID: UUID)
func pause(_ itemID: UUID)
func resume(_ itemID: UUID)
func stop(_ itemID: UUID)
func pauseAll()
func resumeAll()
func stopAll()

func startSceneClock()
func pauseSceneClock()
func resetSceneClock()
func seekSceneClock(to time: TimeInterval)
```

As Views não devem decidir regras de transição, ordem ou áudio.

## Integração com `MainViewModel`

O `MainViewModel` atual concentra o projeto, o player principal, as filas e o Sound Pad. Existem duas opções:

### Opção recomendada

Adicionar uma propriedade:

```swift
@Published var performance: PerformanceViewModel
```

O `MainViewModel` continua sendo o dono do projeto e repassa alterações para persistência. O `PerformanceViewModel` recebe o serviço de áudio por injeção.

### Evolução futura

Se o estado crescer muito, extrair a coordenação de `MainViewModel` para um `AppWorkspaceViewModel`. Isso não é necessário para a primeira implementação.

## Integração com a interface atual

O layout atual em `MainView.swift` deve ser preservado para o Player.

Adicionar um estado de área de trabalho, por exemplo:

```swift
enum WorkspaceMode {
    case player
    case performance
}
```

O topo pode ganhar uma troca de modo, mantendo os botões existentes `Projeto`, `Salvar` e `Novo`.

### Player

Continua exibindo:

- Queue A;
- Queue B;
- Sound Pad;
- Saídas de áudio;
- Reprodução Atual;
- Próxima faixa.

### Performance — seleção de espetáculo

Pode usar a mesma janela, fundo e `dqPanel()` para exibir:

- projetos recentes;
- botão `Novo espetáculo`;
- cenas recentes;
- estado de disponibilidade dos arquivos.

### Performance — execução

A composição recomendada é:

- painel principal largo para a cena;
- título e cena atual;
- navegação entre cenas;
- relógio e progresso da cena;
- controles `Iniciar`, `Pausar`, `Zerar`;
- botão `Parar tudo` sempre visível;
- seletor `Lista` / `Cues`;
- lista sequencial como padrão;
- painel `Ativos agora`;
- classificação ao lado de cada item.

Na visualização `Lista`, todos os itens aparecem em uma única sequência.

Na visualização `Cues`, os mesmos itens são apresentados em colunas ou seções derivadas de `classification`. Nenhuma operação de áudio deve depender de uma visualização específica.

## Serviço de áudio

O `AudioEngineManager` atual possui um player principal para música e players separados para pads. Não criar um segundo player principal para Performance.

### Extensão recomendada

Generalizar o conceito de fontes independentes:

```text
Player principal ── Music Mixer ── Main Mixer ── Output
Sound Pad         ── Pad Mixer ──── Main Mixer ── Output
Performance       ── Cue Mixer ──── Main Mixer ── Output
```

O `Cue Mixer` pode ser um `AVAudioMixerNode` próprio conectado ao `mainMixerNode`.

Manter um `AVAudioPlayerNode` por item ativo:

```swift
private var performancePlayers: [UUID: AVAudioPlayerNode]
```

Também manter os arquivos agendados e os tokens de execução para evitar que callbacks antigos alterem o estado de uma reprodução nova.

### API de áudio sugerida

Adicionar métodos específicos ou um serviço separado, sem colocar regra de cena dentro do View:

```swift
func playPerformanceItem(
    id: UUID,
    url: URL,
    volume: Float,
    loops: Bool
) throws

func pausePerformanceItem(id: UUID)
func resumePerformanceItem(id: UUID)
func stopPerformanceItem(id: UUID)
func stopAllPerformanceItems()
```

O serviço deve informar:

- início da reprodução;
- pausa;
- parada;
- conclusão de item;
- erro de arquivo;
- duração e tempo atual, quando disponíveis.

### Loops

O loop deve ser implementado de forma previsível e testado com arquivos curtos e longos. A implementação atual de loop dos pads deve ser revisada antes de ser reutilizada, pois o módulo Performance terá controles individuais de pausa e parada.

### Pausa versus parada

- `pause`: preserva a posição atual do player;
- `stop`: encerra o player e retorna o item ao início;
- `stopAllPerformanceItems`: afeta apenas o mixer de Performance por padrão.

## Relógio da cena

O relógio da cena deve ser responsabilidade do `PerformanceViewModel`, não do `AudioEngineManager`, porque ele não representa necessariamente um áudio.

Estado sugerido:

```swift
enum SceneClockState {
    case stopped
    case running
    case paused
}

@Published private(set) var sceneElapsedTime: TimeInterval = 0
@Published private(set) var sceneClockState: SceneClockState = .stopped
```

Regras:

- iniciar começa ou retoma o relógio;
- pausar congela o tempo;
- zerar retorna a `00:00`;
- o progresso manual é limitado à duração esperada da cena;
- trocar de cena pausa e zera o relógio, salvo decisão diferente posterior;
- o relógio não dispara itens automaticamente na primeira versão.

Usar um `Timer` no ViewModel ou um mecanismo baseado em `ContinuousClock`, mantendo atualizações na MainActor. O relógio não deve depender do ciclo de renderização da SwiftUI.

## Troca de cena

Ao trocar de cena:

1. atualizar a cena selecionada;
2. pausar e zerar o relógio da nova cena;
3. manter ou parar os itens ativos de acordo com a configuração do projeto;
4. parar itens marcados como `stopOnSceneChange`;
5. preservar visualmente os itens que continuam ativos;
6. não iniciar automaticamente o primeiro item da nova cena.

O padrão recomendado é parar os itens da cena anterior, deixando a continuidade de ambientes como uma configuração explícita.

## Atalhos

O `KeyboardShortcutManager` atual já evita conflitos com campos de texto. A lógica deve passar a ser contextual:

### No Player

Preservar os atalhos existentes:

- `Space`: Play/Pause da fila principal;
- `Esc`: parar player principal;
- `A` / `B`: selecionar fila;
- `←` / `→`: anterior / próxima;
- `0`–`9`: Sound Pad.

### No Performance

Sugestão inicial:

- `Space`: pausar/retomar todos os sons de Performance;
- `Esc`: parar todos os sons de Performance;
- `←` / `→`: item anterior / próximo da lista;
- `Shift + ←` / `Shift + →`: cena anterior / próxima;
- atalho configurado no item: disparar item específico.

Não reutilizar automaticamente `0`–`9` para Performance sem uma decisão explícita, pois esses atalhos já pertencem ao Sound Pad no Player.

## Tratamento de arquivos

Ao importar ou editar um item:

- aceitar os formatos já suportados pelo app;
- calcular e armazenar a duração quando possível;
- verificar a existência do arquivo;
- marcar o item como ausente sem causar crash;
- impedir o disparo de arquivo ausente;
- exibir a mensagem no padrão atual do app.

Uma validação de projeto antes da apresentação deve listar arquivos ausentes de todas as cenas.

## Persistência e autosave

Alterações que devem chamar `autosaveProject()`:

- criar, renomear ou remover espetáculo;
- criar, renomear ou remover cena;
- reordenar cenas;
- adicionar, editar, remover ou reordenar item;
- alterar volume, classificação, loop ou comportamento de transição;
- alterar atalhos;
- alterar configuração do modo Performance.

O relógio da cena e os estados de áudio não devem disparar autosave a cada atualização de tempo.

## Fases de implementação

### Fase 0 — Fechar decisões de produto

- confirmar o nome final: `Performance` ou `Cues`;
- confirmar classificações iniciais;
- confirmar se a duração esperada da cena será manual, calculada ou opcional;
- confirmar o comportamento padrão na troca de cena;
- confirmar se o relógio é apenas referência ou se futuramente poderá controlar automações.

**Saída:** decisões registradas e sem ambiguidades para o modelo de dados.

### Fase 1 — Modelos e migração

- criar `PerformanceProject`, `PerformanceScene` e `PerformanceItem`;
- criar enums de classificação, reprodução e transição;
- adicionar campos ao `AppProject`;
- implementar `Codable` compatível com arquivos antigos;
- adicionar normalização de seleção e IDs;
- adicionar testes de encode/decode e migração.

**Saída:** um projeto antigo abre sem alteração visível e um novo projeto pode armazenar Performance.

### Fase 2 — Motor de áudio

- separar o mixer de Performance;
- adicionar players por item ativo;
- implementar play, pause, resume e stop individuais;
- implementar stop all restrito ao módulo;
- implementar loops confiáveis;
- adicionar callbacks com identificador do item;
- tratar arquivos ausentes e erros;
- validar coexistência com música principal e Sound Pad.

**Saída:** dois ou mais itens podem tocar em paralelo sem interromper indevidamente a fila principal.

### Fase 3 — `PerformanceViewModel`

- criar seleção de projeto e cena;
- implementar CRUD de cenas e itens;
- implementar reordenação;
- implementar itens ativos;
- implementar visualização `Lista` / `Cues`;
- implementar relógio da cena;
- implementar transição entre cenas;
- conectar persistência e mensagens.

**Saída:** as regras funcionam sem depender de Views.

### Fase 4 — Interface de configuração

- criar tela de espetáculos;
- criar editor de cena;
- criar editor de item;
- permitir escolher arquivo, classificação, volume, loop, transição e atalho;
- indicar arquivos ausentes;
- manter a aparência baseada em `Theme.swift` e `dqPanel()`.

**Saída:** um operador consegue preparar um espetáculo antes da apresentação.

### Fase 5 — Interface de execução

- integrar modo Performance ao `MainView`;
- criar execução com lista sequencial padrão;
- criar visualização agrupada derivada;
- adicionar relógio e progresso;
- adicionar ativos agora;
- adicionar pausa, parada e botão de emergência;
- preservar a composição visual atual do app.

**Saída:** um operador consegue executar uma cena sem abrir telas de configuração.

### Fase 6 — Atalhos e proteção operacional

- tornar atalhos contextuais;
- implementar atalho de parar tudo;
- impedir atalhos em campos de texto;
- indicar visualmente o modo atual;
- adicionar confirmação apenas em ações destrutivas de preparação, nunca em comandos de emergência;
- revisar acessibilidade, contraste e tamanhos dos controles.

**Saída:** o modo Performance não interfere nas filas ou no Sound Pad sem intenção explícita.

### Fase 7 — Testes e validação

- adicionar testes de domínio;
- testar persistência de projetos antigos;
- testar transições de cena;
- testar pausa/parada individual e global;
- testar loops e sobreposição;
- testar fila principal + Performance + Sound Pad em paralelo;
- testar arquivos ausentes;
- testar atalhos;
- validar manualmente com saída de áudio real.

**Saída:** comportamento previsível para ensaio e operação real.

## Testes de domínio mínimos

Criar testes em `Tests/DualQueuePlayerTests/` para:

1. manter a ordem ao adicionar e reordenar itens;
2. gerar a visualização agrupada sem alterar a lista original;
3. preservar a classificação de cada item;
4. não repetir ou remover itens ao alternar entre visualizações;
5. iniciar, pausar, retomar e zerar o relógio;
6. limitar o progresso ao tempo total da cena;
7. parar somente itens marcados ao trocar de cena;
8. manter itens configurados como contínuos;
9. impedir reprodução de arquivo ausente;
10. parar todos os itens ativos sem parar a música principal;
11. abrir projetos antigos sem o campo Performance;
12. salvar e reabrir cenas, itens e configurações.

## Critérios de aceite do MVP

O MVP estará pronto quando:

- o operador puder criar um espetáculo com pelo menos uma cena;
- cada cena aceitar uma lista ordenada de itens;
- a lista for a visualização padrão;
- cada item mostrar nome, classificação, duração e estado;
- a visualização agrupada mostrar os mesmos itens sem duplicação;
- o relógio da cena iniciar, pausar, retomar, zerar e aceitar ajuste manual;
- pelo menos dois áudios puderem tocar simultaneamente;
- pausa e parada forem ações distintas;
- `Parar tudo` não interromper a fila principal por padrão;
- trocar de cena não iniciar áudio automaticamente;
- arquivos ausentes forem identificados sem crash;
- o projeto for salvo e reaberto em `.dualqueue`;
- as filas A/B e o Sound Pad continuarem funcionando como antes;
- os testes de lógica e persistência passarem.

## Ordem recomendada de execução

1. Fase 0 — decisões de produto;
2. Fase 1 — modelos e migração;
3. Fase 2 — motor de áudio;
4. Fase 3 — ViewModel e regras;
5. Fase 4 — configuração;
6. Fase 5 — execução;
7. Fase 6 — atalhos e segurança;
8. Fase 7 — testes e validação com áudio real.

Essa ordem reduz o risco de construir a interface sobre uma estrutura de dados ou um comportamento de áudio que depois precise ser refeito.
