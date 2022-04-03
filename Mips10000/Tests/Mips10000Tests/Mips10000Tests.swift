import XCTest
import class Foundation.Bundle
@testable import Mips10000

final class Mips10000Tests: XCTestCase {
    private let fileIO = FileIOController()
    private var testProgram: [Instruction] {
        try! Parser().parseInstructions(fromFile: "test.json")
    }
    private var trueState: [State] {
        try! fileIO.read([State].self, documentName: "test_result.json")
    }
    
    func testStartupState() throws {
        // Write initial state
        let initialState = State()
        try Logger().updateLog(with: initialState, documentName: "test_startup_state.json", deleteExistingFile: true)
        
        let trueInitialState = trueState.first!
    
        checkState(state: initialState, comparedTo: trueInitialState)
    }
    
    func testFetchAndDecodeUnit() throws {
        let fad = FetchAndDecodeUnit()
        var state = State()
        state.programMemory = testProgram
        
        // Fetch&Decode regular test program
        var res = fad.fetchAndDecode(state: state, backPressure: true)
        XCTAssertEqual(res.DecodedPCAction(state.DecodedPCs), [])
        XCTAssertEqual(res.programMemory, testProgram)
        XCTAssertEqual(res.PC, 0)
        
        res = fad.fetchAndDecode(state: state, backPressure: false)
        XCTAssertEqual(res.DecodedPCAction(state.DecodedPCs), [0, 1, 2, 3])
        XCTAssertEqual(res.programMemory, [])
        XCTAssertEqual(res.PC, 4)
        
        // Test with one more instruction (5)
        let fifthInstruction = Instruction(pc: 4, dest: 0, opA: 1, opB: 2, type: .add)
        state = State()
        state.programMemory = testProgram + [fifthInstruction]
        res = fad.fetchAndDecode(state: state, backPressure: false)
        XCTAssertEqual(res.DecodedPCAction(state.DecodedPCs), [0, 1, 2, 3])
        XCTAssertEqual(res.programMemory, [fifthInstruction])
        XCTAssertEqual(res.PC, 4)
        
        // Must update state for next state update
        state.programMemory = res.programMemory
        state.DecodedPCs = res.DecodedPCAction(state.DecodedPCs)
        state.PC = res.PC
        
        res = fad.fetchAndDecode(state: state, backPressure: false)
        XCTAssertEqual(res.DecodedPCAction(state.DecodedPCs), [0, 1, 2, 3, 4])
        XCTAssertEqual(res.programMemory, [])
        XCTAssertEqual(res.PC, 5)
    }
    
    func testTestProgram() throws {
        // Run simulation
        let log = "testTestProgram.json"
        let config = RunConfig(logFile: log, runUpToCycle: 2)
        try App(config: config).run()
        
        // From log, retrieve [State] and compare it to oracle
        let producedStates = try fileIO.read([State].self, documentName: log)
        
        // TODO: when all steps implemented XCTAssertEqual(producedStates.count, trueState.count)
        zip(producedStates, trueState).forEach { checkState(state: $0, comparedTo: $1) }
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
