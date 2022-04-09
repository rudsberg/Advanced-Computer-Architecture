//
//  File.swift
//  
//
//  Created by Joel Rudsberg on 2022-04-02.
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
