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
import PSPDFKit

class UITestingEarlGreyTests: PSPDFTestCase {
    
    func testEarlGrey() {
        EarlGrey().selectElement(with: grey_accessibilityLabel("Thumbnails")).assert(with: grey_sufficientlyVisible()).perform(grey_tap())
    }

    func testAddAndDeleteBookmark() {
        speed = .normal
        let fileURL = Bundle.main.bundleURL.appendingPathComponent("PSPDFKit 6 QuickStart Guide.pdf")
        let document = PSPDFDocument(url: fileURL)
        document.uid = NSUUID().uuidString
        if let bookmarkManager = document.bookmarkManager {
            for bookmark in bookmarkManager.bookmarks {
                bookmarkManager.removeBookmark(bookmark)
            }
        }

        let configuration = PSPDFConfiguration() { builder in
            builder.shouldAskForAnnotationUsername = false
        }

        let controller = PSPDFViewController(document:document, configuration:configuration)

        controller.navigationItem.rightBarButtonItems = [controller.bookmarkButtonItem, controller.outlineButtonItem]

        test(with: controller) {
            XCTAssertEqual(controller.document!.bookmarks.count, 0)

            EarlGrey().selectElement(with: grey_accessibilityLabel("Bookmarks")).assert(with: grey_sufficientlyVisible()).perform(grey_tap())
            XCTAssertEqual(controller.document!.bookmarks.count, 1)

            EarlGrey().selectElement(with: grey_accessibilityLabel("Outline")).assert(with: grey_sufficientlyVisible()).perform(grey_tap())
            EarlGrey().selectElement(with: grey_text("Bookmarks")).perform(grey_tap())

            EarlGrey().selectElement(with: grey_accessibilityLabel("Page 1")).assert(with: grey_sufficientlyVisible()).perform(grey_swipeSlowInDirection(.left))
            EarlGrey().selectElement(with: grey_text("Delete")).assert(with: grey_sufficientlyVisible()).perform(grey_tap())

            EarlGrey().selectElement(with: grey_accessibilityLabel("No Bookmarks")).assert(with: grey_sufficientlyVisible())

            XCTAssertEqual(controller.document!.bookmarks.count, 0)
        }
    }
    
}
