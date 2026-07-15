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
- Define string in URL and when found will automatically turn off app lock (ASAM). Used with REMOTE_LOCK set to ON
- Added deep link support using "managedview://" URL scheme. Use case includes using multiple web clips to support multiple URLs (version 2.4)
- Added QR code scanning option (version 2.5)


## Managed App Config settings

**URL** key: URL to display in app or default home page when BROWSER_MODE is enabled.

**MAINTENANCE_MODE** key: Set to “ON” to display static image and provide user a visual that the device is not available.

**BROWSER_MODE** key: Set to “ON” to display browser navigation bar and provide user an interactive method to navigate web sites.

**BROWSER_BAR_NO_EDIT** key: Set to “ON” to disable the ability to edit the URL address bar.  Use with content filter via config profile to lock down device to specific website.

**REMOTE_LOCK** key: Set to “ON” to remotely trigger Autonomous Single App Mode.  Requires supervised device and config profile with ASAM restriction payload.

**PRIVATE_BROWSING** key: Set to “ON” to enable private browsing mode. While in private browsing mode, the app stores web browsing data in non-persistent local data store similar to Safari using Private Browsing mode.

**RESET_TIMER** key: Set integer value (in seconds) to set an automatic timer to clear browser data and return to default home page. Timer will not activate if already at homepage. Timer is disable by default or disabled with value of 0. (New in version 2.2)

**QUERY_URL_STRING**  Advanced option used with REMOTE_LOCK to support automatically unlocking app when a specific URL is presented. Set value to string contained in URL to be unlocked. Supports completed surveys/forms. (new in version 2.3)

**QR_CODE**  key: Set to “ON” to enable QR Code scanning within the web browser. Setting the value to ON will present camera icon. (new in version 2.5)

**LAUNCH_DELAY**  key: Set integer value (in seconds) to set delay before web page in reloaded after failed attempt. Handy for when network is not available and workaround for timing issues with newer device hardware. (new in version 2.5)

**DECODE_URL** key: Set to "ON" to decode HTML entities in the URL value before loading. Useful when the URL contains encoded characters.

**DETECT_SCROLL** key: Set to "ON" to reset the inactivity timer when the user scrolls the web view. Used with RESET_TIMER.

**REDIRECT_SUPPORT** key: Set to "ON" to redirect new tabs and pop-ups into the existing web view. Set to "ALT" to open pop-ups in a new web view.

**DISABLE_TRUST** key: Set to "ON" to accept untrusted SSL certificates. Useful for internal sites using self-signed certificates.

**AUTO_OPEN_POPUP** key: Set to "ON" to allow JavaScript to automatically open pop-up windows.

**DISABLE_APP_CONFIG_LISTENER** key: Set to "ON" to disable the managed app config change listener. When disabled, config changes will only be applied on app launch.

**BRIGHTNESS** key: Set integer value (0–100) to control device screen brightness. Set to -1 (default) to leave brightness unchanged.

**RESET_TIMER_ON_HOME** key: Set to "ON" to enable the reset timer even when the web view is displaying the home URL. By default, the timer does not activate when already at the homepage.

**RESET_TIMER_WARNING** key: Set integer value (in seconds) to display a warning banner before the reset timer fires. The value must be less than RESET_TIMER. Set to 0 (default) to disable the warning.

**USER_AGENT** key: Set custom user agent string to present to web servers. Useful when sites require a recent browser version. Leave empty (default) to use the standard WebKit user agent. Example values:
- Chrome (iOS): `Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/138.0.7204.51 Mobile/15E148 Safari/604.1`
- Safari (iOS 18): `Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1`
- Chrome (Desktop): `Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36`

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
  <key>QR_CODE</key>
    <string>OFF</string>
  <key>LAUNCH_DELAY</key>
    <integer>0</integer>
  <key>DECODE_URL</key>
    <string>OFF</string>
  <key>DETECT_SCROLL</key>
    <string>OFF</string>
  <key>REDIRECT_SUPPORT</key>
    <string>OFF</string>
  <key>DISABLE_TRUST</key>
    <string>OFF</string>
  <key>AUTO_OPEN_POPUP</key>
    <string>OFF</string>
  <key>DISABLE_APP_CONFIG_LISTENER</key>
    <string>OFF</string>
  <key>BRIGHTNESS</key>
    <integer>-1</integer>
  <key>RESET_TIMER_ON_HOME</key>
    <string>OFF</string>
  <key>RESET_TIMER_WARNING</key>
    <integer>0</integer>
  <key>USER_AGENT</key>
    <string></string>
</dict>
```

Please leave feedback and/or comments on how this could be improved!

Thanks! Aaron
