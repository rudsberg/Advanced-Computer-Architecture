import XCTest
import class Foundation.Bundle
@testable import Mips10000

final class Mips10000Tests: XCTestCase {
    private let fileIO = FileIOController()
    private var testProgram: [Instruction] {
        try! Parser().parseInstructions(fromFile: "test.json")
    }
    
    func testStartupState() throws {
        // Write initial state
        let initialState = State()
        try Logger().updateLog(with: initialState, documentName: "test_startup_state.json", deleteExistingFile: true)
        
        // Load 'true' state
        let trueState = try fileIO.read([State].self, documentName: "test_result.json").first!
        
        checkState(state: initialState, comparedTo: trueState)
    }
    
    func testFetchAndDecodeUnit() {
        let fad = FetchAndDecodeUnit()
        var state = State()
        state.programMemory = testProgram
        
        // Fetch&Decode regular test program
        fad.fetchAndDecode(state: state, backPressure: true)
        XCTAssertEqual(state.DecodedPCs, [])
        XCTAssertEqual(state.programMemory, testProgram)
        XCTAssertEqual(state.PC, 0)
        
        fad.fetchAndDecode(state: state, backPressure: false)
        XCTAssertEqual(state.DecodedPCs, [0, 1, 2, 3])
        XCTAssertEqual(state.programMemory, [])
        XCTAssertEqual(state.PC, 4)
        
        // Test with one more instruction (5)
        let fifthInstruction = Instruction(address: 4, type: .add(0, 1, 2))
        state = State()
        state.programMemory = testProgram + [fifthInstruction]
        fad.fetchAndDecode(state: state, backPressure: false)
        XCTAssertEqual(state.DecodedPCs, [0, 1, 2, 3])
        XCTAssertEqual(state.programMemory, [fifthInstruction])
        XCTAssertEqual(state.PC, 4)
        
        fad.fetchAndDecode(state: state, backPressure: false)
        XCTAssertEqual(state.DecodedPCs, [0, 1, 2, 3, 4])
        XCTAssertEqual(state.programMemory, [])
        XCTAssertEqual(state.PC, 5)
    }
    
    private func checkState(state: State, comparedTo trueState: State) {
        XCTAssertEqual(state.PC, trueState.PC)
        XCTAssertEqual(state.ExceptionPC, trueState.ExceptionPC)
        zip(state.ActiveList, trueState.ActiveList).forEach { XCTAssertEqual($0.0, $0.1) }
        XCTAssertEqual(state.BusyBitTable, trueState.BusyBitTable)
        XCTAssertEqual(state.DecodedPCs, trueState.DecodedPCs)
        XCTAssertEqual(state.Exception, trueState.Exception)
        XCTAssertEqual(state.FreeList, trueState.FreeList)
        zip(state.IntegerQueue, trueState.IntegerQueue).forEach { XCTAssertEqual($0.0, $0.1) }
        XCTAssertEqual(state.RegisterMapTable, trueState.RegisterMapTable)
        XCTAssertEqual(state.PhysicalRegisterFile, trueState.PhysicalRegisterFile)
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
