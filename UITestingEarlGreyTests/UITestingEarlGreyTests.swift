//
//  UITestingEarlGreyTests.swift
//  UITestingEarlGreyTests
//
//  Copyright © 2016 PSPDFKit GmbH. All rights reserved.
//

import PSPDFKit

class UITestingEarlGreyTests: PSPDFTestCase {

    func testAddPage() {
        EarlGrey().selectElement(with: grey_accessibilityLabel("Thumbnails")).assert(with: grey_sufficientlyVisible()).perform(grey_tap())
        EarlGrey().selectElement(with: grey_accessibilityLabel("Document Editor")).assert(with: grey_sufficientlyVisible()).perform(grey_tap())
        EarlGrey().selectElement(with: grey_accessibilityLabel("Add Page")).assert(with: grey_sufficientlyVisible()).perform(grey_tap())
        EarlGrey().selectElement(with: grey_accessibilityLabel("Add")).assert(with: grey_sufficientlyVisible()).perform(grey_tap())
        EarlGrey().selectElement(with: grey_accessibilityLabel("Done")).assert(with: grey_sufficientlyVisible()).perform(grey_tap())
        EarlGrey().selectElement(with: grey_accessibilityLabel("Discard Changes")).atIndex(0).assert(with: grey_sufficientlyVisible()).perform(grey_tap())
        EarlGrey().selectElement(with: grey_accessibilityLabel("Page 1")).assert(with: grey_sufficientlyVisible()).perform(grey_tap())
    }
    
    func testAddAndDeleteBookmark() {
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

            EarlGrey().selectElement(with: grey_accessibilityLabel("Page 1")).atIndex(0).assert(with: grey_sufficientlyVisible()).perform(grey_swipeSlowInDirection(.left))
            EarlGrey().selectElement(with: grey_text("Delete")).assert(with: grey_sufficientlyVisible()).perform(grey_tap())

            EarlGrey().selectElement(with: grey_accessibilityLabel("No Bookmarks")).atIndex(0).assert(with: grey_sufficientlyVisible())

            XCTAssertEqual(controller.document!.bookmarks.count, 0)
        }
    }
    
}
