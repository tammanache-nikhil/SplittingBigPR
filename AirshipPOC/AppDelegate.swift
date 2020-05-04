//
//  AppDelegate.swift
//  AirshipPOC
//
//  Created by Tammanache, Nikhil on 08/01/20.
//  Copyright © 2020 Deloitte. All rights reserved.
//

import UIKit
import Airship

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UARegistrationDelegate {

    let pushHandler = PushHandler()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        // Populate AirshipConfig.plist with your app's info from https://go.urbanairship.com
        // or set runtime properties here.
        let config = UAConfig.default()

        if (config.validate() != true) {
            showInvalidConfigAlert()
            return true
        }
        
        // Call takeOff (which creates the UAirship singleton)
        UAirship.takeOff(config)

        // Print out the application configuration for debugging (optional)
        print("Config:\n \(config)")
        
        // Set the icon badge to zero on startup (optional)
        UAirship.push()?.resetBadge()

        // User notifications will not be enabled until userPushNotificationsEnabled is
        // enabled on UAPush. Once enabled, the setting will be persisted and the user
        // will be prompted to allow notifications. You should wait for a more appropriate
        // time to enable push to increase the likelihood that the user will accept
        // notifications.
        // UAirship.push()?.userPushNotificationsEnabled = true
        UAirship.push().userPushNotificationsEnabled = true
        UAirship.push().notificationOptions = [.alert, .badge, .sound]
        UAirship.push().defaultPresentationOptions = [.alert, .badge, .sound]
        UAirship.push().pushNotificationDelegate = pushHandler
        UAirship.push().registrationDelegate = self
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    @available(iOS 13.0, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    @available(iOS 13.0, *)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    func showInvalidConfigAlert() {
        let alertController = UIAlertController.init(title: "Invalid AirshipConfig.plist", message: "The AirshipConfig.plist must be a part of the app bundle and include a valid appkey and secret for the selected production level.", preferredStyle:.actionSheet)
        alertController.addAction(UIAlertAction.init(title: "Exit Application", style: UIAlertAction.Style.default, handler: { (UIAlertAction) in
            exit(1)
        }))
    }
    
    func apnsRegistrationSucceeded(withDeviceToken deviceToken: Data) {
        
    }
    
    func apnsRegistrationFailedWithError(_ error: Error) {
        
    }
    
    func registrationSucceeded(forChannelID channelID: String, deviceToken: String) {
        
    }
}
