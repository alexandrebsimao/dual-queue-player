# DualQueue Player

Aplicativo nativo macOS desenvolvido com Swift + SwiftUI para operação de áudio ao vivo.

## Regras essenciais

- Existem duas filas principais: Queue A e Queue B.
- Somente uma fila pode estar ativa por vez.
- Trocar de fila para a reprodução atual, preserva a seleção anterior e não inicia a nova fila.
- Existe um único player principal de música; as filas são fontes de `Track`.
- O Sound Pad é independente do player principal e pode tocar em paralelo quando configurado como Overlay.

## Modos de reprodução

- `Sequential`: inicia automaticamente a próxima faixa até o fim da fila.
- `Shuffle`: usa shuffle bag e histórico, sem repetir antes de completar o ciclo.
- `Manual`: ao terminar, para e aguarda um comando explícito.

## Diretrizes técnicas

- Swift, SwiftUI, AVFoundation e AVAudioEngine.
- MVVM; Views não devem conter lógica de áudio ou regras de fila.
- Persistência local com Codable + JSON no formato `.dualqueue`.
- Não adicionar dependências externas sem necessidade.
- Priorizar previsibilidade, segurança de operação e feedback de estado.

## Fora de escopo

Não implementar BPM, beat matching, pitch, VST, DAW ou waveform complexo. O produto deve continuar simples e confiável.
