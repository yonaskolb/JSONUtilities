//
//  Dictionary+KeyPath.swift
//  JSONUtilities
//
//  Created by Luciano Marisi on 04/09/2016.
//  Copyright © 2016 Luciano Marisi All rights reserved.
//

import Foundation

extension Dictionary {

    /// Retrieves a value for a keyPath on the dictionary
    ///
    /// - parameter keyPath: A string of keys separated by dots
    ///
    /// - returns: Optionally returns a generic value for this keyPath or nil
    subscript(keyPath keyPath: KeyPath) -> Any? {
        guard let dictionary = self as? JSONDictionary else {
            return nil
        }
        return keyPath.getValue(dictionary: dictionary)
    }
}
