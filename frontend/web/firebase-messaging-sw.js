// Shows notifications while the app is closed or in the background.
// Paste the same values as in lib/core/push/firebase_config.dart.
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBa-82bVCjm2jfu_o5EiGie93AfH_Dqlbo',
  authDomain: 'annual-leave-15b6e.firebaseapp.com',
  projectId: 'annual-leave-15b6e',
  storageBucket: 'annual-leave-15b6e.firebasestorage.app',
  messagingSenderId: '554338128675',
  appId: '1:554338128675:web:13bea11b38450c1ba2b296',
});

// The server sends a ready-made notification, so the browser shows it on its own.
firebase.messaging();
