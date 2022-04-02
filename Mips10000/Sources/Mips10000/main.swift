import Foundation


// 0. parse JSON to get the program
let program = try Parser().parseInstructions(fromFile: "test.json")
program.forEach({ print($0) })

// 1. dump the state of the reset system
let state = State()
try Logger().updateLog(with: state, documentName: "log.json", deleteExistingFile: true)

//state.PC = 1
//try Logger().updateLog(with: state, documentName: "log.json")

//let url = Bundle.main.path(forResource: "please_work", ofType: "json")!
//try "hej".write(toFile: url, atomically: true, encoding: .utf8)


// 2. the loop for cycle-by-cycle iterations.
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

