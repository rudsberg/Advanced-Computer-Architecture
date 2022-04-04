//
//  File.swift
//  
//
//  Created by Joel Rudsberg on 2022-04-03.
//

import Foundation

struct CommitUnit {
    struct Result {
        var ActiveList: [ActiveListItem]
        var FreeList: [Int]
        // Below fields for case of exception
        var Exception: Bool
        var PC: Int
        var ExceptionPC: Int
    }
    
    func execute(state: State) -> Result {
        var result = Result(
            ActiveList: state.ActiveList,
            FreeList: state.FreeList,
            Exception: state.Exception,
            PC: state.PC,
            ExceptionPC: state.ExceptionPC
        )
        
        // Mark done or exception if existing in forwarding path
        state.ActiveList.enumerated().forEach { (i, item) in
            if let matchingForwardingPath = state.forwardingPaths.first(where: { $0.instructionPC == item.PC }) {
                result.ActiveList[i].Exception = matchingForwardingPath.exception
                result.ActiveList[i].Done = true
            }
        }
        
        // TODO: Retiring or rolling back instructions
        
        // Find instructions to retire/commit - crucially using 'state' and not 'result' due to timing
        let intructionsToCommit = state.ActiveList.enumerated().prefix(while: { (i, item) in
            // First 4 and done
            let passes = i < 4 && item.Done
            
            // Check if exception
            let exception = item.Exception
            if (exception) {
                // TODO: ask TA if OK to do like this with hex
                result.Exception = true
                result.PC = 65536 // 0x10000
                result.ExceptionPC = item.PC
            }
            
            return passes && !exception
        }).map { $0.element }
        
        assert(intructionsToCommit.count <= 4)
        
        // If exception found, next instruction after 'intructionsToCommit' will be the exception
        if (result.Exception) {
            let exceptionInstruction = state.ActiveList[intructionsToCommit.count]
            assert(exceptionInstruction.Exception)
        }
        
        // Remove instructions from active list that will be commited
        intructionsToCommit.forEach { instruction in
            result.ActiveList = result.ActiveList.filter { $0.PC != instruction.PC }
        }
        
        // Free physical registers
        result.FreeList.append(contentsOf: intructionsToCommit.map { $0.LogicalDestination })
        
        return result
    }
}
