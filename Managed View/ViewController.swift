//
//  ViewController.swift
//  Managed View
//


import UIKit

class ViewController: UIViewController {
    
//    let UserDefaults: Foundation.UserDefaults = Foundation.UserDefaults.standard
    
    @IBOutlet var WebView: UIWebView!
    
//  Default URL to display in web view
    var defaultURL = URL(string: "https://www.jamf.com/solutions/industries/retail/")

//  Maintenance mode status
    var MAINTENANCE_MODE = "OFF"
    
//  Last URL loaded in web view
    var url = URL(string: "")
    
//  Pending URL to load
    var newurl = URL(string: "")
    
//  Autonomous Single App Mode (Mode)
    var asamStatus:Bool = true
    var asamStatusString:String = ""


    override func viewDidLoad() {
        super.viewDidLoad()
        
        // request URL to web view
        setupView()
        
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: OperationQueue.main) { _ in
            self.setupView()
            print ("reload")
        }
        
    }
    
    //  Tap Gesture Recognizer (triple tap defined in storyboard)
    //  Gesture used as interactive method to enable or disable Autonomous Single App Mode
    
    @IBAction func tripleTap(_ sender: AnyObject) {
        
        // If ASAM is enabled
        if (UIAccessibilityIsGuidedAccessEnabled() == true ) {
            asamStatus = true
            asamStatusString = "ENABLED"
        }
            
        // if ASAM is not enabled
        else {
            asamStatus = false
            asamStatusString = "DISABLED"

        }
        
        print (asamStatus)
        
        // define dialog to user
        
        let actionSheetController: UIAlertController = UIAlertController(title: "Autonomous Single App Mode is currently\n \(asamStatusString)", message: "Select action", preferredStyle: .actionSheet)
        
       
        //  Customize user dialog based on current state of ASAM and reguest ASAM state change
        if (asamStatus == false) {
            let asamEnable: UIAlertAction = UIAlertAction(title: "Enable", style: .default) { action -> Void in
                UIAccessibilityRequestGuidedAccessSession(true) {
                    success in
                
                    print("INFO: ASAM request to set ON")
                
                    if success {
                        print ("ASAM is enabled")
                        let asamAlert = UIAlertController(title: "Success", message: "Autonomous Single App Mode is\n\n ENABLED.", preferredStyle: UIAlertControllerStyle.alert)
                        asamAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    
                        self.present(asamAlert, animated: true, completion: nil)
                    }
                    else {
                        print ("INFO: ASAM is not capable.")
                        let asamAlert = UIAlertController(title: "Autonomous Single App Mode is not supported", message: "This device does not currently support Automonous Single App Mode (ASAM).  ASAM requires the following:\n\n (1) Device is in supervised state.\n\n(2) Configuration profile supporting ASAM for this specific app installed on device.", preferredStyle: UIAlertControllerStyle.alert)
                        asamAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    
                        self.present(asamAlert, animated: true, completion: nil)

                    }

                }
            }
        
            actionSheetController.addAction(asamEnable)
        }
        
        else {
            let asamDisable: UIAlertAction = UIAlertAction(title: "Disable", style: .default) { action -> Void in
                UIAccessibilityRequestGuidedAccessSession(false) {
                    success in
                    
                    print("INFO: ASAM request to set OFF")
                    
                    if success {
                        print ("ASAM is disenabled")
                        let asamAlert = UIAlertController(title: "Success", message: "Autonomous Single App Mode is\n\n DISABLED.", preferredStyle: UIAlertControllerStyle.alert)
                        asamAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    
                        self.present(asamAlert, animated: true, completion: nil)
                        
                    }
                    else {
                        print ("INFO: ASAM is not capable.")
                        let asamAlert = UIAlertController(title: "Autonomous Single App Mode is not supported", message: "This device does not currently support Automonous Single App Mode (ASAM).  ASAM requires the following:\n\n (1) Device is in supervised state.\n\n(2) Configuration profile supporting ASAM for this specific app installed on device.", preferredStyle: UIAlertControllerStyle.alert)
                        asamAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    
                        self.present(asamAlert, animated: true, completion: nil)

                    }
                }
            }
            actionSheetController.addAction(asamDisable)
        }
        
        //Create and add the Cancel action
        let cancelAction: UIAlertAction = UIAlertAction(title: "Cancel", style: .destructive) { action -> Void in
            //Just dismiss the action sheet
        }
        actionSheetController.addAction(cancelAction)
        
        // for iPad
        actionSheetController.popoverPresentationController?.sourceView = view

        // Present dialog to user
        self.present(actionSheetController, animated: true, completion: nil)
        
    }
    
    func setupView() {

        print ("INFO: setupView")
        
        //  Check for Manged App Config
        
        if let ManAppConfig = UserDefaults.standard.dictionary(forKey: "com.apple.configuration.managed") {
            
            //  Check if MAINTENANCE_MODE key is set
            
            if (ManAppConfig["MAINTENANCE_MODE"] != nil) {
                MAINTENANCE_MODE = String(describing: ManAppConfig["MAINTENANCE_MODE"]!)
                
            }
            else {
                MAINTENANCE_MODE = "OFF"
                
            }
            
            //  Check if MAINTENANCE_MODE key is set to "ON"
            
            if (String(describing: ManAppConfig["MAINTENANCE_MODE"]!) == "ON") {
                
                newurl = URL.init(fileURLWithPath: Bundle.main.path(forResource: "curtain", ofType: "png", inDirectory: "img")!)
                
                //  If URL changed since last web view load then load new URL
                
                if newurl != url {
                    
                    print ("STATUS: loading maintenacne URL \(newurl!)")
                    let request = URLRequest(url: newurl!)
                    
                    WebView.loadRequest(request)
                    url = newurl
                }
                
            }
            
            else {
            
            
            //  Check if URL key is set
            
            if (ManAppConfig["URL"] != nil) {
                
                newurl = URL(string: String(describing: ManAppConfig["URL"]!))
                
                //  If URL changed since last web view load then load new URL
                
                if newurl != url {
                    
                    print ("STATUS: loading updated AppConfig URL \(newurl!)")
                    let request = URLRequest(url: newurl!)
                    
                    WebView.loadRequest(request)
                    url = newurl
                }
                
            }

            // If no Manged App Config URL key set then use default URL
            
            else {
                
                newurl = defaultURL
                
                //  If URL changed since last web view load then load new URL

                if newurl != url {
                    
                    print ("STATUS: loading default URL \(newurl!)")
                    let request = URLRequest(url: newurl!)
                    
                    WebView.loadRequest(request)
                    url = newurl
                }
                
            }
            }
            
        }
            
        // If no Manged App Config then use default URL

        else {
            
            newurl = defaultURL
            
            //  If URL changed since last web view load then load new URL
        
            if newurl != url {
                
                print ("INFO: Refreshing2 \(newurl!)")
                let request = URLRequest(url: newurl!)
                
                WebView.loadRequest(request)
                url = newurl
            }
            
        }
        
    }
   
//  Hide Top Status Bar
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
}

