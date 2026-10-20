# Mudanças em arquivos existentes

Os arquivos novos estão em `Sources/` e `Tests/` deste pacote, nos mesmos caminhos do repositório. Abaixo, o que muda nos arquivos que já existem. Cada trecho mostra o que **sai** e o que **entra**.

---

## 1. `Sources/CotaKit/Stores/SettingsStore.swift`

Em `Keys`:
```swift
static let language = "appLanguage"
+ static let theme = "appTheme"
+ static let followsSystemAppearance = "themeFollowsSystem"
```

Depois de `language`:
```swift
/// Settings → Temas. Drawn by `ThemeController`, which also weighs the
/// system appearance when `followsSystemAppearance` is on.
@Published public var theme: AppTheme {
    didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
}

@Published public var followsSystemAppearance: Bool {
    didSet { defaults.set(followsSystemAppearance, forKey: Keys.followsSystemAppearance) }
}
```

Em `init`, depois de `self.language = …`:
```swift
self.theme =
    defaults.string(forKey: Keys.theme)
    .flatMap(AppTheme.init(rawValue:)) ?? .cota
self.followsSystemAppearance = defaults.bool(forKey: Keys.followsSystemAppearance)
```

## 2. `Sources/Cota/CotaApp.swift`

Em `init()`, depois de criar `settings`:
```swift
ThemeController.shared.attach(to: settings)
```

## 3. `Sources/Cota/Views/PanelView.swift`

```swift
@ObservedObject private var panelState = PanelState.shared
+ @ObservedObject private var theme = ThemeController.shared
```

No `body`:
```swift
- .background(CotaTheme.night)
+ .background(ThemeSurface(CotaTheme.night, in: RoundedRectangle(cornerRadius: CotaTheme.Radius.panel)))
  …
- .environment(\.colorScheme, .dark)
+ .environment(\.colorScheme, CotaTheme.palette.colorScheme)
  …
- .id(settings.language)
+ .id(ThemeKey(language: settings.language, theme: theme.active))
```

## 4. `Sources/Cota/Views/SettingsView.swift`

Seções:
```swift
case menuBar
+ case themes
case alerts
```
Em `title`, acrescente `case .themes: return L10n.t("settings.themes")`. Em `icon`, acrescente `case .themes: return "paintpalette"`. Em `count(for:)`, `.themes` entra junto com `.general, .menuBar` e retorna `nil`.

Em `SettingsView`:
```swift
@ObservedObject var navigation: SettingsNavigation
+ @ObservedObject private var theme = ThemeController.shared
```

No `body`:
```swift
- .background(CotaTheme.window)
+ .background(ThemeSurface(CotaTheme.window))
  …
- .environment(\.colorScheme, .dark)
+ .environment(\.colorScheme, CotaTheme.palette.colorScheme)
  …
- .id(settings.language)
+ .id(ThemeKey(language: settings.language, theme: theme.active))
```

Na barra lateral, `.background(CotaTheme.sidebar)` continua. No Glass, `sidebar` é um véu branco de 6% sobre o vidro da janela.

Em `content`:
```swift
- .background(CotaTheme.window)
+ .background(Color.clear) // a janela já pinta o fundo; no Glass, um segundo fundo apagaria o vidro
```
E no `switch`:
```swift
case .themes:
    ThemesSection(settings: settings, store: store)
```

## 5. `Sources/Cota/Views/AddPairSheet.swift`

```swift
- .background(CotaTheme.sheet)
+ .background(ThemeSurface(CotaTheme.sheet, in: SheetShape(open: true)))
```
O `AlertRows.swift` (popover do seletor de par, linha 203) recebe a mesma troca: `.background(ThemeSurface(CotaTheme.sheet))`.

## 6. `Sources/Cota/SettingsWindowController.swift`

```swift
+ import Combine
  …
  private let navigation: SettingsNavigation
+ private var themeObservation: AnyCancellable?
```

Em `init`, troque:
```swift
- // Dark only: a light variant has not been designed yet.
- window.appearance = NSAppearance(named: .darkAqua)
- window.backgroundColor = NSColor(CotaTheme.window)
```
Depois de `super.init(window: window)`:
```swift
applyTheme()
themeObservation = ThemeController.shared.$active
    .receive(on: RunLoop.main)
    .sink { [weak self] _ in self?.applyTheme() }
```
E o método:
```swift
/// The window's own chrome: the title bar's appearance and what shows
/// behind the SwiftUI content. On glass the window has to be clear, or the
/// material has nothing to blur.
private func applyTheme() {
    guard let window else { return }
    let palette = CotaTheme.palette
    window.appearance = palette.appearance
    window.isOpaque = !palette.isGlass
    window.backgroundColor = palette.isGlass ? .clear : NSColor(CotaTheme.window)
}
```

## 7. `Sources/Cota/Views/MenuBarSettingsSection.swift`

Nenhuma mudança obrigatória: a faixa de prévia já lê `CotaTheme.menuBarStrip`. O texto da prévia usa branco fixo; troque por `CotaTheme.palette.theme == .light ? Color(hex: 0x111714) : .white` para o tema Claro.

## 8. Strings

Acrescente o conteúdo de `Resources/*/Localizable.strings.append` ao fim de `Sources/CotaKit/Resources/pt-BR.lproj/Localizable.strings` e de `…/en.lproj/Localizable.strings`. O `LocalizationTests` já confere se as duas línguas têm as mesmas chaves.
