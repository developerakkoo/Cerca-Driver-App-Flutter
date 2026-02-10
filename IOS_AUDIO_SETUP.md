# iOS Audio Setup (When iOS Support is Added)

If iOS support is added to the driver app, configure background audio as follows:

## Info.plist Configuration

Add the following to `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

This enables background audio playback capability.

## Additional Notes

- The `audioplayers` package handles iOS audio session configuration automatically
- Ensure notification permissions are granted for overlay functionality
- Test on physical iOS device as simulator may have limitations

