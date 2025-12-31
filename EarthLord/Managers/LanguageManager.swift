//
//  LanguageManager.swift
//  EarthLord
//
//  Created by enyu on 2025/12/31.
//

import Foundation
import SwiftUI
import Combine
import ObjectiveC

/// 语言选项枚举
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"      // 跟随系统
    case zhHans = "zh-Hans"     // 简体中文
    case en = "en"              // English

    var id: String { rawValue }

    /// 显示名称
    var displayName: String {
        switch self {
        case .system:
            return "跟随系统"
        case .zhHans:
            return "简体中文"
        case .en:
            return "English"
        }
    }

    /// 获取实际的语言代码（用于加载 Bundle）
    var languageCode: String? {
        switch self {
        case .system:
            return nil // 返回 nil 表示使用系统语言
        case .zhHans:
            return "zh-Hans"
        case .en:
            return "en"
        }
    }
}

/// 语言管理器
/// 负责 App 内语言切换，不依赖系统设置
class LanguageManager: ObservableObject {

    // MARK: - 单例

    static let shared = LanguageManager()

    // MARK: - 发布属性

    /// 当前选择的语言
    @Published var currentLanguage: AppLanguage {
        didSet {
            saveLanguagePreference()
            updateBundle()
            print("🌐 [语言] 切换到: \(currentLanguage.displayName)")
        }
    }

    /// 当前使用的本地化 Bundle
    @Published private(set) var bundle: Bundle = .main

    // MARK: - 私有属性

    private let languageKey = "app_language_preference"

    // MARK: - 初始化

    private init() {
        // 从 UserDefaults 读取保存的语言设置
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
            print("🌐 [语言] 从存储恢复语言设置: \(language.displayName)")
        } else {
            self.currentLanguage = .system
            print("🌐 [语言] 使用默认设置: 跟随系统")
        }

        // 初始化 Bundle 和 AppleLanguages
        updateBundle()
        setupAppleLanguages()
    }

    // MARK: - 公开方法

    /// 获取本地化字符串
    /// - Parameter key: 本地化 key
    /// - Returns: 本地化后的字符串
    func localizedString(_ key: String) -> String {
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    /// 获取本地化字符串（带格式化参数）
    /// - Parameters:
    ///   - key: 本地化 key
    ///   - arguments: 格式化参数
    /// - Returns: 本地化后的字符串
    func localizedString(_ key: String, arguments: CVarArg...) -> String {
        let format = bundle.localizedString(forKey: key, value: nil, table: nil)
        return String(format: format, arguments: arguments)
    }

    // MARK: - 私有方法

    /// 保存语言偏好到 UserDefaults
    private func saveLanguagePreference() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)

        // 同时设置 AppleLanguages 以影响 SwiftUI 的本地化
        if let languageCode = currentLanguage.languageCode {
            UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        } else {
            // 跟随系统：移除自定义设置
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }

        UserDefaults.standard.synchronize()
        print("🌐 [语言] 已保存语言偏好: \(currentLanguage.rawValue)")
    }

    /// 更新本地化 Bundle
    private func updateBundle() {
        if let languageCode = currentLanguage.languageCode {
            // 使用指定语言
            if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                self.bundle = bundle
                // 同时设置 Bundle swizzling 以支持 SwiftUI Text
                Bundle.setLanguage(languageCode)
                print("🌐 [语言] 加载语言包: \(languageCode)")
            } else if languageCode == "zh-Hans" {
                // 中文是源语言，没有单独的 .lproj 文件夹
                // 使用主 bundle（包含源语言字符串）
                self.bundle = .main
                Bundle.setLanguage(nil) // 使用默认/源语言
                print("🌐 [语言] 使用源语言（简体中文）")
            } else {
                // 如果找不到对应的语言包，回退到主 Bundle
                self.bundle = .main
                Bundle.setLanguage(nil)
                print("⚠️ [语言] 未找到语言包 \(languageCode)，使用默认")
            }
        } else {
            // 跟随系统
            self.bundle = .main
            Bundle.setLanguage(nil)
            print("🌐 [语言] 跟随系统语言")
        }
    }

    /// 初始化时设置 AppleLanguages
    private func setupAppleLanguages() {
        if let languageCode = currentLanguage.languageCode {
            UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }

    /// 获取当前实际使用的语言代码
    var effectiveLanguageCode: String {
        if let code = currentLanguage.languageCode {
            return code
        }
        // 跟随系统时，获取系统首选语言
        return Locale.preferredLanguages.first ?? "en"
    }
}

// MARK: - 本地化字符串扩展

extension String {
    /// 使用 LanguageManager 获取本地化字符串
    var localized: String {
        return LanguageManager.shared.localizedString(self)
    }

    /// 使用 LanguageManager 获取本地化字符串（带格式化参数）
    func localized(_ arguments: CVarArg...) -> String {
        let format = LanguageManager.shared.localizedString(self)
        return String(format: format, arguments: arguments)
    }
}

// MARK: - SwiftUI 本地化 Text 视图

/// 支持动态语言切换的 Text 视图
struct LocalizedText: View {
    @ObservedObject private var languageManager = LanguageManager.shared
    let key: String

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        Text(languageManager.localizedString(key))
    }
}

// MARK: - Bundle 扩展（用于运行时语言切换）

private var bundleKey: UInt8 = 0

extension Bundle {
    /// 获取当前语言对应的本地化 Bundle
    static var localizedBundle: Bundle {
        if let languageCode = LanguageManager.shared.currentLanguage.languageCode,
           let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return Bundle.main
    }

    /// 设置自定义语言 Bundle（用于 swizzling）
    static func setLanguage(_ language: String?) {
        defer {
            object_setClass(Bundle.main, language != nil ? LocalizedBundle.self : Bundle.self)
        }

        if let language = language,
           let path = Bundle.main.path(forResource: language, ofType: "lproj") {
            objc_setAssociatedObject(Bundle.main, &bundleKey, path, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        } else {
            objc_setAssociatedObject(Bundle.main, &bundleKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

/// 自定义 Bundle 子类，重写本地化字符串方法
private class LocalizedBundle: Bundle {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let path = objc_getAssociatedObject(self, &bundleKey) as? String,
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}
