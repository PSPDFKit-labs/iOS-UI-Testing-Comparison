//
//  UITestingEarlGreyTests.swift
//  UITestingEarlGreyTests
//
//  Copyright © 2016 PSPDFKit GmbH. All rights reserved.
//

import PSPDFKit

// https://github.com/google/EarlGrey
class UITestingEarlGreyTests: PSPDFTestCase {

    override func setUp() {
        super.setUp()

        // EarlGrey sends analytics by default. Let's disable that.
        (GREYConfiguration.sharedInstance() as AnyObject).setValue(false, forConfigKey: kGREYConfigKeyAnalyticsEnabled)
    }

    func testAddPage() {
        let grey = EarlGrey()!

        grey.selectElement(with: grey_accessibilityLabel("Thumbnails")).assert(with: grey_sufficientlyVisible()).perform(grey_tap())
        grey.selectElement(with: grey_accessibilityLabel("Document Editor")).assert(with: grey_sufficientlyVisible()).perform(grey_tap())

        grey.selectElement(with: grey_accessibilityLabel("Add Page")).assert(with: grey_sufficientlyVisible()).perform(grey_tap())
        grey.selectElement(with: grey_accessibilityLabel("Add")).assert(with: grey_sufficientlyVisible()).perform(grey_tap())
        grey.selectElement(with: grey_accessibilityLabel("Done")).assert(with: grey_sufficientlyVisible()).perform(grey_tap())

        grey.selectElement(with: grey_accessibilityLabel("Discard Changes")).atIndex(0).assert(with: grey_sufficientlyVisible()).perform(grey_tap())
        grey.selectElement(with: grey_accessibilityLabel("Page 1")).assert(with: grey_sufficientlyVisible()).perform(grey_tap())
    }


    func testAddAndDeleteBookmark() {
        let controller = TestControllerFactory().testAddAndDeleteBookmark()

        test(with: controller) {
            XCTAssertEqual(controller.document!.bookmarks.count, 0)

            let grey = EarlGrey()!

            grey.selectElement(with: grey_accessibilityLabel("Bookmarks")).assert(with: grey_sufficientlyVisible()).perform(grey_tap())
            XCTAssertEqual(controller.document!.bookmarks.count, 1)

            grey.selectElement(with: grey_accessibilityLabel("Outline")).assert(with: grey_sufficientlyVisible()).perform(grey_tap())
            grey.selectElement(with: grey_text("Bookmarks")).perform(grey_tap())

            grey.selectElement(with: grey_accessibilityLabel("Page 1")).atIndex(0).assert(with: grey_sufficientlyVisible()).perform(grey_swipeSlowInDirection(.left))
            grey.selectElement(with: grey_text("Delete")).assert(with: grey_sufficientlyVisible()).perform(grey_tap())

            grey.selectElement(with: grey_accessibilityLabel("No Bookmarks")).atIndex(0).assert(with: grey_sufficientlyVisible())

            XCTAssertEqual(controller.document!.bookmarks.count, 0)
        }
    }
}
