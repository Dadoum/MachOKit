//
//  MachOFile+CodeSign.swift
//
//
//  Created by p-x9 on 2024/03/03.
//
//

import Foundation
import MachOKitC

extension MachOFile {
    public struct CodeSign {
        public let data: Data
        public let isSwapped: Bool // bigEndian => false
    }
}

extension MachOFile.CodeSign: CodeSignProtocol {
    public var superBlob: CodeSignSuperBlob? {
        data.withUnsafeBytes {
            guard let basePtr = $0.baseAddress else { return nil }
            var layout = basePtr.assumingMemoryBound(to: CS_SuperBlob.self).pointee
            if isSwapped { layout = layout.swapped }
            return .init(
                layout: layout,
                offset: 0
            )
        }
    }

    public var codeDirectories: [CodeSignCodeDirectory] {
        data.withUnsafeBytes { bufferPointer in
            guard let baseAddress = bufferPointer.baseAddress,
                  let superBlob else {
                return []
            }
            let blobIndices = superBlob.blobIndices(in: self)
            return blobIndices
                .compactMap {
                    let offset: Int = numericCast($0.offset)
                    let ptr = baseAddress.advanced(by: offset)
                    let _blob = ptr.assumingMemoryBound(to: CS_GenericBlob.self).pointee
                    let blob = CodeSignGenericBlob(
                        layout: isSwapped ? _blob.swapped : _blob
                    )
                    guard blob.magic == .codedirectory else {
                        return nil
                    }
                    return (
                        ptr.assumingMemoryBound(to: CS_CodeDirectory.self).pointee,
                        offset
                    )
                }
                .map {
                    isSwapped ? .init(layout: $0.swapped, offset: $1)
                    : .init(layout: $0, offset: $1)
                }
        }
    }

    public var embeddedEntitlementsData: Data? {
        guard let superBlob else {
            return nil
        }
        let blobIndices = superBlob.blobIndices(in: self)
        guard let index = blobIndices.first(
            where: { $0.type == .entitlements }
        ) else {
            return nil
        }
        return blobData(
            in: superBlob,
            at: index,
            includesGenericInfo: false
        )
    }

    public var embeddedEntitlements: [String: Any]? {
        guard let embeddedEntitlementsData else {
            return nil
        }
        guard let entitlements = try? PropertyListSerialization.propertyList(
            from: embeddedEntitlementsData,
            format: nil
        ) else {
            return nil
        }
        return entitlements as? [String: Any]
    }

    public var embeddedDEREntitlementsData: Data? {
        guard let superBlob else {
            return nil
        }
        let blobIndices = superBlob.blobIndices(in: self)
        guard let index = blobIndices.first(
            where: { $0.type == .der_entitlements }
        ) else {
            return nil
        }
        return blobData(
            in: superBlob,
            at: index,
            includesGenericInfo: false
        )
    }

    public var signatureData: Data? {
        guard let superBlob else {
            return nil
        }
        let blobIndices = superBlob.blobIndices(in: self)
        guard let index = blobIndices.first(
            where: { $0.type == .signatureslot }
        ) else {
            return nil
        }
        return blobData(
            in: superBlob,
            at: index,
            includesGenericInfo: false
        )
    }

    public var requirementsBlob: CodeSignSuperBlob? {
        guard let superBlob else {
            return nil
        }
        let blobIndices = superBlob.blobIndices(in: self)
        guard let index = blobIndices.first(
            where: { $0.type == .requirements }
        ) else {
            return nil
        }
        return data.withUnsafeBytes { bufferPointer in
            guard let baseAddress = bufferPointer.baseAddress else {
                return nil
            }
            let offset: Int = numericCast(index.offset)
            let ptr = baseAddress.advanced(by: offset)
            var _blob = ptr
                .assumingMemoryBound(to: CS_SuperBlob.self)
                .pointee
            if isSwapped { _blob = _blob.swapped }

            return .init(
                layout: _blob,
                offset: offset
            )
        }
    }

    public var requirementsData: [Data] {
        guard let requirementsBlob else {
            return []
        }
        let indices = requirementsBlob.blobIndices(in: self)
        return indices.compactMap {
            blobData(
                in: requirementsBlob,
                at: $0,
                includesGenericInfo: true
            )
        }
    }
}

extension MachOFile.CodeSign {
    /// Get blob data as `Data`
    /// - Parameters:
    ///   - superBlob: SuperBlob to which index belongs
    ///   - index: Index of the blob to be gotten
    ///   - includesGenericInfo: A boolean value that indicates whether the data defined in the ``CodeSignGenericBlob``, such as magic and length, are included or not.
    /// - Returns: Data of blob
    ///
    /// Note that when converting from this data to other blob models, byte swapping must be performed appropriately for the ``MachOFile.CodeSign.isSwapped`` parameter.
    public func blobData(
        in superBlob: CodeSignSuperBlob,
        at index: CodeSignBlobIndex,
        includesGenericInfo: Bool = true
    ) -> Data? {
        data.withUnsafeBytes { bufferPointer in
            guard let baseAddress = bufferPointer.baseAddress else {
                return nil
            }
            let offset: Int = numericCast(superBlob.offset) + numericCast(index.offset)
            let ptr = baseAddress.advanced(by: offset)
            guard let _blob: CodeSignGenericBlob = .load(
                from: ptr,
                isSwapped: isSwapped
            ) else { return nil }

            let data = Data(
                bytes: ptr,
                count: numericCast(_blob.length)
            )
            if includesGenericInfo {
                return data
            } else {
                return data.advanced(by: CodeSignGenericBlob.layoutSize)
            }
        }
    }
}
