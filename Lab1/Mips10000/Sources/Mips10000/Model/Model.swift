//
//  File.swift
//  
//
//  Created by Joel Rudsberg on 2022-04-02.
//

import Foundation

typealias Register = Int
typealias RegisterOrImmediate = Int
typealias PC = Int

struct Instruction: Equatable {
    let pc: Int
    let dest: Register
    let opA: Register
    /// Immediate value for addi, register for rest
    let opB: RegisterOrImmediate
    let type: InstructionType
    
    var opBImmediateValue: Int? {
        type.hasImmediateValue ? opB : nil
    }
}

enum InstructionType: String, Equatable {
    case add
    case addi
    case sub
    case mulu
    case divu
    case remu
    
    var hasImmediateValue: Bool {
        self == .addi
    }
}

struct State: Codable {
    /// Remaining program to execute
    var programMemory = [Instruction]()
    var forwardingPaths = [ForwardingPath]()
    var pipelineRegister3: [ALUItem] = [] {
        didSet {
            assert(pipelineRegister3.count <= 4)
        }
    }
    
    var PC = 0
    var PhysicalRegisterFile = [Int](repeating: 0, count: 64)
    var DecodedPCs = [Int]()
    var ExceptionPC = 0
    var Exception = false
    /// Logical --> Physical
    var RegisterMapTable = Array(0...31)
    /// FIFO, head beginning of array and tail end of array
    var FreeList = Array(32...63)
    var BusyBitTable = [Bool](repeating: false, count: 64)
    var ActiveList = [ActiveListItem]() {
        didSet {
            assert(ActiveList.count <= 32)
        }
    }
    /// Reservation Station
    var IntegerQueue = [IntegerQueueItem]() {
        didSet {
            assert(IntegerQueue.count <= 32)
        }
    }
    
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
    var Done = false
    var Exception = false
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
    var PC: Int
}

struct ForwardingPath {
    let value: Int?
    let exception: Bool
    let iq: IntegerQueueItem
}

struct ALUItem {
    var iq: IntegerQueueItem
    var computedValue: Int? = nil
    var exception: Bool = false
}
