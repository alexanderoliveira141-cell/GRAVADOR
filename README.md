# Gravador de Conversas — Protótipo v1

## O que este protótipo já faz
- Botão Start/Stop para gravar áudio (com o app aberto)
- Pede permissão de microfone
- Toca um som ao iniciar a gravação (aviso ético)
- Salva o áudio localmente no celular
- Lista as gravações feitas, com data/hora e duração

## Como rodar pela primeira vez

### 1. Instalar o Flutter
Siga o guia oficial (escolha seu sistema operacional):
https://docs.flutter.dev/get-started/install

Depois de instalar, rode no terminal para confirmar que está tudo certo:
```
flutter doctor
```

### 2. Criar o projeto e copiar os arquivos
```
flutter create gravador_app
```
Depois, substitua os arquivos gerados automaticamente:
- `pubspec.yaml` → pelo arquivo deste pacote
- `lib/main.dart` → pelo arquivo deste pacote

### 3. Instalar as dependências
Dentro da pasta do projeto:
```
flutter pub get
```

### 4. Configurar a permissão de microfone

**Android** — abra `android/app/src/main/AndroidManifest.xml` e adicione,
logo dentro da tag `<manifest>` (antes de `<application>`):
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

**iOS** — abra `ios/Runner/Info.plist` e adicione dentro da tag `<dict>`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Este app precisa do microfone para gravar suas conversas</string>
```

### 5. Rodar o app
Com um celular conectado (ou emulador aberto):
```
flutter run
```

## Próximos passos (na ordem recomendada)

1. **Gravação em segundo plano (Android)** — usar o pacote
   `flutter_foreground_task` para manter a gravação ativa com o app
   minimizado ou a tela apagada (vai exigir uma notificação fixa visível,
   isso é uma exigência do Android, não dá pra remover).
2. **Transcrição + diarização** — depois de parar a gravação, enviar o
   arquivo de áudio para uma API como AssemblyAI ou Deepgram, que devolve
   o texto já separado por quem está falando.
3. **Resumo com IA** — mandar o texto transcrito para a API do Claude
   pedindo um resumo em tópicos, com classificação de assunto.
4. **Reprodução (playback)** — adicionar o pacote `audioplayers` para
   poder ouvir as gravações direto na lista.
5. **Exportar / buscar** — exportar resumos em PDF e permitir buscar
   palavras-chave no histórico salvo.
6. **Portar para iOS** — só depois do app estar sólido no Android, adaptar
   para as limitações de segundo plano do iOS.

## Observação importante
Gravar conversas de terceiros sem que eles saibam pode ter implicações
legais dependendo do seu país e de como o áudio é usado depois. O aviso
sonoro incluído neste protótipo já ajuda nisso, mas vale se informar sobre
a legislação local antes de lançar o app publicamente.
