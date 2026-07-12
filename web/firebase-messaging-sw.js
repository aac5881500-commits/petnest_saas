// web/firebase-messaging-sw.js
// 🔔 Firebase Web 背景推播 Service Worker
// 功能：初始化 Firebase Messaging，接收網頁背景推播

importScripts(
  'https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js',
);
importScripts(
  'https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js',
);

firebase.initializeApp({
  apiKey: 'AIzaSyDTcT3K_RRTLwcVlOaQIU1oLJTvNjvjDa0',
  authDomain: 'petnest-saas.firebaseapp.com',
  projectId: 'petnest-saas',
  storageBucket: 'petnest-saas.firebasestorage.app',
  messagingSenderId: '38879325834',
  appId: '1:38879325834:web:ae2e59521bfcb9cbd40773',
  measurementId: 'G-RN0TSJB10M',
});

firebase.messaging();