# 🚀 GUIA RÁPIDO DE DEPLOY - GIMIE

## ✅ Mudanças Prontas para Deploy

Todas as correções foram mergeadas no `main`:
- ✅ Link de compartilhamento corrigido
- ✅ Seguir usuários funcionando  
- ✅ Busca/trend corrigida
- ✅ Página compartilhada melhorada com foto e @username
- ✅ Botão "Baixar Gimie" destacado

---

## 🎯 DEPLOY EM 3 PASSOS SIMPLES

### Passo 1: Preparar o Ambiente ⚙️

Abra o Terminal no seu computador e execute:

```bash
# 1. Ir para a pasta do projeto
cd "/Users/brunaalvares/Documentos/Gimie atualiza-o/gimie-web"

# 2. Atualizar código do GitHub
git pull origin main

# 3. Instalar/atualizar dependências
flutter pub get
```

### Passo 2: Fazer o Build 🏗️

```bash
flutter build web --release
```

⏱️ Isso vai demorar **2-3 minutos**. Aguarde ver: `✓ Built build/web`

### Passo 3: Deploy no Firebase 🔥

```bash
firebase deploy --only hosting --project gimie-launch
```

⏱️ Demora **1-2 minutos**. Aguarde ver: `✔ Deploy complete!`

---

## 🎉 PRONTO!

Seu site está no ar em:
- **https://gimie-launch.web.app**
- **https://gimie-launch.firebaseapp.com**

---

## 🤖 OU USE O SCRIPT AUTOMÁTICO

Execute apenas um comando que faz tudo:

```bash
cd "/Users/brunaalvares/Documentos/Gimie atualiza-o/gimie-web"
./scripts/deploy_web_firebase.sh
```

Esse script faz automaticamente os passos 2 e 3!

---

## ⚠️ Precisa Instalar Algo?

### Se `flutter: command not found`:
```bash
brew install --cask flutter
flutter config --enable-web
```

### Se `firebase: command not found`:
```bash
npm install -g firebase-tools
firebase login
```

### Se não tem Homebrew:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

---

## ✨ Teste Após o Deploy

Abra o site e teste:

1. ✅ Site carrega corretamente
2. ✅ Faça login
3. ✅ Vá no seu perfil
4. ✅ Clique nos 3 pontos de uma pasta → "Compartilhar pasta"
5. ✅ Verifique se aparece "Link copiado!"
6. ✅ Abra o link em outra aba
7. ✅ Verifique se vê seu avatar e @username
8. ✅ Clique em "Baixar Gimie" e veja o modal
9. ✅ Busque um usuário e clique em "Seguir"
10. ✅ Verifique mensagem de confirmação

---

## 📱 URLs Importantes

- **Site Produção:** https://gimie-launch.web.app
- **Firebase Console:** https://console.firebase.google.com/project/gimie-launch
- **App Store:** https://apps.apple.com/br/app/gimie/id6768790198
- **Play Store:** https://play.google.com/apps/test/com.gimie.app/7

---

## 🆘 Problemas?

### Build dá erro:
```bash
flutter clean
flutter pub get
flutter build web --release
```

### Deploy falha:
```bash
firebase logout
firebase login
firebase deploy --only hosting --project gimie-launch
```

### Site não atualiza:
No navegador, pressione **Cmd + Shift + R** (Mac) para forçar refresh

---

## 📊 Monitoramento

Depois do deploy, acompanhe:
- **Firebase Console** → Analytics
- **Hosting** → Ver número de visitantes
- **Firestore** → Ver novos usuários

---

## 💡 Dicas

- ✅ Sempre teste localmente antes: `flutter run -d chrome`
- ✅ Faça backup do código: `git push`
- ✅ Deploy em horário de baixo tráfego
- ✅ Teste em diferentes dispositivos após deploy
- ✅ Monitore por algumas horas após deploy

---

**🚀 Boa sorte com o deploy!**

Para qualquer problema, consulte o guia completo em: `docs/HOSPEDAR_FIREBASE.md`
