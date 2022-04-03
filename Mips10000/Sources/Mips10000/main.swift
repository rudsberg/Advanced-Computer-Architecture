import Foundation

struct RunConfig {
    typealias Cycle = Int
    let logFile: String
    var numCyclesToRun: Cycle? = nil
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
        let state = State()
        state.programMemory = program
        try Logger().updateLog(with: state, documentName: config.logFile, deleteExistingFile: true)

        // Setup units
        let fetchAndDecodeUnit = FetchAndDecodeUnit()
        let renameAndDispatchUnit = RenameAndDispatchUnit()

        // 2. the loop for cycle-by-cycle iterations.
        var cycleCounter = 0
        while (!(state.programMemory.isEmpty && state.ActiveList.isEmpty)) {
            if (config.numCyclesToRun != nil && cycleCounter > config.numCyclesToRun!) {
                break
            }
            
            // Propagate
            print("======= Starting cycle \(cycleCounter)")
            fetchAndDecodeUnit.fetchAndDecode(
                state: state,
                backPressure: renameAndDispatchUnit.backPresssure(state: state)
            )
            renameAndDispatchUnit.renameAndDispatch(state: state, program: program)
            
            // TODO: latch
            
            // Dump the state
            // TODO: log file too large!
            try Logger().updateLog(with: state, documentName: config.logFile)
            
            // For debugging purposes
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

let config = RunConfig(logFile: "output2.json", numCyclesToRun: 2)
try App(config: config).run()

print("done")
