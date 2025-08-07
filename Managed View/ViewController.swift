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

  // local app configuration
  struct Config {
    var decodeURL: String           // decode URL
    var maintenanceMode: String     // display curtain image
    var newURL: URL!                // new URL request
    var previousURL: URL!           // previously loaded URL
    var browserMode: String         // display user interactive browser controls
    var browserModeNoEdit: String   // disable address bar edit
    var homeURL: URL!               // BROWSER MODE ONLY: URL for home button
    var remoteLock: String          // enable remote ASAM capability
    var currentASAMStatus: String   // current ASAM status
    var privateBrowsing: String     // private browsing mode
    var queryUrlString: String      // private browsing mode
    var resetTimer: Int             // timer in seconds to reset session
    var qrCode: String              // enable QR Code reader
    var launchDelay: Int            // initial page load delayed by seconds
    var detectScroll: String        // reset timer if scrolling
    var redirect: String            // redirect new tabs / pop-ups to webview
    var disabletrust: String        // accept unsecure SSL
    var autoOpenPopup: String       // allow javascipt to auto open popup
    var disableAppConfigListener: String       // allow javascipt to auto open popup
    
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
                      detectScroll: "OFF",
                      redirect: "OFF",
                      disabletrust: "OFF",
                      autoOpenPopup: "OFF",
                      disableAppConfigListener: "OFF"
  )
  
  var timer: Timer?
  
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
    NSLog("App in foreground")
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
      NSLog("Managed app configuration changed")
      // version - 2.8.6
      if self.config.disableAppConfigListener == "OFF" {
        self.readManagedAppConfig()  // reload MDM managed app config to local config
      }
    }
    // listen for managed app config updates
    if config.queryUrlString == "" {
      ManagedAppConfig.shared.addAppConfigChangedHook(myClosure)
    }
    
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
      "RESET_TIMER":0,
      "QR_CODE":"OFF",
      "LAUNCH_DELAY":0,
      "DETECT_SCROLL":"OFF",
      "REDIRECT_SUPPORT":"OFF",
      "DISABLE_TRUST":"OFF",
      "AUTO_OPEN_POPUP":"OFF",
      "DISABLE_APP_CONFIG_LISTENER":"OFF"
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
          } else {
            //version 2.8
            let string = value as! String
            let decoded = string.stringByDecodingHTMLEntities
            print("decoded: \(decoded)")
            self.config.newURL = URL(string: decoded)
            self.config.homeURL = URL(string: decoded)
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
          
          default: NSLog("ERROR: \(key) - undefined managed app config key") }
      } else {
        switch key {
        case "MAINTENANCE_MODE" : config.maintenanceMode = defaultValue as! String
        case "URL" : do {
          self.config.newURL = URL(string: defaultValue as! String)
          self.config.homeURL = URL(string: defaultValue as! String) }
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
          
          default: NSLog("ERROR: \(key) - undefined managed app config key") }
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
    } else if let webView = webView {
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
    }
    
    NSLog(String(describing: config))
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
      NSLog("Created webview - non-persistent")
    } else {
      NSLog("Created webview - persistent")
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
  func loadWebViewIfNeeded() {
    guard let webView = webView else { return }
    
    var urlComponents = URLComponents()
    
    if (config.displayURL.scheme == nil) || (config.displayURL.scheme == "managedview"){
      urlComponents.scheme = "https" }
    else {
      urlComponents.scheme = config.displayURL.scheme }
    urlComponents.host = config.displayURL.host
    urlComponents.path = config.displayURL.path
    urlComponents.query = config.displayURL.query
    urlComponents.fragment = config.displayURL.fragment
    urlComponents.user = config.displayURL.user
    urlComponents.password = config.displayURL.password
    urlComponents.port = config.displayURL.port
    
    config.newURL = urlComponents.url
    
    let myRequest = URLRequest(url: config.displayURL)
    
    webView.load(myRequest)
    
    config.previousURL = config.displayURL
  }
  
  func switchRemoteLock() {
    if (config.remoteLock == "ON") {
      UIAccessibility.requestGuidedAccessSession(enabled: true, completionHandler: {
        success in
        
        if success {
          NSLog("Remote ASAM=ON success")
          self.config.currentASAMStatus = "ON"
          if let navController = self.navigationController {
            navController.toolbar.barTintColor = UIColor.init(red: 0.2, green: 0.6, blue: 0.0, alpha: 1.0)
          }
        } else {
          NSLog("Remote ASAM=ON failure")
        }
      })
    }
    
    else {
      self.navigationController?.isToolbarHidden = true
      
      UIAccessibility.requestGuidedAccessSession(enabled: false, completionHandler: {
        success in
        
        if success {
          self.config.currentASAMStatus = "OFF"
          NSLog("Remote ASAM=OFF success")
        } else {
          NSLog("Remote ASAM=OFF failure")
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
    print ("camera button pushed")
    performSegue(withIdentifier: "cameraSeque", sender: nil)
  }
  
  // BROWSER MODE ONLY: 4 connectors to UI
  @IBAction func goBack(_ sender: Any) {
    webView?.goBack()
  }
  @IBAction func goForward(_ sender: Any) {
    webView?.goForward()
  }
  @IBAction func refreshPage(_ sender: Any) {
    webView?.reload()
  }
  @IBAction func goHome(_ sender: Any) {
    self.resetSession()
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
    NSLog("Timer fired!")
    resetSession()
  }
  
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    UIApplication.shared.isNetworkActivityIndicatorVisible = true
    
    if let url = webView.url {
      self.browserURL.text = String(describing: url)
    }
    
    // version 2.2 - timer to refresh session
    if config.resetTimer != 0 {
      timer?.invalidate()
      NSLog("Timer reset!")
      
      if webView.url != config.homeURL {
        NSLog("Timer started!")
        
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(config.resetTimer), target: self, selector: #selector(fireTimer), userInfo: nil, repeats: false)
      }
    }
    
    // version 2.3 - check for URL string
    if config.queryUrlString != "" {
      let queryString = config.queryUrlString
      let hasSubstring = browserURL.text?.contains(queryString) ?? false
      
      if hasSubstring {
        NSLog("Found string in URL")
        self.blockLockFlag = true
        
        self.navigationController?.isToolbarHidden = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {  // seconds delay
          
          UIAccessibility.requestGuidedAccessSession(enabled: false, completionHandler: {
            success in
            
            if success {
              self.config.currentASAMStatus = "OFF"
              NSLog("Remote ASAM=OFF success")
            } else {
              NSLog("Remote ASAM=OFF failure")
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
    
    // Try to clear session via JavaScript first
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
        NSLog("JavaScript execution error: \(error)")
      }
      
      // Remove all additional webViews
      for additionalWebView in self.additionalWebViews {
        additionalWebView.stopLoading()
        additionalWebView.removeFromSuperview()
      }
      self.additionalWebViews.removeAll()
      
      // Load home URL after a brief delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        self.config.newURL = self.config.homeURL
        self.loadWebViewIfNeeded()
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
        NSLog("No deep link") }
    })
  }
  
  // version 2.5 - observe when camera reads QR Code
  @objc func onNotification(notification:Notification) {
    print("observed")
    if let urlString = notification.userInfo?["qrCode"] as? String {
      let url = URL(string: urlString)
      NSLog("QR Code loading...")
      if let url = url {
        NSLog(url.absoluteString)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
          self.webView?.load(URLRequest(url: url))
        })
      }
    }
  }
  
  // version 2.5 - if error (e.g. network not connected) then retry page load after x.x seconds
  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    DispatchQueue.main.asyncAfter(deadline: .now() + retryTimer) {
      print("trying page load... again")
      webView.load(webView.url != nil ? URLRequest(url: webView.url!) : URLRequest(url: self.config.displayURL))
    }
  }
  
  // version 2.7 - add support for tab/pop-up redirection to webview
  func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
    print("createWebViewWith")
    
    if config.redirect == "ON" {
      NSLog("redirection to existing webview")
      if navigationAction.targetFrame == nil {
        webView.load(navigationAction.request)
      }
    }
    
    if config.redirect == "ALT" {
      NSLog("redirection to new webview")
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
      NSLog("NSURLAuthenticationMethodServerTrust")
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
    NSLog("User interaction detected")
    // Reset timers or handle "active use" here as required.
    if config.detectScroll == "ON", config.resetTimer != 0 {
      timer?.invalidate()
      if webView?.url != config.homeURL {
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(config.resetTimer),
                                     target: self,
                                     selector: #selector(fireTimer),
                                     userInfo: nil,
                                     repeats: false)
      }
    }
  }
  
  // Allow our gesture recognisers to work alongside the web view's own recognisers.
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                         shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
  
  // Clean up when view controller is deallocated
  deinit {
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
