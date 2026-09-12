import Foundation
import Compression

/// Minimal read-only zip support (stored and deflate entries, no zip64, no
/// encryption) — enough for team imports made with Finder or the Files app.
struct ZipArchive {
    struct Entry {
        let path: String
        let compressionMethod: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    enum ZipError: LocalizedError {
        case notAZipFile
        case unsupportedCompression(String)
        case corrupt(String)

        var errorDescription: String? {
            switch self {
            case .notAZipFile: return "Dit bestand is geen zip-bestand."
            case .unsupportedCompression(let path): return "'\(path)' gebruikt een niet-ondersteunde compressie."
            case .corrupt(let path): return "'\(path)' in het zip-bestand is beschadigd."
            }
        }
    }

    private let data: Data
    let entries: [Entry]

    init(data: Data) throws {
        self.data = data
        self.entries = try Self.readCentralDirectory(data)
    }

    /// Entries that are real files, ignoring folders and macOS resource forks
    var fileEntries: [Entry] {
        entries.filter {
            !$0.path.hasSuffix("/") && !$0.path.hasPrefix("__MACOSX/") && !$0.path.split(separator: "/").contains(".DS_Store")
        }
    }

    func entry(named path: String) -> Entry? {
        fileEntries.first { $0.path == path }
    }

    func contents(of entry: Entry) throws -> Data {
        // Local file header: signature(4) version(2) flags(2) method(2) time(2) date(2)
        // crc(4) csize(4) usize(4) nameLen(2) extraLen(2)
        let h = entry.localHeaderOffset
        guard h + 30 <= data.count, u32(at: h) == 0x0403_4b50 else { throw ZipError.corrupt(entry.path) }
        let nameLength = Int(u16(at: h + 26))
        let extraLength = Int(u16(at: h + 28))
        let start = h + 30 + nameLength + extraLength
        let end = start + entry.compressedSize
        guard end <= data.count else { throw ZipError.corrupt(entry.path) }
        let compressed = data.subdata(in: start..<end)

        switch entry.compressionMethod {
        case 0:
            return compressed
        case 8:
            return try inflate(compressed, expectedSize: entry.uncompressedSize, path: entry.path)
        default:
            throw ZipError.unsupportedCompression(entry.path)
        }
    }

    // MARK: - Parsing

    private static func readCentralDirectory(_ data: Data) throws -> [Entry] {
        // End of central directory record (22 bytes + comment), search backwards
        guard data.count >= 22 else { throw ZipError.notAZipFile }
        var eocd = -1
        var i = data.count - 22
        while i >= max(0, data.count - 22 - 0xFFFF) {
            if data.u32(at: i) == 0x0605_4b50 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { throw ZipError.notAZipFile }

        let entryCount = Int(data.u16(at: eocd + 10))
        var offset = Int(data.u32(at: eocd + 16))
        var entries: [Entry] = []

        for _ in 0..<entryCount {
            // Central directory header: signature(4) ... method(10) ... csize(20) usize(24)
            // nameLen(28) extraLen(30) commentLen(32) ... localHeaderOffset(42) name(46)
            guard offset + 46 <= data.count, data.u32(at: offset) == 0x0201_4b50 else {
                throw ZipError.corrupt("central directory")
            }
            let nameLength = Int(data.u16(at: offset + 28))
            let extraLength = Int(data.u16(at: offset + 30))
            let commentLength = Int(data.u16(at: offset + 32))
            let nameData = data.subdata(in: (offset + 46)..<(offset + 46 + nameLength))
            let path = String(data: nameData, encoding: .utf8) ?? String(decoding: nameData, as: UTF8.self)
            entries.append(Entry(
                path: path,
                compressionMethod: data.u16(at: offset + 10),
                compressedSize: Int(data.u32(at: offset + 20)),
                uncompressedSize: Int(data.u32(at: offset + 24)),
                localHeaderOffset: Int(data.u32(at: offset + 42))
            ))
            offset += 46 + nameLength + extraLength + commentLength
        }
        return entries
    }

    private func inflate(_ compressed: Data, expectedSize: Int, path: String) throws -> Data {
        // Zip "deflate" is raw DEFLATE, which is what COMPRESSION_ZLIB decodes.
        var destination = Data(count: max(expectedSize, 1))
        let written = destination.withUnsafeMutableBytes { dst -> Int in
            compressed.withUnsafeBytes { src -> Int in
                guard let d = dst.bindMemory(to: UInt8.self).baseAddress,
                      let s = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(d, dst.count, s, src.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written == expectedSize else { throw ZipError.corrupt(path) }
        return destination
    }

    private func u16(at offset: Int) -> UInt16 { data.u16(at: offset) }
    private func u32(at offset: Int) -> UInt32 { data.u32(at: offset) }
}

private extension Data {
    func u16(at offset: Int) -> UInt16 {
        let i = startIndex + offset
        return UInt16(self[i]) | UInt16(self[i + 1]) << 8
    }

    func u32(at offset: Int) -> UInt32 {
        let i = startIndex + offset
        return UInt32(self[i]) | UInt32(self[i + 1]) << 8 | UInt32(self[i + 2]) << 16 | UInt32(self[i + 3]) << 24
    }
}
