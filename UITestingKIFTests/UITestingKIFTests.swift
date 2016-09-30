//
//  UITestingKIFTests.swift
//  UITestingKIFTests
//
//  Copyright © 2016 PSPDFKit GmbH. All rights reserved.
//
//  THIS SOURCE CODE AND ANY ACCOMPANYING DOCUMENTATION ARE PROTECTED BY INTERNATIONAL COPYRIGHT LAW
//  AND MAY NOT BE RESOLD OR REDISTRIBUTED. USAGE IS BOUND TO THE PSPDFKIT LICENSE AGREEMENT.
//  UNAUTHORIZED REPRODUCTION OR DISTRIBUTION IS SUBJECT TO CIVIL AND CRIMINAL PENALTIES.
//  This notice may not be removed from this file.
//


import XCTest
import PSPDFKit

class UITestingKIFTests: PSPDFTestCase {

    func testKIF() {
        tester.tapView(withAccessibilityLabel: "Thumbnails")
        tester.tapView(withAccessibilityLabel: "Document Editor")
        tester.tapView(withAccessibilityLabel: "Add Page")
        tester.tapView(withAccessibilityLabel: "Add")

        waitForCondition(condition: true)
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
