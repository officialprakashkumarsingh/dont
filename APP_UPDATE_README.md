# App Update Configuration Guide

## How to Set Up App Updates

The app uses a JSON file hosted on GitHub to check for updates. Follow these steps to configure it:

### 1. Upload the JSON File to GitHub

1. Go to your repository: `https://github.com/officialprakashkumarsingh/ahamai-landingpage`
2. Create or update the file `app-update.json` in the main branch
3. Use the following JSON structure:

```json
{
  "latest_version": "1.2.0",
  "download_url": "https://github.com/officialprakashkumarsingh/ahamai-landingpage/releases/download/v1.2.0/ahamai_v1.2.0.apk",
  "force_update": false,
  "release_date": "2024-01-15",
  "file_size_mb": 25,
  "improvements": [
    "Added file upload support for PDF, ZIP, and 30+ text formats",
    "Improved image analysis with streaming responses",
    "Enhanced code block rendering with terminal-style UI",
    "Added web search integration for real-time information",
    "Fixed keyboard focus issues in search",
    "Optimized performance and reduced app size",
    "Added support for multiple file selection",
    "Improved UI with borderless design elements"
  ],
  "min_supported_version": "1.0.0",
  "changelog_url": "https://github.com/officialprakashkumarsingh/ahamai-landingpage/blob/main/CHANGELOG.md"
}
```

### 2. JSON Fields Explanation

- **latest_version**: The newest version of your app (e.g., "1.2.0")
- **download_url**: Direct link to the APK file
- **force_update**: Set to `true` to force users to update (removes "Later" button)
- **release_date**: Date of the release (format: "YYYY-MM-DD")
- **file_size_mb**: Size of the APK file in megabytes
- **improvements**: Array of strings describing what's new in this version
- **min_supported_version**: Minimum version that can still use the app
- **changelog_url**: Optional link to full changelog

### 3. Upload APK to GitHub Releases

1. Go to your repository's Releases page
2. Click "Create a new release"
3. Tag version: `v1.2.0` (match your version)
4. Upload the APK file
5. Copy the download link and use it in `download_url`

### 4. Update Check Flow

The app checks for updates in two ways:

1. **Automatic Check**: When the app starts (MainPage)
2. **Manual Check**: Settings > About > Check for Updates button

### 5. Version Format

Use semantic versioning: `MAJOR.MINOR.PATCH`
- MAJOR: Breaking changes
- MINOR: New features
- PATCH: Bug fixes

### 6. Testing Updates

To test the update flow:

1. Set `latest_version` to a higher version than your current app
2. The update dialog should appear
3. Test both "Later" and "Update Now" buttons
4. For force updates, set `force_update: true`

### 7. Required Permissions (Android)

Make sure your `AndroidManifest.xml` includes:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

### 8. Package Dependencies

Ensure these packages are in your `pubspec.yaml`:

```yaml
dependencies:
  package_info_plus: ^5.0.1
  dio: ^5.4.0
  open_file: ^3.3.2
  path_provider: ^2.1.1
```

### 9. Update the JSON URL

If you need to change the JSON URL, update it in:
`lib/core/services/app_update_service.dart`

```dart
static const String updateJsonUrl = 
    'https://raw.githubusercontent.com/officialprakashkumarsingh/ahamai-landingpage/main/app-update.json';
```

## Example Update Scenario

When you release version 1.3.0:

1. Build your APK
2. Upload to GitHub Releases as `ahamai_v1.3.0.apk`
3. Update `app-update.json`:
   - Change `latest_version` to "1.3.0"
   - Update `download_url` with new APK link
   - Add new improvements
   - Update `release_date` and `file_size_mb`
4. Commit and push the JSON file
5. Users will see the update dialog when they open the app!

## Troubleshooting

- **Update not showing**: Check if JSON is accessible at the URL
- **Download fails**: Verify the APK download URL is correct
- **Installation fails**: Check Android permissions
- **Version comparison issues**: Ensure version format is correct (X.Y.Z)