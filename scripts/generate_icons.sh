#!/bin/bash

# Script para gerar ícones do app Lumen Reader
# Executa o flutter_launcher_icons para criar ícones em todas as plataformas

echo "🚀 Gerando ícones do Lumen Reader..."
echo "📱 Plataformas: Android, iOS, Web"
echo ""

# Instalar dependências se necessário
echo "📦 Instalando dependências..."
flutter pub get

echo ""
echo "🎨 Gerando ícones a partir de assets/icon/app_icon.png..."

# Gerar ícones
flutter pub run flutter_launcher_icons:main

echo ""
echo "✅ Ícones gerados com sucesso!"
echo "📱 Android: android/app/src/main/res/mipmap-*/"
echo "🍎 iOS: ios/Runner/Assets.xcassets/AppIcon.appiconset/"
echo "🌐 Web: web/icons/"
echo ""
echo "🔧 Para aplicar as mudanças:"
echo "   - Android: Rebuild do projeto"
echo "   - iOS: Rebuild do projeto"
echo "   - Web: Refresh do navegador"