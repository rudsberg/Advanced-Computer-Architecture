//
//  RegisterAllocator.swift
//  VLIW470
//
//  Created by Joel Rudsberg on 2022-05-05.
//

import Foundation

struct RegisterAllocator {
    func alloc_b(schedule: Schedule, depTable: DependencyTable) -> AllocatedTable {
        // Map schedule to alloc table, containing the instructions rather than only their original address
        var at: AllocatedTable = schedule.map {
            func find(_ addr: Int?) -> Instruction? {
                if let addr = addr {
                    return depTable[addr].instr
                } else {
                    return nil
                }
            }
            
            return .init(addr: $0.addr, ALU0: find($0.ALU0), ALU1: find($0.ALU1), Mult: find($0.Mult), Mem: find($0.Mem), Branch: find($0.Branch))
        }

        // Phase 1: Allocate fresh unique registers to each instruction producing a new value
        // Output: all destinations registers specified
        var regCounter = 1
        at.enumerated().forEach { (i, b) in
            // Map schedule to instructions & sort in instruction order
//            let instructions = [b.ALU0, b.ALU1, b.Mult, b.Mem, b.Branch]
//                .compactMap { $0 }
//                .sorted(by: { $0.ad < $1 })
//                .map { depTable[$0].instr }
            
        }
        
        // Phase 2: Link each operand to the registers newly allocated in phase 1
        // If two dependencies, must be in bb0 and bb1, then use register of bb0. Incorrectness resolved in phase 3.
        // Output: all operand registers specified
        
        // Phase 3: Fix the interloop dependencies
        // View - see loop body as a function and interloop dependencies as function parameters.
        // Since we choose dest register r produced in bb0 as operands for consumers in bb1 (for those with dep in bb0)
        // those registers are effectively like function arguments. Thus, values produced in bb1 that actually point to
        // same register as in bb0 must be moved to r to respect the 'calling conventions'. Do this by *inserting* mov
        // instructions at last bundle of loop, creating space if needed (pushing down loop). NOTE: instruction dep must
        // be checked to not be violated.
        
        print("\n======= alloc_b allocation =======")
        at.forEach({ print($0) })
        
        return at
    }
}
