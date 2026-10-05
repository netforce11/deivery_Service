importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyCTIKFqyZHScGsQVrrsRtwIt0_UvJFwqlE",
  authDomain: "delivery-service-98dfc.firebaseapp.com",
  projectId: "delivery-service-98dfc",
  storageBucket: "delivery-service-98dfc.firebasestorage.app",
  messagingSenderId: "785254949728",
  appId: "1:785254949728:web:8273e778ef87525af53405",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("라이더 백그라운드 알림:", payload);
  const { title, body } = payload.notification;
  self.registration.showNotification(title, {
    body,
    icon: "/icons/Icon-192.png",
  });
});
