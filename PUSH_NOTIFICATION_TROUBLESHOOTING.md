# Push Notification Troubleshooting Guide

**Note:** This app uses Firebase Spark (free) plan. Notifications work via Firestore listeners for foreground and background states. Kill state notifications are not supported on Spark plan.

## Quick Checks

### 1. ✅ Verify FCM Tokens are Saved
Check in Firebase Console → Firestore → `users` collection:
- Each user document should have an `fcmToken` field
- The token should be a long string starting with letters/numbers

**To check in app logs:**
- Look for: `✅ FCM Token saved to Firestore for user: [userId]`
- Look for: `📱 FCM Token obtained (complete): [full token]`
- If you see `⚠️ FCM Token is null`, notifications won't work

### 2. ✅ Verify Both Users Have FCM Tokens
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
4. Check logs for complete FCM token: `📱 FCM Token obtained (complete): [token]`

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
   - Firestore → `users`: Both users should have `fcmToken`
   - Firestore → `chat_rooms`: Messages should be saved correctly

## Debug Logs to Look For

**When app starts:**
- `📱 FCM Token obtained (complete): [full token]`
- `✅ FCM Token saved to Firestore for user: [userId]`

**When sending message:**
- Messages are saved to Firestore automatically
- Notifications trigger via Firestore StreamBuilder (foreground) or listeners (background)

**If errors:**
- `❌` prefix indicates errors
- `⚠️` prefix indicates warnings (may still work)

## Notification States Supported

- ✅ **Foreground**: Works via Firestore StreamBuilder (real-time updates)
- ✅ **Background**: Works via Firestore listeners (automatic notifications)
- ⚠️ **Kill State**: Not supported on Spark plan (requires Blaze plan for Cloud Functions)

