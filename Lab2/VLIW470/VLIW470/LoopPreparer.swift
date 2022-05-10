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
        at = prepareBeforeLoop(at)
        at = prepareLoopBody(at)
        
        print("\n======= Prepared loop =======")
        at.table.forEach {
            let x = $0
            print("\(x.addr) | ALU0=\(x.ALU0.instr), ALU1=\(x.ALU1.instr), Mult=\(x.Mult.instr), Mem=\(x.Mem.instr), Branch=\(x.Branch.instr)")
        }
        
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
                type: .setSpecialRegWithImmediate,
                reg: MoveInstruction.EC,
                val: schedule.numStages - 1
            ),
            MoveInstruction(
                addr: addrBeforeLoop,
                type: .setPredicateReg,
                reg: 32,
                val: 1
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
            
            // Update addr
            at = updateAddrToBeSequential(at)
            
            // Add instructions
            let (newRow2, remainingInstructions2) = add(instrToAdd, toRow: at.table[newAddr])
            at.table[newAddr] = newRow2
            assert(remainingInstructions2.isEmpty)
            
            return at
        }
    }
    
    private func updateAddrToBeSequential(_ allocTable: AllocatedTable) -> AllocatedTable {
        var at = allocTable
        at.table.enumerated().forEach { (i, row) in
            at.table[i].addr = i
        }
        return at
    }
    
    private func prepareLoopBody(_ allocTable: AllocatedTable) -> AllocatedTable {
        var at = allocTable
        
        // Drop loop body and bb2 to get only bb1
        at.table = allocTable.table.filter { $0.block == 0 }
        
        // Create empty loop body
        let addrBeforeLoop = allocTable.table.last(where: { $0.block == 0 })!.addr
        for i in 1...schedule.II {
            at.table.append(.init(block: 1, addr: addrBeforeLoop + i, addrWithStage: nil))
        }
        
        // Map instruction addr to predicate
        let predicates = Array(32...95)
        var addrToPredicate = [Int: Int]()
        self.allocTable.table.filter { $0.block == 1 }.chunked(by: schedule.II).enumerated().forEach { (i, chunk) in
            func setPred(_ instr: Instruction?) {
                if let instr = instr {
                    addrToPredicate[instr.addr] = predicates[i]
                }
            }
            
            Array(chunk).forEach { row in
                row.execEntries.forEach { setPred($0.instr) }
            }
        }
        
        // From start address of loop (start_addr), iterate II times and insert each instruction at start_addr+stage_addr at same exec unit it was scheduled on
        let startI = self.allocTable.table.first(where: { $0.block == 1 })!.addrWithStage!
        var insertIndex = addrBeforeLoop + 1
        for stage in startI...startI+schedule.II {
            // For each row in this stage, assign instruction
            let rowSameStage = self.allocTable.table.filter { $0.addrWithStage == stage }
            rowSameStage.forEach { row in
                let i = insertIndex
                if var instr = row.ALU0.instr {
                    instr.predicate = addrToPredicate[instr.addr]
                    at.table[i].ALU0.instr = instr
                }
                if var instr = row.ALU1.instr {
                    instr.predicate = addrToPredicate[instr.addr]
                    at.table[i].ALU1.instr = instr
                }
                if var instr = row.Mult.instr {
                    instr.predicate = addrToPredicate[instr.addr]
                    at.table[i].Mult.instr = instr
                }
                if var instr = row.Mem.instr {
                    instr.predicate = addrToPredicate[instr.addr]
                    at.table[i].Mem.instr = instr
                }
                if let instr = row.Branch.instr {
                    at.table[i].Branch.instr = instr
                }
            }
            insertIndex += 1
        }
        
        // Append bb2 again
        at.table.append(contentsOf: allocTable.table.filter { $0.block == 2 })
        
        at = updateAddrToBeSequential(at)
         
        // Update loop to be loop.pip and its loop adress
        let loopIndex = at.table.firstIndex(where: { $0.Branch.instr != nil })!
        var loopInstr = at.table[loopIndex].Branch.instr as! LoopInstruction
        loopInstr.type = .loop_pip
        loopInstr.loopStart = at.table.first(where: { $0.block == 1 })!.addr
        at.table[loopIndex].Branch.instr = loopInstr
        
        return at
    }
    
    private func bundlesIn(block: Int) -> Int {
        allocTable.table.filter { $0.block == block }.count
    }
}
