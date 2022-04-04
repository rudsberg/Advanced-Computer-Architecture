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
        guard !state.Exception else {
            return exceptionRecovery(state: state)
        }
        
        var result = Result(
            ActiveList: state.ActiveList,
            FreeList: state.FreeList,
            Exception: state.Exception,
            PC: state.PC,
            ExceptionPC: state.ExceptionPC,
            RegisterMapTable: state.RegisterMapTable,
            BusyBitTable: state.BusyBitTable
        )
        
        // Use list in 'program order', i.e. low to high pc
        let activeList = state.ActiveList.sorted(by: { $0.PC < $1.PC })
        
        // Mark done or exception if existing in forwarding path
        activeList.enumerated().forEach { (i, item) in
            if let matchingForwardingPath = state.forwardingPaths.first(where: { $0.iq.PC == item.PC }) {
                result.ActiveList[i].Exception = matchingForwardingPath.exception
                result.ActiveList[i].Done = true
            }
        }
        
        let intructionsToCommit = activeList.prefix(upTo: min(4, activeList.count)).prefix(while: { $0.Done && !$0.Exception })
        
        // If head of list is exception enter recovery next cycle
        if (intructionsToCommit.count < result.ActiveList.count && activeList[intructionsToCommit.count].Exception) {
            print("EXCEPTION FOUND!!!!!!")
            result.Exception = true
        }
                
        // Find instructions to retire/commit - crucially using 'state' and not 'result' due to timing
//        let intructionsToCommit = activeList.enumerated().prefix(while: { (i, item) in
//            // First 4 and done
//            let passes = i < 4 && item.Done
//
//            // Check if exception
//            let exception = item.Exception
//            if (exception) {
//                result.Exception = true
//                result.ExceptionPC = item.PC
//            }
//
//            return passes && !exception
//        }).map { $0.element }
        
        assert(intructionsToCommit.count <= 4)
        
        // Remove instructions from active list that will be commited
        intructionsToCommit.forEach { instruction in
            result.ActiveList = result.ActiveList.filter { $0.PC != instruction.PC }
        }
        
        print("CU – commiting \(intructionsToCommit.map { String($0.PC) }.split(separator: ", "))")
        
        // Free physical registers
        result.FreeList.append(contentsOf: intructionsToCommit.map { $0.LogicalDestination })
        
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
            
            // Update register map table
            result.RegisterMapTable[instruction.LogicalDestination] = instruction.OldDestination
            
            // Add to free list
            result.FreeList.append(instruction.OldDestination)
        }
        
        // Drop selected items from active list
        result.ActiveList = result.ActiveList.filter { item in !instructions.contains(where: { $0.PC == item.PC }) }
        
        return result
    }
}
