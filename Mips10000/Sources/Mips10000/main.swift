import Foundation

struct RunConfig {
    typealias Cycle = Int
    let programFile: String
    let logFile: String
    var runUpToCycle: Cycle? = nil
}

struct App {
    let config: RunConfig
    
    func run() throws {
        // Setup environ
        // 0. parse JSON to get the program
        let program = try Parser().parseInstructions(fromFile: config.programFile)
        print("======= Program =======")
        program.forEach({ print($0) })

        // 1. dump the state of the reset system
        var state = State()
        state.programMemory = program
        try Logger().updateLog(with: state, documentName: config.logFile, deleteExistingFile: true)

        // Setup units
        var fetchAndDecodeUnit = FetchAndDecodeUnit()
        let renameAndDispatchUnit = RenameAndDispatchUnit()
        let issueUnit = IssueUnit()
        var ALUs = (0...4).map { ALU(id: $0) }
        let commitUnit = CommitUnit()
        
        // 2. the loop for cycle-by-cycle iterations.
        var cycleCounter = 1
        while (!(state.programMemory.isEmpty && state.ActiveList.isEmpty) || cycleCounter <= 2) {
            if (config.runUpToCycle != nil && cycleCounter > config.runUpToCycle!) {
                break
            }
            
            print("\n======= Starting cycle \(cycleCounter)")
            
            // MARK: - Exception Recovery - part of the Commit Stage
            if (state.Exception) {
                // Check if rollback & recovery is completed
                if (state.ActiveList.isEmpty) {
                    return
                }
                
                // Update ExceptionPC (if not done already) - must be top of the active list
                if (state.ExceptionPC == 0) {
                    let exceptionInstruction = state.ActiveList.sorted(by: { $0.PC < $1.PC }).first!
                    assert(exceptionInstruction.Exception)
                    state.ExceptionPC = exceptionInstruction.PC
                }
                
                // Reset the integer queue and execution stage
                state.IntegerQueue.removeAll()
                state.pipelineRegister3.removeAll()
                ALUs.enumerated().forEach { (i, _) in ALUs[i].clearCurrentInstruction() }
                
                // Execute CU which will enter recovery mode
                let recovery = commitUnit.execute(state: state)
                state.ActiveList = recovery.ActiveList
                state.BusyBitTable = recovery.BusyBitTable
                state.RegisterMapTable = recovery.RegisterMapTable
                state.FreeList = recovery.FreeList
            }
            
            // MARK: - Propagate
            // Run ALU action first so forwarding paths are broadcasted before other units execute
            var aluResults = [ALUItem]()
            ALUs.enumerated().forEach { (i, alu) in
                let instructionToProcess = state.pipelineRegister3.count > i ? state.pipelineRegister3[i] : nil
                if let aluRes = ALUs[i].execute(newInstruction: instructionToProcess) {
                    aluResults.append(aluRes)
                }
            }
            // Broadcast alu result on forwarding paths
            state.forwardingPaths = aluResults.map { .init(value: $0.computedValue, exception: $0.exception, iq: $0.iq) }

            let oldState = state
            let fadUpdates = fetchAndDecodeUnit.fetchAndDecode(
                state: oldState,
                backPressure: renameAndDispatchUnit.backPresssure(state: oldState)
            )
            let radUpdates = renameAndDispatchUnit.renameAndDispatch(
                state: oldState,
                program: program
            )
            // state.IntegerQueue = radUpdates.IntegerQueue TODO: double check current update logic with TA
            state.ActiveList = radUpdates.ActiveList
            state.FreeList = radUpdates.FreeList
            let iUpdates = issueUnit.issue(state: oldState)
            
            // Propagate immediate changes to active list to commit unit
            var oldStatePlusImmediateChanges = oldState
            oldStatePlusImmediateChanges.ActiveList = state.ActiveList
            oldStatePlusImmediateChanges.FreeList = state.FreeList
            let commitUpdates = commitUnit.execute(state: oldStatePlusImmediateChanges)
                        
            // MARK: - Latch -> submit all changes that are not immediate (eg integer queue)
            state.programMemory = fadUpdates.programMemory
            state.PC = fadUpdates.PC
            state.DecodedPCs = radUpdates.DecodedPCAction(fadUpdates.DecodedPCAction(state.DecodedPCs))
            state.RegisterMapTable = radUpdates.RegisterMapTable
            state.BusyBitTable = radUpdates.BusyBitTable
            state.PhysicalRegisterFile = radUpdates.PhysicalRegisterFile
            state.IntegerQueue = iUpdates.IntegerQueue
            state.IntegerQueue.append(contentsOf: radUpdates.IntegerQueueItemsToAdd)
            state.pipelineRegister3 = iUpdates.issuedInstructions.map { ALUItem(iq: $0) }
            state.FreeList = commitUpdates.FreeList
            state.ActiveList = commitUpdates.ActiveList
            
            // Check for exception, Fetch And Decode should be notified same cycle to update PC and clear DIR
            if (commitUpdates.Exception) {
                state.Exception = true

                let fadExceptionUpdates = fetchAndDecodeUnit.onException(state: state)
                state.DecodedPCs = fadExceptionUpdates.DecodedPCAction(state.DecodedPCs)
                state.PC = fadExceptionUpdates.PC
            }
            
            // MARK: - Dump the state
            try Logger().updateLog(with: state, documentName: config.logFile)
            
            // For debugging purposes
            print("======= Ending cycle \(cycleCounter)\n")
            cycleCounter += 1
            if (cycleCounter > 100) {
                // TODO: remove for final submission
                fatalError("Likely an infite loop")
            }
        }
    }
}

let config = RunConfig(
    programFile: "test2.json",
    logFile: "test2baby.json",
    runUpToCycle: 100
)

try App(config: config).run()

