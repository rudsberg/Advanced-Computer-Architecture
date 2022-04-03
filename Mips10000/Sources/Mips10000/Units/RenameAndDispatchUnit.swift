//
//  File.swift
//  
//
//  Created by Joel Rudsberg on 2022-04-02.
//

import Foundation

struct RenameAndDispatchUnit {
    func backPresssure(state: State) -> Bool {
        // TODO: unsure, "check if there are enough physical registers", always enough with 64?
        maxInstructionsRetrievable(state: state) == 0
    }
    
    func renameAndDispatch(state: State, program: [Instruction]) {
        guard !backPresssure(state: state) else { return }
        
        // Retrive max amount of instructions
        let numToRetrive = min(maxInstructionsRetrievable(state: state), min(4, state.DecodedPCs.count))
        let instructions = Array(state.DecodedPCs.prefix(upTo: numToRetrive)).map { decodedPC in
            program.first(where: { $0.pc == decodedPC })!
        }
        
        // Remove retrieved from DIR
        print("R&D – Decoding \(numToRetrive) instructions")
        state.DecodedPCs = Array(state.DecodedPCs.dropFirst(numToRetrive))
        
        // Rename up to 4 registers from DIR
        instructions.forEach { i in
            // Get first free element in free list
            let physicalRegister = state.FreeList.first!
            state.FreeList = Array(state.FreeList.dropFirst())
                        
            // Add it to active list
            let logical = i.dest
            let oldDest = state.RegisterMapTable[logical]
            let activeListItem = ActiveListItem(LogicalDestination: logical, OldDestination: oldDest, PC: i.pc)
            state.ActiveList.append(activeListItem)
            
            // Update Register Map Table
            state.RegisterMapTable[logical] = physicalRegister
            
            // Update busy bit table with register we used (physical)
            state.BusyBitTable[physicalRegister] = true
            
            // Allocate entry in integer queue
            let opAValue = value(forOp: i.opA, checkImmediateValueForInstruction: nil, state: state)
            let opBValue = value(forOp: i.opB, checkImmediateValueForInstruction: i, state: state)
            let rsItem = IntegerQueueItem(
                DestRegister: physicalRegister,
                OpAIsReady: opAValue != nil,
                OpARegTag: i.opA,
                OpAValue: opAValue ?? 0,
                OpBIsReady: opBValue != nil,
                OpBRegTag: i.opB,
                OpBValue: opBValue ?? 0,
                OpCode: i.type.rawValue,
                PC: i.pc
            )
            state.IntegerQueue.append(rsItem)
        }
        // TODO: "Observe the results of all functional units through the forwarding paths and update the physical register file as well as the Busy Bit Table." have I handled this?
    }
    
    /// Num instructions that the active list and integer queue can maximally handle
    private func maxInstructionsRetrievable(state: State) -> Int {
        let capacity = 32
        return min(capacity - state.ActiveList.count, capacity - state.IntegerQueue.count)
    }
    
    private func value(forOp operand: Register, checkImmediateValueForInstruction instruction: Instruction?, state: State) -> Int? {
        // Immediate value, in physical register or on forwarding path. If not there's no value available
        if let immediate = instruction?.opBImmediateValue {
            return immediate
        }
        
        if (!state.BusyBitTable[operand]) {
            return state.PhysicalRegisterFile[operand]
        }
        
        if let fp = state.forwardingPaths.first(where: { $0.dest == operand }) {
            return fp.value
        }
        
        return nil
    }
}
