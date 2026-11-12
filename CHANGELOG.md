# Histórico do Walkmen

O primeiro código preservado neste repositório é a versão **0.8.3+14**. As
versões anteriores abaixo documentam o desenvolvimento feito antes do Git.
Não existem snapshots completos recuperados dessas versões, portanto elas
não recebem tags nem commits retroativos. Datas dos commits representam a
entrada real no controle de versão.

## 0.12.1+26 — alterações locais

- Permite escolher pasta e nome do backup pelo seletor Android, preservando a exportação direta em Downloads.
- Trata cancelamento, falhas e conflitos sem apagar backups anteriores.
- Atualiza o ícone adaptável e o logotipo do app com a nova imagem da fita.

## 0.12.0+25 — alterações locais

- Migra a coleção do JSON interno para armazenamento SQLite com transações, preservando os arquivos anteriores.
- Exporta e importa backup JSON em Downloads, incluindo imagens incorporadas, figurinhas, fitas, favoritas, trechos e preferências.
- Confirma a substituição, valida o arquivo e preserva a coleção anterior se houver falha na preparação ou gravação.
- A permissão da pasta de músicas é verificada novamente; arquivos de áudio não são copiados para o backup.

## 0.11.4+24 — alterações locais

- Renderização 3D em isolate persistente, com cache limitado de texturas e descarte seguro ao fechar.
- Menos trabalho por pixel, faces mais próximas primeiro e omissão da fita encoberta pela case fechada.
- Resolução adaptável durante gestos e refinamento ao finalizar.
- Testes de composição, cache, transparência, encerramento e rotação sem vazamento da fita.

## 0.11.3+23 — alterações locais

- Remove escurecimento das fotos de capa e clareia o fundo da capa padrão.
- Ajusta contraste das letras, preservando cores personalizadas.

## 0.11.2+22 — alterações locais

- Substitui a ordenação média de faces por buffer de profundidade por pixel no 3D.
- Corrige interpolação de textura em perspectiva e elimina vazamento da fita através da case fechada.
- Torna as paredes da case opacas e descarta quadros atrasados durante gestos.
- Acrescenta testes de faces cruzadas, transparência, perspectiva e rotação da caixa fechada.

## 0.11.1+21 — alterações locais

- Restaura case por código e remove a dependência do GLB da case excluído pelo usuário.
- Preserva a fita GLB e sua personalização, inclusive no interior da case.

## 0.11.0+20 — alterações locais

- Integra os GLBs de fita e case fornecidos pelo usuário, sem dependência de visualizador web.
- Normaliza o encaixe e a orientação, preserva a tampa articulada e aplica as personalizações às faces e laterais.
- Sincroniza a silhueta 2D com a geometria dos modelos; mantém recorte das figurinhas.
- Pré-carrega as malhas e subdivide faces grandes para corrigir sobreposição de polígonos.

## 0.10.1+19 — alterações locais

- Recorte de figurinhas pela silhueta física da fita em 2D.
- Pesquisa global com reprodução pelo resultado.
- Preparação de fila em lotes e janela de 50 itens na sessão de mídia Android; catálogo completo preservado.
- Serialização de atualizações da fila nativa e nova tentativa após falha ao abrir áudio.

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
