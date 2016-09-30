//
//  UITestingKIFTests.swift
//  UITestingKIFTests
//
//  Copyright © 2016 PSPDFKit GmbH. All rights reserved.
//

import PSPDFKit

class UITestingKIFTests: PSPDFTestCase {

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

            tester.tapView(withAccessibilityLabel: "Bookmarks")
            XCTAssertEqual(controller.document!.bookmarks.count, 1)

            tester.tapView(withAccessibilityLabel: "Outline")
            tester.tapView(withAccessibilityLabel: "Bookmarks")

            // Delete bookmark.
            tester.swipeView(withAccessibilityLabel: "Page 1", in:.left)
            tester.tapView(withAccessibilityLabel: "Delete")
            tester.waitForView(withAccessibilityLabel: "No Bookmarks")

            XCTAssertEqual(controller.document!.bookmarks.count, 0)
        }
    }

}
