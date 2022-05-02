//
//  File.swift
//  
//
//  Created by Joel Rudsberg on 2022-04-02.
//

import Foundation

struct FetchAndDecodeUnit {
    private var inException = false
    
    struct Updates {
        var programMemory: [Instruction]
        var DecodedPCAction: ([Int]) -> [Int]
        var PC: Int
    }
        
    func fetchAndDecode(state: State, backPressure: Bool) -> Updates {
        var state = state
        guard !backPressure, !inException else {
            return Updates(programMemory: state.programMemory, DecodedPCAction: { $0 }, PC: state.PC)
        }
        
        // Fetch up to 4 instructions from program memory
        let numToFetch = state.programMemory.count > 4 ? 4 : state.programMemory.count
        print("F&D - Fetching \(numToFetch) instructions")
        let fetched = state.programMemory.prefix(upTo: numToFetch)
        state.programMemory = Array(state.programMemory.dropFirst(numToFetch))
        
        // Pass fetched instructions to Rename and Dispatch stage
        let decodedPCAction: ([Int]) -> [Int] = { $0 + fetched.map { $0.pc } }
        // state.DecodedPCs = state.DecodedPCs + fetched.map { $0.pc }
        
        // Update PC
        state.PC += fetched.count
        
        return Updates(
            programMemory: state.programMemory,
            DecodedPCAction: decodedPCAction,
            PC: state.PC
        )
    }
    
    mutating func onException(state: State) -> Updates {
        var updates = Updates(programMemory: state.programMemory, DecodedPCAction: { $0 }, PC: state.PC)
        
        // Halt all future fetching
        inException = true
        
        // Set PC to 0x10000
        updates.PC = 65536
        
        // Clear DIR register
        updates.DecodedPCAction = { _ in [Int]() }
        
        return updates
    }
}
