//
//  Dictionary+Equatable.swift
//  JSONUtilities
//
//  Created by Luciano Marisi on 08/05/2016.
//  Copyright © 2016 Luciano Marisi All rights reserved.
//

import Foundation

// Compares JSON values by their serialized form, so that the result doesn't depend on how each platform's
// Foundation bridges numbers and booleans (NSDictionary.isEqual differs between Darwin and Linux)
private func jsonEqual(_ lhs: Any, _ rhs: Any) -> Bool {
    guard let lhsData = try? JSONSerialization.data(withJSONObject: lhs, options: .sortedKeys),
        let rhsData = try? JSONSerialization.data(withJSONObject: rhs, options: .sortedKeys) else {
        return false
    }
    return lhsData == rhsData
}

public func == (lhs: [String: Any], rhs: [String: Any]) -> Bool {
    return jsonEqual(lhs, rhs)
}

public func == (lhs: [String: Any]?, rhs: [String: Any]?) -> Bool {
    guard let lhs = lhs, let rhs = rhs else { return false }
    return jsonEqual(lhs, rhs)
}

public func == (lhs: [[String: Any]], rhs: [[String: Any]]) -> Bool {
    return jsonEqual(lhs, rhs)
}

public func == (lhs: [[String: Any]]?, rhs: [[String: Any]]?) -> Bool {
    guard let lhs = lhs, let rhs = rhs else { return false }
    return jsonEqual(lhs, rhs)
}
