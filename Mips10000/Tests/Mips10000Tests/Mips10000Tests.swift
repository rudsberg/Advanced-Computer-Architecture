import XCTest
import class Foundation.Bundle
@testable import Mips10000

final class Mips10000Tests: XCTestCase {
    private let fileIO = FileIOController()
    
    func testStartupState() throws {
        // Write initial state
        let initialState = State()
        try Logger().updateLog(with: initialState, documentName: "test_startup_state.json", deleteExistingFile: true)
        
        let trueInitialState = try fileIO.read([State].self, documentName: "test_result.json").first!
        
        checkState(state: initialState, comparedTo: trueInitialState)
    }
    
    func testFetchAndDecodeUnit() throws {
        let testProgram = try Parser().parseInstructions(fromFile: "test.json")
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
    
    func testMulProgram() throws {
        /*
         [
             "addi x0 x0 2",    -- x0 <- 2
             "addi x1 x1 3",    -- x1 <- 3
             "mulu x2 x0 x1"    -- x2 <- 2*3, RAW dependency
         ]
         */
        let logFile = "result5-simple-mul.json"
        let config = RunConfig(programFile: "test5-simple-mul.json", logFile: logFile, runUpToCycle: nil)
        try App(config: config).run()
        let producedStates = try fileIO.read([State].self, documentName: logFile)
        
        // Cycle 3 mulu should be waiting in the Integer Queue for the two add instructions
        let cycle3 = producedStates[3]
        var mulInstr = cycle3.IntegerQueue.first
        XCTAssertEqual(cycle3.IntegerQueue.count, 1)
        XCTAssertEqual(mulInstr?.OpAIsReady, false)
        XCTAssertEqual(mulInstr?.OpBIsReady, false)
        XCTAssertEqual(mulInstr?.OpCode, InstructionType.mulu.rawValue)
        
        // Same for cycle 4
        let cycle4 = producedStates[4]
        mulInstr = cycle4.IntegerQueue.first
        XCTAssertEqual(cycle4.IntegerQueue.count, 1)
        XCTAssertEqual(mulInstr?.OpAIsReady, false)
        XCTAssertEqual(mulInstr?.OpBIsReady, false)
        XCTAssertEqual(mulInstr?.OpCode, InstructionType.mulu.rawValue)
        
        // Cycle 5 now should it be processed
        let cycle5 = producedStates[5]
        XCTAssertEqual(cycle5.IntegerQueue.count, 0)
        
        // Verify last state
        let lastState = producedStates.last!
        XCTAssertEqual(lastState.PhysicalRegisterFile[lastState.RegisterMapTable[0]], 2)
        XCTAssertEqual(lastState.PhysicalRegisterFile[lastState.RegisterMapTable[1]], 3)
        XCTAssertEqual(lastState.PhysicalRegisterFile[lastState.RegisterMapTable[2]], 2*3)
    }
    
    func testException() throws {
        // Exception program
        // TODO: mul verkar inte spara 30 i x2!
        /*
         [
         "addi x0 x1 10",   -- load 10 into x0
         "addi x1 x2 3",    -- load 3 into x1
         "mulu x2 x0 x1",   -- x2 <- 10 * 3
         "divu x0 x1 x13",  -- Exception
         "addi x0 x5 20",   -- These adds should not be executed (from PC=4)
         "addi x1 x5 21",
         "addi x2 x5 22",
         ]
         */
        
        // Run program
        //        let logFile = "result4.json"
        //        let config = RunConfig(programFile: "test4.json", logFile: logFile, runUpToCycle: nil)
        //        try App(config: config).run()
        //        let producedStates = try fileIO.read([State].self, documentName: logFile)
        //
        //        // Verify what we know must be true
        //        XCTAssert(producedStates.allSatisfy { $0.PC != 4 || $0.PC != 5 || $0.PC != 6 }) // TODO: right?
        //        let lastState = producedStates.last!
        //        XCTAssertEqual(lastState.PhysicalRegisterFile[0], 10)
        //        XCTAssertEqual(lastState.PhysicalRegisterFile[1], 3)
        //        XCTAssertEqual(lastState.PhysicalRegisterFile[2], 30)
        //        XCTAssertEqual(lastState.PhysicalRegisterFile.reduce(0, +), 43)
        //        XCTAssert(producedStates.contains(where: { $0.Exception && $0.ExceptionPC == 65536 }))
        //        XCTAssert(producedStates.contains(where: { $0.ExceptionPC == 3 }))
    }
    
    func testTestProgram() throws {
        try verifyProgram(
            saveOutputInLog: "testTestProgram.json",
            programFile: "test.json",
            oracleFile: "test_result.json"
        )
    }
    
    //    func testTestProgram1() throws {
    //        try verifyProgram(
    //            saveOutputInLog: "test1output.json",
    //            programFile: "test1.json",
    //            oracleFile: "result1.json"
    //        )
    //    }
    //
    //    func testTestProgram2() throws {
    //        try verifyProgram(
    //            saveOutputInLog: "test2output.json",
    //            programFile: "test2.json",
    //            oracleFile: "result2.json"
    //        )
    //    }
    //
    //    func testTestProgram3() throws {
    //        try verifyProgram(
    //            saveOutputInLog: "test3output.json",
    //            programFile: "test3.json",
    //            oracleFile: "result3.json"
    //        )
    //    }
    
    private func verifyProgram(saveOutputInLog log: String, programFile: String, oracleFile: String) throws {
        // Run simulation
        let config = RunConfig(programFile: programFile, logFile: log, runUpToCycle: nil)
        try App(config: config).run()
        
        // Load oracle
        let oracle = try fileIO.read([State].self, documentName: oracleFile)
        
        // From produced log, retrieve [State]
        let producedStates = try fileIO.read([State].self, documentName: log)
        
        // Num produced states should be equal to num oracle states
        XCTAssertEqual(producedStates.count, oracle.count)
        
        // Verify cycle per cycle
        var cycle = 0
        zip(producedStates, oracle).forEach {
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
