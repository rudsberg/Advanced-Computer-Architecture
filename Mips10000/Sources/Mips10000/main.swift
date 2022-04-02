import Foundation

struct FileIOController {
    private let folderName = "Files_HW1"
    
    func write<T: Encodable>(_ value: T, toDocumentNamed documentName: String, encodedUsing encoder: JSONEncoder = .init()) throws {
        let folderURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )

        let fileURL = folderURL.appendingPathComponent(folderName).appendingPathComponent(documentName)
        let data = try encoder.encode(value)
        try data.write(to: fileURL)
    }
    
    func read(documentName: String) throws -> [String] {
        let folderURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let fileURL = folderURL.appendingPathComponent(folderName).appendingPathComponent(documentName)
        let data = FileManager.default.contents(atPath: fileURL.path)!
        return try JSONDecoder().decode([String].self, from: data)
    }
}

// MARK: - Models
typealias Register = Int
typealias PC = Int

struct Instruction {
    let address: Int
    let type: InstructionType
}

enum InstructionType {
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
    private init() {}
    static let shared = State()
    
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
}

struct ActiveListItem: Codable {
    var Done: Bool
    var Exception: Bool
    var LogicalDestination: Int
    var OldDestination: Int
    var PC: Int
}

struct IntegerQueueItem: Codable {
    var DestRegister: Int
    var OpAIsReady: Bool
    var OpARegTag: Int
    var OpAValue: Int
    var OpBIsReady: Bool
    var OpBRegTag: Int
    var OpBValue: Int
    var OpCode: String
}

// MARK: - Parsing
func intructionStrings(fromFile file: String) throws -> [String] {
    let loader = FileIOController()
    return try loader.read(documentName: file)
//    let path = Bundle.main.path(forResource: file, ofType: "json")!
//    let data = FileManager.default.contents(atPath: path)!
//    let decoder = JSONDecoder()
//    return try decoder.decode([String].self, from: data)
}

func parseInstructions(fromFile file: String) throws -> [Instruction] {
    // Load json and parse as an array of strings
    let instructionStrings = try intructionStrings(fromFile: file)
     
    // Map strings to instructions
    var pc = -1 // TODO: not hexadeciamal?
    return instructionStrings.map { i -> (String, Int, Int, Int) in
        print(i)
        let parts = Array(i.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "x", with: "").split(separator: " "))
        print(parts)
        return (String(parts[0]), Int(parts[1])!, Int(parts[2])!, Int(parts[3])!)
    }.map { (type, dest, arg1, arg2) in
        pc += 1
        switch (type) {
        case "add":
            return Instruction(address: pc, type: .add(dest, arg1, arg2))
        case "addi":
            return Instruction(address: pc, type: .addi(dest, arg1, arg2))
        case "sub":
            return Instruction(address: pc, type: .sub(dest, arg1, arg2))
        case "mulu":
            return Instruction(address: pc, type: .mulu(dest, arg1, arg2))
        case "divu":
            return Instruction(address: pc, type: .divu(dest, arg1, arg2))
        case "remu":
            return Instruction(address: pc, type: .remu(dest, arg1, arg2))
        default:
            fatalError("Non-supported instruction")
        }
    }
}

// MARK: - Logging
func updateLog(newFile: Bool) throws {
    // Create file if it doens't exists
    let logFileName = "test_result"
    let path = Bundle.main.path(forResource: logFileName, ofType: "json")! // playgroundSharedDataDirectory.appendingPathComponent(logFileName).path
//    if (newFile) {
//        let empty = try JSONEncoder().encode([String]())
//        FileManager.default.createFile(atPath: path, contents: empty, attributes: nil)
//    }
    
    // assert(path == Bundle.main.path(forResource: logFileName, ofType: "json")!)
   
    // Get existing file data
    let data = FileManager.default.contents(atPath: path)!
    let decoder = JSONDecoder()
    var state = try decoder.decode([State].self, from: data)
    
    // Append current state
    state.append(State.shared)
    
    // Write new state update
    let encoder = JSONEncoder()
    let newStateEncoded = try encoder.encode(state)
    try newStateEncoded.write(to: URL(fileURLWithPath: path))
}

// 0. parse JSON to get the program
let program = try parseInstructions(fromFile: "test.json")
program.forEach({ print($0) })
// try FileIOController().write("snääälllla", toDocumentNamed: "my_test.txt")

// 1. dump the state of the reset system
// try updateLog(newFile: true)

//let url = Bundle.main.path(forResource: "please_work", ofType: "json")!
//try "hej".write(toFile: url, atomically: true, encoding: .utf8)


// 2. the loop for cycle-by-cycle iterations.
// while(not (noInstruction() and activeListIsEmpty())){
    // do propagation
    // if you have multiple modules, propagate each of them
    // propagate();
    // advance clock, start next cycle
    // latch();
    // dump the state
    // dumpStateIntoLog();
// }
// 3. save the output JSON log
// saveLog();

