//
//  ViewController.swift
//  Managed View
//

import Foundation
import UIKit
@preconcurrency import WebKit
import ManagedAppConfigLib

class ViewController: UIViewController, UITextFieldDelegate, WKUIDelegate, WKNavigationDelegate, UIScrollViewDelegate, UIGestureRecognizerDelegate {
  
  @IBOutlet weak var browserURL: UITextField!  //BROWSER MODE ONLY: URL address bar
  var webView: WKWebView?
  
  // Keep track of all webViews created by createWebViewWith
  private var additionalWebViews: [WKWebView] = []
  
  var defaultURL = URL(string: "https://maximlink.com/readme")
  
  var blockLockFlag = false
  
  // Add flag to prevent multiple webView creation attempts
  private var isCreatingWebView = false
  private var needsWebViewUpdate = false
  
  // Add constraint reference for dynamic updates
  private var webViewBottomConstraint: NSLayoutConstraint?
  
  // Add flag to prevent multiple toolbar setups
  private var isSettingUpToolbar = false
  
  // Reference to the storyboard toolbar
  @IBOutlet weak var storyboardToolbar: UIToolbar?
  
  // Loading indicator components
  private var loadingIndicator: UIActivityIndicatorView?
  private var loadingBackgroundView: UIView?
  private var loadingLabel: UILabel?
  
  // Add flag to prevent double taps on browser buttons
  private var isBrowserBarAnimating = false
  
  // Navigation bar button outlets for enabling/disabling during loading
  @IBOutlet weak var backButton: UIBarButtonItem?
  @IBOutlet weak var forwardButton: UIBarButtonItem?
  @IBOutlet weak var refreshButton: UIBarButtonItem?
  @IBOutlet weak var homeButton: UIBarButtonItem?
  
  // local app configuration
  struct Config {
    var decodeURL: String                 // decode URL
    var maintenanceMode: String           // display curtain image
    var newURL: URL!                      // new URL request
    var previousURL: URL!                 // previously loaded URL
    var browserMode: String               // display user interactive browser controls
    var browserModeNoEdit: String         // disable address bar edit
    var homeURL: URL!                     // BROWSER MODE ONLY: URL for home button
    var remoteLock: String                // enable remote ASAM capability
    var currentASAMStatus: String         // current ASAM status
    var privateBrowsing: String           // private browsing mode
    var queryUrlString: String            // private browsing mode
    var resetTimer: Int                   // timer in seconds to reset session
    var qrCode: String                    // enable QR Code reader
    var launchDelay: Int                  // initial page load delayed by seconds
    var detectScroll: String              // reset timer if scrolling
    var redirect: String                  // redirect new tabs / pop-ups to webview
    var disabletrust: String              // accept unsecure SSL
    var autoOpenPopup: String             // allow javascipt to auto open popup
    var disableAppConfigListener: String  // disable managed app config listener
    var brightness: Int                   // device brightness control (-1=disabled, 0-100=brightness %)
    var resetTimerOnHome: String          // enable reset timer when at home URL
    var resetTimerWarning: Int            // seconds before reset to show warning (0=disabled)
    
    
    var displayURL: URL {
      if maintenanceMode == "ON" {  // display curtain image
        return URL.init(fileURLWithPath: Bundle.main.path(forResource: "curtain", ofType: "png", inDirectory: "img")!)
      }
      else { // or new URL request
        return newURL
      }
    }
  }
  
  // set local configuration defaults
  var config = Config(decodeURL: "OFF",
                      maintenanceMode: "OFF",
                      newURL: URL(string: ""),
                      previousURL: URL(string: ""),
                      browserMode: "OFF",
                      browserModeNoEdit: "OFF",
                      homeURL: URL(string: ""),
                      remoteLock: "OFF",
                      currentASAMStatus: "OFF",
                      privateBrowsing: "OFF",
                      queryUrlString: "",
                      resetTimer: 0,
                      qrCode: "OFF",
                      launchDelay: 0,
                      detectScroll: "ON",
                      redirect: "OFF",
                      disabletrust: "OFF",
                      autoOpenPopup: "OFF",
                      disableAppConfigListener: "OFF",
                      brightness: -1,
                      resetTimerOnHome: "OFF",
                      resetTimerWarning: 0
  )
  
  var timer: Timer?
  
  // Warning timer for reset countdown
  private var warningTimer: Timer?
  private var warningBannerView: UIView?
  private var warningLabel: UILabel?
  private var countdownLabel: UILabel?
  private var countdownTimer: Timer?
  private var countdownSeconds: Int = 0
  
  // version 2.5 - observe when camera reads QR Code
  static let notificationCamera = Notification.Name("qrCode")
  
  // version 2.5 - if error (e.g. network not connected) then retry page load after x.x seconds
  let retryTimer = 1.0
  
  // WKWebView setup via code - required for < iOS 11
  override func loadView() {
    super.loadView()
    // Initial webView creation will happen in viewDidLoad
  }
  
  //  Hide Top Status Bar
  override var prefersStatusBarHidden: Bool {
    return true
  }
  
  @objc func appCameToForeGround(notification: Notification) {
    print("App in foreground")
    deepLink()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Configure navigation bar appearance to respect system appearance mode
    configureNavigationBarAppearance()
    
    if let delay = ManagedAppConfig.shared.getConfigValue(forKey: "LAUNCH_DELAY") {
      DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay as! Int)) {  // seconds delay
        self.readManagedAppConfig() }
    } else {
      DispatchQueue.main.async {self.readManagedAppConfig()}
    }
    
    let myClosure = { (configDict: [String : Any?]) -> Void in
      print("Managed app configuration changed")
      // version - 2.8.6
      if self.config.disableAppConfigListener == "OFF" {
        self.readManagedAppConfig()  // reload MDM managed app config to local config
      }
    }
    // listen for managed app config updates
    if config.queryUrlString == "" {
      ManagedAppConfig.shared.addAppConfigChangedHook(myClosure)
    }
    
    // version 2.8.10 - add device lock detection
    print("Device lock detection enabled")
    addDeviceLockDetection()
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(appCameToForeGround(notification:)),
                                           name: UIApplication.willEnterForegroundNotification,
                                           object: nil)
    
    deepLink() // initial check if app launched by deep link
    
    NotificationCenter.default.addObserver(self, selector: #selector(onNotification(notification:)), name: ViewController.notificationCamera, object: nil)
  }
  
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    
    // Reconfigure appearance when appearance mode changes
    if #available(iOS 13.0, *) {
      if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
        configureNavigationBarAppearance()
      }
    }
  }
  
  private func configureNavigationBarAppearance() {
    guard let navigationController = navigationController else { return }
    
    if #available(iOS 13.0, *) {
      // Use the new appearance API for iOS 13+
      let appearance = UINavigationBarAppearance()
      appearance.configureWithDefaultBackground() // This will respect system appearance
      
      navigationController.navigationBar.standardAppearance = appearance
      navigationController.navigationBar.scrollEdgeAppearance = appearance
      navigationController.navigationBar.compactAppearance = appearance
      
      // Remove any fixed tint colors to allow system colors
      navigationController.navigationBar.barTintColor = nil
      navigationController.navigationBar.backgroundColor = nil
    } else {
      // For iOS 12 and earlier, use system default
      navigationController.navigationBar.barTintColor = nil
      navigationController.navigationBar.backgroundColor = nil
      navigationController.navigationBar.barStyle = .default
    }
  }
  
  func readManagedAppConfig() {
    // default managed app config settings
    let macDict = [
      "DECODE_URL":"OFF",
      "MAINTENANCE_MODE":"OFF",
      "URL":String(describing: defaultURL!),
      "REMOTE_LOCK":"OFF",
      "BROWSER_MODE":"OFF",
      "BROWSER_BAR_NO_EDIT":"OFF",
      "PRIVATE_BROWSING":"OFF",
      "QUERY_URL_STRING":"",
      "RESET_TIMER":901,
      "QR_CODE":"OFF",
      "LAUNCH_DELAY":0,
      "DETECT_SCROLL":"OFF",
      "REDIRECT_SUPPORT":"OFF",
      "DISABLE_TRUST":"OFF",
      "AUTO_OPEN_POPUP":"OFF",
      "DISABLE_APP_CONFIG_LISTENER":"OFF",
      "BRIGHTNESS":-1,
      "RESET_TIMER_ON_HOME":"OFF",
      "RESET_TIMER_WARNING":890
    ] as [String : Any]
    
    // Store previous private browsing setting to check if it changed
    let previousPrivateBrowsing = config.privateBrowsing
    
    // determine if MDM pushed managed app config and assign to local config, if not use defaults
    for (key,defaultValue) in macDict {
      if let value = ManagedAppConfig.shared.getConfigValue(forKey: key) {
        switch key {
        case "MAINTENANCE_MODE" : config.maintenanceMode = value as! String
        case "URL" : do {
          if config.decodeURL != "ON" {
            self.config.newURL = URL(string: value as! String)
            self.config.homeURL = URL(string: value as! String)
            print("DEBUG: homeURL set to: \(String(describing: self.config.homeURL))")
          } else {
            //version 2.8
            let string = value as! String
            let decoded = string.stringByDecodingHTMLEntities
            print("decoded: \(decoded)")
            self.config.newURL = URL(string: decoded)
            self.config.homeURL = URL(string: decoded)
            print("DEBUG: homeURL set to (decoded): \(String(describing: self.config.homeURL))")
          }
        }
        case "REMOTE_LOCK" : config.remoteLock = value as! String
        case "BROWSER_MODE" : config.browserMode = value as! String
        case "BROWSER_BAR_NO_EDIT" : config.browserModeNoEdit = value as! String
        case "PRIVATE_BROWSING" : config.privateBrowsing = value as! String
        case "QUERY_URL_STRING" : config.queryUrlString = value as! String
        case "RESET_TIMER" : config.resetTimer = value as! Int
        case "QR_CODE" : config.qrCode = value as! String
        case "LAUNCH_DELAY" : config.launchDelay = value as! Int
        case "DETECT_SCROLL" : config.detectScroll = value as! String
        case "REDIRECT_SUPPORT" : config.redirect = value as! String
        case "DISABLE_TRUST" : config.disabletrust = value as! String
        case "AUTO_OPEN_POPUP" : config.autoOpenPopup = value as! String
        case "DECODE_URL" : config.decodeURL = value as! String
        case "DISABLE_APP_CONFIG_LISTENER" : config.disableAppConfigListener = value as! String
        case "BRIGHTNESS" : config.brightness = value as! Int
        case "RESET_TIMER_ON_HOME" : config.resetTimerOnHome = value as! String
        case "RESET_TIMER_WARNING" : config.resetTimerWarning = value as! Int
          
          default: print("ERROR: \(key) - undefined managed app config key") }
      } else {
        switch key {
        case "MAINTENANCE_MODE" : config.maintenanceMode = defaultValue as! String
        case "URL" : do {
          self.config.newURL = URL(string: defaultValue as! String)
          self.config.homeURL = URL(string: defaultValue as! String)
          print("DEBUG: homeURL set to default: \(String(describing: self.config.homeURL))")
        }
        case "REMOTE_LOCK" : config.remoteLock = defaultValue as! String
        case "BROWSER_MODE" : config.browserMode = defaultValue as! String
        case "BROWSER_BAR_NO_EDIT" : config.browserModeNoEdit = defaultValue as! String
        case "PRIVATE_BROWSING" : config.privateBrowsing = defaultValue as! String
        case "QUERY_URL_STRING" : config.queryUrlString = defaultValue as! String
        case "RESET_TIMER" : config.resetTimer = defaultValue as! Int
        case "QR_CODE" : config.qrCode = defaultValue as! String
        case "LAUNCH_DELAY" : config.launchDelay = defaultValue as! Int
        case "DETECT_SCROLL" : config.detectScroll = defaultValue as! String
        case "REDIRECT_SUPPORT" : config.redirect = defaultValue as! String
        case "DISABLE_TRUST" : config.disabletrust = defaultValue as! String
        case "AUTO_OPEN_POPUP" : config.autoOpenPopup = defaultValue as! String
        case "DECODE_URL" : config.decodeURL = defaultValue as! String
        case "DISABLE_APP_CONFIG_LISTENER" : config.disableAppConfigListener = defaultValue as! String
        case "BRIGHTNESS" : config.brightness = defaultValue as! Int
        case "RESET_TIMER_ON_HOME" : config.resetTimerOnHome = defaultValue as! String
        case "RESET_TIMER_WARNING" : config.resetTimerWarning = defaultValue as! Int
          
          default: print("ERROR: \(key) - undefined managed app config key") }
      }
    }
    
    // switch ASAM setting if new request is different than previous
    if self.config.currentASAMStatus != config.remoteLock {
      switchRemoteLock()
    }
    
    // Only create new webView if private browsing setting changed or webView doesn't exist
    let needsPrivateBrowsingChange = (webView == nil || previousPrivateBrowsing != config.privateBrowsing)
    
    if needsPrivateBrowsingChange {
      updateWebViewIfNeeded()
    } else if webView != nil {
      // If webView already exists and settings haven't changed, just load the new URL
      DispatchQueue.main.async {
        self.loadWebViewIfNeeded()
      }
    } else {
      // Create webView if it doesn't exist
      updateWebViewIfNeeded()
    }
    
    // check for browser mode status and set accordingly
    DispatchQueue.main.async {
      self.checkBrowserMode()
      self.setBrightness()
    }
    
    print(String(describing: config))
  }
  
  // MARK: - Brightness Control
  private func setBrightness() {
    // Only set brightness if the value is >= 0 (-1 means disabled/default)
    guard config.brightness >= 0 else {
      print("Brightness setting is -1 (disabled), skipping brightness control")
      return
    }
    
    // Ensure the value is within valid range (0-100)
    let clampedValue = max(0, min(100, config.brightness))
    
    // Convert from 0-100 range to 0.0-1.0 range for UIScreen.brightness
    let screenBrightness = Float(clampedValue) / 100.0
    
    DispatchQueue.main.async {
      UIScreen.main.brightness = CGFloat(screenBrightness)
      print("Device brightness set to: \(clampedValue)% (\(screenBrightness))")
    }
  }
  
  // MARK: - Loading Indicator
  private func createLoadingIndicator() {
    // Only create if it doesn't already exist
    guard loadingIndicator == nil else { return }
    
    // Create background view
    loadingBackgroundView = UIView()
    loadingBackgroundView?.backgroundColor = UIColor.black.withAlphaComponent(0.5)
    loadingBackgroundView?.translatesAutoresizingMaskIntoConstraints = false
    
    // Create activity indicator
    if #available(iOS 13.0, *) {
      loadingIndicator = UIActivityIndicatorView(style: .large)
    } else {
      loadingIndicator = UIActivityIndicatorView(style: .whiteLarge)
    }
    loadingIndicator?.color = .white
    loadingIndicator?.translatesAutoresizingMaskIntoConstraints = false
    
    // Create loading label
    loadingLabel = UILabel()
    loadingLabel?.text = "Loading..."
    loadingLabel?.textColor = .white
    loadingLabel?.font = UIFont.systemFont(ofSize: 16)
    loadingLabel?.translatesAutoresizingMaskIntoConstraints = false
    
    guard let backgroundView = loadingBackgroundView,
          let indicator = loadingIndicator,
          let label = loadingLabel else { return }
    
    // Add to view hierarchy
    view.addSubview(backgroundView)
    backgroundView.addSubview(indicator)
    backgroundView.addSubview(label)
    
    // Set up constraints to cover entire screen including navigation bar
    NSLayoutConstraint.activate([
      // Background view fills entire screen, extending beyond safe area
      backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
      backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      
      // Center activity indicator
      indicator.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
      indicator.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor),
      
      // Position label below indicator
      label.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
      label.topAnchor.constraint(equalTo: indicator.bottomAnchor, constant: 16)
    ])
    
    // Initially hidden
    backgroundView.isHidden = true
  }
  
  // MARK: - Navigation Button Control
  private func setNavigationButtonsEnabled(_ enabled: Bool) {
    DispatchQueue.main.async {
      // Only control buttons if they exist and browser mode is ON
      guard self.config.browserMode == "ON" else { return }
      
      // Get navigation bar buttons programmatically since outlets may not be connected
      if let leftBarButtonItems = self.navigationItem.leftBarButtonItems {
        for button in leftBarButtonItems {
          button.isEnabled = enabled
        }
      }
      
      if let rightBarButtonItems = self.navigationItem.rightBarButtonItems {
        for button in rightBarButtonItems {
          button.isEnabled = enabled
        }
      }
      
      // Also try the outlet approach if they're connected
      self.backButton?.isEnabled = enabled
      self.forwardButton?.isEnabled = enabled
      self.refreshButton?.isEnabled = enabled
      self.homeButton?.isEnabled = enabled
      
      print("Navigation buttons \(enabled ? "enabled" : "disabled")")
    }
  }
  
  private func showLoadingIndicator() {
    DispatchQueue.main.async {
      // Create if needed
      self.createLoadingIndicator()
      
      // Disable navigation buttons during loading
      self.setNavigationButtonsEnabled(false)
      
      // Show and start animating
      self.loadingBackgroundView?.isHidden = false
      self.loadingIndicator?.startAnimating()
      
      // Add to navigation controller's view if available to cover nav bar, otherwise use our view
      let targetView = self.navigationController?.view ?? self.view!
      
      // Remove from current parent if it exists
      self.loadingBackgroundView?.removeFromSuperview()
      
      // Add to the target view
      if let backgroundView = self.loadingBackgroundView {
        targetView.addSubview(backgroundView)
        
        // Update constraints for the new parent view
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
          backgroundView.topAnchor.constraint(equalTo: targetView.topAnchor),
          backgroundView.leadingAnchor.constraint(equalTo: targetView.leadingAnchor),
          backgroundView.trailingAnchor.constraint(equalTo: targetView.trailingAnchor),
          backgroundView.bottomAnchor.constraint(equalTo: targetView.bottomAnchor)
        ])
        
        // Bring to front to ensure it's visible above everything
        targetView.bringSubviewToFront(backgroundView)
      }
    }
  }
  
  private func hideLoadingIndicator() {
    DispatchQueue.main.async {
      self.loadingBackgroundView?.isHidden = true
      self.loadingIndicator?.stopAnimating()
      
      // Re-enable navigation buttons when loading is complete
      self.setNavigationButtonsEnabled(true)
    }
  }
  
  // MARK: - Reset Warning Banner
  private var continueButton: UIButton?
  private var warningOverlayView: UIView?
  
  private func createWarningBanner() {
    // Only create if it doesn't already exist
    guard warningBannerView == nil else { return }
    
    let targetView = navigationController?.view ?? view!
    
    // Create semi-transparent overlay
    warningOverlayView = UIView()
    warningOverlayView?.backgroundColor = UIColor.black.withAlphaComponent(0.4)
    warningOverlayView?.translatesAutoresizingMaskIntoConstraints = false
    
    // Create banner container (white card)
    warningBannerView = UIView()
    warningBannerView?.backgroundColor = UIColor.systemBackground
    warningBannerView?.translatesAutoresizingMaskIntoConstraints = false
    warningBannerView?.layer.cornerRadius = 16
    warningBannerView?.layer.shadowColor = UIColor.black.cgColor
    warningBannerView?.layer.shadowOffset = CGSize(width: 0, height: 4)
    warningBannerView?.layer.shadowOpacity = 0.3
    warningBannerView?.layer.shadowRadius = 8
    
    // Create icon image view (using SF Symbol)
    let iconImageView = UIImageView()
    if #available(iOS 13.0, *) {
      let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .regular)
      iconImageView.image = UIImage(systemName: "timer", withConfiguration: config)
      iconImageView.tintColor = .secondaryLabel
    }
    iconImageView.contentMode = .scaleAspectFit
    iconImageView.translatesAutoresizingMaskIntoConstraints = false
    
    // Create icon background
    let iconBackground = UIView()
    iconBackground.backgroundColor = UIColor.secondarySystemBackground
    iconBackground.layer.cornerRadius = 12
    iconBackground.translatesAutoresizingMaskIntoConstraints = false
    
    // Create title label
    let titleLabel = UILabel()
    titleLabel.text = "Your session will be reset soon"
    titleLabel.textColor = .label
    titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
    titleLabel.textAlignment = .center
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    
    // Create description label
    warningLabel = UILabel()
    let timerDescription = formatTimerDuration(seconds: config.resetTimer)
    warningLabel?.text = "This happens when device isn't used for \(timerDescription)."
    warningLabel?.textColor = .secondaryLabel
    warningLabel?.font = UIFont.systemFont(ofSize: 15)
    warningLabel?.textAlignment = .center
    warningLabel?.numberOfLines = 0
    warningLabel?.translatesAutoresizingMaskIntoConstraints = false
    
    // Create countdown container
    let countdownContainer = UIView()
    countdownContainer.backgroundColor = UIColor.secondarySystemBackground
    countdownContainer.layer.cornerRadius = 8
    countdownContainer.translatesAutoresizingMaskIntoConstraints = false
    
    // Create countdown label
    countdownLabel = UILabel()
    countdownLabel?.text = "Time Remaining: 10 seconds"
    countdownLabel?.textColor = .label
    countdownLabel?.font = UIFont.systemFont(ofSize: 15)
    countdownLabel?.textAlignment = .center
    countdownLabel?.translatesAutoresizingMaskIntoConstraints = false
    
    // Create continue button
    continueButton = UIButton(type: .system)
    continueButton?.setTitle("Continue using", for: .normal)
    continueButton?.setTitleColor(.white, for: .normal)
    continueButton?.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
    continueButton?.backgroundColor = UIColor.systemBlue
    continueButton?.layer.cornerRadius = 25
    continueButton?.translatesAutoresizingMaskIntoConstraints = false
    continueButton?.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
    
    guard let overlay = warningOverlayView,
          let bannerView = warningBannerView,
          let warning = warningLabel,
          let countdown = countdownLabel,
          let button = continueButton else { return }
    
    // Add to view hierarchy
    targetView.addSubview(overlay)
    targetView.addSubview(bannerView)
    iconBackground.addSubview(iconImageView)
    bannerView.addSubview(iconBackground)
    bannerView.addSubview(titleLabel)
    bannerView.addSubview(warning)
    bannerView.addSubview(countdownContainer)
    countdownContainer.addSubview(countdown)
    bannerView.addSubview(button)
    
    // Set up constraints
    NSLayoutConstraint.activate([
      // Overlay covers entire screen
      overlay.topAnchor.constraint(equalTo: targetView.topAnchor),
      overlay.leadingAnchor.constraint(equalTo: targetView.leadingAnchor),
      overlay.trailingAnchor.constraint(equalTo: targetView.trailingAnchor),
      overlay.bottomAnchor.constraint(equalTo: targetView.bottomAnchor),
      
      // Banner centered in screen
      bannerView.centerXAnchor.constraint(equalTo: targetView.centerXAnchor),
      bannerView.centerYAnchor.constraint(equalTo: targetView.centerYAnchor),
      bannerView.leadingAnchor.constraint(greaterThanOrEqualTo: targetView.leadingAnchor, constant: 24),
      bannerView.trailingAnchor.constraint(lessThanOrEqualTo: targetView.trailingAnchor, constant: -24),
      bannerView.widthAnchor.constraint(lessThanOrEqualToConstant: 400),
      
      // Icon background at top
      iconBackground.topAnchor.constraint(equalTo: bannerView.topAnchor, constant: 24),
      iconBackground.centerXAnchor.constraint(equalTo: bannerView.centerXAnchor),
      iconBackground.widthAnchor.constraint(equalToConstant: 64),
      iconBackground.heightAnchor.constraint(equalToConstant: 64),
      
      // Icon centered in background
      iconImageView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
      iconImageView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
      iconImageView.widthAnchor.constraint(equalToConstant: 40),
      iconImageView.heightAnchor.constraint(equalToConstant: 40),
      
      // Title below icon
      titleLabel.topAnchor.constraint(equalTo: iconBackground.bottomAnchor, constant: 16),
      titleLabel.leadingAnchor.constraint(equalTo: bannerView.leadingAnchor, constant: 24),
      titleLabel.trailingAnchor.constraint(equalTo: bannerView.trailingAnchor, constant: -24),
      
      // Description below title
      warning.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
      warning.leadingAnchor.constraint(equalTo: bannerView.leadingAnchor, constant: 24),
      warning.trailingAnchor.constraint(equalTo: bannerView.trailingAnchor, constant: -24),
      
      // Countdown container below description
      countdownContainer.topAnchor.constraint(equalTo: warning.bottomAnchor, constant: 20),
      countdownContainer.centerXAnchor.constraint(equalTo: bannerView.centerXAnchor),
      countdownContainer.heightAnchor.constraint(equalToConstant: 36),
      
      // Countdown label inside container
      countdown.topAnchor.constraint(equalTo: countdownContainer.topAnchor, constant: 8),
      countdown.bottomAnchor.constraint(equalTo: countdownContainer.bottomAnchor, constant: -8),
      countdown.leadingAnchor.constraint(equalTo: countdownContainer.leadingAnchor, constant: 16),
      countdown.trailingAnchor.constraint(equalTo: countdownContainer.trailingAnchor, constant: -16),
      
      // Continue button at bottom
      button.topAnchor.constraint(equalTo: countdownContainer.bottomAnchor, constant: 24),
      button.leadingAnchor.constraint(equalTo: bannerView.leadingAnchor, constant: 24),
      button.trailingAnchor.constraint(equalTo: bannerView.trailingAnchor, constant: -24),
      button.heightAnchor.constraint(equalToConstant: 50),
      button.bottomAnchor.constraint(equalTo: bannerView.bottomAnchor, constant: -24)
    ])
    
    // Initially hidden
    overlay.isHidden = true
    overlay.alpha = 0
    bannerView.isHidden = true
    bannerView.alpha = 0
  }
  
  @objc private func continueButtonTapped() {
    print("Continue button tapped - resetting timer")
    
    // Cancel warning and reset timer
    timer?.invalidate()
    cancelWarningTimer()
    
    // Restart the timer if needed
    if config.resetTimer != 0 {
      let shouldStartTimer: Bool
      if config.resetTimerOnHome == "ON" {
        shouldStartTimer = true
      } else {
        shouldStartTimer = (webView?.url != config.homeURL)
      }
      
      if shouldStartTimer {
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(config.resetTimer),
                                     target: self,
                                     selector: #selector(fireTimer),
                                     userInfo: nil,
                                     repeats: false)
        startWarningTimer()
      }
    }
  }
  
  private func showWarningBanner(secondsRemaining: Int) {
    DispatchQueue.main.async {
      // Create banner if needed
      self.createWarningBanner()
      
      // Set initial countdown
      self.countdownSeconds = secondsRemaining
      self.updateCountdownLabel()
      
      // Show overlay and banner with animation
      self.warningOverlayView?.isHidden = false
      self.warningBannerView?.isHidden = false
      UIView.animate(withDuration: 0.3) {
        self.warningOverlayView?.alpha = 1.0
        self.warningBannerView?.alpha = 1.0
      }
      
      // Start countdown timer
      self.countdownTimer?.invalidate()
      self.countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
        guard let self = self else { return }
        self.countdownSeconds -= 1
        self.updateCountdownLabel()
        
        if self.countdownSeconds <= 0 {
          self.countdownTimer?.invalidate()
          self.countdownTimer = nil
        }
      }
      
      print("Warning banner shown with \(secondsRemaining) seconds remaining")
    }
  }
  
  private func hideWarningBanner() {
    // Stop countdown timer immediately (on current thread if main, otherwise dispatch)
    if Thread.isMainThread {
      self.countdownTimer?.invalidate()
      self.countdownTimer = nil
      
      // Hide overlay and banner with animation
      UIView.animate(withDuration: 0.3, animations: {
        self.warningOverlayView?.alpha = 0
        self.warningBannerView?.alpha = 0
      }) { _ in
        self.warningOverlayView?.isHidden = true
        self.warningBannerView?.isHidden = true
      }
      
      print("Warning banner hidden")
    } else {
      DispatchQueue.main.async {
        self.countdownTimer?.invalidate()
        self.countdownTimer = nil
        
        // Hide overlay and banner with animation
        UIView.animate(withDuration: 0.3, animations: {
          self.warningOverlayView?.alpha = 0
          self.warningBannerView?.alpha = 0
        }) { _ in
          self.warningOverlayView?.isHidden = true
          self.warningBannerView?.isHidden = true
        }
        
        print("Warning banner hidden")
      }
    }
  }
  
  private func updateCountdownLabel() {
    DispatchQueue.main.async {
      self.countdownLabel?.text = "Time Remaining: \(self.countdownSeconds) seconds"
    }
  }
  
  private func startWarningTimer() {
    // Only start warning timer if both reset timer and warning are configured
    guard config.resetTimer > 0, config.resetTimerWarning > 0 else { return }
    
    // Warning should be less than the reset timer
    guard config.resetTimerWarning < config.resetTimer else {
      print("Warning: RESET_TIMER_WARNING (\(config.resetTimerWarning)) must be less than RESET_TIMER (\(config.resetTimer))")
      return
    }
    
    // Calculate when to show the warning
    let warningDelay = config.resetTimer - config.resetTimerWarning
    
    warningTimer?.invalidate()
    warningTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(warningDelay), repeats: false) { [weak self] _ in
      guard let self = self else { return }
      self.showWarningBanner(secondsRemaining: self.config.resetTimerWarning)
    }
    
    print("Warning timer scheduled to fire in \(warningDelay) seconds")
  }
  
  private func cancelWarningTimer() {
    // Stop the warning timer that triggers the banner
    warningTimer?.invalidate()
    warningTimer = nil
    
    // Also stop countdown timer directly (in case banner is showing)
    countdownTimer?.invalidate()
    countdownTimer = nil
    
    // Hide the banner if visible
    hideWarningBanner()
  }
  
  private func formatTimerDuration(seconds: Int) -> String {
    if seconds >= 60 {
      let minutes = seconds / 60
      if minutes == 1 {
        return "1 minute"
      } else {
        return "\(minutes) minutes"
      }
    } else {
      if seconds == 1 {
        return "1 second"
      } else {
        return "\(seconds) seconds"
      }
    }
  }

  private func updateWebViewIfNeeded() {
    // Prevent multiple simultaneous webView creation attempts
    guard !isCreatingWebView else {
      needsWebViewUpdate = true
      return
    }
    
    isCreatingWebView = true
    needsWebViewUpdate = false
    
    let isPrivate = (config.privateBrowsing == "ON")
    
    // Clean up existing webView if it exists
    if let existingWebView = webView {
      DispatchQueue.main.async {
        existingWebView.removeFromSuperview()
        self.webView = nil
        self.createWebView(isPrivate: isPrivate)
      }
    } else {
      // Create new webView on main queue
      DispatchQueue.main.async {
        self.createWebView(isPrivate: isPrivate)
      }
    }
  }
  
  private func createWebView(isPrivate: Bool) {
    // Clean up any existing webView
    webView?.removeFromSuperview()
    webViewBottomConstraint = nil
    
    let webConfiguration = WKWebViewConfiguration()
    if isPrivate {
      webConfiguration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
    }
    
    // version 2.8.2 - auto open popup
    if config.autoOpenPopup == "ON" {
      print("Auto open popup ON")
      webConfiguration.preferences.javaScriptCanOpenWindowsAutomatically = true
    }
    
    webView = WKWebView(frame: .zero, configuration: webConfiguration)
    guard let webView = webView else {
      isCreatingWebView = false
      return
    }
    
    webView.uiDelegate = self
    webView.navigationDelegate = self
    browserURL.delegate = self
    if #available(iOS 11.0, *) {
      webView.scrollView.contentInsetAdjustmentBehavior = .never
    }
    
    view.addSubview(webView)
    webView.translatesAutoresizingMaskIntoConstraints = false
    
    // Set up constraints - use different bottom constraint based on QR code setting
    let bottomAnchor: NSLayoutYAxisAnchor
    if config.qrCode == "ON" {
      // Respect safe area to avoid toolbar overlap
      bottomAnchor = view.safeAreaLayoutGuide.bottomAnchor
    } else {
      // Extend to bottom of screen
      bottomAnchor = view.bottomAnchor
    }
    
    // Create and store the bottom constraint for later updates
    webViewBottomConstraint = webView.bottomAnchor.constraint(equalTo: bottomAnchor)
    
    NSLayoutConstraint.activate([
      webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      webViewBottomConstraint!
    ])
    
    webView.scrollView.delegate = self
    
    addUserActivityDetection()
    
    if isPrivate {
      print("Created webview - non-persistent")
    } else {
      print("Created webview - persistent")
    }
    
    // Reset the creation flag
    isCreatingWebView = false
    
    // Check if another update was requested while we were creating
    if needsWebViewUpdate {
      DispatchQueue.main.async {
        self.updateWebViewIfNeeded()
      }
    } else {
      // Load initial URL
      loadWebViewIfNeeded()
    }
  }
  
  // load new URL request & check scheme (v2.3.1)
  // version 2.8.12 - updated check scheme method
  func loadWebViewIfNeeded() {
    guard let webView = webView else { return }
    
    var finalURL = config.displayURL
    
    // Check if scheme is nil or managedview and set to https
    if config.displayURL.scheme == nil || config.displayURL.scheme == "managedview"{
      // Get the URL string and prepend https://
      let urlString = config.displayURL.absoluteString
      if let httpsURL = URL(string: "https://" + urlString) {
        finalURL = httpsURL
      }
    }
    
    // Show loading indicator when starting to load
    showLoadingIndicator()
    
    let myRequest = URLRequest(url: finalURL)
    webView.load(myRequest)
    
    config.previousURL = finalURL
  }
  
  func switchRemoteLock() {
    if (config.remoteLock == "ON") {
      UIAccessibility.requestGuidedAccessSession(enabled: true, completionHandler: {
        success in
        
        if success {
          print("Remote ASAM=ON success")
          self.config.currentASAMStatus = "ON"
          if let navController = self.navigationController {
            navController.toolbar.barTintColor = UIColor.init(red: 0.2, green: 0.6, blue: 0.0, alpha: 1.0)
          }
        } else {
          print("Remote ASAM=ON failure")
        }
      })
    }
    
    else {
      self.navigationController?.isToolbarHidden = true
      
      UIAccessibility.requestGuidedAccessSession(enabled: false, completionHandler: {
        success in
        
        if success {
          self.config.currentASAMStatus = "OFF"
          print("Remote ASAM=OFF success")
        } else {
          print("Remote ASAM=OFF failure")
        }
      })
    }
  }
  
  func checkBrowserMode() {
    if config.browserMode == "ON" {
      navigationController?.isNavigationBarHidden = false
      navigationController?.hidesBarsOnSwipe = true
      if config.browserModeNoEdit == "ON" {
        browserURL.isEnabled = false
      }
      
    } else {
      navigationController?.isNavigationBarHidden = true
      navigationController?.hidesBarsOnSwipe = false
    }
    
    // Always hide the navigation controller's toolbar since we use the storyboard one
    navigationController?.isToolbarHidden = true
    self.toolbarItems = nil
    
    // Find the storyboard toolbar
    var storyboardToolbar: UIToolbar?
    for subview in view.subviews {
      if let toolbar = subview as? UIToolbar {
        storyboardToolbar = toolbar
        break
      }
    }
    
    if config.qrCode == "ON" {
      storyboardToolbar?.isHidden = false
      updateWebViewBottomConstraint(usesSafeArea: true)
    } else {
      storyboardToolbar?.isHidden = true
      updateWebViewBottomConstraint(usesSafeArea: false)
    }
    
    view.layoutIfNeeded()
  }
  
  private func updateWebViewBottomConstraint(usesSafeArea: Bool) {
    guard let webView = webView, let bottomConstraint = webViewBottomConstraint else { return }
    
    // Find the storyboard toolbar to get its position
    var storyboardToolbar: UIToolbar?
    for subview in view.subviews {
      if let toolbar = subview as? UIToolbar {
        storyboardToolbar = toolbar
        break
      }
    }
    
    // Deactivate current constraint
    bottomConstraint.isActive = false
    
    // Create new constraint with appropriate anchor
    let newBottomAnchor: NSLayoutYAxisAnchor
    if usesSafeArea && storyboardToolbar?.isHidden == false {
      // If toolbar is visible, position web view above it
      newBottomAnchor = storyboardToolbar?.topAnchor ?? view.safeAreaLayoutGuide.bottomAnchor
    } else {
      // Extend to bottom of screen when toolbar is hidden
      newBottomAnchor = view.bottomAnchor
    }
    
    webViewBottomConstraint = webView.bottomAnchor.constraint(equalTo: newBottomAnchor)
    webViewBottomConstraint?.isActive = true
  }
  
  @objc func presentCamera() {
    print("camera button pushed")
    performSegue(withIdentifier: "cameraSeque", sender: nil)
  }
  // BROWSER MODE ONLY: 4 connectors to UI
  @IBAction func goBack(_ sender: Any) {
    provideBrowserButtonFeedback(for: sender)
    webView?.goBack()
  }
  @IBAction func goForward(_ sender: Any) {
    provideBrowserButtonFeedback(for: sender)
    webView?.goForward()
  }
  @IBAction func refreshPage(_ sender: Any) {
    provideBrowserButtonFeedback(for: sender)
    webView?.reload()
  }
  @IBAction func goHome(_ sender: Any) {
    provideBrowserButtonFeedback(for: sender)
    self.resetSession()
  }
  
  // MARK: - Browser Button Feedback
  private func provideBrowserButtonFeedback(for sender: Any) {
    // Prevent double taps during animation
    guard !isBrowserBarAnimating else {
      print("Browser bar animation in progress, ignoring tap")
      return
    }
    
    // Only proceed if browser mode is ON and navigation bar is visible
    guard config.browserMode == "ON",
          let navigationController = navigationController,
          !navigationController.isNavigationBarHidden else {
      print("Browser mode off or navigation bar already hidden")
      return
    }
    
    isBrowserBarAnimating = true
    
    // Haptic feedback
    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    impactFeedback.impactOccurred()
    
    // Hide navigation bar with animation (0.4 seconds)
    UIView.animate(withDuration: 0.4, animations: {
      navigationController.setNavigationBarHidden(true, animated: false)
      self.view.layoutIfNeeded()
    }) { _ in
      // Show navigation bar again after a brief delay (0.2s delay + 0.4s animation = 1.0s total)
      UIView.animate(withDuration: 0.4, delay: 0.2, options: [], animations: {
        navigationController.setNavigationBarHidden(false, animated: false)
        self.view.layoutIfNeeded()
      }) { _ in
        self.isBrowserBarAnimating = false
      }
    }
  }
  
  // BROWSER MODE ONLY: enable user input via URL address bar
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder() // hide the keyboard
    
    guard let webView = webView else { return true }
    
    let userURL = URL(string: browserURL.text ?? "")
    config.newURL = userURL
    
    loadWebViewIfNeeded()
    
    return true
  }
  
  @objc func fireTimer() {
    print("Timer fired!")
    hideWarningBanner()
    resetSession()
  }
  
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    // Hide loading indicator when page finishes loading
    hideLoadingIndicator()
    
    UIApplication.shared.isNetworkActivityIndicatorVisible = true
    
    if let url = webView.url {
      self.browserURL.text = String(describing: url)
    }
    
    // version 2.2 - timer to refresh session
    if config.resetTimer != 0 {
      timer?.invalidate()
      cancelWarningTimer()
      print("Timer reset!")
      print("DEBUG: Current webView URL: \(String(describing: webView.url))")
      print("DEBUG: Config homeURL: \(String(describing: config.homeURL))")
      print("DEBUG: resetTimerOnHome setting: \(config.resetTimerOnHome)")
      
      // Check if we should start timer based on current URL and resetTimerOnHome setting
      let shouldStartTimer: Bool
      if config.resetTimerOnHome == "ON" {
        // When resetTimerOnHome is ON, always start the timer regardless of URL
        shouldStartTimer = true
        print("DEBUG: Timer will start (resetTimerOnHome is ON)")
      } else {
        // Default behavior: only start timer when NOT at home URL
        shouldStartTimer = (webView.url != config.homeURL)
        print("DEBUG: webView.url = \(String(describing: webView.url))")
        print("DEBUG: Timer will \(shouldStartTimer ? "start" : "NOT start") (default behavior, at home: \(!shouldStartTimer))")
      }
      
      if shouldStartTimer {
        print("Timer started!")
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(config.resetTimer), target: self, selector: #selector(fireTimer), userInfo: nil, repeats: false)
        startWarningTimer()
      }
    }
    
    // version 2.3 - check for URL string
    if config.queryUrlString != "" {
      let queryString = config.queryUrlString
      let hasSubstring = browserURL.text?.contains(queryString) ?? false
      
      if hasSubstring {
        print("Found string in URL")
        self.blockLockFlag = true
        
        self.navigationController?.isToolbarHidden = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {  // seconds delay
          
          UIAccessibility.requestGuidedAccessSession(enabled: false, completionHandler: {
            success in
            
            if success {
              self.config.currentASAMStatus = "OFF"
              print("Remote ASAM=OFF success")
            } else {
              print("Remote ASAM=OFF failure")
            }
          })
        }
      }
      else {
        self.blockLockFlag = false
        switchRemoteLock()
      }
    }
  }
  
  // version 2.8.5
  func resetSession() {
    timer?.invalidate()
    
    guard let webView = webView else { return }
    
    print("Resetting session...")
    // Remove all additional webViews first
    for additionalWebView in additionalWebViews {
      additionalWebView.stopLoading()
      additionalWebView.removeFromSuperview()
    }
    additionalWebViews.removeAll()
    
    // Clear sessionStorage, localStorage, and cookies using JavaScript
    let javascript = """
    if (typeof sessionStorage !== 'undefined') {
        sessionStorage.clear();
    }
    if (typeof localStorage !== 'undefined') {
        localStorage.clear();
    }
    if (typeof document.cookie !== 'undefined') {
        document.cookie.split(";").forEach(function(c) {
            document.cookie = c.replace(/^ +/, "").replace(/=.*/, "=;expires=" + new Date().toUTCString() + ";path=/");
        });
    }
    """
    
    webView.evaluateJavaScript(javascript) { (_, error) in
      if let error = error {
        print("JavaScript execution error: \(error)")
      }
      
      // Clear WKWebView website data store (this is crucial for Microsoft login)
      let websiteDataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
      let dataStore = webView.configuration.websiteDataStore
      
      dataStore.removeData(ofTypes: websiteDataTypes, modifiedSince: Date(timeIntervalSince1970: 0)) {
        print("Website data cleared")
        
        // Load home URL after clearing data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          self.config.newURL = self.config.homeURL
          self.loadWebViewIfNeeded()
        }
      }
    }
  }
  
  // version 2.4 - deep link support
  func deepLink() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
      let appDelegate = UIApplication.shared.delegate as! AppDelegate
      if appDelegate.deepLink != nil {
        print("deepLink: \(appDelegate.deepLink!)")
        self.config.newURL = appDelegate.deepLink
        self.config.homeURL = appDelegate.deepLink
        DispatchQueue.main.async {
          self.loadWebViewIfNeeded()
        }
      }
      else {
        print("No deep link") }
    })
  }
  
  // version 2.5 - observe when camera reads QR Code
  @objc func onNotification(notification:Notification) {
    print("observed")
    if let urlString = notification.userInfo?["qrCode"] as? String {
      let url = URL(string: urlString)
      print("QR Code loading...")
      if let url = url {
        print(url.absoluteString)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
          // Show loading indicator when loading QR code URL
          self.showLoadingIndicator()
          self.webView?.load(URLRequest(url: url))
        })
      }
    }
  }
  
  // version 2.5 - if error (e.g. network not connected) then retry page load after x.x seconds
  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    // Hide loading indicator on error
    hideLoadingIndicator()
    
    // Log comprehensive error details
    print("ERROR: didFailProvisionalNavigation - \(error.localizedDescription)")
    print("ERROR: Error domain: \(error._domain)")
    print("ERROR: Error code: \(error._code)")
    print("ERROR: Failed URL: \(webView.url?.absoluteString ?? "unknown")")
    print("ERROR: Target URL: \(config.displayURL.absoluteString)")
    
    // Log additional error details if it's an NSError
    if let nsError = error as NSError? {
      print("ERROR: NSError userInfo: \(nsError.userInfo)")
      if let failingURL = nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL {
        print("ERROR: Failing URL from userInfo: \(failingURL.absoluteString)")
      }
      if let failingURLString = nsError.userInfo[NSURLErrorFailingURLStringErrorKey] as? String {
        print("ERROR: Failing URL string from userInfo: \(failingURLString)")
      }
    }
    
    // Check if this is a cancellation error (NSURLErrorCancelled = -999)
    // These should NOT trigger retries as they indicate intentional cancellation
    if let nsError = error as NSError?,
       nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
      print("ERROR: Request was cancelled (-999) - not retrying to avoid infinite loop")
      return
    }
    
    // Check for WebKit frame load interrupted (code 102)
    // This usually happens when multiple rapid navigations occur
    if let nsError = error as NSError?,
       nsError.domain == "WebKitErrorDomain" && nsError.code == 102 {
      print("ERROR: Frame load interrupted (102) - not retrying to avoid conflicts")
      return
    }
    
    // Only retry for legitimate network/loading errors
    DispatchQueue.main.asyncAfter(deadline: .now() + retryTimer) {
      print("trying page load... again")
      // Show loading indicator when retrying
      self.showLoadingIndicator()
      webView.load(webView.url != nil ? URLRequest(url: webView.url!) : URLRequest(url: self.config.displayURL))
    }
  }
  
  // version 2.7 - add support for tab/pop-up redirection to webview
  func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
    print("createWebViewWith")
    
    if config.redirect == "ON" {
      print("redirection to existing webview")
      if navigationAction.targetFrame == nil {
        webView.load(navigationAction.request)
      }
    }
    
    if config.redirect == "ALT" {
      print("redirection to new webview")
      if navigationAction.targetFrame?.isMainFrame != true {
        let newWebView = WKWebView(frame: webView.frame,
                                   configuration: configuration)
        newWebView.load(navigationAction.request)
        newWebView.uiDelegate = self
        newWebView.navigationDelegate = self
        webView.superview?.addSubview(newWebView)
        
        // Keep track of this webView
        additionalWebViews.append(newWebView)
        
        return newWebView
      }
    }
    
    return nil
  }
  
  // version 2.8.1 - add option to bypass secure SSL
  // version 2.8.2 - fixed crash
  func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    if config.disabletrust == "OFF" && challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
      completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!) )
    } else {
      completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil )
    }
  }
  
  // MARK: - User-activity detection (touch / pan / tap anywhere in the view)
  // version 2.8.5
  private func addUserActivityDetection() {
    // We add recognisers only once.
    guard view.gestureRecognizers?.contains(where: { $0.name == "userActivity" }) != true else { return }
    
    let tap = UITapGestureRecognizer(target: self, action: #selector(userDidInteract))
    tap.cancelsTouchesInView = false
    tap.name = "userActivity"
    tap.delegate = self
    
    let pan = UIPanGestureRecognizer(target: self, action: #selector(userDidInteract))
    pan.cancelsTouchesInView = false
    pan.name = "userActivity"
    pan.delegate = self
    
    view.addGestureRecognizer(tap)
    view.addGestureRecognizer(pan)
  }
  
  @objc private func userDidInteract() {
    print("User interaction detected")
    
    // Check if warning banner is currently visible
    let warningBannerVisible = warningBannerView?.isHidden == false && warningBannerView?.alpha ?? 0 > 0
    
    // Reset timers if:
    // 1. detectScroll is ON (existing behavior), OR
    // 2. Warning banner is visible (user should be able to dismiss by interacting)
    if (config.detectScroll == "ON" || warningBannerVisible), config.resetTimer != 0 {
      timer?.invalidate()
      cancelWarningTimer()
      
      // Check if we should start timer based on current URL and resetTimerOnHome setting
      let shouldStartTimer: Bool
      if config.resetTimerOnHome == "ON" {
        // When resetTimerOnHome is ON, always start the timer regardless of URL
        shouldStartTimer = true
      } else {
        // Default behavior: only start timer when NOT at home URL
        shouldStartTimer = (webView?.url != config.homeURL)
      }
      
      if shouldStartTimer {
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(config.resetTimer),
                                     target: self,
                                     selector: #selector(fireTimer),
                                     userInfo: nil,
                                     repeats: false)
        startWarningTimer()
      }
    }
  }
  
  // Allow our gesture recognisers to work alongside the web view's own recognisers.
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                         shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
  
  // MARK: - Device Lock Detection
  private func addDeviceLockDetection() {
    // Listen for device lock events
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(deviceDidLock),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
    
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(deviceDidUnlock),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(deviceWillLock),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
  }
  
  @objc private func deviceWillLock() {
    print("Device will lock - preparing for lock state")
    // Pause any ongoing operations, timers, etc.
    timer?.invalidate()
    webView?.stopLoading()
  }
  
  @objc private func deviceDidLock() {
    print("Device locked - app entered background")
    // Additional cleanup when device is locked
    // This could trigger session reset, clear sensitive data, etc.
    if config.resetTimer != 0 {
      // Reset session immediately on device lock if timer is enabled
      DispatchQueue.main.async {
        self.resetSession()
      }
    }
  }
  
  @objc private func deviceDidUnlock() {
    print("Device unlocked - app became active")
    
  }
  
  // Clean up when view controller is deallocated
  deinit {
    // Remove device lock observers
    NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
    NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
    webView?.removeFromSuperview()
    webView = nil
  }
}

// version 2.8
// the following snippet is from https://stackoverflow.com/questions/25607247/how-do-i-decode-html-entities-in-swift/30141700#30141700

private let characterEntities : [ Substring : Character ] = [
  // XML predefined entities:
  "&quot;"    : "\"",
  "&amp;"     : "&",
  "&apos;"    : "'",
  "&lt;"      : "<",
  "&gt;"      : ">",
  
  // HTML character entity references:
  "&nbsp;"    : "\u{00a0}",
  // ...
  "&diams;"   : "♦",
]

extension String {
  var stringByDecodingHTMLEntities : String {
    func decodeNumeric(_ string : Substring, base : Int) -> Character? {
      guard let code = UInt32(string, radix: base),
            let uniScalar = UnicodeScalar(code) else { return nil }
      return Character(uniScalar)
    }
    
    func decode(_ entity : Substring) -> Character? {
      if entity.hasPrefix("&#x") || entity.hasPrefix("&#X") {
        return decodeNumeric(entity.dropFirst(3).dropLast(), base: 16)
      } else if entity.hasPrefix("&#") {
        return decodeNumeric(entity.dropFirst(2).dropLast(), base: 10)
      } else {
        return characterEntities[entity]
      }
    }
    
    var result = ""
    var position = startIndex
    
    // Find the next '&' and copy the characters preceding it to `result`:
    while let ampRange = self[position...].range(of: "&") {
      result.append(contentsOf: self[position ..< ampRange.lowerBound])
      position = ampRange.lowerBound
      
      // Find the next ';' and copy everything from '&' to ';' into `entity`
      guard let semiRange = self[position...].range(of: ";") else {
        // No matching ';'.
        break
      }
      let entity = self[position ..< semiRange.upperBound]
      position = semiRange.upperBound
      
      if let decoded = decode(entity) {
        // Replace by decoded character:
        result.append(decoded)
      } else {
        // Invalid entity, copy verbatim:
        result.append(contentsOf: entity)
      }
    }
    // Copy remaining characters to `result`:
    result.append(contentsOf: self[position...])
    return result
  }
}
