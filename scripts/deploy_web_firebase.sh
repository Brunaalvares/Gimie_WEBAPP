#!/usr/bin/env bash
# Build Flutter web and deploy to Firebase Hosting (project: gimie-launch).
# Requires: npm i -g firebase-tools && firebase login
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
flutter build web
firebase deploy --only hosting --project gimie-launch
