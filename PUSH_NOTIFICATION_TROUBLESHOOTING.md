# Push Notification Troubleshooting Guide

## Quick Checks

### 1. ✅ Verify FCM Tokens are Saved
Check in Firebase Console → Firestore → `users` collection:
- Each user document should have an `fcmToken` field
- The token should be a long string starting with letters/numbers

**To check in app logs:**
- Look for: `✅ FCM Token saved to Firestore for user: [userId]`
- If you see `⚠️ FCM Token is null`, notifications won't work

### 2. ✅ Deploy Cloud Functions
The Cloud Function must be deployed for automatic notifications to work:

```bash
cd functions
npm install  # If you haven't already
firebase deploy --only functions:sendMessageNotification
```

**Check deployment:**
- Go to Firebase Console → Functions
- You should see `sendMessageNotification` function listed
- Status should be "Active"

### 3. ✅ Check Cloud Function Logs
After sending a message, check Firebase Console → Functions → Logs:
- Look for: `🔔 Cloud Function triggered for new message`
- Check for any error messages
- Verify: `✅ Successfully sent notification`

### 4. ✅ Verify Both Users Have FCM Tokens
**Both sender AND receiver must:**
- Be logged in
- Have granted notification permissions
- Have FCM tokens saved in Firestore

### 5. ✅ Test on Real Device
- Emulators without Google Play Services won't receive notifications
- Use a physical Android device
- Ensure device has internet connection

## Common Issues

### Issue: "Receiver FCM token not found"
**Solution:**
1. Make sure the receiver user has logged in
2. Check Firestore → `users/{receiverId}` → should have `fcmToken` field
3. Receiver should see: `✅ FCM Token saved to Firestore` in logs

### Issue: Cloud Function not triggering
**Solution:**
1. Verify function is deployed: `firebase functions:list`
2. Check Firestore security rules allow writes
3. Verify message structure matches what Cloud Function expects

### Issue: Notifications not appearing
**Solution:**
1. Check device notification settings (Android Settings → Apps → Your App → Notifications)
2. Verify app has notification permission
3. Check if device is in Do Not Disturb mode
4. Test with app in background (not foreground)

## Testing Steps

1. **User A (Sender):**
   - Login
   - Check logs for: `✅ FCM Token saved to Firestore`
   - Send a message to User B

2. **User B (Receiver):**
   - Login (on different device)
   - Check logs for: `✅ FCM Token saved to Firestore`
   - Put app in background
   - Wait for notification from User A

3. **Check Firebase Console:**
   - Functions → Logs: Should see Cloud Function execution
   - Firestore → `users`: Both users should have `fcmToken`

## Debug Logs to Look For

**When sending message:**
- `📤 Attempting to send push notification...`
- `✅ Push notification sent successfully via Cloud Function`

**In Cloud Function logs:**
- `🔔 Cloud Function triggered for new message`
- `✅ Successfully sent notification`

**If errors:**
- `❌` prefix indicates errors
- `⚠️` prefix indicates warnings (may still work)

