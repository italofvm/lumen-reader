# Guia de Configuração: Google Drive Integration

Para que a integração com o Google Drive funcione corretamente no **Lumen Reader**, você precisa configurar o seu projeto no **Google Cloud Console**.

## 1. Google Cloud Console
1. Acesse [Google Cloud Console](https://console.cloud.google.com/).
2. Crie um novo projeto (ex: `Lumen Reader`).
3. Vá em **APIs & Services > Library** e pesquise por **Google Drive API**. Ative-a.
4. Vá em **OAuth consent screen**:
   - Escolha **External**.
   - Preencha as informações obrigatórias.
   - Em **Scopes**, adicione: `.../auth/drive.file` e `.../auth/drive.readonly`.

## 2. Credenciais

### Android
1. Vá em **APIs & Services > Credentials**.
2. Clique em **Create Credentials > OAuth client ID**.
3. Selecione **Android**.
4. Informe o **Package Name** (ex: `com.italo.reader`) e o **SHA-1 certificate fingerprint**.
   - Você pode obter o SHA-1 rodando `./gradlew signingReport` na pasta `android`.

### iOS / macOS
1. Vá em **APIs & Services > Credentials**.
2. Clique em **Create Credentials > OAuth client ID**.
3. Selecione **iOS**.
4. Informe o **Bundle ID**.
5. No seu projeto Flutter, você precisará adicionar o `REVERSED_CLIENT_ID` no arquivo `Info.plist`.

## 3. Testando
Após configurar as credenciais, você poderá clicar no botão **+** na biblioteca e escolher **Google Drive**. O app abrirá o fluxo de login do Google e listará seus arquivos PDF e EPUB.
