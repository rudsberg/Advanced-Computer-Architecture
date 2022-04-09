# Advanced-Computer-Architecture

## How to run & Design HW1

### How to run it

The implementation is written in Swift. According to Louis Coulon, the grader will have installed swift through [here](https://www.swift.org/download/). 


The top level of the extracted zip file contains a file, `AllInOneFile.swift` and a folder `Mips10000`. The folder contains the project as it was created in Xcode, but to simplify for the grader (assuming Xcode is not installed), the `AllInOneFile.swift` contains all source code packaged into one file. **This is the file to run**. Here is an example run:

```
swift AllInOneFile.swift /Users/joelrudsberg/Desktop/test_hw1 test.json test-log.json
```

The arguments are (i) the path to the folder where the program resides and where the log file will be saved, (ii) the program to run (must be in the folder), and (iii) the output log file. **The folder must be created before running**.

## How to review the files
Review the files in the folder `Mips10000`, because here the code is separated into files. Or, even easier, through the [repository](https://github.com/rudsberg/Advanced-Computer-Architecture). 

### Design

`App.swift` is the main actor that instantiates the components, invokes the components, and updates the `State.swift`. The State contains all data structures as outlined by the Assignment, the forwarding paths, pipeline register 3, and the remaining program to run. 

#### Components
One struct has been created for each component: `FetchAndDecodeUnit.swift`, `RenameAndDispatchUnit.swift`, `IssueUnit.swift`, `ALU.swift`, and `CommitUnit.swift`.  Each has an appropriate function representing its main responsibility. All return a Result struct that is unique for each, which exactly represent the fields of the State that may have been modified. Most components operate solely on a data structure and those can simply be set in the latch stage. However, when multiple components operate on the same data, then the Result struct contain a closure representing the action to perform. This is a way to cleanly merge updates done by several components. For instance, both the R&D and F&D unit operate on DecodedPCs, thus they both return a closure

 `([Int]) -> [Int]` 

which represent a transformation of the DecodedPC. F&D appends entries `` while R&D removes entries. The actions are performed in the latch stage. 

```
let fetchAndDecodeAction: ([Int]) -> [Int] = { $0 + fetched.map { $0.pc } }
let decodedPCAction: ([Int]) -> [Int] = { Array($0.dropFirst(numToRetrive)) }
// Merged in main loop:
state.DecodedPCs = radUpdates.DecodedPCAction(fadUpdates.DecodedPCAction(state.DecodedPCs))
```

The structure of a pure function and a Result type creates high separation (no component can operate on wrong part of the state) which reduces risk for error and increase testability. 

#### The Main Loop 
Naturally, `App.swift` contains the main application loop that for each iteration represent a cycle. First, the exception mode handling is performed if in exception. Then follows the Propagation stage, starting with the ALUs running to ensure that potential updates to the forwarding paths are broadcasted as the other components execute. The components operate on `oldState`, which is injected to the components. The Result of all components are collected and updated in the Latch stage, with the exception for structures that need immediate updates (integer queue, active list and free list), these are updated and injected in the same cycle. 

In Latch all structures are updated either directly by setting the value or by applying the closure transformations. Lastly, the commit updates are checked if there is an Exception, and in that case runs F&D which updates the DecodedPC and PC, and the ExceptionPC is set by taking the top-most element in the free list. Finally, if Exception is true and active list is empty, Exception is set to false and program is exited. 

