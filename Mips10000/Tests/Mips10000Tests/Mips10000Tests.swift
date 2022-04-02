import XCTest
import class Foundation.Bundle
@testable import Mips10000

final class Mips10000Tests: XCTestCase {
    func testStartupState() throws {
        // Save 
//        let program = try Parser().parseInstructions(fromFile: "test.json")
//        program.forEach({ print($0) })
//        try Logger().updateLog(newFile: true)
//        
        
    }

    /// Returns path to the built products directory.
    var productsDirectory: URL {
      #if os(macOS)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        fatalError("couldn't find the products directory")
      #else
        return Bundle.main.bundleURL
      #endif
    }
}
