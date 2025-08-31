# API Configuration Setup (Secure Method)

The AhamAI app uses compile-time variables to securely manage API keys. This is a more secure method than using a `.env` file, as the keys are compiled directly into the application and not stored as plain-text files in the app's assets.

## How to Configure Your API Keys

You must provide your API keys during the build or run process using the `--dart-define` flag.

### Required Keys

-   `API_KEY`: Your main key for the AhamAI backend.
-   `BRAVE_API_KEYS`: A comma-separated list of one or more keys for the Brave Search API.

### For Running in Debug Mode

To run the app for development (e.g., in VS Code or Android Studio, or with `flutter run`), you need to configure the `--dart-define` arguments.

**Example for `flutter run`:**

```bash
flutter run --dart-define=API_KEY=your_main_api_key_here --dart-define=BRAVE_API_KEYS=your_brave_key_1,your_brave_key_2
```

**Example for VS Code:**

Create or edit the `.vscode/launch.json` file in your project and add the `args` to your configuration:

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "AhamAI",
            "request": "launch",
            "type": "dart",
            "args": [
                "--dart-define=API_KEY=your_main_api_key_here",
                "--dart-define=BRAVE_API_KEYS=your_brave_key_1,your_brave_key_2"
            ]
        }
    ]
}
```

### For Building a Release APK

When you build the final application, you must include the same flags.

```bash
flutter build apk --dart-define=API_KEY=your_main_api_key_here --dart-define=BRAVE_API_KEYS=your_brave_key_1,your_brave_key_2
```

### Security Benefits

-   ✅ **Keys are NOT stored in plain text** in the app's assets.
-   ✅ **Cannot be easily extracted** by simply decompiling the APK to view asset files.
-   ✅ Keys are only available at runtime as Dart constants.
-   ✅ This is the recommended approach for handling sensitive keys in a production Flutter application.
