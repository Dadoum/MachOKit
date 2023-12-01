//
//  CPU.swift
//
//
//  Created by p-x9 on 2023/11/29.
//  
//

import Foundation

public struct CPU {
    public let typeRawValue: cpu_type_t
    public let subtypeRawValue: cpu_subtype_t

    public var type: CPUType? {
        .init(rawValue: typeRawValue)
    }

    public var subtype: CPUSubType? {
        if let type {
            let subtypeRaw = (cpu_subtype_t(subtypeRawValue) & cpu_subtype_t(~CPU_SUBTYPE_MASK))
            return .init(rawValue: subtypeRaw, of: type)
        }
        return nil
    }
}

extension CPU: CustomStringConvertible {
    public var description: String {
        let type = type?.description ?? "unknown\(typeRawValue)"
        let subtype = subtype?.description ?? "unknown"

        return "\(type)(\(subtype))"
    }
}
