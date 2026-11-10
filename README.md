# Walkmen — 0.9.2

Leia [minha ideia para o Walkmen](docs/IDEIA_DO_PROJETO.md): a concepção do aplicativo em primeira pessoa, a experiência que quero criar, o que já foi desenvolvido e as possibilidades futuras.

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

