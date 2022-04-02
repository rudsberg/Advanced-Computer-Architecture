//
//  File.swift
//  
//
//  Created by Joel Rudsberg on 2022-04-02.
//

import Foundation

struct FetchAndDecodeUnit {
    func fetchAndDecode(state: State, backPressure: Bool) {
        guard !backPressure else { return }
        
        // Fetch up to 4 instructions from program memory
        let numToFetch = state.programMemory.count > 4 ? 4 : state.programMemory.count
        let fetched = state.programMemory.prefix(upTo: numToFetch)
        state.programMemory = Array(state.programMemory.dropFirst(numToFetch))
        
        // Pass fetched instructions to Rename and Dispatch stage
        state.DecodedPCs = state.DecodedPCs + fetched.map { $0.pc }
        
        // Update PC
        state.PC += fetched.count
    }
}
