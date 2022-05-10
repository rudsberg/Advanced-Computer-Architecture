//
//  LoopPreparer.swift
//  VLIW470
//
//  Created by Joel Rudsberg on 2022-05-10.
//

import Foundation

struct LoopPreparer {
    let schedule: Schedule
    let allocTable: AllocatedTable
    
    func prepare() -> AllocatedTable {
        var at = allocTable
        
        // In bb0, prepare the loop by setting first predicate register to true and EC to 1
        at = prepareBeforeLoop(at)
                
        at = prepareLoopBody(at)
        
        print("\n======= Prepared loop =======")
        at.table.forEach { print($0) }
        
        return at
    }
    
    private func prepareBeforeLoop(_ allocTable: AllocatedTable) -> AllocatedTable {
        func add(_ instructions: [Instruction], toRow row: RegisterAllocRow) -> (RegisterAllocRow, [Instruction]) {
            var instrs = instructions
            var row = row
            if row.ALU0.instr == nil && !instrs.isEmpty {
                row.ALU0.instr = instrs[0]
                instrs = Array(instrs.dropFirst())
            }
            if row.ALU1.instr == nil && !instrs.isEmpty {
                row.ALU1.instr = instrs[0]
                instrs = Array(instrs.dropFirst())
            }
            return (row, instrs)
        }
        
        var at = allocTable
        let addrBeforeLoop = at.table.last(where: { $0.block == 0 })!.addr
        var instrToAdd: [Instruction] = [
            MoveInstruction(
                addr: addrBeforeLoop,
                type: .setPredicateReg,
                reg: 32,
                val: 1
            ),
            MoveInstruction(
                addr: addrBeforeLoop,
                type: .setSpecialRegWithImmediate,
                reg: MoveInstruction.EC,
                val: schedule.numStages - 1
            )
        ]
        
        // Perform update on ALU spots that currently are available in last bundle before loop
        let (newRow1, remainingInstructions1) = add(instrToAdd, toRow: at.table[addrBeforeLoop])
        at.table[addrBeforeLoop] = newRow1
        instrToAdd = remainingInstructions1
        
        if instrToAdd.isEmpty {
            return at
        } else {
            // Insert new bundle
            let newAddr = addrBeforeLoop + 1
            at.table.insert(.init(block: 0, addr: newAddr, addrWithStage: nil), at: newAddr)
            
            // Update instructions adresses
            let _instrToAdd = instrToAdd
            _instrToAdd.enumerated().forEach { (i, instr) in
                instrToAdd[i].addr = newAddr
            }
            
            // Add instructions
            let (newRow2, remainingInstructions2) = add(instrToAdd, toRow: at.table[newAddr])
            at.table[newAddr] = newRow2
            assert(remainingInstructions2.isEmpty)
            
            return at
        }
    }
    
    private func prepareLoopBody(_ allocTable: AllocatedTable) -> AllocatedTable {
        var at = allocTable
        
        // Drop loop body and bb2 to get only bb1, save bb2 before
        at.table = allocTable.table.filter { $0.block == 0 }
        
        // Create empty loop body
        let addrStartLoop = allocTable.table.first(where: { $0.block == 1 })!.addr
        for i in 0...schedule.II-1 {
            at.table.append(.init(block: 1, addr: addrStartLoop + i, addrWithStage: nil))
        }
        
        // From start address of loop (start_addr), iterate II times and insert each instruction at start_addr+stage_addr at same exec unit it was scheduled on
        for stage in 0...schedule.II-1 {
            // For each row in this stage, assign instruction
            allocTable.table.filter { $0.addrWithStage == stage }.forEach { row in
                let i = addrStartLoop + stage
                if let instr = row.ALU0.instr {
                    at.table[i].ALU0.instr = instr
                }
                if let instr = row.ALU1.instr {
                    at.table[i].ALU1.instr = instr
                }
                if let instr = row.Mult.instr {
                    at.table[i].Mult.instr = instr
                }
                if let instr = row.Mem.instr {
                    at.table[i].Mem.instr = instr
                }
                if let instr = row.Branch.instr {
                    at.table[i].Branch.instr = instr
                }
            }
        }
        
        // Append bb2 again
        at.table.append(contentsOf: allocTable.table.filter { $0.block == 2 })
        
        return at
    }
    
    private func bundlesIn(block: Int) -> Int {
        allocTable.table.filter { $0.block == block }.count
    }
}
