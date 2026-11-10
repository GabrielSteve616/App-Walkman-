# Validação local — Walkmen 0.9.0+15

Data: 10/11/2026. Alterações mantidas no PC, sem envio ao GitHub.

## Verificações automatizadas

- `flutter analyze`: sem problemas.
- `flutter test`: 33 testes aprovados.
- `:app:lintRelease`: aprovado, com avisos de dependências/Gradle.
- APK release compilado e assinatura verificada; atualização sobre a versão
  anterior instalada no emulador foi aceita.
- Recurso `ic_stat_walkmen` confirmado no APK otimizado. Os ícones de mídia
  acessados por nome são preservados pelo redutor de recursos.

Os testes cobrem player vertical com fita, seleção de faixas pelo catálogo,
busca de posição apenas ao soltar a barra, dez cores, salvamento e reabertura
de trechos, abertura da case por gesto e as funcionalidades anteriores.

## Teste de execução no Android 11 emulado

Foi usado um WAV de teste gerado localmente, com reprodução sem saída sonora
no PC. A verificação acompanha a sessão de mídia, a posição do áudio e o
serviço, não a qualidade sonora em alto-falantes ou fones.

- Player abriu em pé, com fita e imagem/placeholder centralizados.
- A sessão de mídia permaneceu ativa com a tela bloqueada e a posição avançou.
- A atividade foi retirada dos recentes durante a reprodução; a sessão
  continuou em estado de reprodução e o serviço permaneceu em primeiro plano.
  A pausa posterior confirmou avanço de aproximadamente 36 segundos desde
  o início dessa etapa.
- Comandos de reprodução e pausa continuaram respondendo sem a atividade.
- Um trecho foi marcado pela interface, salvo e reproduzido. A reprodução
  começou em aproximadamente 36,3 segundos e pausou em aproximadamente
  51,3 segundos, inclusive após sair da tela do app.
- O arquivo, o trecho e a fila temporária de teste foram removidos ao terminar.

Uma primeira compilação release revelou que a redução de recursos removia
o ícone usado por nome na notificação. Isso causava encerramento ao notificar.
Foi corrigido com preservação dos recursos e um ícone alternativo; os testes
de execução acima foram realizados novamente no APK corrigido.

## Limites desta validação

Ainda é necessário testar o travamento relatado no celular físico, incluindo
áudio audível, permissões da pasta, notificações e políticas de bateria do
fabricante. O teste emulado usou uma fila local de teste preconfigurada e não
valida o seletor de pastas do aparelho. Parada forçada do app pelo Android
encerra a reprodução; manter o áudio vale para sair da tela e retirar a
atividade dos recentes enquanto o serviço está ativo.
