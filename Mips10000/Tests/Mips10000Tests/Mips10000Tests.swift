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
    
    func testALU() {
        var alu = ALU(id: 1)
        var item1 = ALUItem(iq: .mock)
        item1.iq.OpAValue = 6
        item1.iq.OpBValue = 11
        item1.iq.OpCode = "add"
        
        var res = alu.execute(newInstruction: item1)
        XCTAssertNil(res)
        
        var item2 = ALUItem(iq: .mock)
        item2.iq.OpAValue = 10
        item2.iq.OpBValue = 3
        item2.iq.OpCode = "sub"
        
        res = alu.execute(newInstruction: item2)
        XCTAssertEqual(res?.computedValue, 6+11)
        XCTAssertEqual(res?.exception, false)
        
        res = alu.execute(newInstruction: nil)
        XCTAssertEqual(res?.computedValue, 10-3)
        XCTAssertEqual(res?.exception, false)
        
        res = alu.execute(newInstruction: nil)
        XCTAssertNil(res)
    }
    
    func testTestProgram() throws {
        // Run simulation
        let log = "testTestProgram.json"
        let config = RunConfig(logFile: log, runUpToCycle: 4)
        try App(config: config).run()
        
        // From log, retrieve [State] and compare it to oracle
        let producedStates = try fileIO.read([State].self, documentName: log)
        
        // TODO: when all steps implemented XCTAssertEqual(producedStates.count, trueState.count)
        var cycle = 0
        zip(producedStates, trueState).forEach {
            checkState(state: $0, comparedTo: $1, cycle: cycle)
            cycle += 1
        }
    }
    
    private func checkState(state: State, comparedTo trueState: State, cycle: Int? = nil) {
        if let cycle = cycle {
            print("----------- Verifying cycle \(cycle)")
        }
        XCTAssertEqual(state.PC, trueState.PC)
        XCTAssertEqual(state.ExceptionPC, trueState.ExceptionPC)
        zip(state.ActiveList, trueState.ActiveList).forEach { XCTAssertEqual($0.0, $0.1) }
        XCTAssertEqual(state.ActiveList.count, trueState.ActiveList.count)
        XCTAssertEqual(state.BusyBitTable, trueState.BusyBitTable)
        XCTAssertEqual(state.DecodedPCs, trueState.DecodedPCs)
        XCTAssertEqual(state.Exception, trueState.Exception)
        XCTAssertEqual(state.FreeList, trueState.FreeList)
        zip(state.IntegerQueue, trueState.IntegerQueue).forEach { XCTAssertEqual($0.0, $0.1) }
        XCTAssertEqual(state.IntegerQueue.count, trueState.IntegerQueue.count)
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

extension IntegerQueueItem {
    static var mock: IntegerQueueItem {
        .init(DestRegister: 1, OpAIsReady: true, OpARegTag: 0, OpAValue: 0, OpBIsReady: true, OpBRegTag: 0, OpBValue: 10, OpCode: "add", PC: 0)
    }
}
