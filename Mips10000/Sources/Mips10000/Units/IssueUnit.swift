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
        // TODO: unsure about filtering value
        state.forwardingPaths.filter{ $0.value != nil }.enumerated().forEach { (i, fp) in
            // Check all opA and update
            // TODO: dest of ALU operation may been overwritten, how do I retrieve the original logical value?
            let logical = state.RegisterMapTable.firstIndex(where: { $0 == fp.iq.DestRegister })
            if let indexUpdate = state.IntegerQueue.firstIndex(where: { $0.OpARegTag == logical }) {
                state.IntegerQueue[indexUpdate].OpAValue = fp.value!
                state.IntegerQueue[indexUpdate].OpAIsReady = true
            }
            
            // Check all opB, and not immediate value, then update
            if let indexUpdate = state.IntegerQueue.firstIndex(where: { $0.OpBRegTag == logical }) {
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
