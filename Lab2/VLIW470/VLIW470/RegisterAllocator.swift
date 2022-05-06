//
//  RegisterAllocator.swift
//  VLIW470
//
//  Created by Joel Rudsberg on 2022-05-05.
//

import Foundation

struct RegisterAllocator {
    let depTable: DependencyTable
    
    func alloc_b(schedule: Schedule) -> AllocatedTable {
        var at = createInitialAllocTable(schedule: schedule, depTable: depTable)
        
        // Phase 1: Allocate fresh unique registers to each instruction producing a new value
        // Output: all destinations registers specified
        at = allocFreshRegisters(at)
        
        // Phase 2: Link each operand to the registers newly allocated in phase 1
        // If two dependencies, must be in bb0 and bb1, then use register of bb0. Incorrectness resolved in phase 3.
        // Output: all operand registers specified
        at = linkRegisters(at)
        
        // Phase 3: Fix the interloop dependencies
        // View - see loop body as a function and interloop dependencies as function parameters.
        // Since we choose dest register r produced in bb0 as operands for consumers in bb1 (for those with dep in bb0)
        // those registers are effectively like function arguments. Thus, values produced in bb1 that actually point to
        // same register as in bb0 must be moved to r to respect the 'calling conventions'. Do this by *inserting* mov
        // instructions at last bundle of loop, creating space if needed (pushing down loop). NOTE: instruction dep must
        // be checked to not be violated.
        
        print("\n======= alloc_b allocation =======")
        at.table.enumerated().forEach{ (addr, x) in
            print("\(addr) | ALU0=\(x.ALU0.instr), ALU1=\(x.ALU1.instr), Mult=\(x.Mult.instr), Mem=\(x.Mem.instr), Branch=\(x.Branch.instr)")
        }
        
        return at
    }
    
    /// Maps schedule to alloc table, containing the instructions rather than only their original address
    private func createInitialAllocTable(schedule: Schedule, depTable: DependencyTable) -> AllocatedTable {
        let table: [RegisterAllocRow] = schedule.map {
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
        return .init(table: table, renamedRegs: [])
    }
    
    private func allocFreshRegisters(_ allocTable: AllocatedTable) -> AllocatedTable {
        var at = allocTable
        var regCounter = 1
        allocTable.table.enumerated().forEach { (bIndex, b) in
            [b.ALU0, b.ALU1, b.Mult, b.Mem, b.Branch].forEach { entry in
                if let instr = entry.instr, instr.isProducingInstruction {
                    // Allocate new fresh register
                    let newReg = "\(regCounter)"
                    var oldReg: String! = ""
                    switch entry.execUnit {
                    case .ALU(let i):
                        if i == 0 {
                            oldReg = at.table[bIndex].ALU0.instr?.destReg
                            at.table[bIndex].ALU0.instr?.destReg = newReg
                        } else {
                            oldReg = at.table[bIndex].ALU1.instr?.destReg
                            at.table[bIndex].ALU1.instr?.destReg = newReg
                        }
                    case .Mult:
                        oldReg = at.table[bIndex].Mult.instr?.destReg
                        at.table[bIndex].Mult.instr?.destReg = newReg
                    case .Mem:
                        oldReg = at.table[bIndex].Mem.instr?.destReg
                        at.table[bIndex].Mem.instr?.destReg = newReg
                    case .Branch:
                        oldReg = at.table[bIndex].Branch.instr?.destReg
                        at.table[bIndex].Branch.instr?.destReg = newReg
                    }
                    print("oldreg ", oldReg)
                    at.renamedRegs.append(.init(
                        block: depTable.first(where: { $0.addr == instr.addr })!.block,
                        oldReg: oldReg.regToAddr,
                        newReg: regCounter
                    ))
                    regCounter += 1
                }
            }
        }
        return at
    }
    
    private func linkRegisters(_ allocTable: AllocatedTable) -> AllocatedTable {
        // All readRegs need to be recomputed.
        var at = allocTable
        print("renamed regs: ", at.renamedRegs)
        allocTable.table.enumerated().forEach { (bIndex, b) in
            [b.ALU0, b.ALU1, b.Mult, b.Mem, b.Branch].forEach { entry in
                if let instr = entry.instr, let readRegs = instr.readRegs, !readRegs.isEmpty  {
                    // Rename each read register
                    // Find what readReg was renamed to
                    // readRegs are pointing to the OLD regs, check renamed regs for those that have match
                    // and return the old regs
                    let newRegs = readRegs.map { oldRegToNewFreshReg(oldReg: $0, allocTable: allocTable) }

                    switch entry.execUnit {
                    case .ALU(let i):
                        if i == 1 {
                            at.table[bIndex].ALU0.instr?.readRegs = newRegs
                        } else {
                            at.table[bIndex].ALU1.instr?.readRegs = newRegs
                        }
                    case .Mult:
                        at.table[bIndex].Mult.instr?.readRegs = newRegs
                    case .Mem:
                        at.table[bIndex].Mem.instr?.readRegs = newRegs
                    case .Branch:
                        at.table[bIndex].Branch.instr?.readRegs = newRegs
                    }
                }
            }
        }
        return at
    }
    
    private func oldRegToNewFreshReg(oldReg: String, allocTable: AllocatedTable) -> String {
        // If two match then return the one in bb0
        let newRegs = allocTable.renamedRegs
            .filter { oldReg.regToAddr == $0.oldReg }
            .map { ($0.block, $0.newReg.toReg) }
        assert(newRegs.count <= 2)
        if newRegs.count == 2 {
            // Take the one in bb0
            return newRegs.first(where: { $0.0 == 0 })!.1
        } else {
            return newRegs[0].1
        }
    }
}
