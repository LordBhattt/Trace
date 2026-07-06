# Firebase Configuration

## Setup Instructions

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (or create one)
3. Go to **Project Settings → Service Accounts**
4. Click **Generate new private key**
5. Save the downloaded JSON file as `firebase-credentials.json` in this directory

## File Structure
```
config/firebase/
├── README.md                    ← You are here
└── firebase-credentials.json    ← Place your key here (git-ignored)
```

## Environment Variable Alternative
Instead of using a local file, you can set the full JSON as an environment variable:
```
FIREBASE_SERVICE_ACCOUNT={"type":"service_account","project_id":"..."}
```

This is recommended for production deployments (Render, Heroku, etc.)

> **⚠️ NEVER commit `firebase-credentials.json` to version control.**
