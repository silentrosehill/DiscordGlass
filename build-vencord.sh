#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
SOURCE='.build-deps/Vencord'
REVISION="$(tr -d '\n' < UPSTREAM.txt)"
if [ ! -d "$SOURCE/.git" ]; then
  mkdir -p .build-deps
  git clone --filter=blob:none https://github.com/Vendicated/Vencord.git "$SOURCE"
  git -C "$SOURCE" checkout --detach "$REVISION"
fi
[ "$(git -C "$SOURCE" rev-parse HEAD)" = "$REVISION" ] || { echo 'Unexpected Vencord revision'; exit 1; }
mkdir -p "$SOURCE/src/userplugins/discordGlass"
cp discordGlass/*.ts "$SOURCE/src/userplugins/discordGlass/"
(cd "$SOURCE" && pnpm install --frozen-lockfile && pnpm exec tsc --noEmit && pnpm buildStandalone)
mkdir -p Vencord-dist
for name in patcher.js patcher.js.LEGAL.txt preload.js renderer.js renderer.js.LEGAL.txt renderer.css; do
  cp "$SOURCE/dist/$name" "Vencord-dist/$name"
done
printf '{}\n' > Vencord-dist/package.json
git -C "$SOURCE" archive --format=tar.gz -o "$(pwd)/Vencord-source.tar.gz" "$REVISION"
