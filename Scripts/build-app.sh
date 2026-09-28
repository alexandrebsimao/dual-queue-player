#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/DualQueue Player.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ASSET_CATALOG_DIR="$ROOT_DIR/Resources/Assets.xcassets"

cd "$ROOT_DIR"
swift build -c release

BIN_PATH="$ROOT_DIR/.build/out/Products/Release/DualQueuePlayer"
if [[ ! -x "$BIN_PATH" ]]; then
    BIN_PATH="$(find "$ROOT_DIR/.build" -type f -name DualQueuePlayer -perm -111 -print -quit)"
fi
if [[ -z "$BIN_PATH" ]]; then
    echo "Não foi possível localizar o executável Release." >&2
    exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_PATH" "$MACOS_DIR/DualQueuePlayer"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

if [[ -d "$ASSET_CATALOG_DIR" ]]; then
    xcrun actool \
        --compile "$RESOURCES_DIR" \
        --platform macosx \
        --minimum-deployment-target 13.0 \
        --app-icon AppIcon \
        --output-partial-info-plist "$CONTENTS_DIR/asset-info.plist" \
        "$ASSET_CATALOG_DIR" >/dev/null
    rm -f "$CONTENTS_DIR/asset-info.plist"
elif [[ -f "$ROOT_DIR/Resources/AppIcon.icns" ]]; then
    cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
else
    echo "Aviso: AppIcon não encontrado; o app usará o ícone padrão do macOS."
fi

# Assinatura ad-hoc para permitir a abertura local pelo Finder.
codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "Aplicativo criado em: $APP_DIR"
echo "Para abrir: open \"$APP_DIR\""
