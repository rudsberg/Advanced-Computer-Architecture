//
//  File.swift
//  
//
//  Created by Joel Rudsberg on 2022-04-03.
//

import Foundation

struct IssueUnit {
    struct Updates {
        let IntegerQueue: [IntegerQueueItem]
        let issuedInstructions: [IntegerQueueItem]
    }
    
    func issue(state: State) -> Updates {
        var state = state
        
        // Update IQ based on forwarding paths
        state.forwardingPaths.enumerated().forEach { (i, fp) in
            // Check all opA and update
            if let indexUpdate = state.IntegerQueue.firstIndex(where: { $0.OpARegTag == fp.dest }) {
                state.IntegerQueue[indexUpdate].OpAValue = fp.value!
                state.IntegerQueue[indexUpdate].OpAIsReady = true
            }
            
            // Check all opB, and not immediate value, then update
            if let indexUpdate = state.IntegerQueue.firstIndex(where: { $0.OpBRegTag == fp.dest }) {
                if (state.IntegerQueue[indexUpdate].OpCode != InstructionType.addi.rawValue) {
                    state.IntegerQueue[indexUpdate].OpBValue = fp.value!
                    state.IntegerQueue[indexUpdate].OpBIsReady = true
                }
            }
        }
        
        // Pick up to 4 ready instructions
        var readyInstructions = state.IntegerQueue.filter { $0.OpAIsReady && $0.OpBIsReady }
        let numToIssue = min(4, readyInstructions.count)
        readyInstructions = Array(readyInstructions.prefix(upTo: numToIssue))
        print("I – Issuing \(numToIssue) instructions")
        
        // Remove picked instructions from IQ
        state.IntegerQueue = state.IntegerQueue.filter { iqItem in
            !readyInstructions.contains(where: { $0.PC == iqItem.PC })
        }
                
        return Updates(IntegerQueue: state.IntegerQueue, issuedInstructions: readyInstructions)
    }
}
