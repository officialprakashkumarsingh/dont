# Maintenance Mode Configuration Guide

## Overview
The app includes a maintenance mode feature that allows you to temporarily disable access while performing updates or maintenance. The configuration is fetched from a JSON file hosted on GitHub.

## Setup Instructions

### 1. Create the JSON File
Create a file named `maintenance.json` in your GitHub repository:
`https://github.com/officialprakashkumarsingh/ahamai-landingpage/blob/main/maintenance.json`

### 2. JSON Configuration

Use the following structure for your `maintenance.json` file:

```json
{
  "maintenance_mode": false,
  "title": "System Maintenance",
  "message": "We're currently upgrading our servers to provide you with a better experience. The app will be back online shortly. Thank you for your patience!",
  "estimated_end_time": "2:00 PM UTC",
  "contact_email": "support@ahamai.com",
  "type": "full",
  "progress_percentage": 75,
  "allowed_features": []
}
```

### 3. Configuration Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `maintenance_mode` | boolean | Yes | Set to `true` to enable maintenance mode, `false` to disable |
| `title` | string | Yes | The title displayed on the maintenance page |
| `message` | string | Yes | The main message explaining the maintenance |
| `estimated_end_time` | string | No | When maintenance is expected to end (e.g., "2:00 PM UTC", "30 minutes") |
| `contact_email` | string | No | Support email for users to contact |
| `type` | string | No | Type of maintenance: `"full"`, `"partial"`, or `"readonly"` |
| `progress_percentage` | number | No | Progress percentage (0-100) to show a progress bar |
| `allowed_features` | array | No | List of features still accessible during partial maintenance |

### 4. Maintenance Types

- **`full`**: Complete maintenance, no access to any features
- **`partial`**: Some features are still available (specified in `allowed_features`)
- **`readonly`**: Users can view content but cannot make changes

### 5. Example Configurations

#### Basic Maintenance
```json
{
  "maintenance_mode": true,
  "title": "Quick Maintenance",
  "message": "We'll be back in a few minutes!"
}
```

#### Scheduled Maintenance with Progress
```json
{
  "maintenance_mode": true,
  "title": "Scheduled Maintenance",
  "message": "We're upgrading our infrastructure to serve you better.",
  "estimated_end_time": "3:00 PM EST",
  "progress_percentage": 45,
  "contact_email": "help@ahamai.com"
}
```

#### Emergency Maintenance
```json
{
  "maintenance_mode": true,
  "title": "Emergency Maintenance",
  "message": "We're fixing a critical issue. Sorry for the inconvenience.",
  "contact_email": "urgent@ahamai.com",
  "type": "full"
}
```

### 6. How to Enable/Disable Maintenance

1. **To Enable Maintenance:**
   - Edit `maintenance.json` in your GitHub repository
   - Set `"maintenance_mode": true`
   - Customize the message and other fields
   - Commit and push the changes

2. **To Disable Maintenance:**
   - Set `"maintenance_mode": false`
   - Commit and push the changes

### 7. Features

- **Real-time Updates**: The app checks for maintenance status on launch
- **Beautiful UI**: Animated maintenance page with progress indicators
- **User-Friendly**: Shows estimated time and contact information
- **Retry Option**: Users can check again to see if maintenance is complete
- **Offline Support**: Caches the last known maintenance status

### 8. Testing

To test maintenance mode:
1. Set `"maintenance_mode": true` in your JSON file
2. Launch the app - you should see the maintenance page
3. Click "Check Again" to refresh the status
4. Set `"maintenance_mode": false` to restore normal access

### 9. Best Practices

- **Advance Notice**: Update the message a few hours before maintenance
- **Clear Communication**: Explain what's being done and why
- **Accurate Timing**: Provide realistic estimated end times
- **Contact Info**: Always include a way for users to reach support
- **Progress Updates**: Use `progress_percentage` for long maintenance

### 10. Troubleshooting

- **Maintenance page not showing**: Check if the JSON file is accessible at the URL
- **Can't exit maintenance**: Ensure `maintenance_mode` is set to `false`
- **JSON not updating**: GitHub may cache raw files; wait a few minutes

## URL Configuration

If you need to change the JSON URL, update it in:
`lib/core/services/maintenance_service.dart`

```dart
static const String maintenanceJsonUrl = 
    'https://raw.githubusercontent.com/officialprakashkumarsingh/ahamai-landingpage/main/maintenance.json';
```

## UI Customization

The maintenance page includes:
- Animated gear and tool icons
- Progress bar (if percentage provided)
- Dotted background pattern
- Responsive design for all screen sizes
- Theme-aware colors

The page automatically adapts to the app's current theme (light/dark mode).