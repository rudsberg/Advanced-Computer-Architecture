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
        var Exception: Bool
    }
    
    func execute(state: State) -> Result {
        var result = Result(ActiveList: state.ActiveList, FreeList: state.FreeList, Exception: state.Exception)
        
        // Mark done or exception if existing in forwarding path
        state.ActiveList.enumerated().forEach { (i, item) in
            if let matchingForwardingPath = state.forwardingPaths.first(where: { $0.instructionPC == item.PC }) {
                result.ActiveList[i].Exception = matchingForwardingPath.exception
                result.ActiveList[i].Done = true
            }
        }
        
        // TODO: Retiring or rolling back instructions
        
        // Find instructions to retire/commit
        let intructionsToCommit = state.ActiveList.enumerated().prefix(while: { (i, item) in
            let exception = item.Exception
            if (exception) {
                result.Exception = true
            }
            return i < 4 && item.Done && !exception
        }).map { $0.element }
        
        // Remove instructions from active list that will be commited
        intructionsToCommit.forEach { instruction in
            result.ActiveList = result.ActiveList.filter { $0.PC != instruction.PC }
        }
        
        // Free physical registers
        result.FreeList.append(contentsOf: intructionsToCommit.map { $0.LogicalDestination })
        
        return result
    }
}
