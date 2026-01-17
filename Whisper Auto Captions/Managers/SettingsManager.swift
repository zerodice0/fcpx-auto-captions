//
//  SettingsManager.swift
//  Whisper Auto Captions
//
//  Manages application settings persistence and state
//

import Foundation
import SwiftUI

/// Manages WhisperSettings persistence using AppStorage
class SettingsManager: ObservableObject {
    // MARK: - Singleton
    static let shared = SettingsManager()

    // MARK: - Published Properties
    @Published var settings: WhisperSettings {
        didSet {
            saveSettings()
            updatePreset()
        }
    }

    @Published var currentPreset: WhisperPreset = .balanced {
        didSet {
            if currentPreset != .custom {
                applyPreset(currentPreset)
            }
        }
    }

    // MARK: - Storage Keys
    private enum StorageKeys {
        static let settings = "whisperSettings"
        static let preset = "whisperPreset"
    }

    // MARK: - UserDefaults
    private let defaults = UserDefaults.standard

    // MARK: - Initialization
    private init() {
        // Load settings from UserDefaults
        if let data = defaults.data(forKey: StorageKeys.settings),
           let decoded = try? JSONDecoder().decode(WhisperSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = WhisperSettings.default
        }

        // Load preset from UserDefaults
        if let presetRaw = defaults.string(forKey: StorageKeys.preset),
           let preset = WhisperPreset(rawValue: presetRaw) {
            self.currentPreset = preset
        } else {
            self.currentPreset = WhisperPreset.detect(from: settings)
        }
    }

    // MARK: - Persistence
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            defaults.set(encoded, forKey: StorageKeys.settings)
        }
        defaults.set(currentPreset.rawValue, forKey: StorageKeys.preset)
    }

    // MARK: - Preset Management
    private func updatePreset() {
        let detected = WhisperPreset.detect(from: settings)
        if detected != currentPreset && currentPreset != .custom {
            currentPreset = .custom
        }
    }

    func applyPreset(_ preset: WhisperPreset) {
        guard preset != .custom else { return }

        var newSettings = preset.settings
        // Preserve basic settings that shouldn't change with presets
        newSettings.model = settings.model
        newSettings.language = settings.language
        newSettings.fps = settings.fps
        newSettings.prompt = settings.prompt

        settings = newSettings
    }

    func resetToDefaults() {
        settings = WhisperSettings.default
        currentPreset = .balanced
    }

    // MARK: - Convenience Accessors
    var model: String {
        get { settings.model }
        set { settings.model = newValue }
    }

    var language: String {
        get { settings.language }
        set { settings.language = newValue }
    }

    var fps: String {
        get { settings.fps }
        set { settings.fps = newValue }
    }

    // MARK: - Settings Window State
    @Published var isSettingsWindowOpen = false

    func openSettings() {
        isSettingsWindowOpen = true
    }

    func closeSettings() {
        isSettingsWindowOpen = false
    }
}

// MARK: - Environment Key
struct SettingsManagerKey: EnvironmentKey {
    static let defaultValue: SettingsManager = SettingsManager.shared
}

extension EnvironmentValues {
    var settingsManager: SettingsManager {
        get { self[SettingsManagerKey.self] }
        set { self[SettingsManagerKey.self] = newValue }
    }
}
