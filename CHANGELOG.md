# Histórico do Walkmen

O primeiro código preservado neste repositório é a versão **0.8.3+14**. As
versões anteriores abaixo documentam o desenvolvimento feito antes do Git.
Não existem snapshots completos recuperados dessas versões, portanto elas
não recebem tags nem commits retroativos. Datas dos commits representam a
entrada real no controle de versão.

## 0.10.0+18 — alterações locais

- Materiais sólido e cristalino para a fita, aplicados ao 2D e ao 3D.
- Marcadores de início múltiplos e renomeáveis substituem a seleção de intervalo; dados antigos preservados.
- Paleta do catálogo derivada da capa, com contraste automático.
- Compartimento, pinos, paredes e tampa da case 3D refinados.
- Interface com nova tipografia, fundos, painéis e miniplayer.
- Corrige bordas que se cruzavam e peças internas que apareciam atravessando o modelo em 3D.

## 0.9.2+17 — alterações locais

- − marca o início atual e + marca o fim atual do áudio; salvar registra esse trecho específico.
- Impede salvar antes de marcar os dois pontos; finalizar encerra a seleção.
- Remove a instalação do celular virtual e seus atalhos, preservando as ferramentas de compilação.

## 0.9.1+16 — alterações locais

- Navegação inferior semitransparente.
- Trechos marcados na barra principal, com ajustes −/+, salvar e finalizar.
- Abertura por gesto, sem barras de animação.
- Catálogo expansível para mostrar mais faixas; interface com menos textos.

## 0.9.0+15 — alterações locais

- Player vertical padrão com fita e arte, acesso ao catálogo completo e escolha de faixas sem recarregar a fila.
- Trechos favoritos persistidos, com início/fim e reprodução do intervalo.
- Paleta de dez cores e atualização dos controles e ícones.
- Abertura da case por gesto e animação de retirada controlável.
- Notificação nativa quando o app está em segundo plano; menos redesenhos e serviço mantido em primeiro plano.
- Compilação release otimizada, preservando a chave de assinatura local. Sem publicação no GitHub.

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
