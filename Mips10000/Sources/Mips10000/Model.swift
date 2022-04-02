//
//  File.swift
//  
//
//  Created by Joel Rudsberg on 2022-04-02.
//

import Foundation

typealias Register = Int
typealias PC = Int

struct Instruction: Equatable {
    let address: Int
    let type: InstructionType
}

enum InstructionType: Equatable {
    case add(Register, Register, Register)
    case addi(Register, Register, Int)
    case sub(Register, Register, Register)
    case mulu(Register, Register, Register)
    case divu(Register, Register, Register)
    case remu(Register, Register, Register)
    
    var description: String {
        switch self {
        case .add(_, _, _):
            return "add"
        case .addi(_, _, _):
            return "addi"
        case .sub(_, _, _):
            return "sub"
        case .mulu(_, _, _):
            return "mulu"
        case .divu(_, _, _):
            return "divu"
        case .remu(_, _, _):
            return "remu"
        }
    }
}

class State: Codable {
    // The remaining program to execute
    var programMemory = [Instruction]()
    var PC = 0
    var PhysicalRegisterFile = [Int](repeating: 0, count: 64)
    var DecodedPCs = [Int]()
    var ExceptionPC = 0
    var Exception = false
    var RegisterMapTable = Array(0...31)
    var FreeList = Array(32...63)
    var BusyBitTable = [Bool](repeating: false, count: 64)
    var ActiveList = [ActiveListItem]() {
        didSet {
            assert(ActiveList.count <= 32)
        }
    }
    var IntegerQueue = [IntegerQueueItem]() {
        didSet {
            assert(IntegerQueue.count <= 32)
        }
    }
    
    // Encode/decode all but program memory
    enum CodingKeys: String, CodingKey {
        case PC
        case PhysicalRegisterFile
        case DecodedPCs
        case ExceptionPC
        case Exception
        case RegisterMapTable
        case FreeList
        case BusyBitTable
        case ActiveList
        case IntegerQueue
    }
}

struct ActiveListItem: Codable, Equatable {
    var Done: Bool
    var Exception: Bool
    var LogicalDestination: Int
    var OldDestination: Int
    var PC: Int
}

struct IntegerQueueItem: Codable, Equatable {
    var DestRegister: Int
    var OpAIsReady: Bool
    var OpARegTag: Int
    var OpAValue: Int
    var OpBIsReady: Bool
    var OpBRegTag: Int
    var OpBValue: Int
    var OpCode: String
}
