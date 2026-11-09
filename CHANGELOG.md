# Histórico do Walkmen

O primeiro código preservado neste repositório é a versão **0.8.3+14**. As
versões anteriores abaixo documentam o desenvolvimento feito antes do Git.
Não existem snapshots completos recuperados dessas versões, portanto elas
não recebem tags nem commits retroativos. Datas dos commits representam a
entrada real no controle de versão.

## 0.8.3+14

- Centraliza o conjunto da abertura da case e retirada da fita.
- Ajusta o enquadramento pela altura disponível da tela.
- Validação local: análise sem problemas, 30 testes passaram e APK assinado.

## Evolução anterior documentada

| Versão | Mudanças |
| --- | --- |
| 0.8.2+13 | Recorte retangular com alças nos cantos e bordas, grade e movimento da seleção; recorte livre preservado. |
| 0.8.1+12 | Dois modos explícitos na tela de recorte. |
| 0.8.0+11 | Cores da case, capa, fita, rótulo e letras; fotos independentes no rótulo da frente e do verso. |
| 0.7.0+10 | Segurar para inspecionar em 3D e arrastar para reorganizar a estante; ordem persistente. |
| 0.6.1+9 | Ajustes de animação, caixa alinhada e novo desenho da fita 2D. |
| 0.6.0+8 | Case deitada, estante de lombadas, imagens no catálogo, paredes 3D e adesivos nas bordas. |
| 0.5.0+6 | Widgets de prateleira e Walkman, notificação de mídia personalizada e catálogo de faixas. |
| 0.4.0+5 | Fita 2D/3D, verso com faixas, figurinhas por contorno livre e modos de player. |
| 0.3.0+4 e anteriores | Biblioteca por pastas, escolha persistente da pasta de músicas, reprodução offline, favoritas, criação e personalização de fitas. |

## Próximas versões

Cada alteração será registrada em commits reais. Versões publicadas devem
ter uma tag `vMAJOR.MINOR.PATCH`, um incremento de `versionCode` no
`pubspec.yaml` e notas com as mudanças e validações.
