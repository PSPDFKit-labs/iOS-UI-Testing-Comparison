//
//  PDFViewController.swift
//  UITestingComparison
//
//  Copyright © 2016 PSPDFKit GmbH. All rights reserved.
//

import UIKit
import PSPDFKit

class PDFViewController: PSPDFViewController {

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        let fileURL = Bundle.main.bundleURL.appendingPathComponent("PSPDFKit 6 QuickStart Guide.pdf")
        let writableURL = copyFileURLToDocumentFolder(fileURL)
        self.document = PSPDFDocument(url: writableURL)
    }

    private func copyFileURLToDocumentFolder(_ documentURL: URL, override: Bool = false) -> URL {
        let docsURL = URL(fileURLWithPath:(NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!))
        let newURL = docsURL.appendingPathComponent(documentURL.lastPathComponent)
        let needsCopy = !FileManager.default.fileExists(atPath: newURL.path)
        if override {
            _ = try? FileManager.default.removeItem(at: newURL)
        }
        if needsCopy || override {
            do {
                try FileManager.default.copyItem(at: documentURL, to: newURL)
            } catch let error {
                print("Error while copying \(documentURL.path): \(error.localizedDescription)")
            }
        }
        return newURL
    }
}
