//
//  AppDelegate.swift
//  UITestingComparison
//
//  Copyright © 2016 PSPDFKit GmbH. All rights reserved.
//

import UIKit
import PSPDFKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    public func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        // Custom apps will require either a demo or commercial license key from http://pspdfkit.com
        PSPDFKit.setLicenseKey("YOUR_LICENSE_KEY_GOES_HERE")

        return true
    }
}
