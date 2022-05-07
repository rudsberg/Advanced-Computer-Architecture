//
//  Helpers.swift
//  VLIW470
//
//  Created by Joel Rudsberg on 2022-05-02.
//

import Foundation

let alphabet = "abcdefghijklmnopqrstuvwxyz"
    .uppercased()
    .map { String($0) }

extension Optional where Wrapped == Int {
    var toChar: String {
        if let num = self {
            if num >= 26 {
                return "\(num)"
            } else {
                return String(alphabet[num])
            }
        } else {
            return "-"
        }
    }
}

extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var set = Set<Element>()
        return filter { set.insert($0).inserted }
    }
}

class FileIOController {
    static let shared = FileIOController()
    
    /// Path that all logging and results will be saved in, as well as where the reading of program files will be done in
    static var folderPath: String?
    private var folderURL: URL {
        if let folderPath = FileIOController.folderPath {
            if (!FileManager.default.fileExists(atPath: folderPath)) {
                fatalError("Folder does not exist at path \(folderPath). Please create the folder first.")
            }
            return URL(fileURLWithPath: folderPath, isDirectory: true)
        } else {
            fatalError("static attribute folderPath has not been set in FileIOController")
        }
    }
    
    private init() {}
    
    func createFile(documentName: String) {
        let fileURL = folderURL.appendingPathComponent(documentName)
        FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
    }
    
    func write<T: Encodable>(_ value: T, toDocumentNamed documentName: String, encodedUsing encoder: JSONEncoder = .init()) throws {
        let fileURL = folderURL.appendingPathComponent(documentName)
        let data = try encoder.encode(value)
        try data.write(to: fileURL)
    }
    
    func read<T: Decodable>(_ type: T.Type, documentName: String) throws -> T {
        let fileURL = folderURL.appendingPathComponent(documentName)
        let data = FileManager.default.contents(atPath: fileURL.path)!
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func fileExist(documentName: String) -> Bool {
        FileManager.default.fileExists(atPath: folderURL.appendingPathComponent(documentName).path)
    }
    
    func deleteFile(documentName: String) throws {
        try FileManager.default.removeItem(at: folderURL.appendingPathComponent(documentName))
    }
}

//struct Logger {
//    func updateLog(with state: State, documentName: String, deleteExistingFile: Bool = false) throws {
//        let fileIO = FileIOController.shared
//        
//        if (fileIO.fileExist(documentName: documentName) && !deleteExistingFile) {
//            // Get current state, append current state and write update
//            var newState = try fileIO.read([State].self, documentName: documentName)
//            newState.append(state)
//            // Transforms all 'addi' to 'add'
//            newState.enumerated().forEach { (i, state) in
//                newState[i].IntegerQueue.enumerated().forEach { (j, item) in
//                    if (item.OpCode == InstructionType.addi.rawValue) {
//                        newState[i].IntegerQueue[j].OpCode = InstructionType.add.rawValue
//                    }
//                }
//            }
//            try fileIO.write(newState, toDocumentNamed: documentName)
//        } else {
//            // Create file and write current state
//            fileIO.createFile(documentName: documentName)
//            try fileIO.write([state], toDocumentNamed: documentName)
//        }
//    }
//}

struct Parser {
    func parseInstructions(fromFile file: String) throws -> Program {
        // Load json and parse as an array of strings
        let instructionStrings = try intructionStrings(fromFile: file)
        
        var addr = -1
        let program = instructionStrings.map { i in
            Array(i
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: "x", with: "")
                .replacingOccurrences(of: "(", with: " ")
                .replacingOccurrences(of: ")", with: "")
                .split(separator: " ")
            ).map { String($0) }
        }.map { p -> Instruction in // parts
            addr += 1
            return extractInstruction(from: p, addr: addr)
        }
        
        print("======= Program =======")
        program.forEach { print($0) }
        
        return program
    }
    
    private func extractInstruction(from strings: [String], addr: Address) -> Instruction {
        let p = strings
        switch (p.first!) {
        case "add", "addi", "sub", "mulu":
            return ArithmeticInstruction(addr: addr, mnemonic: .init(rawValue: p[0])!, dest: Int(p[1])!, opA: Int(p[2])!, opB: Int(p[3])!)
        case "ld", "st":
            return MemoryInstruction(addr: addr, mnemonic: .init(rawValue: p[0])!, destOrSource: Int(p[1])!, imm: Int(p[2])!, loadStoreAddr: Int(p[3])!)
        case "loop", "loop.pip":
            return LoopInstruction(addr: addr, type: .init(rawValue: p[0])!, loopStart: Int(p[1])!)
        case "nop":
            return NoOp(addr: addr)
        case "mov":
            var type: MoveInstructionType!
            let v = p[1]
            if (v.first == "p") {
                type = .setPredicateReg
            } else if (v == "LC" || v == "EC") {
                type = .setSpecialRegWithImmediate
            } else if (p[2].first == "x") {
                type = .setDestRegWithSourceReg
            } else {
                type = .setDestRegWithImmediate
            }
            
            let reg = v == "LC" ? -1 : (v == "EC" ? -2 : Int(p[1])!)
            return MoveInstruction(addr: addr, type: type, reg: reg, val: Int(p[2])!)
        default:
            fatalError("No matching instruction")
        }
    }
    
    private func intructionStrings(fromFile file: String) throws -> [String] {
        let loader = FileIOController.shared
        return try loader.read([String].self, documentName: file)
    }
}

func combos<T>(elements: ArraySlice<T>, k: Int) -> [[T]] {
    if k == 0 {
        return [[]]
    }

    guard let first = elements.first else {
        return []
    }

    let head = [first]
    let subcombos = combos(elements: elements, k: k - 1)
    var ret = subcombos.map { head + $0 }
    ret += combos(elements: elements.dropFirst(), k: k)

    return ret
}

func combos<T>(elements: Array<T>, k: Int) -> [[T]] {
    return combos(elements: ArraySlice(elements), k: k)
}
