# 🍎 Deploy no macOS - Guia Completo

## ⚡ Instalação Rápida (Recomendado)

### 1. Instalar Homebrew (se não tiver)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Instalar Flutter
```bash
brew install --cask flutter
```

### 3. Configurar Flutter
```bash
# Aceitar licenças
flutter doctor --android-licenses

# Habilitar web
flutter config --enable-web

# Verificar instalação
flutter doctor
```

### 4. Instalar Node.js (para Firebase CLI)
```bash
brew install node
```

### 5. Instalar Firebase CLI
```bash
npm install -g firebase-tools
```

### 6. Login no Firebase
```bash
firebase login
```

### 7. Deploy! 🚀
```bash
cd ~/caminho/para/Gimie_WEBAPP
./scripts/deploy_web_firebase.sh
```

---

## 📝 Instalação Manual (Sem Homebrew)

### 1. Instalar Flutter
```bash
# Baixar Flutter
cd ~
curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.24.0-stable.zip

# Extrair
unzip flutter_macos_3.24.0-stable.zip

# Adicionar ao PATH
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.zshrc
source ~/.zshrc

# Verificar
flutter --version
```

### 2. Instalar Node.js
Baixe de: https://nodejs.org/en/download/

### 3. Instalar Firebase CLI
```bash
npm install -g firebase-tools
```

---

## 🎯 Comandos Completos (Copie e Cole)

### Se você tem Homebrew:
```bash
# Instalar tudo de uma vez
brew install --cask flutter
brew install node
npm install -g firebase-tools

# Configurar Flutter
flutter config --enable-web
flutter doctor

# Login Firebase
firebase login

# Ir para o projeto e fazer deploy
cd ~/caminho/para/Gimie_WEBAPP
./scripts/deploy_web_firebase.sh
```

### Se NÃO tem Homebrew:
```bash
# Baixar e instalar Flutter
cd ~
curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.24.0-stable.zip
unzip flutter_macos_3.24.0-stable.zip
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.zshrc
source ~/.zshrc

# Baixar Node.js manualmente de: https://nodejs.org
# Depois:
npm install -g firebase-tools
firebase login

# Ir para o projeto e fazer deploy
cd ~/caminho/para/Gimie_WEBAPP
./scripts/deploy_web_firebase.sh
```

---

## ✅ Verificar se Tudo Está Instalado

Rode estes comandos para verificar:

```bash
flutter --version    # Deve mostrar Flutter 3.x.x
node --version       # Deve mostrar v20.x.x ou similar
npm --version        # Deve mostrar 10.x.x ou similar
firebase --version   # Deve mostrar 13.x.x ou similar
```

---

## 🚀 Fazer Deploy

Depois de tudo instalado:

```bash
# Navegue até a pasta do projeto
cd ~/caminho/para/Gimie_WEBAPP

# Execute o script
./scripts/deploy_web_firebase.sh
```

**Tempo estimado:** 3-5 minutos

---

## 🎬 O que o Deploy Faz

1. **Build** (`flutter build web`)
   - Compila o código Flutter para JavaScript
   - Cria pasta `build/web/` com arquivos estáticos
   - ⏱️ ~2-3 minutos

2. **Deploy** (`firebase deploy`)
   - Faz upload dos arquivos para Firebase Hosting
   - Publica em https://gimie-launch.web.app
   - ⏱️ ~1-2 minutos

---

## 🔍 Troubleshooting

### ❌ "flutter: command not found"
```bash
# Verifique o PATH
echo $PATH

# Adicione Flutter ao PATH
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.zshrc
source ~/.zshrc
```

### ❌ "firebase: command not found"
```bash
# Reinstale Firebase CLI
npm uninstall -g firebase-tools
npm install -g firebase-tools

# Verifique
which firebase
```

### ❌ "Permission denied: npm install"
```bash
# Use sudo (macOS)
sudo npm install -g firebase-tools
```

### ❌ "Firebase login failed"
```bash
# Logout e tente novamente
firebase logout
firebase login

# Ou use token
firebase login --no-localhost
```

---

## 📱 Atalhos Úteis

### Build apenas
```bash
flutter build web
```

### Deploy apenas (sem build)
```bash
firebase deploy --only hosting
```

### Ver logs
```bash
firebase hosting:channel:list
```

---

## 🎯 Resumo para Você

Como você está no **macOS**, a forma mais fácil é:

1. **Abra o Terminal** (Cmd + Espaço, digite "Terminal")

2. **Cole estes comandos:**
```bash
# Instalar Homebrew (se não tiver)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Instalar Flutter e Node
brew install --cask flutter
brew install node

# Instalar Firebase
npm install -g firebase-tools

# Configurar
flutter config --enable-web
firebase login
```

3. **Navegue até seu projeto:**
```bash
cd ~/caminho/para/Gimie_WEBAPP
```

4. **Deploy:**
```bash
./scripts/deploy_web_firebase.sh
```

**Pronto!** 🎉

---

## ⏱️ Tempo Total

- Instalação: ~10-15 minutos (primeira vez)
- Deploy: ~3-5 minutos
- **Total: ~15-20 minutos**

---

## 🌐 Resultado

Após o deploy, seu site estará em:
- https://gimie-launch.web.app
- https://gimie-launch.firebaseapp.com

Com todas as novas funcionalidades:
- ✅ Compartilhamento de pastas
- ✅ Barreira de download do app
- ✅ Links das lojas configurados

---

## 💡 Próximos Deploys

Depois da primeira vez, é só:

```bash
cd ~/caminho/para/Gimie_WEBAPP
git pull
./scripts/deploy_web_firebase.sh
```

**2-3 minutos** ⚡
