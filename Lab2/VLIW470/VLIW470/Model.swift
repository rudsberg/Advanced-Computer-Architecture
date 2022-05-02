//
//  Model.swift
//  VLIW470
//
//  Created by Joel Rudsberg on 2022-05-02.
//

import Foundation


protocol Instruction {}

struct ArithmeticInstruction: Instruction {
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
    let type: LoopInstructionType
    let loopStart: Int
}

enum LoopInstructionType: String {
    case loop
    case loop_pip = "loop.pip"
}

struct NoOp: Instruction {}

struct MoveInstruction: Instruction {
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
