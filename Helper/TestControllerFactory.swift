//
//  TestControllerFactory.swift
//  UITestingComparison
//
//  Copyright © 2016 PSPDFKit GmbH. All rights reserved.
//

import Foundation
import PSPDFKit

class TestControllerFactory {

    func testAddAndDeleteBookmark() -> PSPDFViewController {
        let fileURL = Bundle.main.bundleURL.appendingPathComponent("PSPDFKit 6 QuickStart Guide.pdf")
        let document = PSPDFDocument(url: fileURL)
        document.uid = NSUUID().uuidString

        // Ensure we don't have any bookmarks
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

        return controller
    }

}
