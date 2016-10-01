//
//  UITestingXCUITests.swift
//  UITestingXCUITests
//
//  Copyright © 2016 PSPDFKit GmbH. All rights reserved.
//

class UITestingXCUITests: PSPDFTestCase {
        
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIApplication().launch()
        XCUIDevice.shared().orientation = .portrait
    }

    func testAddPage() {
        let app = XCUIApplication()
        
        let navigationBar = app.navigationBars
        navigationBar.buttons["Thumbnails"].tap()
        navigationBar.buttons["Document Editor"].tap()
        app.buttons["Add Page"].tap()

        app.tables.staticTexts["Add"].tap()
        app.buttons["Done"].tap()

        app.sheets.buttons["Discard Changes"].tap()
        app.collectionViews["Thumbnail Collection"].cells["Page 1"].tap()
    }

    func testAddAndDeleteBookmark() {
        let app = XCUIApplication()

        let outlineButton = app.navigationBars.buttons["Outline"]
        outlineButton.tap()
        app.navigationBars["Outline"].buttons["Bookmarks"].tap()

        app.toolbars.buttons["Add"].tap()
        app.tables.staticTexts["Page 1"].swipeLeft()
        app.tables.buttons["Delete"].tap()
    }

    func testSearch() {
        let app = XCUIApplication()

        app.navigationBars.buttons["Search"].tap()

        let searchDocumentSearchField = app.searchFields["Search Document"]
        searchDocumentSearchField.typeText("PSPDF")

        app.tables["Search Results"].cells.element(boundBy: 0).tap()
    }
}
