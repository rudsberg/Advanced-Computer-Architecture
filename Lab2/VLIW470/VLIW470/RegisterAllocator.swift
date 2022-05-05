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
            func find(_ addr: Int?, _ unit: ExecutionUnit) -> RegisterAllocEntry {
                if let addr = addr {
                    return .init(execUnit: unit, instr: depTable[addr].instr)
                } else {
                    return .init(execUnit: unit)
                }
            }
            
            return .init(
                addr: $0.addr,
                ALU0: find($0.ALU0, .ALU(0)),
                ALU1: find($0.ALU1, .ALU(1)),
                Mult: find($0.Mult, .Mult),
                Mem: find($0.Mem, .Mem),
                Branch: find($0.Branch, .Branch)
            )
        }
        
        // Phase 1: Allocate fresh unique registers to each instruction producing a new value
        // Output: all destinations registers specified
        let atCopy = at
        var regCounter = 1
        atCopy.enumerated().forEach { (bIndex, b) in
            [b.ALU0, b.ALU1, b.Mult, b.Mem, b.Branch].forEach { entry in
                if let instr = entry.instr, instr.isProducingInstruction {
                    // Allocate new fresh register
                    let newReg = "\(regCounter)"
                    switch entry.execUnit {
                    case .ALU(let i):
                        if i == 0 {
                            at[bIndex].ALU0.instr?.destReg = newReg
                        } else {
                            at[bIndex].ALU1.instr?.destReg = newReg
                        }
                    case .Mult:
                        at[bIndex].Mult.instr?.destReg = newReg
                    case .Mem:
                        at[bIndex].Mem.instr?.destReg = newReg
                    case .Branch:
                        at[bIndex].Branch.instr?.destReg = newReg
                    }
                    regCounter += 1
                }
            }
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
        at.enumerated().forEach{ (addr, x) in
            print("\(addr) | ALU0=\(x.ALU0.instr), ALU1=\(x.ALU1.instr), Mult=\(x.Mult.instr), Mem=\(x.Mem.instr), Branch=\(x.Branch.instr)")
        }
        
        return at
    }
}
