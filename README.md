# Managed View
Simple app leveraging Managed App Config and Anonymous Single Add Mode (ASAM).

Available free in the App Store.
https://apps.apple.com/us/app/managed-view/id1159586083

## Requirements
MDM solution such as Jamf Pro or Jamf School to enable managed app configuration

## Use cases
- Simple Kiosk – lock device into displaying a specific web page
- Secure Kiosk – add timer to return to homepage and remove cached user data
- Interactive Kiosk– add ability for user to enter URL
- Surveys/Forms – present web page survey from while locking device during survey and automatically unlocking device after survey completed
- Maintenance – present curtained view while device is performing maintenance


## Features
- Managed App Config to define URL from central management console.
- Support for Autonomous Single App Mode (ASAM). ASAM allows user to enable and disable Single App Mode within the app.
- Built-in maintenance mode with embedded image. Enabled with Managed App Config.
- Optional navigation bar for user interaction enabled with Managed App Config.
- Add timer to reset app back to predefined URL.
- Option to delete cached user data when touching homepage button or during timer reset
- Define string in URL and when found will automatically turn off app lock (ASAM). Used with REMOTE_LOCK set to ON.


## Managed App Config settings

URL key: URL to display in app or default home page when BROWSER_MODE is enabled.

**MAINTENANCE_MODE** key: Set to “ON” to display static image and provide user a visual that the device is not available.

**BROWSER_MODE** key: Set to “ON” to display browser navigation bar and provide user an interactive method to navigate web sites.

**BROWSER_BAR_NO_EDIT** key: Set to “ON” to disable the ability to edit the URL address bar.  Use with content filter via config profile to lock down device to specific website.

**REMOTE_LOCK** key: Set to “ON” to remotely trigger Autonomous Single App Mode.  Requires supervised device and config profile with ASAM restriction payload.  Green bar will be displayed at bottom of app if ASAM is enabled.  Gray bar indicates ASAM is not enabled, but REMOTE_LOCK is attempting to enable.

**PRIVATE_BROWSING** key: Set to “ON” to enable private browsing mode. While in private browsing mode, the app stores web browsing data in non-persistent local data store similar to Safari using Private Browsing mode.

**RESET_TIMER** key: Set integer value (in seconds) to set an automatic timer to clear browser data and return to default home page. Timer will not activate if already at homepage. Timer is disable by default or disabled with value of 0. (New in version 2.2)

**QUERY_URL_STRING**  Advanced option used with REMOTE_LOCK to support automatically unlocking app when a specific URL is presented. Set value to string contained in URL to be unlocked. Supports completed surveys/forms. (new in version 2.3)

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
  <key>RESET_TIMER</key> 
    <integer>0</integer>
  <key>QUERY_URL_STRING</key> 
    <string></string>
</dict>
```

Please leave feedback and/or comments on how this could be improved!

Thanks! Aaron
