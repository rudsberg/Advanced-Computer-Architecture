import Foundation

// 0. parse JSON to get the program
let program = try Parser().parseInstructions(fromFile: "test.json")
print("======= Program =======")
program.forEach({ print($0) })

// 1. dump the state of the reset system
var state = State()
state.programMemory = program
try Logger().updateLog(with: state, documentName: "log.json", deleteExistingFile: true)

// Setup units
let fetchAndDecodeUnit = FetchAndDecodeUnit()
let renameAndDispatchUnit = RenameAndDispatchUnit()

// 2. the loop for cycle-by-cycle iterations.
while (!(state.programMemory.isEmpty && state.ActiveList.isEmpty)) {
    // Propagate
    fetchAndDecodeUnit.fetchAndDecode(
        state: state,
        backPressure: renameAndDispatchUnit.backPresssure(state: state)
    )
    renameAndDispatchUnit.renameAndDispatch(state: state, program: program)
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

