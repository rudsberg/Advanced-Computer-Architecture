import Foundation

struct RunConfig {
    typealias Cycle = Int
    let numCyclesToRun: Cycle
    var callbackEachCycle: ((Cycle, State) -> Void)? = nil
}

struct App {
    let config: RunConfig
    
    func run(config: RunConfig? = nil) throws {
        let logFile = "log.json"
        // 0. parse JSON to get the program
        let program = try Parser().parseInstructions(fromFile: "test.json")
        print("======= Program =======")
        program.forEach({ print($0) })

        // 1. dump the state of the reset system
        var state = State()
        state.programMemory = program
        try Logger().updateLog(with: state, documentName: logFile, deleteExistingFile: true)

        // Setup units
        let fetchAndDecodeUnit = FetchAndDecodeUnit()
        let renameAndDispatchUnit = RenameAndDispatchUnit()

        // 2. the loop for cycle-by-cycle iterations.
        var cycleCounter = 0
        while (!(state.programMemory.isEmpty && state.ActiveList.isEmpty) || !(config != nil && config!.numCyclesToRun == cycleCounter)) {
            // Propagate
            fetchAndDecodeUnit.fetchAndDecode(
                state: state,
                backPressure: renameAndDispatchUnit.backPresssure(state: state)
            )
            renameAndDispatchUnit.renameAndDispatch(state: state, program: program)
            
            // TODO: latch
            
            // Dump the state
            try Logger().updateLog(with: state, documentName: logFile)
            
            // For debugging purposes
            if config != nil {
                cycleCounter += 1
                config?.callbackEachCycle?(cycleCounter, state)
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

let config = RunConfig(numCyclesToRun: 1, callbackEachCycle: nil)
try App(config: config).run()
