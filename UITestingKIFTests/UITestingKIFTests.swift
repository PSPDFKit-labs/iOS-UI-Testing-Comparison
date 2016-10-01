//
//  UITestingKIFTests.swift
//  UITestingKIFTests
//
//  Copyright © 2016 PSPDFKit GmbH. All rights reserved.
//

import PSPDFKit

// https://github.com/kif-framework/KIF
class UITestingKIFTests: PSPDFTestCase {

    override func setUp() {
        super.setUp()

        // Sadness without that. KIFTestCase would do that for us, but we don't use it here.
        KIFEnableAccessibility()
    }

    func testAddPage() {
        tester.waitForAnimationsToFinish()
        tester.waitForView(withAccessibilityLabel: "Thumbnails")
        tester.tapView(withAccessibilityLabel: "Thumbnails")

        tester.waitForAnimationsToFinish()

        tester.waitForView(withAccessibilityLabel: "Document Editor")
        tester.tapView(withAccessibilityLabel: "Document Editor")

        tester.waitForView(withAccessibilityLabel: "Add Page")
        tester.tapView(withAccessibilityLabel: "Add Page")

        tester.tapView(withAccessibilityLabel: "Add")
        tester.tapView(withAccessibilityLabel: "Done")
        tester.tapView(withAccessibilityLabel: "Discard Changes")
    }

    func testAddAndDeleteBookmark() {
        let controller = TestControllerFactory().testAddAndDeleteBookmark()

        test(with: controller) {
            XCTAssertEqual(controller.document!.bookmarks.count, 0)

            tester.waitForView(withAccessibilityLabel: "Bookmarks")

            tester.tapView(withAccessibilityLabel: "Bookmarks")

            //XCTAssertEqual(controller.document!.bookmarks.count, 1)
            wait(for: controller.document!.bookmarks.count == 1)

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
