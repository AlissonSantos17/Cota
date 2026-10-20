import Foundation

/// The language picked in Settings → General → Language.
///
/// `system` follows macOS; the other two force a language without a restart.
/// Anything that is not Portuguese falls back to English, the only other
/// language the app ships.
public enum AppLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case ptBR = "pt-BR"
    case en

    public var id: String { rawValue }

    public var locale: Locale {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "pt-BR"
            return Locale(identifier: preferred.hasPrefix("pt") ? "pt_BR" : "en_US")
        case .ptBR:
            return Locale(identifier: "pt_BR")
        case .en:
            return Locale(identifier: "en_US")
        }
    }

    /// The `.lproj` folder the strings are read from.
    public var lproj: String {
        locale.identifier.hasPrefix("pt") ? "pt-BR" : "en"
    }

    /// Named in its own language, so someone who landed on the wrong one can
    /// still find the way back.
    public var label: String {
        switch self {
        case .system: return L10n.t("general.language.system")
        case .ptBR: return L10n.t("general.language.ptBR")
        case .en: return L10n.t("general.language.en")
        }
    }
}

/// String lookup that honours the person's choice, not only the system
/// language. SwiftUI's `Text("key")` resolves against the system language and
/// ignores the choice, which is why views go through `L10n.t`.
public enum L10n {
    /// Portuguese until the settings say otherwise: it is the package's
    /// development language, and a fixed starting point keeps formatting the
    /// same on every machine the tests run on.
    public static var language: AppLanguage = .ptBR {
        didSet { bundle = makeBundle(for: language) }
    }

    private static var bundle = makeBundle(for: language)

    /// SwiftPM's native build system (Swift 6.1 and the CI) writes the folder
    /// as `pt-br.lproj`; the newer one keeps `pt-BR.lproj`. Bundle lookups
    /// match case exactly, so both spellings are tried — without the second,
    /// Portuguese silently fell back to English.
    private static func makeBundle(for language: AppLanguage) -> Bundle {
        let names = [language.lproj, language.lproj.lowercased()]
        for name in names {
            if let path = Bundle.module.path(forResource: name, ofType: "lproj"),
                let bundle = Bundle(path: path)
            {
                return bundle
            }
        }
        return .module
    }

    public static func t(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    public static func t(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), locale: language.locale, arguments: args)
    }

    /// The same lookup in a language other than the current one, for tests
    /// and for anything that has to show both side by side.
    public static func t(_ key: String, in language: AppLanguage) -> String {
        makeBundle(for: language).localizedString(forKey: key, value: nil, table: nil)
    }

    /// The localized name of a currency, or its code when there is none.
    public static func currencyName(_ code: String) -> String {
        let key = "currency.\(code)"
        let name = t(key)
        return name == key ? code : name
    }
}
