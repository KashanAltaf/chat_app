# Cloud Functions Setup (NOT USED - Spark Plan Only)

**Note:** This app uses Firebase Spark (free) plan and does NOT use Cloud Functions.

Cloud Functions require Firebase Blaze (pay-as-you-go) plan, which is not used in this project.

## Current Notification System

Notifications work automatically via:
- **Foreground**: Firestore StreamBuilder shows messages in real-time
- **Background**: Firestore listeners trigger local notifications automatically

Kill state notifications are not supported on Spark plan.

## If You Want to Upgrade to Blaze Plan

If you upgrade to Blaze plan in the future, you can:
1. Deploy the Cloud Functions in the `functions/` directory
2. Enable automatic notifications for kill state
3. See `functions/index.js` for the Cloud Function code

For now, the app works perfectly with foreground and background notifications on the free Spark plan.
