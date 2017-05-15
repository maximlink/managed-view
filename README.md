# Managed View
Simple app leveraging Managed App Config and Anonymous Single Add Mode (ASAM).

## Requirements
MDM solution such as Jamf Pro to remotely modify default URL or enable maintenance mode.

## Use cases
1. Simple Kiosk - lock app into URL and empower local approved user to unlock app while centrally managing URL and app.
2. Webclip (Web View) on steroids - now have the ability to easily lock a URL or PDF into single app mode.
3. Maintenance Mode - use the app to display maintenance page while performing routine maintenance such as app updates.

## Features
1. Managed App Config to define URL from central management console
2. Support for Autonomous Single App Mode (ASAM). ASAM allows user to enable and disable Single App Mode within the app.  Hidden gesture used to access the feature.
2. Built-in maintenance mode with embedded image.  Enabled with Managed App Config.

## Managed App Config settings

URL key: URL to display in app.

MAINTENANCE_MODE key: Set to “ON” to display static image and provide user a visual that the device is not available.

## App Config template

<dict>
<key>MAINTENANCE_MODE</key>
<string>OFF</string>
<key>URL</key>
<string>http://foo.com</string>
</dict>

Please leave feedback and/or comments on how this could be improved!

Thanks! Aaron
