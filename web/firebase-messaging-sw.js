// Firebase Messaging Service Worker
// This file is required for Firebase Cloud Messaging (FCM) push notifications on web.

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCFxPa8y4Te186YjSqW2_A_eYaQYCKaofE',
  authDomain: 'studysphere-app-3a480.firebaseapp.com',
  projectId: 'studysphere-app-3a480',
  storageBucket: 'studysphere-app-3a480.firebasestorage.app',
  messagingSenderId: '726667741250',
  appId: '1:726667741250:web:9b876c4744938e725a85db',
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification?.title || 'StudySphere';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
  };
  self.registration.showNotification(notificationTitle, notificationOptions);
});
