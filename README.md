# Walkmen — 0.12.1

Leia [minha ideia para o Walkmen](docs/IDEIA_DO_PROJETO.md): a concepção do aplicativo em primeira pessoa, a experiência que quero criar, o que já foi desenvolvido e as possibilidades futuras.

## Atualização 0.12.1

- Em Backup, escolha entre salvar diretamente em Downloads ou abrir o seletor Android para definir pasta e nome do JSON.
- Cancelar o seletor não cria backup nem altera a coleção. Erros de escrita são informados; a exportação direta não apaga um arquivo anterior em caso de conflito de nome.
- Novo ícone adaptável e logotipo interno gerados a partir de image app.png, com enquadramento seguro para a tela inicial.

## Atualização 0.12.0

- A coleção usa SQLite com gravação transacional e uma cópia anterior de segurança. Na primeira abertura, o JSON interno antigo é migrado; os arquivos antigos são preservados.
- Em Ajustes → Backup e restauração, exporte um JSON para Downloads ou escolha um backup para importar. A importação mostra confirmação antes de substituir a coleção.
- O arquivo inclui fitas, ordem, cores, fotos de capa e rótulo, figurinhas, posições, favoritas, trechos e opções de reprodução. As imagens são incorporadas ao JSON para permitir restauração.
- O backup contém referências às músicas, não os arquivos de áudio. Ao reinstalar ou trocar de celular, mantenha ou copie as músicas para o mesmo local e autorize novamente a pasta quando solicitado.
- O backup é limitado a 128 MB e a 12 MB por imagem. Se uma imagem não estiver disponível, a exportação informa o problema em vez de omiti-la.

## Atualização 0.11.4

- Rotação e abertura da case 3D mais leves: renderização de profundidade em segundo plano, texturas reaproveitadas e menos cálculos por pixel.
- Com a case fechada, a fita interna não é processada, pois está encoberta. Ao abri-la, a fita aparece no interior normalmente.
- Durante o gesto a prévia usa menos resolução, restaurando os detalhes ao soltar. A correção de profundidade e as cores de capa permanecem.

## Atualização 0.11.3

- Capa com foto preserva as cores da imagem, sem a camada preta sobreposta.
- Capa padrão mais clara e letras com contraste automático. Sombra fica apenas nas letras sobre fotos.
- Ajuste aplicado ao 2D e às texturas usadas no 3D.

## Atualização 0.11.2

- Renderização 3D com profundidade por pixel: faces da fita e da case deixam de ser ordenadas pela distância média, evitando texturas atravessadas durante a rotação.
- Coordenadas das texturas corrigidas pela perspectiva para acompanhar a malha sem deslizar.
- Paredes da case opacas; material cristalino da fita continua disponível.
- Quadros de rotação antigos são descartados e texturas ficam em cache. A fita continua GLB e a case continua gerada por código.
- Teste de regressão gira a case fechada por uma volta e verifica que a fita não aparece através dela.

## Atualização 0.11.1

- Case restaurada ao modelo gerado por código em 2D e 3D, com tampa por gesto.
- Fita continua usando o GLB, inclusive dentro da case. O app não depende mais do arquivo case.glb.

## Atualização 0.11.0

- Fita e case em 3D usam os GLBs fornecidos na pasta modelos, empacotados no APK e carregados sem internet.
- Ajustes de escala, orientação e profundidade acontecem na importação; os arquivos originais foram preservados. A tampa usa a peça animada e seu pivô original, controlada pelo gesto Abrir.
- A malha recebe as cores, capas, fotos, verso e figurinhas do app, com projeção também nas laterais. Fita sólida/cristalina permanece disponível.
- O desenho 2D usa a silhueta frontal dos mesmos modelos; as figurinhas são recortadas por esse contorno.
- Faces grandes são subdivididas para reduzir problemas de sobreposição na renderização. Modelos e texturas são reutilizados durante a navegação.

## Atualização 0.10.1

- Figurinhas recortadas na silhueta da fita em 2D, inclusive nos cantos arredondados; a posição salva continua disponível no modelo 3D.
- Pesquisa global por música, artista, álbum e pasta, com reprodução direta do resultado mesmo quando outra pasta estava aberta.
- Pastas grandes: abre primeiro a faixa escolhida e prepara o restante em lotes de até 50, mantendo a ordem e a seleção. A fila externa do Android recebe uma janela limitada para evitar mensagens excessivamente grandes; o catálogo do app mantém todas as faixas.
- Uma falha de carregamento não deixa a fila marcada como pronta; tocar novamente tenta preparar o áudio outra vez.

## Atualização 0.10.0

- Fita sólida ou cristalina na customização, com carretéis e mecanismos visíveis no material transparente em 2D e 3D.
- Trechos agora são marcadores de início. Salvar início registra o ponto atual; é possível guardar vários por música, renomear e excluir cada um. Tocar em um marcador reproduz a partir dele, sem parada no fim de um intervalo antigo.
- Catálogo combina com a cor da capa e ajusta automaticamente o contraste das letras.
- Case 3D com compartimento interno, paredes, apoios, pinos e tampa articulada. Preserva o desenho atual da capa.
- Tipografia, fundo, painéis, campos e miniplayer renovados. APK local Walkmen.apk; sem publicação no GitHub.

## Atualização 0.9.2

- Trechos > Marcar volta ao player. O botão − registra o início na posição atual do áudio e + registra o fim. Salvar guarda esse intervalo específico; finalizar sai da marcação.
- Salvar fica desabilitado até haver início e fim válidos. Também é possível selecionar o intervalo pelas alças da própria barra.
- Removidos o emulador, sua imagem Android, o dispositivo virtual, os arquivos de teste e os atalhos de simulação. Flutter e SDK de compilação foram mantidos.

## Atualização 0.9.1

- Barra inferior com aproximadamente 50% de opacidade e desfoque do conteúdo ao fundo. As listas mantêm espaço para alcançar os últimos itens.
- Trechos > Marcar fecha a lista e ativa a seleção na própria barra do player. Os ícones −/+ ajustam o início ou fim selecionado em passos de um segundo; salvar mantém o modo de marcação e finalizar volta ao player normal. O nome do trecho é gerado automaticamente.
- Removidas as barras e explicações das animações. A abertura continua por gesto, com modos Girar/Abrir no 3D.
- Ao puxar o catálogo, a prévia da fita diminui e libera até cerca de um quarto da altura da tela para a lista. A seta recolhe o catálogo novamente.
- Cabeçalhos e instruções reduzidos. Sem envio ao GitHub.

## Atualização 0.9.0

- Player vertical como padrão, mantendo a fita animada com a imagem da música na janela central. O modo deitado continua disponível no menu.
- Catálogo acessível pelo player para escolher qualquer faixa; trocar dentro da mesma fila não recarrega todos os arquivos. Toques feitos durante carregamento preservam a última escolha.
- Trechos favoritos com nome, início e fim: Player > Trechos > Marcar. São salvos no aparelho, podem ser reproduzidos e excluídos; a reprodução pausa ao chegar ao fim marcado.
- Personalização com dez cores principais por toque, sem códigos ou controles técnicos.
- Botões arredondados, navegação e ícones renovados, mantendo as cores e a identidade Walkmen.
- Case 3D com os modos Girar e Abrir com o dedo; arrastar para cima abre e para baixo fecha. O controle deslizante continua disponível. A animação de retirada também pode ser controlada pelo dedo e pela barra.
- Serviço de áudio configurado para continuar em primeiro plano, inclusive na pausa, e permanecer ao remover a atividade dos recentes. Fora do app, a notificação usa o painel nativo de mídia, sem redesenhar bitmaps continuamente. Parada forçada pelo sistema/usuário encerra a reprodução.
- APK gerado em modo release otimizado, com a mesma chave local utilizada nas instalações anteriores. Não foi enviada nenhuma alteração ao GitHub.

## Atualização 0.8.3

- Animação centralizada pelo conjunto visível: caixa, tampa aberta e fita em retirada. O enquadramento acompanha as etapas e considera a altura disponível para evitar cortes em telas menores.

## Atualização 0.8.2

- Os dois modos principais são Com o dedo e Retângulo. No retângulo clássico, puxe os quatro cantos ou os meios das bordas para redimensionar, e arraste por dentro para reposicionar. A grade ajuda no enquadramento.
- Retângulo não depende dos controles de largura/altura. Os demais formatos continuam disponíveis e conservam esses controles.
- Teste por gestos verifica redimensionamento, movimento, dimensões e conteúdo do PNG exportado.

## Atualização 0.8.1

- O recorte tem dois modos explícitos: Com o dedo e Recorte antigo. O antigo reúne retângulo, círculo, estrela, coração e triângulo, com largura, altura e arraste da seleção.
- Alternar preserva o contorno desenhado e a seleção anterior de formato e tamanho.

## Atualização 0.8.0

- Personalizar fita > Fita: cor da carcaça, cor do rótulo (retângulo branco) e cor das letras. Os seletores oferecem paleta, tonalidade, intensidade, brilho e código hexadecimal.
- Escolha Frente ou Verso e use Foto no rótulo. As duas faces podem ter fotos independentes; a imagem fica recortada no rótulo atrás do nome e da janela das bobinas. Remover foto restaura a cor escolhida.
- Personalizar fita > Caixa / capa: cor do plástico da case, cor da capa, cor das letras e imagem da capa.
- Cores e fotos ficam salvas na coleção e são usadas nas texturas 2D e 3D, na inspeção, na abertura e nas prévias dos widgets. Fitas antigas recebem valores padrão sem perder suas personalizações.
- Testes cobrem compatibilidade de dados, salvamento das novas opções, posição da foto na face correta e alteração de cor pelo editor.

## Atualização 0.7.0

- Na estante, segure a fita por meio segundo para mostrar a prévia 3D. Solte sem arrastar para abrir a inspeção: gire, amplie, veja o verso e abra a caixa.
- Segure e arraste sobre outra fita para mudar a posição. O destino fica destacado; as demais fitas se deslocam para abrir espaço. A ordem é salva e também é mantida ao editar uma fita.
- Arrastar perto das bordas superior ou inferior rola a estante automaticamente. Tocar rapidamente continua abrindo a animação e o catálogo.
- Testes verificam os dois gestos, a ordem após reabrir e a preservação da posição ao editar.

## Atualização 0.6.1

- Visualização da caixa alinhada: removida a rotação decorativa do 2D e centralizado o ângulo inicial do 3D.
- Retirada da fita em etapas: abrir tampa, levantar a fita, retirar da bandeja e centralizar. A bandeja fica parada até a retirada.
- Fita 2D redesenhada com carcaça arredondada, rótulo proporcional, janela das bobinas, ponte inferior e parafusos reposicionados.
- Prévia da abertura e retirada conferida em build/previews/abertura-061-*.png. Os testes usam fonte de teste; as letras em blocos nas capturas não representam a fonte do aplicativo.

## Recursos da versão 0.6.0

- Caixa deitada em 2D e 3D, com proporções de uma case de cassete.
- Estante com lombadas lado a lado e nomes, como uma biblioteca.
- Animação de abertura pela borda longa, seguida da retirada da fita.
- Catálogo com a arte de cada música, número acima do título e favoritas.
- Case 3D com bandeja, paredes laterais, tampa articulada e uma fita com volume dentro. O modelo se enquadra ao abrir a tampa.
- Adesivos continuam da frente ou do verso pelas laterais e, se ultrapassarem a espessura, pela face oposta. As personalizações são compartilhadas entre 2D e 3D.
- Recorte com o dedo e retângulo, além de círculo, estrela, coração e triângulo.
- Dois widgets Android: prateleira para abrir fitas e Walkman para controlar a reprodução. Adicione em Ajustes ou pelo seletor de widgets do Android.
- Notificação de mídia com arte, controles e progresso. A visualização expandida personalizada usa uma fita com bobinas atualizadas durante a reprodução e paradas na pausa.

A aparência da notificação depende da versão do Android e do fabricante: o sistema pode substituir o layout personalizado pelo painel padrão de mídia. A abertura da Biblioteca foi verificada no emulador; reprodução real, permissões, widgets e notificação ainda devem ser conferidos em um celular físico. O APK atual é uma compilação release otimizada, assinada com a chave local de desenvolvimento para manter compatibilidade com as instalações anteriores.

Projeto Flutter Android em `C:\03 - Dados Gabriel\projetos\Projetos-gerais\wlak`.
APK instalável: `Walkmen.apk`, na mesma pasta do código.
Flutter, Java e Android SDK permanecem em `C:\Walkman-tools`.

## Pedidos incorporados

- Cabeçalho com a logo enviada, nome Walkmen, ícone de pesquisa e ícone de atualizar.
- Biblioteca abre por pastas. Os botões antigos Escolher pasta / Todo o aparelho / Permissões e a inscrição Local Offline foram retirados do topo.
- Na primeira abertura, uma ação Escolher pasta de músicas abre o gerenciador Android. A autorização e o caminho ficam memorizados. Ajustes permite trocar a pasta se necessário.
- O ícone de nova pasta cria subpastas reais dentro da pasta de músicas autorizada. Em instalações antigas com acesso apenas de leitura, reautorize a pasta em Ajustes para permitir criação.
- Capas incorporadas ao áudio são extraídas pelo Android. Arquivos sem capa usam um ícone de álbum.
- Tocar em uma música inicia áudio real. Toque longo mostra sua localização. O player tem pausa, próximo/anterior, progresso, volume, repetição e aleatório, com fila contínua, serviço em segundo plano e controles de mídia.
- O coração salva favoritas; outro coração junto ao título da biblioteca abre a lista. As favoritas e os metadados são persistidos.
- O menu de uma pasta tem Criar fita; dentro da pasta há também um botão. A fita referencia os áudios originais, sem copiá-los.
- A aba Fitas mostra uma estante de caixas, com acesso à fita, edição, exclusão e reprodução. O editor permite nome, descrição, cores, aparência transparente, imagem de capa e ordem das músicas.
- A aba Figurinhas importa imagens da galeria e recorta retângulos de proporção livre, elipses/círculos, estrelas, corações, triângulos e contornos desenhados com o dedo. Os recortes são PNG com transparência.
- No editor da fita, aplique figurinhas na fita ou na caixa, arraste, redimensione, gire e salve. As mesmas personalizações aparecem na coleção e no 3D.
- No detalhe de uma fita, alterne Fita/Caixa e ative 3D. Arraste para girar em todos os lados, use dois dedos para ampliar e o controle Abrir caixa para movimentar a tampa. A geometria tem espessura, faces com textura, perspectiva e tampa articulada; não depende de vídeos ou acesso à internet.
- Na visualização 2D da fita, as bobinas acompanham o estado de reprodução. O player ampliado solicita orientação horizontal e restaura a vertical ao sair.

## Compilar

```powershell
.\build-apk.ps1
```

O script resolve dependências, executa análise e testes, compila o APK otimizado e copia para Walkmen.apk. O CMake do SDK está configurado em android/local.properties. As saídas intermediárias ficam em build e podem ser removidas após a compilação; a próxima compilação as recria. O script não cria uma segunda cópia em dist.

## Validação

Testes de navegação, pesquisa, fila enviada ao player, favoritas, primeira escolha de pasta, conversão da ponte Android, cancelamento do seletor, persistência em arquivo, recuperação de backup, isolamento do rascunho, máscaras de recorte e gestos/renderização 3D. Prévias geradas pelos testes em build/previews.

A reprodução em alto-falante/fone, permissões reais, notificação na tela bloqueada e seleção da galeria precisam de validação em um telefone: não havia dispositivo conectado. Os testes Flutter simulam a parte nativa nessas interações. O APK inclui as implementações nativas e as bibliotecas de áudio; não é uma simulação visual.

As imagens dos áudios só aparecem quando existe arte incorporada. Ao criar subpastas, o app não move músicas automaticamente. Os modelos 3D são formas geométricas locais com a arte personalizada aplicada, e não digitalizações de aparelhos reais.

## Código

lib/screens, lib/models, lib/services, lib/widgets, lib/animations, assets, test e android. Os áudios são referências content:// com autorização persistente. Coleção, favoritas, figurinhas e imagens de capa ficam no armazenamento privado do aplicativo; as autorizações anteriores são mantidas para que fitas já salvas continuem usando seus arquivos após trocar a pasta principal.

Validação da versão 0.9.2+17 em 10/11/2026: análise sem problemas, 33 testes aprovados e APK release com assinatura verificada. A marcação foi testada registrando 0:37 pelo botão − e 0:52 pelo botão +, salvando e reproduzindo exatamente esse intervalo. Os testes de áudio em segundo plano da versão 0.9.0 estão em [validação e limites](docs/VALIDACAO_0.9.0.md). O emulador foi removido a pedido.

