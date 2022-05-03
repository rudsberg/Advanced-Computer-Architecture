//
//  Helpers.swift
//  VLIW470
//
//  Created by Joel Rudsberg on 2022-05-02.
//

import Foundation

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
    func parseInstructions(fromFile file: String) throws -> [(Int, Instruction)] {
        // Load json and parse as an array of strings
        let instructionStrings = try intructionStrings(fromFile: file)
        
        var pc = -1
        return instructionStrings.map { i in
            Array(i
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: "x", with: "")
                .replacingOccurrences(of: "(", with: " ")
                .replacingOccurrences(of: ")", with: "")
                .split(separator: " ")
            ).map { String($0) }
        }.map { p -> (Int, Instruction) in // parts
            pc += 1
            return (pc, extractInstruction(from: p))
        }
    }
    
    private func extractInstruction(from strings: [String]) -> Instruction {
        let p = strings
        switch (p.first!) {
        case "add", "addi", "sub", "mulu":
            return ArithmeticInstruction(mnemonic: .init(rawValue: p[0])!, dest: Int(p[1])!, opA: Int(p[2])!, opB: Int(p[3])!)
        case "ld", "st":
            return MemoryInstruction(mnemonic: .init(rawValue: p[0])!, destOrSource: Int(p[1])!, imm: Int(p[2])!, addr: Int(p[3])!)
        case "loop", "loop.pip":
            return LoopInstruction(type: .init(rawValue: p[0])!, loopStart: Int(p[1])!)
        case "nop":
            return NoOp()
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
            return MoveInstruction(type: type, reg: reg, val: Int(p[2])!)
        default:
            fatalError("No matching instruction")
        }
    }
    
    private func intructionStrings(fromFile file: String) throws -> [String] {
        let loader = FileIOController.shared
        return try loader.read([String].self, documentName: file)
    }
}
