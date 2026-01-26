# Cloud Function Setup for Push Notifications

This guide will help you set up Firebase Cloud Functions to automatically send push notifications when messages are sent, **without needing a backend server**.

## Prerequisites

1. Firebase CLI installed: `npm install -g firebase-tools`
2. Node.js 18+ installed
3. Firebase project created

## Setup Steps

### 1. Initialize Firebase Functions (if not already done)

```bash
cd functions
npm install
```

### 2. Login to Firebase

```bash
firebase login
```

### 3. Initialize Firebase in your project (if not already done)

```bash
firebase init functions
```

When prompted:
- Select your Firebase project
- Choose JavaScript (or TypeScript if you prefer)
- Say "Yes" to install dependencies

### 4. Deploy the Cloud Function

```bash
firebase deploy --only functions:sendMessageNotification
```

Or deploy all functions:

```bash
firebase deploy --only functions
```

## How It Works

1. **Automatic Trigger**: When a message is written to `chat_rooms/{chatRoomId}/messages/{messageId}` in Firestore, the Cloud Function automatically triggers.

2. **No Backend Required**: Cloud Functions are serverless - Firebase handles all the infrastructure. You don't need to maintain any servers.

3. **Secure**: The function runs on Firebase's servers with admin privileges, so it can securely access Firestore and send notifications.

4. **Cost-Effective**: Firebase Cloud Functions have a generous free tier (2 million invocations/month).

## Testing

After deployment, send a message in your app. The Cloud Function will automatically:
- Detect the new message
- Fetch the receiver's FCM token from Firestore
- Get the sender's name
- Send a push notification

Check the Firebase Console > Functions > Logs to see the function execution logs.

## Troubleshooting

- **Function not triggering**: Make sure the function is deployed and check Firestore security rules allow writes
- **Notifications not received**: Verify FCM tokens are saved in Firestore (`users/{userId}/fcmToken`)
- **Check logs**: `firebase functions:log` or Firebase Console > Functions > Logs

## Cost

- **Free Tier**: 2 million invocations/month, 400,000 GB-seconds/month
- **Pricing**: After free tier, very affordable ($0.40 per million invocations)

This is a one-time setup - once deployed, it works automatically!

