# Managed View
Simple app leveraging Managed App Config and Anonymous Single Add Mode (ASAM).

Available free in the App Store.
https://apps.apple.com/us/app/managed-view/id1159586083

## Requirements
MDM solution such as Jamf Pro to remotely modify default URL or enable maintenance mode.

## Use cases
1. Simple Kiosk - lock app into URL and empower local approved user to unlock app while centrally managing URL and app.
2. Webclip (Web View) on steroids - now have the ability to easily lock a URL or PDF into single app mode.
3. Maintenance Mode - use the app to display maintenance page while performing routine maintenance such as app updates.

## Features
1. Managed App Config to define URL from central management console.
2. Support for Autonomous Single App Mode (ASAM). ASAM allows user to enable and disable Single App Mode within the app.  Hidden gesture used to access the feature.  Use triple tap gesture to access ASAM feature.
2. Built-in maintenance mode with embedded image.  Enabled with Managed App Config.

## Managed App Config settings

URL key: URL to display in app or default home page when BROWSER_MODE is enabled.

**MAINTENANCE_MODE** key: Set to “ON” to display static image and provide user a visual that the device is not available.

**BROWSER_MODE** key: Set to “ON” to display browser navigation bar and provide user an interactive method to navigate web sites.

**BROWSER_BAR_NO_EDIT** key: Set to “ON” to disable the ability to edit the URL address bar.  Use with content filter via config profile to lock down device to specific website.

**REMOTE_LOCK** key: Set to “ON” to remotely trigger Autonomous Single App Mode.  Requires supervised device and config profile with ASAM restriction payload.  Green bar will be displayed at bottom of app if ASAM is enabled.  Gray bar indicates ASAM is not enabled, but REMOTE_LOCK is attempting to enable.

**PRIVATE_BROWSING** key: Set to “ON” to enable private browsing mode. While in private browsing mode, the app stores web browsing data in non-persistent local data store similar to Safari using Private Browsing mode.

## App Config template
```xml
<dict>
  <key>MAINTENANCE_MODE</key>
    <string>OFF</string>
  <key>BROWSER_MODE</key> 
    <string>OFF</string>
  <key>BROWSER_BAR_NO_EDIT</key>
    <string>OFF</string>
  <key>URL</key>
    <string>https://foo.com</string>
  <key>REMOTE_LOCK</key> 
    <string>OFF</string>
  <key>PRIVATE_BROWSING</key> 
    <string>OFF</string>
</dict>
```

Please leave feedback and/or comments on how this could be improved!

Thanks! Aaron
