//
//  ScreenshotManager.swift
//  Fuwari
//
//  Created by Kengo Yokoyama on 2018/07/01.
//  Copyright © 2018年 AppKnop. All rights reserved.
//

import Cocoa
import Darwin

class ScreenshotManager: NSObject {

    static let shared = ScreenshotManager()

    private let captureRectAttribute = "com.apple.metadata:kMDItemScreenCaptureGlobalRect"
    
    private let defaults = UserDefaults.standard
    
    private var tapCount = 0

    private var eventHandler: ((URL, NSRect?, SpaceMode) -> Void)?

    func eventHandler(eventHandler: @escaping (URL, NSRect?, SpaceMode) -> Void) {
        self.eventHandler = eventHandler
    }

    func startCapture(spaceMode: SpaceMode) {
        tapCount += 1

        let fileUrl = FileManager.default.temporaryDirectory.appendingPathComponent("fuwari-temporary-screenshot.png")
        let captureProcess = Process()
        let pipe = Pipe()
        captureProcess.launchPath = "/usr/sbin/screencapture"
        captureProcess.arguments = ["-x", "-i", "-o"] + [fileUrl.path]
        captureProcess.environment = ["OS_ACTIVITY_DT_MODE": "YES"]
        captureProcess.standardError = pipe
        captureProcess.terminationHandler = { task in
            guard task.terminationStatus == 0 else { return }
            let output = pipe.fileHandleForReading.availableData
            let str = String(decoding: output, as: UTF8.self)
            let rect = self.extractCoordinates(from: fileUrl) ?? self.extractCoordinates(str: str)
            DispatchQueue.main.async { [weak self] in
                guard let tapCount = self?.tapCount else { return }
                if (tapCount == 1) {
                    guard let singleTapCaptureMode = self?.defaults.integer(forKey: Constants.UserDefaults.singleTapCaptureMode) else { return }
                    self?.eventHandler?(fileUrl, rect, SpaceMode(rawValue: singleTapCaptureMode) ?? .all)
                } else {
                    guard let doubleTapCaptureMode = self?.defaults.integer(forKey: Constants.UserDefaults.doubleTapCaptureMode) else { return }
                    self?.eventHandler?(fileUrl, rect, SpaceMode(rawValue: doubleTapCaptureMode) ?? .current)
                }
                self?.tapCount = 0
            }
        }
        captureProcess.launch()
    }

    func extractCoordinates(from fileUrl: URL) -> NSRect? {
        let data = fileUrl.path.withCString { filePath in
            captureRectAttribute.withCString { attributeName -> Data? in
                let size = getxattr(filePath, attributeName, nil, 0, 0, 0)
                guard size > 0 else { return nil }

                var data = Data(count: size)
                let bytesRead = data.withUnsafeMutableBytes { buffer in
                    getxattr(filePath, attributeName, buffer.baseAddress, buffer.count, 0, 0)
                }
                guard bytesRead == size else { return nil }
                return data
            }
        }

        guard
            let data = data,
            let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [NSNumber],
            values.count == 4
        else {
            return nil
        }

        return NSRect(
            x: values[0].doubleValue,
            y: values[1].doubleValue,
            width: values[2].doubleValue,
            height: values[3].doubleValue
        )
    }

    func extractCoordinates(str: String) -> NSRect? {
        // Note, not found when capturing a window, rather than a selection
        let capturePattern = #"captureRect = \((?<x>-?[\d.]+), (?<y>-?[\d.]+), (?<width>[\d.]+), (?<height>[\d.]+)\)"#
        guard let match = Regex.match(str: str, regexPattern: capturePattern) else {
            return nil
        }

        let getIntFromRegexGroup = {(name: String) throws -> Int in
            Int(round(Float(try Regex.getGroup(match: match, name: name, str: str))!))
        }

        do {
            return try NSRect(
                x: getIntFromRegexGroup("x"),
                y: getIntFromRegexGroup("y"),
                width: getIntFromRegexGroup("width"),
                height: getIntFromRegexGroup("height")
            )
        } catch RegexError.missingGroup(let name) {
            print("missing group: \(name)")
            return nil
        } catch {
            return nil
        }
    }
}
