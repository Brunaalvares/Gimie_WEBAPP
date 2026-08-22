# 🚀 Como Fazer Deploy do Gimie Web

## 📋 Pré-requisitos

Antes de começar, você precisa ter:

### 1. Flutter Instalado
```bash
flutter --version
# Deve mostrar Flutter 3.x ou superior
```

Se não tiver, instale em: https://docs.flutter.dev/get-started/install

### 2. Firebase CLI Instalado
```bash
firebase --version
```

Se não tiver:
```bash
npm install -g firebase-tools
```

### 3. Autenticação no Firebase
```bash
firebase login
```

Isso abrirá o navegador para você fazer login com sua conta Google.

### 4. Verificar Acesso ao Projeto
```bash
firebase projects:list
```

Você deve ver o projeto `gimie-launch` na lista.

---

## 🎯 Deploy Rápido (Método Recomendado)

O projeto tem um script pronto que faz tudo automaticamente:

```bash
./scripts/deploy_web_firebase.sh
```

Esse script:
1. ✅ Faz build do Flutter para web
2. ✅ Faz deploy no Firebase Hosting
3. ✅ Usa o projeto `gimie-launch` automaticamente

### Se der erro de permissão:
```bash
chmod +x scripts/deploy_web_firebase.sh
./scripts/deploy_web_firebase.sh
```

---

## 📝 Deploy Passo a Passo (Método Manual)

Se preferir fazer manualmente ou entender o processo:

### 1. Build do Flutter
```bash
flutter build web
```

Isso cria a pasta `build/web/` com todos os arquivos estáticos.

**Importante:** Sempre faça o build antes do deploy!

### 2. Deploy no Firebase
```bash
firebase deploy --only hosting --project gimie-launch
```

Ou simplesmente (usa o projeto default do `.firebaserc`):
```bash
firebase deploy --only hosting
```

---

## 🌐 Após o Deploy

### URL do Site
Seu site estará disponível em:
```
https://gimie-launch.web.app
```

ou

```
https://gimie-launch.firebaseapp.com
```

### Verificar Deploy
Acesse a URL e teste:
1. ✅ Site carrega corretamente
2. ✅ Login funciona
3. ✅ Pastas aparecem
4. ✅ Botão de compartilhar funciona
5. ✅ Links compartilhados funcionam com `?shared=true`

---

## 🔄 Workflow Completo de Desenvolvimento

### 1. Desenvolvimento Local
```bash
# Instalar dependências
flutter pub get

# Rodar localmente
flutter run -d chrome

# Ou com hot reload
flutter run -d chrome --hot
```

### 2. Testar Build Local
```bash
# Build
flutter build web

# Servir localmente para testar
cd build/web
python3 -m http.server 8000
# Acesse http://localhost:8000
```

### 3. Deploy para Produção
```bash
# Método 1: Script automático
./scripts/deploy_web_firebase.sh

# Método 2: Manual
flutter build web
firebase deploy --only hosting
```

---

## 🔧 Configurações do Firebase Hosting

O arquivo `firebase.json` já está configurado com:

### Public Directory
```json
"public": "build/web"
```
Aponta para a pasta de build do Flutter.

### SPA Rewrite
```json
"rewrites": [
  {
    "source": "**",
    "destination": "/index.html"
  }
]
```
Redireciona todas as URLs para `index.html` (necessário para SPAs).

### Cache Headers
- Service Worker: `no-cache` (sempre atualizado)
- JS/WASM: `max-age=31536000` (1 ano de cache para assets com hash)

---

## 🚨 Problemas Comuns

### ❌ "Command not found: flutter"
**Solução:**
```bash
# Adicione Flutter ao PATH
export PATH="$PATH:/caminho/para/flutter/bin"

# Ou reinstale Flutter
```

### ❌ "Command not found: firebase"
**Solução:**
```bash
npm install -g firebase-tools
```

### ❌ "Permission denied: deploy_web_firebase.sh"
**Solução:**
```bash
chmod +x scripts/deploy_web_firebase.sh
```

### ❌ "Error: HTTP Error: 403, Permission denied"
**Solução:**
```bash
# Faça login novamente
firebase logout
firebase login

# Verifique se tem acesso ao projeto
firebase projects:list
```

### ❌ "Build failed" ou erros de compilação
**Solução:**
```bash
# Limpe o build anterior
flutter clean

# Baixe dependências novamente
flutter pub get

# Tente novamente
flutter build web
```

### ❌ Site não atualiza após deploy
**Solução:**
```bash
# Limpe o cache do navegador
# Ou abra em modo anônimo
# Ou force refresh: Ctrl+Shift+R (Windows/Linux) ou Cmd+Shift+R (Mac)
```

---

## 📦 O Que Está Sendo Deployed

Quando você faz deploy, estes arquivos vão para o Firebase:

```
build/web/
├── index.html                 # Página principal
├── main.dart.js              # Código Flutter compilado
├── flutter_service_worker.js # Service worker para PWA
├── manifest.json             # Manifesto PWA
├── assets/                   # Imagens, fontes, etc.
│   ├── fonts/
│   ├── images/
│   └── ...
└── ...
```

**Tamanho aproximado:** 2-5 MB (comprimido)

---

## 🎯 Deploy das Suas Mudanças

Você acabou de implementar a funcionalidade de compartilhamento! Para fazer deploy:

### 1. Mesclar a branch (se ainda não fez)
```bash
# Se estiver na branch de feature
git checkout main
git pull origin main
git merge cursor/add-app-download-barrier-bfa6
```

Ou faça via Pull Request no GitHub e depois:
```bash
git checkout main
git pull origin main
```

### 2. Deploy
```bash
./scripts/deploy_web_firebase.sh
```

### 3. Testar
```bash
# Acesse o site
open https://gimie-launch.web.app

# Teste o compartilhamento:
# 1. Faça login
# 2. Vá para Perfil
# 3. Clique nos três pontos de uma pasta
# 4. Clique em "Compartilhar pasta"
# 5. Cole o link em uma aba anônima
# 6. Clique em "Shop Now" em um produto
# 7. Veja o modal de download aparecer!
```

---

## 📊 Monitoramento

### Ver Logs do Deploy
```bash
firebase hosting:channel:list
```

### Ver Uso do Hosting
Acesse o console do Firebase:
```
https://console.firebase.google.com/project/gimie-launch/hosting
```

### Estatísticas
- Total de requisições
- Largura de banda usada
- Domínios customizados

---

## 🌍 Domínio Customizado (Opcional)

Se quiser usar um domínio próprio (ex: `gimie.site`):

### 1. No Firebase Console
```
Firebase Console → Hosting → Add custom domain
```

### 2. Configure DNS
Adicione os registros DNS que o Firebase mostrar.

### 3. Aguarde Propagação
Pode levar até 24h para o domínio ficar ativo.

---

## 🔐 Variáveis de Ambiente

O projeto usa Firebase para configuração. Não há `.env` files.

Configurações estão em:
- `lib/firebase_options.dart` - Chaves do Firebase
- `lib/config/api_config.dart` - URLs da API
- `lib/widgets/app_download_modal.dart` - URLs das lojas

**Já configurado:**
- ✅ Firebase project: `gimie-launch`
- ✅ App Store: https://apps.apple.com/br/app/gimie/id6768790198
- ✅ Play Store: https://play.google.com/apps/test/com.gimie.app/7

---

## ✅ Checklist de Deploy

Antes de fazer deploy em produção:

- [ ] Código testado localmente
- [ ] Build funciona sem erros: `flutter build web`
- [ ] Testes manuais passaram
- [ ] Links de compartilhamento funcionam
- [ ] Modal de download aparece corretamente
- [ ] URLs das lojas estão corretas
- [ ] PR foi revisada e aprovada
- [ ] Branch mergeada no `main`
- [ ] Documentação atualizada

Depois do deploy:

- [ ] Site carrega em produção
- [ ] Funcionalidades testadas em produção
- [ ] Links compartilhados testados
- [ ] Mobile responsivo verificado
- [ ] Performance aceitável

---

## 📱 Deploy do App Mobile (Separado)

**Importante:** Este repositório é **só para Web**.

O deploy dos apps iOS e Android é feito separadamente:

### iOS (App Store)
- Xcode + TestFlight
- Repositório mobile separado

### Android (Play Store)
- Android Studio + Play Console
- Repositório mobile separado

---

## 🆘 Ajuda

### Firebase CLI
```bash
firebase help
firebase deploy --help
```

### Flutter Build
```bash
flutter build web --help
```

### Documentação
- Firebase Hosting: https://firebase.google.com/docs/hosting
- Flutter Web: https://docs.flutter.dev/platform-integration/web

---

## 🚀 Deploy Automático (CI/CD) - Opcional

Para automatizar deploys, você pode usar GitHub Actions:

### `.github/workflows/deploy.yml`
```yaml
name: Deploy to Firebase Hosting

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
      
      - run: flutter pub get
      - run: flutter build web
      
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          projectId: gimie-launch
```

Isso fará deploy automático toda vez que você der push no `main`!

---

✨ **Pronto para deploy!** ✨

Execute: `./scripts/deploy_web_firebase.sh`
