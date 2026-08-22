# 🔥 Como Hospedar o Gimie no Firebase Hosting

## 📋 Pré-requisitos

### Você vai precisar de:
- ✅ Conta Google
- ✅ Acesso ao projeto Firebase `gimie-launch`
- ✅ macOS (você já tem)
- ✅ Conexão com internet

---

## 🚀 Guia Completo - Do Zero ao Deploy

### Passo 1: Instalar Ferramentas Necessárias

#### 1.1 Abrir Terminal
```bash
# Pressione: Cmd + Espaço
# Digite: Terminal
# Pressione: Enter
```

#### 1.2 Instalar Homebrew (gerenciador de pacotes)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
⏱️ **Tempo:** ~5 minutos

#### 1.3 Instalar Flutter
```bash
brew install --cask flutter
```
⏱️ **Tempo:** ~10 minutos

#### 1.4 Configurar Flutter para Web
```bash
flutter config --enable-web
flutter doctor
```

#### 1.5 Instalar Node.js
```bash
brew install node
```
⏱️ **Tempo:** ~3 minutos

#### 1.6 Instalar Firebase CLI
```bash
npm install -g firebase-tools
```
⏱️ **Tempo:** ~2 minutos

#### 1.7 Verificar Instalações
```bash
flutter --version   # Deve mostrar versão do Flutter
node --version      # Deve mostrar versão do Node
npm --version       # Deve mostrar versão do npm
firebase --version  # Deve mostrar versão do Firebase CLI
```

✅ **Se todos mostrarem versões, está pronto para continuar!**

---

### Passo 2: Preparar o Projeto

#### 2.1 Navegar para a Pasta do Projeto
```bash
cd "/Users/brunaalvares/Documentos/Gimie atualiza-o/gimie-web"
```

**OU** se ainda não clonou:

```bash
# Criar pasta para projetos
mkdir -p ~/Projetos
cd ~/Projetos

# Clonar repositório
git clone https://github.com/Brunaalvares/Gimie_WEBAPP.git gimie-web
cd gimie-web
```

#### 2.2 Instalar Dependências do Flutter
```bash
flutter pub get
```
⏱️ **Tempo:** ~1 minuto

---

### Passo 3: Configurar Firebase

#### 3.1 Fazer Login no Firebase
```bash
firebase login
```

**Isso vai:**
1. Abrir seu navegador
2. Pedir para fazer login com sua conta Google
3. Pedir permissão para o Firebase CLI

**Clique em "Permitir"**

#### 3.2 Verificar Acesso ao Projeto
```bash
firebase projects:list
```

Você deve ver:
```
┌──────────────┬──────────────────┬────────────────┐
│ Project ID   │ Display Name     │ Resource ID    │
├──────────────┼──────────────────┼────────────────┤
│ gimie-launch │ Gimie Launch     │ gimie-launch   │
└──────────────┴──────────────────┴────────────────┘
```

✅ **Se ver `gimie-launch`, está tudo certo!**

---

### Passo 4: Build da Aplicação

#### 4.1 Fazer Build para Web
```bash
flutter build web
```

**Você verá:**
```
Building without sound null safety
Compiling lib/main.dart for the Web...
```

⏱️ **Tempo:** ~2-3 minutos

**Ao finalizar:**
```
✓ Built build/web
```

✅ **Build concluído!** A pasta `build/web` foi criada com todos os arquivos.

---

### Passo 5: Deploy no Firebase Hosting

#### 5.1 Fazer Deploy
```bash
firebase deploy --only hosting --project gimie-launch
```

**Você verá:**
```
=== Deploying to 'gimie-launch'...

i  deploying hosting
i  hosting[gimie-launch]: beginning deploy...
i  hosting[gimie-launch]: found 50 files in build/web
✔  hosting[gimie-launch]: file upload complete
i  hosting[gimie-launch]: finalizing version...
✔  hosting[gimie-launch]: version finalized
i  hosting[gimie-launch]: releasing new version...
✔  hosting[gimie-launch]: release complete

✔  Deploy complete!
```

⏱️ **Tempo:** ~1-2 minutos

---

### Passo 6: Verificar Deploy

#### 6.1 Abrir o Site
```bash
open https://gimie-launch.web.app
```

Ou acesse manualmente:
- https://gimie-launch.web.app
- https://gimie-launch.firebaseapp.com

#### 6.2 Testar Funcionalidades

✅ **Site carrega**
✅ **Pode fazer login**
✅ **Pode ver perfil**
✅ **Botão de compartilhar aparece nas pastas**
✅ **Modal de download aparece em links compartilhados**

---

## ⚡ Script Automático (Próximos Deploys)

Depois da primeira vez, use o script pronto:

```bash
cd "/Users/brunaalvares/Documentos/Gimie atualiza-o/gimie-web"
./scripts/deploy_web_firebase.sh
```

Esse script faz:
1. `flutter build web` (build)
2. `firebase deploy --only hosting` (deploy)

⏱️ **Tempo total:** ~3-5 minutos

---

## 📁 Estrutura do Projeto

```
gimie-web/
├── lib/                          # Código Dart/Flutter
│   ├── main.dart
│   ├── screens/
│   ├── services/
│   │   └── shared_link_service.dart   # Novo! Compartilhamento
│   ├── widgets/
│   │   └── app_download_modal.dart    # Novo! Modal de download
│   └── ...
├── web/                          # Assets web
├── build/web/                    # Build output (criado após flutter build)
├── scripts/
│   └── deploy_web_firebase.sh    # Script de deploy
├── firebase.json                 # Config Firebase Hosting
├── .firebaserc                   # Projeto Firebase
└── pubspec.yaml                  # Dependências Flutter
```

---

## 🔄 Workflow de Deploy

### Deploy Completo (Primeira vez ou grandes mudanças)
```bash
cd "/Users/brunaalvares/Documentos/Gimie atualiza-o/gimie-web"
git pull origin main
flutter clean
flutter pub get
flutter build web
firebase deploy --only hosting
```

### Deploy Rápido (Pequenas mudanças)
```bash
cd "/Users/brunaalvares/Documentos/Gimie atualiza-o/gimie-web"
git pull origin main
./scripts/deploy_web_firebase.sh
```

### Deploy Manual (Se o script não funcionar)
```bash
cd "/Users/brunaalvares/Documentos/Gimie atualiza-o/gimie-web"
git pull origin main
flutter build web
firebase deploy --only hosting --project gimie-launch
```

---

## 🎯 Comandos Úteis

### Ver versões instaladas
```bash
flutter --version
firebase --version
```

### Limpar build anterior
```bash
flutter clean
```

### Testar build localmente
```bash
flutter build web
cd build/web
python3 -m http.server 8000
# Abrir http://localhost:8000
```

### Ver logs do Firebase
```bash
firebase hosting:channel:list
```

### Logout/Login Firebase
```bash
firebase logout
firebase login
```

### Atualizar Firebase CLI
```bash
npm update -g firebase-tools
```

---

## 🚨 Troubleshooting

### ❌ "flutter: command not found"
```bash
brew install --cask flutter
flutter config --enable-web
```

### ❌ "firebase: command not found"
```bash
npm install -g firebase-tools
```

### ❌ "HTTP Error: 403, Permission denied"
```bash
firebase logout
firebase login
firebase projects:list  # Verificar acesso
```

### ❌ "Could not find a file named pubspec.yaml"
```bash
# Você não está na pasta correta
cd "/Users/brunaalvares/Documentos/Gimie atualiza-o/gimie-web"
ls pubspec.yaml  # Deve existir
```

### ❌ Build demora muito ou trava
```bash
flutter clean
flutter pub get
flutter build web --release
```

### ❌ "Error: No Firebase project found"
```bash
firebase use gimie-launch
```

### ❌ Site não atualiza após deploy
```bash
# No navegador:
# Cmd + Shift + R (Mac) - Hard refresh
# Ou abra em aba anônima
```

---

## 📊 O Que Foi Deployed

### Código
- ✅ Detecção de links compartilhados
- ✅ Modal de download do app
- ✅ Botão de compartilhar nas pastas
- ✅ URLs das lojas (App Store e Play Store)
- ✅ Todos os recursos anteriores

### Features Novas
1. **Compartilhamento de Pastas**
   - Botão na AppBar da pasta
   - Opção no menu (⋮)
   - Cópia automática do link

2. **Barreira de Download**
   - Detecta `?shared=true` na URL
   - Mostra modal ao clicar "Shop Now"
   - Links para App Store e Play Store

### URLs das Lojas Configuradas
- App Store: https://apps.apple.com/br/app/gimie/id6768790198
- Play Store: https://play.google.com/apps/test/com.gimie.app/7

---

## ✅ Checklist de Deploy

Antes de fazer deploy:
- [ ] Código testado localmente
- [ ] Git atualizado (`git pull`)
- [ ] Dependências instaladas (`flutter pub get`)
- [ ] Build funciona (`flutter build web`)
- [ ] Firebase CLI autenticado (`firebase login`)

Durante o deploy:
- [ ] Build completa sem erros
- [ ] Upload de arquivos bem-sucedido
- [ ] Mensagem "Deploy complete!" aparece

Após o deploy:
- [ ] Site carrega em produção
- [ ] Login funciona
- [ ] Compartilhamento funciona
- [ ] Modal de download aparece
- [ ] Mobile responsivo OK

---

## 🌐 URLs da Aplicação

### Produção
- **Principal:** https://gimie-launch.web.app
- **Alternativa:** https://gimie-launch.firebaseapp.com

### Teste Local
- **Local:** http://localhost:8000 (após `python3 -m http.server 8000`)

### Firebase Console
- **Console:** https://console.firebase.google.com/project/gimie-launch/hosting

---

## 💰 Custos

Firebase Hosting - Plano Gratuito (Spark):
- ✅ 10 GB armazenamento
- ✅ 360 MB/dia transferência
- ✅ SSL grátis
- ✅ Domínio customizado grátis

**Para o Gimie, é grátis!** (A menos que tenha MUITO tráfego)

---

## 📞 Suporte

### Documentação Oficial
- Flutter Web: https://docs.flutter.dev/platform-integration/web
- Firebase Hosting: https://firebase.google.com/docs/hosting

### Comandos de Ajuda
```bash
flutter help
firebase help
firebase deploy --help
```

---

## 🎉 Sucesso!

Se você chegou até aqui e fez o deploy, **parabéns!** 🎊

Seu aplicativo está agora hospedado em:
**https://gimie-launch.web.app**

Com todas as novas funcionalidades:
- ✅ Compartilhamento de pastas
- ✅ Barreira de download
- ✅ Links das lojas

---

## 📱 Próximos Passos

1. **Testar em diferentes dispositivos**
   - Desktop
   - Mobile (iOS e Android)
   - Diferentes navegadores

2. **Monitorar uso**
   - Firebase Console → Analytics
   - Ver quantas pessoas acessam
   - Ver quais features usam mais

3. **Configurar domínio customizado** (opcional)
   - Firebase Console → Hosting → Add custom domain
   - Ex: gimie.site

4. **Automatizar deploys** (opcional)
   - Configurar GitHub Actions
   - Deploy automático ao dar push

---

✨ **Tudo pronto para produção!** ✨
