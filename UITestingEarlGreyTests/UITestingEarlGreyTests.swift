//
//  UITestingEarlGreyTests.swift
//  UITestingEarlGreyTests
//
//  Copyright © 2016 PSPDFKit GmbH. All rights reserved.
//
//  THIS SOURCE CODE AND ANY ACCOMPANYING DOCUMENTATION ARE PROTECTED BY INTERNATIONAL COPYRIGHT LAW
//  AND MAY NOT BE RESOLD OR REDISTRIBUTED. USAGE IS BOUND TO THE PSPDFKIT LICENSE AGREEMENT.
//  UNAUTHORIZED REPRODUCTION OR DISTRIBUTION IS SUBJECT TO CIVIL AND CRIMINAL PENALTIES.
//  This notice may not be removed from this file.
//

import XCTest

class UITestingEarlGreyTests: XCTestCase {
    
    func testEarlGrey() {
        EarlGrey().selectElement(with: grey_accessibilityLabel("Thumbnails")).assert(with: grey_sufficientlyVisible()).perform(grey_tap())
    }
    
}