//
//  ServerConfiguration.swift
//  MockPad
//
//  Created by Olof Petterson on 2026-02-16.
//

import Foundation

enum ServerConfiguration {
    static var port: UInt16 {
        get {
            let value = UserDefaults.standard.integer(forKey: "serverPort")
            return value == 0 ? 8080 : UInt16(clamping: value)
        }
        set {
            UserDefaults.standard.set(Int(newValue), forKey: "serverPort")
        }
    }

    static var corsEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: "corsEnabled") == nil
                ? true
                : UserDefaults.standard.bool(forKey: "corsEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "corsEnabled")
        }
    }

    static var autoStart: Bool {
        get {
            UserDefaults.standard.object(forKey: "autoStart") == nil
                ? true
                : UserDefaults.standard.bool(forKey: "autoStart")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "autoStart")
        }
    }
}
