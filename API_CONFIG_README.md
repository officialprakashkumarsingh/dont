# API Configuration Setup

## How to Configure Your API Key

The AhamAI app uses environment variables to securely manage the API key. This approach ensures that your API key is NOT exposed in the compiled code.

### Step 1: Setup the .env File

The `.env` file in the root directory contains:
```
API_KEY=YOUR_API_KEY_HERE
```

### Step 2: Add Your API Key

Replace `YOUR_API_KEY_HERE` with your actual API key:
```
API_KEY=ahamaipriv05
```

### Step 3: Security Benefits

**Why use .env files?**
- ✅ **API key is NOT compiled into the app binary**
- ✅ **Cannot be extracted by decompiling the APK/IPA**
- ✅ **Loaded at runtime from the asset bundle**
- ✅ **Easy to manage different keys for dev/prod**

### For Production Deployment

1. **Before building for production:**
   - Update `.env` with your production API key
   - Build the app: `flutter build apk --release`

2. **For open source projects:**
   - Uncomment `.env` in `.gitignore` to prevent committing real keys
   - Use `.env.example` as a template for other developers
   - Each developer creates their own `.env` file locally

### Example File

A template is provided at `.env.example`:
```
API_KEY=ahamaipriv05
```

## Important Security Notes

- The `.env` file is included in the app's assets but is NOT readable by decompiling
- The key is loaded at runtime using `flutter_dotenv`
- This is much more secure than hardcoding in Dart files
- For maximum security in production, consider using:
  - Platform-specific secure storage (iOS Keychain, Android Keystore)
  - Remote configuration services
  - Certificate pinning for API calls