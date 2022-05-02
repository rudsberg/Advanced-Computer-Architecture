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
        // Below fields for case of exception
        var Exception: Bool
        var PC: Int
        var ExceptionPC: Int
        // For rollback & FreeList
        var RegisterMapTable: [Int]
        var BusyBitTable: [Bool]
    }
    
    func execute(state: State) -> Result {
        var state = state
        guard !state.Exception else {
            return exceptionRecovery(state: state)
        }
        
        // Use active list in 'program order', i.e. low to high pc
        state.ActiveList = state.ActiveList.sorted(by: { $0.PC < $1.PC })
        
        var result = Result(
            ActiveList: state.ActiveList,
            FreeList: state.FreeList,
            Exception: state.Exception,
            PC: state.PC,
            ExceptionPC: state.ExceptionPC,
            RegisterMapTable: state.RegisterMapTable,
            BusyBitTable: state.BusyBitTable
        )
                
        // Mark done or exception if existing in forwarding path
        state.ActiveList.enumerated().forEach { (i, item) in
            if let matchingForwardingPath = state.forwardingPaths.first(where: { $0.iq.PC == item.PC }) {
                result.ActiveList[i].Exception = matchingForwardingPath.exception
                result.ActiveList[i].Done = true
            }
        }
        
        // At most 4 that are done and not marked as exception
        let intructionsToCommit = state.ActiveList
            .prefix(upTo: min(4, state.ActiveList.count))
            .prefix(while: {
                if ($0.Exception) {
                    print("CU – Exception detected")
                    result.Exception = true
                    return false
                } else {
                    return $0.Done
                }
            })
        
        assert(intructionsToCommit.count <= 4 && intructionsToCommit.allSatisfy { $0.Done })
        
        // Remove instructions from active list that will be commited
        result.ActiveList = Array(result.ActiveList.dropFirst(intructionsToCommit.count))
        
        print("CU – commiting \(intructionsToCommit.map { String($0.PC) }.split(separator: ", "))")
        
        // Free physical registers
        result.FreeList.append(contentsOf: intructionsToCommit.map { $0.OldDestination })
        
        return result
    }
    
    private func exceptionRecovery(state: State) -> Result {
        var result = Result(ActiveList: state.ActiveList, FreeList: state.FreeList, Exception: state.Exception, PC: state.PC, ExceptionPC: state.ExceptionPC, RegisterMapTable: state.RegisterMapTable, BusyBitTable: state.BusyBitTable)
        
        // Pick up to four instructions at bottom of reversed program order (highest PCs, excluding exception)
        var instructions = Array(state.ActiveList
                                    .sorted(by: { $0.PC > $1.PC }))
        instructions = Array(instructions.prefix(upTo: min(4, instructions.count)))
        
        print("CU - exception recovery, rolling back \(instructions.count) instructions")
        
        instructions.forEach { instruction in
            // Update busy bit
            let busyBitIndexToUpdate = state.RegisterMapTable[instruction.LogicalDestination]
            result.BusyBitTable[busyBitIndexToUpdate] = false
            
            // Add to free list
            if (instruction.Exception) {
                // Add what the physical register is currently mapping to
                result.FreeList.append(result.RegisterMapTable[instruction.LogicalDestination])
            } else {
                result.FreeList.append(instruction.OldDestination)
            }
            
            // Update register map table
            result.RegisterMapTable[instruction.LogicalDestination] = instruction.OldDestination
        }
        
        // Drop selected items from active list
        result.ActiveList = result.ActiveList.filter { item in !instructions.contains(where: { $0.PC == item.PC }) }
        
        return result
    }
}
