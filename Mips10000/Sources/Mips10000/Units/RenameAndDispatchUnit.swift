//
//  File.swift
//  
//
//  Created by Joel Rudsberg on 2022-04-02.
//

import Foundation

struct RenameAndDispatchUnit {
    struct Updates {
        var DecodedPCAction: ([Int]) -> [Int]
        var FreeList: [Int]
        var ActiveList: [ActiveListItem]
        var RegisterMapTable: [Int]
        var BusyBitTable: [Bool]
        var PhysicalRegisterFile: [Int]
        var IntegerQueueItemsToAdd: [IntegerQueueItem]
    }
    
    func backPresssure(state: State) -> Bool {
        // TODO: unsure, "check if there are enough physical registers", always enough with 64?
        maxInstructionsRetrievable(state: state) == 0
    }
    
    func renameAndDispatch(state: State, program: [Instruction]) -> Updates {
        var state = state
        guard !backPresssure(state: state) else {
            return Updates(
                DecodedPCAction: { $0 },
                FreeList: state.FreeList,
                ActiveList: state.ActiveList,
                RegisterMapTable: state.RegisterMapTable,
                BusyBitTable: state.BusyBitTable,
                PhysicalRegisterFile: state.PhysicalRegisterFile,
                IntegerQueueItemsToAdd: []
            )
        }
        
        // Update the physical register file as well as the Busy Bit Table
        state.forwardingPaths.forEach {
            state.BusyBitTable[$0.dest] = false
            state.PhysicalRegisterFile[$0.dest] = $0.value
        }
        
        // Retrive max amount of instructions
        let numToRetrive = min(maxInstructionsRetrievable(state: state), min(4, state.DecodedPCs.count))
        let instructions = Array(state.DecodedPCs.prefix(upTo: numToRetrive)).map { decodedPC in
            program.first(where: { $0.pc == decodedPC })!
        }
        
        // Remove retrieved from DIR
        print("R&D – Decoding \(numToRetrive) instructions")
        let decodedPCAction: ([Int]) -> [Int] = { Array($0.dropFirst(numToRetrive)) }
        
        // Rename up to 4 registers from DIR
        var IntegerQueueItemsToAdd = [IntegerQueueItem]()
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
                OpARegTag: i.opA, // TODO: 'when value of operand A is available within integer queue we don't care of this field' 
                OpAValue: opAValue ?? 0,
                OpBIsReady: opBValue != nil,
                OpBRegTag: i.opBImmediateValue != nil ? 0 : i.opB, // Fallback to 0 for immediate value to conform to test suite
                OpBValue: opBValue ?? 0,
                OpCode: i.type.rawValue,
                PC: i.pc
            )
            IntegerQueueItemsToAdd.append(rsItem)
        }
        
        return Updates(
            DecodedPCAction: decodedPCAction,
            FreeList: state.FreeList,
            ActiveList: state.ActiveList,
            RegisterMapTable: state.RegisterMapTable,
            BusyBitTable: state.BusyBitTable,
            PhysicalRegisterFile: state.PhysicalRegisterFile,
            IntegerQueueItemsToAdd: IntegerQueueItemsToAdd
        )
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
