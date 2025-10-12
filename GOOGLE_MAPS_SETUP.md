# Google Maps Setup Guide

## 🗺️ Get Google Maps API Key

### Step 1: Create Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click "Select a project" → "New Project"
3. Name it (e.g., "Cerca Driver App")
4. Click "Create"

### Step 2: Enable Google Maps SDK
1. In the console, go to "APIs & Services" → "Library"
2. Search for and enable these APIs:
   - **Maps SDK for Android**
   - **Maps SDK for iOS** (if building for iOS)
   - **Directions API** (optional, for route drawing)
   - **Geocoding API** (optional, for address lookup)

### Step 3: Create API Key
1. Go to "APIs & Services" → "Credentials"
2. Click "Create Credentials" → "API Key"
3. Copy your API key (looks like: `AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`)

### Step 4: Restrict API Key (Recommended)
1. Click on your API key to edit
2. Under "Application restrictions":
   - Select "Android apps"
   - Click "Add an item"
   - Package name: `com.example.driver_cerca`
   - SHA-1: Get from your keystore (see below)
3. Under "API restrictions":
   - Select "Restrict key"
   - Choose: Maps SDK for Android
4. Click "Save"

### Get SHA-1 Certificate Fingerprint
```bash
# Debug keystore (for development)
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Release keystore (for production)
keytool -list -v -keystore /path/to/your/release.keystore -alias your_alias
```

## 📱 Add API Key to Android App

Open `android/app/src/main/AndroidManifest.xml` and replace:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY_HERE"/>
```

With your actual API key:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"/>
```

## 🍎 iOS Setup (Optional)

1. Open `ios/Runner/AppDelegate.swift`
2. Add this import:
   ```swift
   import GoogleMaps
   ```

3. In the `application` method, add:
   ```swift
   GMSServices.provideAPIKey("YOUR_API_KEY_HERE")
   ```

4. Update `ios/Runner/Info.plist`:
   ```xml
   <key>io.flutter.embedded_views_preview</key>
   <true/>
   ```

## ✅ Verify Setup

Run your app and check the console for:
- ✅ No "API key not found" errors
- ✅ Map loads correctly
- ✅ Markers appear on the map

## 💰 Pricing (Important!)

Google Maps has a free tier:
- **$200 monthly credit** (covers ~28,000 map loads)
- Set up billing alerts in Google Cloud Console
- Enable billing to use the API (free tier still applies)

## 🔒 Security Best Practices

1. ✅ Restrict API key to Android app package
2. ✅ Restrict to only needed APIs
3. ✅ Don't commit API keys to Git (use environment variables for production)
4. ✅ Set up billing alerts
5. ✅ Monitor usage in Google Cloud Console

## 🆘 Troubleshooting

### Map shows grey screen
- Check if API key is correct
- Verify Maps SDK for Android is enabled
- Check SHA-1 certificate is added to restrictions

### "This app won't run unless you update Google Play services"
- Update Google Play Services on your device
- This is normal on emulators without Google Play

### Markers not showing
- Check if coordinates are in correct format: `LatLng(latitude, longitude)`
- Verify coordinates are not (0, 0)

## 📚 Resources

- [Google Maps Flutter Plugin](https://pub.dev/packages/google_maps_flutter)
- [Google Cloud Console](https://console.cloud.google.com/)
- [Maps Platform Documentation](https://developers.google.com/maps/documentation)

