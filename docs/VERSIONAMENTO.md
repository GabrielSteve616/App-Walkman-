# Versionamento e publicação

Repositório: https://github.com/GabrielSteve616/App-Walkman-

## Estrutura do histórico

- `main` guarda o código e os commits reais do desenvolvimento.
- Tags como `v0.8.3` identificam versões preservadas do código.
- Releases guardam o APK correspondente, fora do histórico de código.
- `CHANGELOG.md` registra mudanças e distingue versões anteriores sem snapshot.

O código, as imagens do app, as dependências vendorizadas e seus avisos de
licença são versionados. SDKs, emuladores, dados de teste, caches, logs,
credenciais, chaves de assinatura e APKs locais são ignorados pelo Git.

## Publicar uma atualização

1. Faça as alterações e registre commits com descrições claras.
2. Atualize a versão e o número de compilação em `pubspec.yaml`, a versão
   exibida em Ajustes e o `CHANGELOG.md`.
3. Execute `build-apk.ps1` no Windows. O script valida e gera `Walkmen.apk`.
4. Faça commit dos arquivos de código e documentação atualizados.
5. Crie e envie a tag correspondente:

   ```powershell
   git tag -a v0.8.3 -m "Walkmen 0.8.3"
   git push origin main
   git push origin v0.8.3
   ```

6. No GitHub, crie uma Release dessa tag e anexe `Walkmen.apk`, junto das
   notas da versão. Nas próximas atualizações, substitua o número do exemplo.

O workflow Validar Walkmen executa análise e testes. Sua primeira execução
no GitHub ainda precisa ser confirmada após o envio inicial.

## Assinatura do APK

O APK atual é uma compilação debug para instalação local. Preserve a chave
local existente fora do repositório para atualizar instalações já feitas.
Uma compilação em outra máquina com outra chave pode exigir desinstalar a
versão anterior. Chaves e senhas de assinatura não devem ser commitadas.

O histórico local já contém o tag da primeira versão preservada. O upload
da Release depende de autenticação com acesso de escrita ao repositório.
