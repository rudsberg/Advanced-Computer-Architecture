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
        
        // Mark done or exception depending on result on forwarding paths
        state.forwardingPaths.forEach {
            state.ActiveList[$0.dest].Done = true
            state.ActiveList[$0.dest].Exception = $0.exception
        }
        
        // Retiring or rolling back instructions
        
        // Recycling physical registers and push them back to free list
        
        return Result(ActiveList: state.ActiveList)
    }
}
