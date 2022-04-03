import Foundation

struct RunConfig {
    typealias Cycle = Int
    let logFile: String
    var runUpToCycle: Cycle? = nil
}

typealias StateMutation = () -> State

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
            let oldState = state
            let fadUpdates = fetchAndDecodeUnit.fetchAndDecode(
                state: oldState,
                backPressure: renameAndDispatchUnit.backPresssure(state: oldState)
            )
            let radUpdates = renameAndDispatchUnit.renameAndDispatch(
                state: oldState,
                program: program
            )
            state.IntegerQueue = radUpdates.IntegerQueue
            state.ActiveList = radUpdates.ActiveList
            state.FreeList = radUpdates.FreeList
        
            
            // MARK: - Latch -> submit all changes that are not immediate (eg integer queue)
            state.programMemory = fadUpdates.programMemory
            state.DecodedPCs = radUpdates.DecodedPCAction(fadUpdates.DecodedPCAction(state.DecodedPCs))
            state.PC = fadUpdates.PC
            state.RegisterMapTable = radUpdates.RegisterMapTable
            state.BusyBitTable = radUpdates.BusyBitTable
            
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

let config = RunConfig(logFile: "output3.json", runUpToCycle: 2)
try App(config: config).run()

print("done")
