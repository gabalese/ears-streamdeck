// Stream Deck plugin: toggle Ears' InstaMute and show the current microphone mute state.
//
// State is read from CoreAudio (mute flag of the default input device), which is
// what Ears itself sets. Toggling goes through Ears' InstaMute hotkey, because Ears
// keeps its own "should be muted" state and re-asserts it if the flag is changed
// behind its back.

import AppKit
import ApplicationServices
import CoreAudio
import Foundation

// MARK: - Arguments

var args: [String: String] = [:]
do {
    let a = CommandLine.arguments
    var i = 1
    while i + 1 < a.count { args[a[i]] = a[i + 1]; i += 2 }
}
guard let port = args["-port"], let pluginUUID = args["-pluginUUID"], let registerEvent = args["-registerEvent"] else {
    FileHandle.standardError.write("Usage: -port N -pluginUUID X -registerEvent Y -info JSON\n".data(using: .utf8)!)
    exit(1)
}

let actionUUID = "it.alese.ears.mute.toggle"
let stateLive = 0, stateMuted = 1

// MARK: - WebSocket

let session = URLSession(configuration: .default)
let socket = session.webSocketTask(with: URL(string: "ws://127.0.0.1:\(port)")!)

func send(_ obj: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: obj),
          let text = String(data: data, encoding: .utf8) else { return }
    socket.send(.string(text)) { err in if err != nil { exit(0) } }
}

let debugLog = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/ElgatoStreamDeck/ears-plugin-debug.log")
func log(_ msg: String) {
    send(["event": "logMessage", "payload": ["message": "[ears] \(msg)"]])
    let line = "\(Date()) \(msg)\n"
    if let h = try? FileHandle(forWritingTo: debugLog) { h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close() }
    else { try? line.write(to: debugLog, atomically: true, encoding: .utf8) }
}

// MARK: - CoreAudio

var contexts = Set<String>()
var currentDevice = AudioDeviceID(0)
var muteAddr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute,
                                          mScope: kAudioDevicePropertyScopeInput,
                                          mElement: kAudioObjectPropertyElementMain)
var defaultInputAddr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                                  mScope: kAudioObjectPropertyScopeGlobal,
                                                  mElement: kAudioObjectPropertyElementMain)

func defaultInputDevice() -> AudioDeviceID {
    var id = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultInputAddr, 0, nil, &size, &id)
    return id
}

func isMuted() -> Bool {
    guard currentDevice != 0, AudioObjectHasProperty(currentDevice, &muteAddr) else { return false }
    var v = UInt32(0)
    var size = UInt32(4)
    return AudioObjectGetPropertyData(currentDevice, &muteAddr, 0, nil, &size, &v) == noErr && v != 0
}

func pushState(to only: String? = nil) {
    let state = isMuted() ? stateMuted : stateLive
    log("state -> \(state == stateMuted ? "muted" : "live") (device \(currentDevice), keys \(contexts.count))")
    for ctx in only.map({ [$0] }) ?? Array(contexts) {
        send(["event": "setState", "context": ctx, "payload": ["state": state]])
    }
}

let muteListener: AudioObjectPropertyListenerBlock = { _, _ in pushState() }

func bindDefaultInput() {
    let dev = defaultInputDevice()
    if dev == currentDevice { return }
    if currentDevice != 0 {
        AudioObjectRemovePropertyListenerBlock(currentDevice, &muteAddr, DispatchQueue.main, muteListener)
    }
    currentDevice = dev
    log("default input changed to device \(dev), has mute: \(AudioObjectHasProperty(dev, &muteAddr))")
    if dev != 0 && AudioObjectHasProperty(dev, &muteAddr) {
        AudioObjectAddPropertyListenerBlock(dev, &muteAddr, DispatchQueue.main, muteListener)
    }
    pushState()
}

AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultInputAddr, DispatchQueue.main) { _, _ in
    bindDefaultInput()
}

// MARK: - Ears InstaMute hotkey

/// Reads Ears' InstaMute shortcut (a keyed-archived MASShortcut) from its preferences.
func instaMuteShortcut() -> (keyCode: CGKeyCode, flags: CGEventFlags)? {
    guard let data = CFPreferencesCopyAppValue("kInstaMuteShortcut" as CFString, "com.clickontyler.Ears" as CFString) as? Data,
          let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
          let objects = plist["$objects"] as? [Any] else { return nil }
    for case let o as [String: Any] in objects {
        if let code = o["KeyCode"] as? Int, let mods = o["ModifierFlags"] as? Int {
            // NSEvent and CGEvent modifier masks share bit positions for shift/ctrl/alt/cmd.
            let relevant: UInt64 = CGEventFlags.maskShift.rawValue | CGEventFlags.maskControl.rawValue
                | CGEventFlags.maskAlternate.rawValue | CGEventFlags.maskCommand.rawValue
            return (CGKeyCode(code), CGEventFlags(rawValue: UInt64(mods) & relevant))
        }
    }
    return nil
}

let scriptQueue = DispatchQueue(label: "ears.applescript")

func toggle(context: String) {
    guard let shortcut = instaMuteShortcut() else {
        log("No InstaMute shortcut found in Ears preferences. Set one in Ears > Preferences > InstaMute.")
        send(["event": "showAlert", "context": context])
        return
    }
    // Raw CGEvents don't trigger Ears' hotkey; keystrokes sent through System Events do.
    var mods: [String] = []
    if shortcut.flags.contains(.maskShift) { mods.append("shift down") }
    if shortcut.flags.contains(.maskControl) { mods.append("control down") }
    if shortcut.flags.contains(.maskAlternate) { mods.append("option down") }
    if shortcut.flags.contains(.maskCommand) { mods.append("command down") }
    let source = "tell application \"System Events\" to key code \(shortcut.keyCode)"
        + (mods.isEmpty ? "" : " using {\(mods.joined(separator: ", "))}")
    log("toggle: \(source) (muted before: \(isMuted()))")
    scriptQueue.async {
        var err: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&err)
        DispatchQueue.main.async {
            if let err {
                // -1743: Automation (System Events) denied; -1719 / 1002: Accessibility denied.
                log("AppleScript failed: \(err). Allow Stream Deck under System Settings > Privacy & Security > Accessibility and > Automation > System Events.")
                send(["event": "showAlert", "context": context])
            }
        }
        // The CoreAudio listener updates the key; re-check in case nothing changed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { log("muted after: \(isMuted())"); pushState(to: context) }
    }
}

// MARK: - Event loop

func handle(_ text: String) {
    guard let data = text.data(using: .utf8),
          let msg = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let event = msg["event"] as? String else { return }
    let context = msg["context"] as? String
    log("event \(event) context=\(context ?? "-") action=\(msg["action"] as? String ?? "-")")
    switch event {
    case "willAppear":
        if let c = context { contexts.insert(c); pushState(to: c) }
    case "willDisappear":
        if let c = context { contexts.remove(c) }
    case "keyDown":
        if let c = context { toggle(context: c) }
    case "keyUp":
        if let c = context { pushState(to: c) }
    case "systemDidWakeUp":
        bindDefaultInput(); pushState()
    default:
        break
    }
}

func receive() {
    socket.receive { result in
        switch result {
        case .failure:
            exit(0) // Stream Deck went away
        case .success(let message):
            if case .string(let text) = message { DispatchQueue.main.async { handle(text) } }
            receive()
        }
    }
}

socket.resume()
send(["event": registerEvent, "uuid": pluginUUID])
receive()
DispatchQueue.main.async { bindDefaultInput() }
dispatchMain()
