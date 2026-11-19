//
//  URL+JSONPrimitiveConvertible.swift
//  JSONUtilities
//
//  Created by Sam Dods on 14/09/2016.
//  Copyright © 2016 Luciano Marisi. All rights reserved.
//

import Foundation

extension URL: JSONPrimitiveConvertible {

    public typealias JSONType = String

    /// Creates a URL from a string, in order to conform to JSONPrimitiveConvertible
    ///
    /// - parameter jsonValue: The string representation of a valid URL
    ///
    /// - returns: Returns a URL if the input string was successfully converted to a URL
    public static func from(jsonValue: String) -> URL? {
        #if canImport(Darwin)
        // Since macOS 14 and iOS 17, URL(string:) percent-encodes invalid characters instead of failing.
        // Keep rejecting invalid URL strings, as on older systems and on Linux.
        if #available(macOS 14, iOS 17, tvOS 17, watchOS 10, *) {
            return URL(string: jsonValue, encodingInvalidCharacters: false)
        }
        #endif
        return URL(string: jsonValue)
    }
}
