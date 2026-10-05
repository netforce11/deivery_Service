#!/bin/bash
set -e

echo "🏗️  Building all apps..."

echo "📱 Building customer app..."
cd customer_app
flutter build web --release
cd ..

echo "🏪 Building store app..."
cd store_app
flutter build web --release
cd ..

echo "🛵 Building rider app..."
cd rider_app
flutter build web --release
cd ..

echo "📦 Installing Cloud Functions dependencies..."
cd functions
npm install
cd ..

echo "🚀 Deploying to Firebase Hosting + Cloud Functions..."
firebase deploy --only hosting,functions

echo ""
echo "✅ 배포 완료!"
echo "고객앱:  https://delivery-customer-app.web.app"
echo "업체앱:  https://delivery-store-app.web.app"
echo "라이더앱: https://delivery-rider-app.web.app"
