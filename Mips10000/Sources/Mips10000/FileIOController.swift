//
//  File.swift
//  
//
//  Created by Joel Rudsberg on 2022-04-02.
//

import Foundation

struct FileIOController {
    private let folderName = "Files_HW1"
    private var folderURL: URL {
        try! FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ).appendingPathComponent(folderName)
    }
    
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
}
