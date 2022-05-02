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
        state.forwardingPaths.filter{ $0.value != nil }.enumerated().forEach { (i, fp) in
            state.IntegerQueue.enumerated().forEach { (i, item) in
                if (item.OpARegTag == fp.iq.DestRegister) {
                    state.IntegerQueue[i].OpAValue = fp.value!
                    state.IntegerQueue[i].OpAIsReady = true
                }
                
                if (state.IntegerQueue[i].OpCode != InstructionType.addi.rawValue && item.OpBRegTag == fp.iq.DestRegister) {
                    state.IntegerQueue[i].OpBValue = fp.value!
                    state.IntegerQueue[i].OpBIsReady = true
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
