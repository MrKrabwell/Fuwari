//
//  ViewController.swift
//  Fuwari
//
//  Created by Kengo Yokoyama on 2016/11/29.
//  Copyright © 2016年 AppKnop. All rights reserved.
//

import Cocoa
import Quartz

class ViewController: NSViewController {

    private var windowControllers = [FloatWindow]()
    private var isCancelled = false
    private var oldApp: NSRunningApplication?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(startCapture), name: Notification.Name(rawValue: Constants.Notification.capture), object: nil)
        
        oldApp = NSWorkspace.shared.frontmostApplication
        oldApp?.activate(options: .activateIgnoringOtherApps)
        
        ScreenshotManager.shared.eventHandler {
            imageUrl in
            let currentScreen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            guard let currentScaleFactor = currentScreen?.backingScaleFactor else { return }
            let mouseLocation = NSEvent.mouseLocation
            let ciImage = CIImage(contentsOf: imageUrl)?.copy() as? CIImage
            let context = CIContext(options: nil)
            let cgImage = context.createCGImage(ciImage!, from: ciImage!.extent)
            
            self.createFloatWindow(rect: NSRect(x: Int(mouseLocation.x) - cgImage!.width / Int(2 * currentScaleFactor), y: Int(mouseLocation.y) - cgImage!.height / Int(2 * currentScaleFactor), width: Int(CGFloat(cgImage!.width) / currentScaleFactor), height: Int(CGFloat(cgImage!.height) / currentScaleFactor)), image: cgImage!)
            try? FileManager.default.removeItem(at: imageUrl)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name(rawValue: Constants.Notification.capture), object: nil)
    }
    
    private func createFloatWindow(rect: NSRect, image: CGImage) {
        let floatWindow = FloatWindow(contentRect: rect, image: image)
        floatWindow.floatDelegate = self
        windowControllers.append(floatWindow)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func startCapture() {
        ScreenshotManager.shared.startCapture()
    }
}

extension ViewController: FloatDelegate {
    func close(floatWindow: FloatWindow) {
        if !isCancelled {
            if windowControllers.filter({ $0 === floatWindow }).first != nil {
                floatWindow.fadeWindow(isIn: false) {
                    guard let index = self.windowControllers.index(where: {$0 === floatWindow}) else { return }
                    self.windowControllers.remove(at: index)
                    self.windowControllers.last?.makeKey()
                }
            }
        }
        isCancelled = false

        if windowControllers.count == 0 {
            oldApp?.activate(options: .activateIgnoringOtherApps)
        }        
    }

    func save(floatWindow: FloatWindow, image: CGImage) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        savePanel.nameFieldStringValue = "screenshot-\(formatter.string(from: Date()))"
        savePanel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.modalPanelWindow)))
        let saveOptions = IKSaveOptions(imageProperties: [:], imageUTType: kUTTypePNG as String?)
        saveOptions?.addAccessoryView(to: savePanel)
        
        let result = savePanel.runModal()
        if result == .OK {
            if let url = savePanel.url as CFURL?, let type = saveOptions?.imageUTType as CFString? {
                guard let destination = CGImageDestinationCreateWithURL(url, type, 1, nil) else { return }
                CGImageDestinationAddImage(destination, image, saveOptions!.imageProperties! as CFDictionary)
                CGImageDestinationFinalize(destination)
            }
        }
    }
}
