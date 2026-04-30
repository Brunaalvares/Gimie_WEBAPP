# Gimie — Web (Flutter)

Projeto Flutter **só para Web** (sem pastas `android/` / `ios/`). O código partilhado com a app móvel vive em `lib/`, `web/`, `assets/`.

## Requisitos

- [Flutter](https://docs.flutter.dev/get-started/install) com suporte Web (`flutter config --enable-web`).

## Comandos

```bash
flutter pub get
flutter run -d chrome
flutter build web
```

Deploy Firebase Hosting (com [Firebase CLI](https://firebase.google.com/docs/cli) autenticada):

```bash
./scripts/deploy_web_firebase.sh
```

## Publicar no GitHub

1. Cria um repositório **vazio** em [github.com/new](https://github.com/new) (sem README/licença, para evitar conflito).
2. Na pasta deste projeto:

```bash
git init
git add .
git commit -m "Initial commit: Gimie Flutter web"
git branch -M main
git remote add origin https://github.com/SEU_USUARIO/SEU_REPO.git
git push -u origin main
```

Substitui `SEU_USUARIO/SEU_REPO` pelo teu URL.
