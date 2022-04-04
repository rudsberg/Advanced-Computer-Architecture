//
//  File.swift
//  
//
//  Created by Joel Rudsberg on 2022-04-03.
//

import Foundation

struct CommitUnit {
    struct Result {
        let ActiveList: [ActiveListItem]
    }
    
    func execute(state: State) -> Result {
        var state = state
        
        // Mark done or exception if existing in forwarding path
        state.ActiveList.enumerated().forEach { (i, item) in
            if let matchingForwardingPath = state.forwardingPaths.first(where: { $0.instructionPC == item.PC }) {
                state.ActiveList[i].Exception = matchingForwardingPath.exception
                state.ActiveList[i].Done = true
            }
        }
        
        // Retiring or rolling back instructions
        
        // Recycling physical registers and push them back to free list
        
        return Result(ActiveList: state.ActiveList)
    }
}
