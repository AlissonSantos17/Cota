# Cota

Aplicativo macOS em SwiftUI para acompanhar cotações na barra de menus usando a AwesomeAPI.

## Requisitos
- macOS 13+
- Xcode 15+

## Abrir
1. Abra o projeto no Xcode: `open Package.swift`
2. Execute o projeto.

O app atualiza as cotações automaticamente a cada 5 minutos.

## Comandos
`make lint` precisa do [SwiftLint](https://github.com/realm/SwiftLint): `brew install swiftlint`.

```bash
make test      # testes
make build     # build debug
make format    # reescreve o Swift com swift-format
make lint      # checa format + SwiftLint
make rebuild   # build, codesign e abre o app
```
