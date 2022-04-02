import XCTest
import class Foundation.Bundle
@testable import Mips10000

final class Mips10000Tests: XCTestCase {
    private let fileIO = FileIOController()
    
    func testStartupState() throws {
        // Write initial state
        let initialState = State()
        try Logger().updateLog(with: initialState, documentName: "test_startup_state.json", deleteExistingFile: true)
        
        // Load 'true' state
        let trueState = try fileIO.read([State].self, documentName: "test.json").first!
        
        checkState(state: initialState, comparedTo: trueState)
    }
    
    private func checkState(state: State, comparedTo trueState: State) {
        XCTAssertEqual(state.PC, trueState.PC)
        XCTAssertEqual(state.ExceptionPC, trueState.ExceptionPC)
//        XCTAssertEqual(state.ActiveList, trueState.PC)
//        XCTAssertEqual(state.PC, trueState.PC)
//        XCTAssertEqual(state.PC, trueState.PC)
//        XCTAssertEqual(state.PC, trueState.PC)
//        XCTAssertEqual(state.PC, trueState.PC)
//        XCTAssertEqual(state.PC, trueState.PC)

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
