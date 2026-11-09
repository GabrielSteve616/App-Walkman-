# Walkmen — 0.8.3

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

A aparência da notificação depende da versão do Android e do fabricante: o sistema pode substituir o layout personalizado pelo painel padrão de mídia. Não há celular ou emulador conectado neste ambiente; reprodução real, permissões, widgets e notificação devem ser conferidos no aparelho. O APK é uma compilação debug assinada, para instalação local.

Projeto Flutter Android em `C:\03 - Dados Gabriel\projetos\Projetos-gerais\wlak`.
APK instalável: `Walkmen.apk`, na mesma pasta do código.
Flutter, Java e Android SDK permanecem em `C:\Walkman-tools`.

## Celular virtual no PC

Abra `Abrir celular.cmd` para iniciar o emulador Android 11 e instalar/abrir o APK atual. Use o mouse para tocar e arrastar. O dispositivo Walkmen_Celular e seus dados ficam em `C:\Walkman-tools\avd`; o emulador e a imagem Android ficam no SDK fora dos projetos. Feche a janela do emulador quando terminar.

A instalação e a abertura da tela Biblioteca foram verificadas no emulador em 09/11/2026. Ele tem armazenamento próprio, separado das músicas do PC e de um celular físico. Essa verificação não cobre reprodução, permissões, widgets e notificações em aparelhos reais.

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

O script resolve dependências, executa análise e testes, compila o APK de depuração e copia para Walkmen.apk. O CMake do SDK está configurado em android/local.properties. As saídas intermediárias ficam em build e dist.

## Validação

Testes de navegação, pesquisa, fila enviada ao player, favoritas, primeira escolha de pasta, conversão da ponte Android, cancelamento do seletor, persistência em arquivo, recuperação de backup, isolamento do rascunho, máscaras de recorte e gestos/renderização 3D. Prévias geradas pelos testes em build/previews.

A reprodução em alto-falante/fone, permissões reais, notificação na tela bloqueada e seleção da galeria precisam de validação em um telefone: não havia dispositivo conectado. Os testes Flutter simulam a parte nativa nessas interações. O APK inclui as implementações nativas e as bibliotecas de áudio; não é uma simulação visual.

As imagens dos áudios só aparecem quando existe arte incorporada. Ao criar subpastas, o app não move músicas automaticamente. Os modelos 3D são formas geométricas locais com a arte personalizada aplicada, e não digitalizações de aparelhos reais.

## Código

lib/screens, lib/models, lib/services, lib/widgets, lib/animations, assets, test e android. Os áudios são referências content:// com autorização persistente. Coleção, favoritas, figurinhas e imagens de capa ficam no armazenamento privado do aplicativo; as autorizações anteriores são mantidas para que fitas já salvas continuem usando seus arquivos após trocar a pasta principal.

Validação final em 09/11/2026: flutter analyze sem problemas, 30 testes passaram, Android lintDebug aprovado e APK 0.8.3+14 compilado com assinatura verificada. Nome Walkmen e versão conferidos no APK. Nenhum celular conectado para teste de som, permissões, widgets e notificação reais.

