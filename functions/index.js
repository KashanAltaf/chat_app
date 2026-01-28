const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Cloud Function that triggers when a new message is created in Firestore
 * Automatically sends push notification to the receiver
 */
exports.sendMessageNotification = functions.firestore
  .document('chat_rooms/{chatRoomId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const messageData = snap.data();
    const { senderId, receiverId, message, type } = messageData;

    console.log('🔔 Cloud Function triggered for new message');
    console.log('   Message data:', JSON.stringify(messageData));
    console.log('   ChatRoomId:', context.params.chatRoomId);

    // Don't send notification if message is from system or missing required fields
    if (!senderId || !receiverId) {
      console.log('⚠️ Missing senderId or receiverId, skipping notification');
      console.log('   senderId:', senderId);
      console.log('   receiverId:', receiverId);
      return null;
    }

    // Don't send notification if sender is sending to themselves
    if (senderId === receiverId) {
      console.log('⚠️ Sender and receiver are the same, skipping notification');
      return null;
    }

    try {
      // Get receiver's user document to fetch FCM token
      const receiverDoc = await admin.firestore()
        .collection('users')
        .doc(receiverId)
        .get();

      if (!receiverDoc.exists) {
        console.log('Receiver user not found');
        return null;
      }

      const receiverData = receiverDoc.data();
      console.log('   Receiver data keys:', Object.keys(receiverData || {}));
      
      // Check for token with multiple possible field names (case variations)
      const receiverToken = receiverData?.fcmToken || receiverData?.FCMToken || receiverData?.fcm_token || receiverData?.FCM_TOKEN;

      console.log('   Receiver found:', receiverId);
      console.log('   Receiver has FCM token:', !!receiverToken);
      console.log('   FCM Token type:', typeof receiverToken);
      console.log('   FCM Token value:', receiverToken ? (typeof receiverToken === 'string' ? receiverToken.substring(0, 20) + '...' : String(receiverToken)) : 'null');
      console.log('   FCM Token length:', receiverToken && typeof receiverToken === 'string' ? receiverToken.length : 'N/A');

      // Check if token is valid (not null, not undefined, not empty string)
      if (!receiverToken || (typeof receiverToken === 'string' && receiverToken.trim().length === 0)) {
        console.log('⚠️ Receiver FCM token is null, undefined, or empty');
        console.log('   Available fields:', Object.keys(receiverData || {}));
        console.log('   fcmToken value:', receiverData?.fcmToken);
        console.log('   FCMToken value:', receiverData?.FCMToken);
        console.log('   fcm_token value:', receiverData?.fcm_token);
        console.log('   Receiver data:', JSON.stringify(receiverData, null, 2));
        return null;
      }

      // Get sender's name
      const senderDoc = await admin.firestore()
        .collection('users')
        .doc(senderId)
        .get();

      const senderData = senderDoc.data();
      const senderName = senderData?.name || senderData?.displayName || 'Someone';

      // Prepare notification content based on message type
      let notificationTitle = `New message from ${senderName}`;
      let notificationBody = message || 'New message';

      if (type === 'voice') {
        notificationBody = '🎤 Voice message';
      } else if (type === 'image') {
        notificationBody = '📷 Image';
      } else if (message && typeof message === 'string' && message.length > 100) {
        notificationBody = message.substring(0, 100) + '...';
      }

      // Prepare notification payload
      const payload = {
        notification: {
          title: notificationTitle,
          body: notificationBody,
          sound: 'default',
        },
        data: {
          senderId: senderId,
          receiverId: receiverId,
          type: type || 'message',
          chatRoomId: context.params.chatRoomId,
        },
        token: receiverToken,
      };

      // Send notification
      console.log('📤 Sending FCM notification...');
      console.log('   Payload:', JSON.stringify(payload, null, 2));
      const response = await admin.messaging().send(payload);
      console.log('✅ Successfully sent notification:', response);
      return response;
    } catch (error) {
      console.error('❌ Error sending notification:', error);
      console.error('   Error details:', JSON.stringify(error, null, 2));
      return null;
    }
  });

/**
 * HTTP Callable Cloud Function for sending push notifications
 * Can be called directly from the client app
 */
exports.sendPushNotification = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to send notifications'
    );
  }

  const { receiverUserId, messageContent, chatId, messageType } = data;

  // Validate required fields
  if (!receiverUserId || !messageContent || !chatId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required fields: receiverUserId, messageContent, or chatId'
    );
  }

  try {
    console.log('🔍 Looking up receiver:', receiverUserId);
    
    // Get receiver's user document to fetch FCM token
    const receiverDoc = await admin.firestore()
      .collection('users')
      .doc(receiverUserId)
      .get();

    console.log('   Document exists:', receiverDoc.exists);
    
    if (!receiverDoc.exists) {
      console.log('❌ Receiver user document does not exist');
      throw new functions.https.HttpsError(
        'not-found',
        'Receiver user not found in Firestore'
      );
    }

    const receiverData = receiverDoc.data();
    console.log('   Receiver data keys:', Object.keys(receiverData || {}));
    console.log('   Receiver data:', JSON.stringify(receiverData, null, 2));
    
    // Check for token with multiple possible field names (case variations)
    const receiverToken = receiverData?.fcmToken || receiverData?.FCMToken || receiverData?.fcm_token || receiverData?.FCM_TOKEN;
    console.log('   FCM Token exists:', !!receiverToken);
    console.log('   FCM Token type:', typeof receiverToken);
    console.log('   FCM Token value:', receiverToken ? (typeof receiverToken === 'string' ? receiverToken.substring(0, 20) + '...' : String(receiverToken)) : 'null');
    console.log('   FCM Token length:', receiverToken && typeof receiverToken === 'string' ? receiverToken.length : 'N/A');

    // Check if token is valid (not null, not undefined, not empty string)
    if (!receiverToken || (typeof receiverToken === 'string' && receiverToken.trim().length === 0)) {
      console.log('❌ Receiver FCM token is null, undefined, or empty');
      console.log('   Available fields:', Object.keys(receiverData || {}));
      console.log('   fcmToken value:', receiverData?.fcmToken);
      console.log('   FCMToken value:', receiverData?.FCMToken);
      console.log('   fcm_token value:', receiverData?.fcm_token);
      throw new functions.https.HttpsError(
        'not-found',
        `Receiver FCM token not found. Available fields: ${Object.keys(receiverData || {}).join(', ')}. Token value: ${receiverToken}`
      );
    }

    // Get sender's information
    const senderId = context.auth.uid;
    const senderDoc = await admin.firestore()
      .collection('users')
      .doc(senderId)
      .get();

    const senderData = senderDoc.exists ? senderDoc.data() : {};
    const senderName = senderData?.name || senderData?.displayName || 'Someone';

    // Prepare notification content based on message type
    let notificationTitle = senderName;
    let notificationBody = messageContent;

    if (messageType === 'voice') {
      notificationBody = '🎤 Voice message';
    } else if (messageType === 'image') {
      notificationBody = '📷 Image';
    } else if (messageContent && messageContent.length > 100) {
      notificationBody = messageContent.substring(0, 100) + '...';
    }

    // Prepare notification payload
    const payload = {
      notification: {
        title: notificationTitle,
        body: notificationBody,
        sound: 'default',
      },
      data: {
        type: messageType || 'chat',
        chatId: chatId,
        senderId: senderId,
        senderName: senderName,
        senderPhoto: senderData?.photoURL || '',
      },
      token: receiverToken,
    };

    // Send notification
    const response = await admin.messaging().send(payload);
    console.log('Successfully sent notification:', response);
    return { success: true, messageId: response };
  } catch (error) {
    console.error('Error sending notification:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError(
      'internal',
      'Failed to send notification',
      error.message
    );
  }
});

