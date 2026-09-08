#!/usr/bin/env bash
# Build Flutter web and deploy to Firebase Hosting (project: gimie-launch).
# Requires: npm i -g firebase-tools && firebase login

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Iniciando deploy do Gimie...${NC}\n"

# Get root directory
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo -e "${YELLOW}📍 Diretório: $ROOT${NC}\n"

# Check if we're on main branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
  echo -e "${RED}⚠️  Você não está no branch main!${NC}"
  echo -e "${YELLOW}Branch atual: $CURRENT_BRANCH${NC}"
  echo -e "${YELLOW}Deseja continuar? (y/n)${NC}"
  read -r response
  if [ "$response" != "y" ]; then
    echo -e "${RED}Deploy cancelado.${NC}"
    exit 1
  fi
fi

# Pull latest changes
echo -e "${BLUE}📥 Atualizando código...${NC}"
git pull origin main

# Get dependencies
echo -e "\n${BLUE}📦 Instalando dependências...${NC}"
flutter pub get

# Build for web
echo -e "\n${BLUE}🏗️  Fazendo build para web...${NC}"
flutter build web --release

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ Build concluído com sucesso!${NC}\n"
else
  echo -e "${RED}❌ Build falhou!${NC}"
  exit 1
fi

# Deploy to Firebase
echo -e "${BLUE}🔥 Fazendo deploy no Firebase Hosting...${NC}"
firebase deploy --only hosting --project gimie-launch

if [ $? -eq 0 ]; then
  echo -e "\n${GREEN}✅ Deploy concluído com sucesso!${NC}"
  echo -e "\n${GREEN}🌐 Seu site está no ar:${NC}"
  echo -e "${BLUE}   → https://gimie-launch.web.app${NC}"
  echo -e "${BLUE}   → https://gimie-launch.firebaseapp.com${NC}\n"
  
  echo -e "${YELLOW}💡 Dica: Faça um hard refresh (Cmd+Shift+R) no navegador${NC}\n"
else
  echo -e "${RED}❌ Deploy falhou!${NC}"
  exit 1
fi
