// Firebase Cloud Messaging Service Worker
// Flutter Web FCM을 위해 필수

importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyCTIKFqyZHScGsQVrrsRtwIt0_UvJFwqlE",
  authDomain: "delivery-service-98dfc.firebaseapp.com",
  projectId: "delivery-service-98dfc",
  storageBucket: "delivery-service-98dfc.firebasestorage.app",
  messagingSenderId: "785254949728",
  appId: "1:785254949728:web:97aa4858dd37678ff53405",
});

const messaging = firebase.messaging();

// 백그라운드 메시지 처리
messaging.onBackgroundMessage((payload) => {
  console.log("백그라운드 메시지 수신:", payload);
  const { title, body } = payload.notification;
  self.registration.showNotification(title, {
    body,
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
  });
});
