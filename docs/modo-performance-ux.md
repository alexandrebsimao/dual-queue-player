# Modo Performance — proposta de produto e UX

> Status: proposta conceitual. Este documento não representa uma funcionalidade implementada.

## Contexto

Além de operar músicas em duas filas, o operador pode precisar executar efeitos, trilhas, falas e sons para danças, teatros e esquetes.

Esse tipo de operação tem necessidades diferentes das filas musicais:

- disparo imediato e manual;
- pausa instantânea;
- execução de vários sons simultaneamente;
- organização por grupos, cenas ou momentos do espetáculo;
- identificação visual rápida;
- controle individual e um comando de emergência para interromper tudo.

## Recomendação de produto

Inicialmente, essa experiência deve fazer parte do DualQueue Player como um módulo separado chamado **Performance** ou **Cues**.

O módulo deve compartilhar a biblioteca de áudio e a infraestrutura geral do aplicativo, mas ter uma lógica e uma interface próprias.

### Por que permanecer no mesmo aplicativo

- O público é o mesmo: operadores de áudio ao vivo.
- O contexto de uso é semelhante: apresentação, evento, culto, aula ou transmissão.
- O Sound Pad já cobre parte do caso de uso.
- O operador pode precisar usar uma fila musical e efeitos independentes na mesma apresentação.

### Quando considerar um aplicativo separado

Um produto separado só deveria ser considerado caso o módulo evolua para incluir necessidades maiores, como:

- timeline complexa;
- roteamento multicanal avançado;
- automações extensas;
- sincronização com iluminação ou vídeo;
- operação por vários operadores;
- recursos de edição próximos de uma DAW.

Esses recursos não fazem parte do escopo atual do DualQueue Player.

## Separação entre os modos

O aplicativo deve manter conceitos distintos para evitar uma interface confusa:

| Modo | Finalidade | Regra principal |
| --- | --- | --- |
| Filas A/B | Reprodução contínua de músicas | O próximo áudio é determinado pela fila e pelo modo de reprodução |
| Sound Pad | Disparo rápido de sons independentes | Acesso imediato a pads configuráveis |
| Performance | Operação organizada por espetáculo, cena e cue | O operador decide quando cada áudio acontece |

O Sound Pad pode continuar existindo para disparos simples. O modo Performance deve ser usado quando houver organização por cenas, grupos e roteiro.

## Estrutura de navegação

Uma navegação lateral poderia ser organizada assim:

```text
Player
├── Queue A
└── Queue B

Performance
├── Espetáculos
├── Cenas
└── Execução

Sound Pad
Biblioteca
Configurações
```

O fluxo mais importante deve ser curto:

1. selecionar um espetáculo;
2. selecionar uma cena;
3. executar os sons na tela de execução.

O operador não deveria precisar editar ou organizar conteúdo durante a apresentação.

## Organização por espetáculo, cena e grupo

### Espetáculo

Representa uma apresentação, dança, peça ou esquete completa.

Exemplo:

```text
Espetáculo: A Viagem
```

### Cena

Representa um momento do espetáculo e reúne os sons relevantes para aquele momento.

```text
Espetáculo: A Viagem
├── Cena 1 — Entrada
├── Cena 2 — Floresta
├── Cena 3 — Confronto
└── Cena 4 — Final
```

### Grupo

Agrupa sons por função operacional, e não apenas por pasta de arquivos.

Exemplos:

- Trilha;
- Efeitos;
- Vozes;
- Impactos;
- Ambientes;
- Transições;
- Falas;
- Sons de uma dança específica.

Uma cena poderia ser apresentada assim:

```text
Cena 2 — Floresta
├── Trilha
├── Efeitos
├── Vozes
└── Ambiente
```

## Tela de execução

A tela mais utilizada durante uma apresentação deve priorizar botões grandes, contraste alto e leitura rápida.

```text
[ Espetáculo: A Viagem ]       [Cena 2 de 8]       [PARAR TUDO]

[ Cena anterior ]                                  [ Próxima cena ]

┌───────────────┬───────────────┬───────────────┐
│ TRILHA        │ EFEITOS       │ VOZES         │
│               │               │               │
│ [Entrada]     │ [Impacto 1]   │ [Narrador]    │
│ [Loop cena]   │ [Porta]       │ [Fala 2]      │
│ [Final]       │ [Passos]      │ [Grito]       │
└───────────────┴───────────────┴───────────────┘

Ativos agora:
[▶ Trilha — 01:24] [Pausar] [Parar]
[▶ Ambiente — loop] [Pausar] [Parar]
```

Cada som deve ser representado por um bloco ou botão com:

- nome curto;
- cor do grupo;
- ícone ou tipo do som;
- duração, quando aplicável;
- indicação de loop;
- indicação clara de que está tocando;
- controle secundário para pausar ou parar individualmente.

O botão principal deve executar o áudio. A edição de nome, volume e configurações deve ocorrer fora da tela de operação.

## Modos de operação

### Modo Livre

Funcionaria como um soundboard organizado:

- qualquer som pode ser disparado a qualquer momento;
- grupos permanecem visíveis;
- vários sons podem tocar simultaneamente;
- adequado para ensaios, danças e improvisos.

### Modo Espetáculo

Seria organizado por cenas e cues:

- exibe os sons relevantes da cena atual;
- permite avançar e voltar entre cenas;
- pode mostrar uma sequência de próximos cues;
- mantém o disparo manual para preservar o controle do operador;
- adequado para peças e apresentações ensaiadas.

Os dois modos podem usar a mesma biblioteca de sons.

## Comportamentos essenciais

### Execução imediata

Ao tocar em um som, ele deve começar imediatamente, sem abrir menus ou exigir confirmação.

### Pausa instantânea

Pausa e parada devem ser ações diferentes:

- **Pausar:** congela o áudio no ponto atual;
- **Parar:** interrompe o áudio e retorna ao início;
- **Pausar tudo:** congela todos os sons do módulo Performance;
- **Parar tudo:** interrompe todos os sons do módulo Performance.

Essa diferença deve ser visível tanto pelo texto quanto pelo ícone.

### Execução simultânea

Vários sons podem tocar ao mesmo tempo. A tela deve manter uma lista ou área de **Ativos agora**, mostrando:

- quais sons estão tocando;
- tempo decorrido ou duração;
- se estão em loop;
- controles de pausa e parada individuais.

### Loops

Cada som pode ter um comportamento configurável:

- tocar uma vez;
- repetir;
- repetir até parar;
- opcionalmente, tocar enquanto o botão estiver pressionado para efeitos muito curtos.

O comportamento padrão deve ser explícito antes da apresentação.

## Botão de emergência

A tela de execução deve manter um comando visível e permanente:

> **PARAR TUDO**

Por segurança, o comportamento deve ser configurável e descrito claramente:

- parar somente os sons do modo Performance; ou
- parar todos os áudios do aplicativo.

O padrão mais seguro para evitar interferência acidental nas filas é parar apenas o módulo Performance. Uma opção separada poderia permitir o comportamento global.

O botão deve exigir uma ação simples e direta, sem confirmação modal durante a apresentação.

## Transição entre cenas

Trocar de cena não deve necessariamente parar os sons ativos. A transição precisa ter um comportamento definido para cada projeto ou cena:

- manter sons ativos;
- parar sons da cena anterior;
- parar somente sons marcados como exclusivos da cena;
- permitir que determinados ambientes continuem em loop.

A tela deve indicar se a cena atual contém sons ainda ativos da cena anterior.

Para navegação rápida, a interface pode oferecer:

```text
[Cena 1] [Cena 2] [Cena 3] [Cena 4] [Cena 5]
```

Além de:

- **Cena anterior**;
- **Próxima cena**.

Os dois modelos podem coexistir: acesso direto para ensaio e navegação sequencial para apresentação.

## Cues e roteiro

No Modo Espetáculo, a cena pode exibir uma sequência de cues sugeridos:

```text
Cena 3 — Floresta

Próximo cue: Passos na mata
Depois: Entrada da trilha
Depois: Impacto
```

Essa lista deve servir como guia, não como automação obrigatória. O operador continua decidindo o momento exato do disparo.

## Sequência da cena e controle de tempo

No caso de uso principal deste módulo, os sons de uma cena não precisam ser separados em grupos para serem executados. A cena deve possuir uma **lista sequencial única**, com uma ordem operacional clara.

Cada item da lista pode exibir:

- número da sequência;
- nome do áudio;
- classificação ao lado do nome, como `Trilha`, `Efeito`, `Voz` ou `Ambiente`;
- duração;
- estado atual;
- ação de disparo, pausa ou parada.

Exemplo:

```text
01  Floresta — ambiente       [Ambiente]  Loop     04:12   ▶
02  Passos na mata            [Efeito]    Uma vez  00:08   ▶
03  Narrador — atenção        [Voz]       Uma vez  00:12   ▶
04  Tensão crescente          [Trilha]    Uma vez  01:36   ▶
05  Impacto                   [Efeito]    Uma vez  00:05   ▶
```

### Visualizações alternativas

A lista sequencial deve ser a visualização padrão. Como alternativa, o operador pode selecionar uma visualização de **Cues agrupadas**, que distribui os mesmos itens em colunas por classificação.

```text
[ Lista ] [ Cues agrupadas ]
```

Essa alternância deve mudar somente a forma de visualizar os itens. A ordem, os arquivos e os estados de reprodução continuam sendo os mesmos.

### Controle de tempo da cena

A tela de execução deve manter um relógio independente para a cena, com:

- tempo decorrido;
- duração total estimada;
- barra de progresso ajustável;
- iniciar o tempo;
- pausar e retomar o tempo;
- zerar o tempo;
- indicação clara de que o relógio pertence à cena, não somente ao áudio selecionado.

Exemplo:

```text
Tempo da cena  01:24 / 08:42  ────────────────  [Pausar tempo] [Zerar]
```

O relógio pode servir como referência para o operador, sem obrigar a execução automática dos itens. O disparo dos áudios continua manual, salvo se uma automação futura for explicitamente configurada.

### Estado do item atual

O item selecionado ou em execução deve ser destacado na lista. A cena também deve mostrar quais sons continuam ativos quando houver sobreposição, especialmente quando um ambiente em loop permanece tocando enquanto outros itens são disparados.

## Configuração de cada som

Antes da apresentação, cada item deveria permitir configurar:

- nome exibido;
- grupo;
- cor;
- ícone;
- volume;
- saída de áudio, se aplicável;
- tocar uma vez ou em loop;
- comportamento ao trocar de cena;
- iniciar do começo ou continuar;
- permitir sobreposição;
- atalho de teclado opcional;
- imagem ou identificador visual opcional.

As configurações operacionais devem ser separadas da execução, para reduzir o risco de alterações acidentais.

## Identificação visual

As cores podem ajudar na leitura rápida, desde que não sejam a única forma de identificação.

Sugestão inicial:

| Cor | Categoria sugerida |
| --- | --- |
| Azul | Músicas e trilhas |
| Amarelo | Efeitos |
| Roxo | Vozes e falas |
| Verde | Ambientes e loops |
| Vermelho | Ações críticas ou paradas |

Cada item também deve usar nome e ícone, para manter a interface acessível a pessoas que não distinguem todas as cores.

## Atalhos de teclado

Atalhos podem ser úteis para cues críticos, mas não devem ser obrigatórios.

Recomendações:

- permitir configurar atalhos por som;
- mostrar o atalho no próprio botão;
- evitar conflitos com atalhos globais do player;
- não disparar atalhos quando o operador estiver digitando em um campo de texto;
- reservar uma combinação clara para pausar ou parar tudo, se essa opção for habilitada.

## Regras de segurança operacional

O módulo deve priorizar previsibilidade:

- nenhum som deve iniciar automaticamente apenas por trocar de cena, salvo configuração explícita;
- a cena selecionada e a cena em execução devem ser visualmente distinguíveis;
- sons ativos devem permanecer visíveis mesmo quando o operador navega entre cenas;
- erros de arquivo devem aparecer antes da apresentação, não somente no momento do disparo;
- ações críticas devem ter feedback visual imediato;
- o botão de parar tudo deve ser sempre fácil de encontrar;
- o operador deve conseguir retornar ao estado inicial de um som sem abrir um painel de edição.

## Relação com o player principal

O módulo Performance deve ser independente do player principal, mas a interface precisa deixar claro o que está tocando em cada sistema.

Exemplo de separação visual:

```text
Player principal
[Queue A — Trilha principal — tocando]

Performance
[Ambiente — tocando]
[Passos — tocando]
```

O Sound Pad e o Performance podem tocar em paralelo com a fila principal quando configurados como Overlay. O comportamento de interrupção ou ducking deve ser explicitamente configurável para cada áudio.

## Escopo recomendado para uma primeira versão

Uma primeira versão conceitual e enxuta deveria conter:

- projetos de Performance;
- cenas;
- grupos;
- botões grandes de disparo;
- execução simultânea;
- pausa e parada individuais;
- pausa tudo e parar tudo;
- loops;
- indicação de sons ativos;
- troca manual de cenas;
- configuração de nome, volume e comportamento do som;
- persistência no projeto `.dualqueue`.

Recursos como timeline, sincronização automática e roteamento avançado devem permanecer fora do escopo inicial.

## Decisões ainda em aberto

Antes de implementar, seria necessário decidir:

1. Se o nome final será **Performance**, **Cues** ou outro termo mais familiar ao público do aplicativo.
2. Se a unidade principal de disparo será chamada de **cue**, **som**, **ação** ou **pad**.
3. Se a troca de cena mantém ou encerra os sons ativos por padrão.
4. Se o botão **Parar tudo** afeta somente Performance ou todos os áudios do aplicativo.
5. Se a seleção de cena é apenas navegação ou também representa o estado operacional atual.
6. Se atalhos de teclado serão globais, por cena ou por projeto.

## Resumo da recomendação

O DualQueue Player pode evoluir para atender teatro, dança e esquetes sem abandonar sua proposta original. A melhor direção é adicionar um módulo **Performance** separado das filas e do Sound Pad, com foco em:

- disparo manual imediato;
- pausa e parada sem ambiguidade;
- vários sons simultâneos;
- organização por espetáculo, cena e grupo;
- feedback constante do que está ativo;
- um botão de emergência claro;
- navegação simples durante a apresentação.

O módulo deve continuar simples e previsível. A prioridade é dar confiança ao operador, não transformar o aplicativo em uma DAW.
