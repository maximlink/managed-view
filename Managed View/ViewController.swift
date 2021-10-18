//
//  ViewController.swift
//  Managed View
//
//

import Foundation
import UIKit
import WebKit
import ManagedAppConfigLib  // courtesy of James Felton -> https://github.com/jamf/ManagedAppConfigLib

class ViewController: UIViewController, UITextFieldDelegate, WKUIDelegate, WKNavigationDelegate {
    
    @IBOutlet weak var browserURL: UITextField!  //BROWSER MODE ONLY: URL address bar
    var webView: WKWebView!

    var defaultURL = URL(string: "https://maximlink.com/readme")

    var blockLockFlag = false
    
    // local app configuration
    struct Config {
        var maintenanceMode: String     // display curtain image
        var newURL: URL!                // new URL request
        var previousURL: URL!           // previously loaded URL
        var browserMode: String         // display user interactive browser controls
        var browserModeNoEdit: String   // disable address bar edit
        var homeURL: URL!               // BROWSER MODE ONLY: URL for home button
        var remoteLock: String          // enable remote ASAM capability
        var currentASAMStatus: String   // current ASAM status
        var privateBrowsing: String     // private browsing mode
        var queryUrlString: String     // private browsing mode
        var resetTimer: Int             // timer in seconds to reset session
        
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
    var config = Config(maintenanceMode: "OFF",
                        newURL: URL(string: ""),
                        previousURL: URL(string: ""),
                        browserMode: "OFF",
                        browserModeNoEdit: "OFF",
                        homeURL: URL(string: ""),
                        remoteLock: "OFF",
                        currentASAMStatus: "OFF",
                        privateBrowsing: "OFF",
                        queryUrlString: "",
                        resetTimer: 0
    )
    
    var timer: Timer?
    
    // WKWebView setup via code - required for < iOS 11
    override func loadView() {
        newWebView()
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

        readManagedAppConfig()  // initial load of MDM managed app config to local config
        
        let myClosure = { (configDict: [String : Any?]) -> Void in
            NSLog("mannaged app configuration changed")
            self.readManagedAppConfig()  // reload MDM managed app config to local config
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

    }
    
    func readManagedAppConfig() {
        
        // default managed app config settings
        let macDict = [
            "MAINTENANCE_MODE":"OFF",
            "URL":String(describing: defaultURL!),
            "REMOTE_LOCK":"OFF",
            "BROWSER_MODE":"OFF",
            "BROWSER_BAR_NO_EDIT":"OFF",
            "PRIVATE_BROWSING":"OFF",
            "QUERY_URL_STRING":"",
            "RESET_TIMER":0
        ] as [String : Any]
        
        // determine if MDM pushed managed app config and assign to local config, if not use defaults
        for (key,defaultValue) in macDict {
            if let value = ManagedAppConfig.shared.getConfigValue(forKey: key) {
                switch key {
                case "MAINTENANCE_MODE" : config.maintenanceMode = value as! String
                case "URL" : do {
                    self.config.newURL = URL(string: value as! String)
                    self.config.homeURL = URL(string: value as! String) }
                case "REMOTE_LOCK" : config.remoteLock = value as! String
                case "BROWSER_MODE" : config.browserMode = value as! String
                case "BROWSER_BAR_NO_EDIT" : config.browserModeNoEdit = value as! String
                case "PRIVATE_BROWSING" : config.privateBrowsing = value as! String
                case "QUERY_URL_STRING" : config.queryUrlString = value as! String
                case "RESET_TIMER" : config.resetTimer = value as! Int

                default: NSLog("ERROR: undefined managed app config key") }
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

                default: NSLog("ERROR: undefined managed app config key") }
            }
        }
        
        // switch ASAM setting if new request is different than previous
        if self.config.currentASAMStatus != config.remoteLock {
            switchRemoteLock()
        }
        
        // initiate new web view (persistent or private mode)
        if self.config.privateBrowsing == "ON" {
            DispatchQueue.main.async {
                self.newWebViewPrivate()
            }
        } else {
            DispatchQueue.main.async {
                self.newWebView()
            }
        }
 
        DispatchQueue.main.async {
            self.loadWebView()
        }

        // check for browser mode status and set accordingly
        DispatchQueue.main.async {
            self.checkBrowserMode()
        }
        
        NSLog(String(describing: config))
    }
    
    // initiate new Web View - persistent
    func newWebView() {
        let webConfiguration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        browserURL.delegate = self
        
        view = webView
        NSLog("Initiate webview - persistant")

    }
    
    // initiate new Web View - non-persistent
    func newWebViewPrivate() {
        let webConfiguration = WKWebViewConfiguration()
        // Private Mode v2.1
        webConfiguration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        browserURL.delegate = self
        
        view = webView
        NSLog("Initiate webview - non-persistant")

    }
    
    // load new URL request & check scheme (v2.3.1)
    func loadWebView() {
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
            self.navigationController?.isToolbarHidden = false
            
            UIAccessibility.requestGuidedAccessSession(enabled: true, completionHandler: {
                success in
                
                if success {
                    NSLog("Remote ASAM=ON success")
                    self.config.currentASAMStatus = "ON"
                    self.navigationController!.toolbar.barTintColor = UIColor.init(red: 0.2, green: 0.6, blue: 0.0, alpha: 1.0)
                } else {
                    NSLog("Remote ASAM=ON failure")
                    
                    // wait x seconds and try again
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {  // seconds delay
                        NSLog("Remote ASAM enable retry")
                        if !self.blockLockFlag {
                            self.switchRemoteLock()}
                    }
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
    }
    
    // BROWSER MODE ONLY: 4 connectors to UI
    @IBAction func goBack(_ sender: Any) {
        webView.goBack()
    }
    @IBAction func goForward(_ sender: Any) {
        webView.goForward()
    }
    @IBAction func refreshPage(_ sender: Any) {
        webView.reload()
    }
    @IBAction func goHome(_ sender: Any) {
        
        self.resetSession()
    }
    
    // BROWSER MODE ONLY: enable user input via URL address bar
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder() // hide the keyboard
        
        let userURL = URL(string: browserURL.text!)
        config.newURL = userURL
        
        loadWebView()
        
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
            let hasSubstring = browserURL.text!.contains(queryString)
            
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
    
    func resetSession() {
        // delete cookies
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            for cookie in cookies {
                self.webView.configuration.websiteDataStore.httpCookieStore.delete(cookie)
                print("DELETE COOKIE: \(cookie.name) = \(cookie.value)")
            }
        }
        
        config.newURL = config.homeURL
        loadWebView()
    }
    
    // version 2.3.3 - deep link support
    
    func deepLink() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
            let appDelegate =
                UIApplication.shared.delegate as! AppDelegate
            if appDelegate.deepLink != nil {
                print("deepLink: \(appDelegate.deepLink!)")
                self.config.newURL = appDelegate.deepLink
                self.config.homeURL = appDelegate.deepLink
                DispatchQueue.main.async {
                    self.loadWebView()
                }
                
            }
            else {
                NSLog("No deep link") }
        })
    }
    
}
