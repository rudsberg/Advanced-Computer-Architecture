import Foundation

struct RunConfig {
    typealias Cycle = Int
    let logFile: String
    var runUpToCycle: Cycle? = nil
}

struct App {
    let config: RunConfig
    
    func run() throws {
        // Setup environ
        // 0. parse JSON to get the program
        let program = try Parser().parseInstructions(fromFile: "test.json")
        print("======= Program =======")
        program.forEach({ print($0) })

        // 1. dump the state of the reset system
        var state = State()
        state.programMemory = program
        try Logger().updateLog(with: state, documentName: config.logFile, deleteExistingFile: true)

        // Setup units
        let fetchAndDecodeUnit = FetchAndDecodeUnit()
        let renameAndDispatchUnit = RenameAndDispatchUnit()
        let issueUnit = IssueUnit()
        var ALUs = (0...4).map { ALU(id: $0) }
        let commitUnit = CommitUnit()
        
        // 2. the loop for cycle-by-cycle iterations.
        var cycleCounter = 1
        while (true /* TODO: Quits prematurely, need one more cycle !(state.programMemory.isEmpty && state.ActiveList.isEmpty) */ ) {
            if (config.runUpToCycle != nil && cycleCounter > config.runUpToCycle!) {
                break
            }
            
            // MARK: - Propagate
            // Make copy of current state which will be consumed & updated by units EXCEPT
            // those units that can access data structures that can be updated and read in the same
            // cycle -> Integer Queue, Active List, Free List
            print("\n======= Starting cycle \(cycleCounter)")
            // Unit READS old state, UPDATES real state
            
            // Run ALU action first so forwarding paths are broadcasted before other units execute
            var aluResults = [ALUItem]()
            ALUs.enumerated().forEach { (i, alu) in
                let instructionToProcess = state.pipelineRegister3.count > i ? state.pipelineRegister3[i] : nil
                if let aluRes = ALUs[i].execute(newInstruction: instructionToProcess) {
                    aluResults.append(aluRes)
                }
            }
            // Broadcast alu result on forwarding paths
            state.forwardingPaths = aluResults
                .map { .init(dest: $0.iq.DestRegister, value: $0.computedValue!, exception: $0.exception) }
            
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
            state.ActiveList = commitUpdates.ActiveList
            
            // TODO: exceptions
    
            
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
            
            
            // MARK: - Dump the state
            // TODO: log file too large!
            try Logger().updateLog(with: state, documentName: config.logFile)
            
            // For debugging purposes
            print("======= Ending cycle \(cycleCounter)\n")
            cycleCounter += 1
            
            // TODO: remove for final submission
            if (cycleCounter >= 100) {
                fatalError("Stuck in while loop")
            }
        }
        // while(not (noInstruction() and activeListIsEmpty())){
            // do propagation
            // if you have multiple modules, propagate each of them
            // propagate();
            // advance clock, start next cycle
            // latch();
            // dump the state
            // dumpStateIntoLog();
        // }
        // 3. save the output JSON log
        // saveLog();
    }
}

let config = RunConfig(logFile: "output3.json", runUpToCycle: 3)
try App(config: config).run()

print("done")
