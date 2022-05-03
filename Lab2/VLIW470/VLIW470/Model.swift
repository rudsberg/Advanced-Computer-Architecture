//
//  Model.swift
//  VLIW470
//
//  Created by Joel Rudsberg on 2022-05-02.
//

import Foundation


protocol Instruction {
    var name: String { get }
    var destReg: String? { get }
    var readRegs: [String]? { get }
}

struct ArithmeticInstruction: Instruction {
    var name: String {
        mnemonic.rawValue
    }
    var destReg: String? {
        dest.toReg
    }
    var readRegs: [String]? {
        [opA, opB].map { $0.toReg }
    }
    
    let mnemonic: ArithmeticInstructionType
    let dest: Int
    let opA: Int
    let opB: Int // or immediate
}

enum ArithmeticInstructionType: String {
    case add
    case addi
    case sub
    case mulu
}

struct MemoryInstruction: Instruction {
    var name: String {
        mnemonic.rawValue
    }
    var destReg: String? {
        mnemonic == .ld ? destOrSource.toReg : nil
    }
    var readRegs: [String]? {
        let forBoth = [(imm + addr).toReg]
        if mnemonic == .st {
            return forBoth + [destOrSource.toReg]
        } else {
            return forBoth
        }
    }
    
    // dest for load, source for store
    let mnemonic: MemoryInstructionType
    let destOrSource: Int
    let imm: Int
    let addr: Int
}

enum MemoryInstructionType: String {
    case ld
    case st
}

struct LoopInstruction: Instruction {
    var name: String {
        type.rawValue
    }
    var destReg: String? {
        nil
    }
    var readRegs: [String]? {
        nil
    }
    
    let type: LoopInstructionType
    let loopStart: Int
}

enum LoopInstructionType: String {
    case loop
    case loop_pip = "loop.pip"
}

struct NoOp: Instruction {
    var name: String {
        "noop"
    }
    var destReg: String? {
        nil
    }
    var readRegs: [String]? {
        nil
    }
}

struct MoveInstruction: Instruction {
    var name: String {
        "mov"
    }
    /// -1 for LC, -2 for EC
    var destReg: String? {
        reg == -1 ? "LC" : (reg == -2 ? "EC" : reg.toReg)
    }
    var readRegs: [String]? {
        type == .setDestRegWithSourceReg ? [val.toReg] : nil
    }
    
    let type: MoveInstructionType
    let reg: Int
    // bool, imm, or source
    let val: Int
}

enum MoveInstructionType {
    case setPredicateReg
    case setSpecialRegWithImmediate
    case setDestRegWithImmediate
    case setDestRegWithSourceReg
}

extension Int {
    var toReg: String {
        "x\(self)"
    }
}

extension Sequence where Element == (Int, Instruction) {
    var producingInstructions: [(Int, Instruction)] {
        filter{ $0.1.destReg != nil && !($0.1.destReg == "LC" || $0.1.destReg == "EC") }
    }
    
    var consumingInstructions: [(Int, Instruction)] {
        filter{ $0.1.readRegs != nil && !$0.1.readRegs!.isEmpty }
    }
}
