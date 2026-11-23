import Foundation
import SwiftSignalKit
import Display
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext

struct AyuShotAppearance {
    let theme: PresentationTheme
    let wallpaper: TelegramWallpaper
}

func ayuShotAppearance(context: AccountContext, theme: AyuShotTheme) -> Signal<AyuShotAppearance, NoError> {
    let current = context.sharedContext.currentPresentationData.with { $0 }
    let currentAppearance = AyuShotAppearance(theme: current.theme, wallpaper: current.chatWallpaper)
    if case .app = theme {
        return .single(currentAppearance)
    }
    let accountManager = context.sharedContext.accountManager
    return accountManager.sharedData(keys: Set([ApplicationSpecificSharedDataKeys.presentationThemeSettings]))
    |> take(1)
    |> map { sharedData -> AyuShotAppearance in
        let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings]?.get(PresentationThemeSettings.self) ?? PresentationThemeSettings.defaultSettings
        let resolve: (PresentationThemeReference, TelegramBaseTheme?) -> AyuShotAppearance? = { reference, baseTheme in
            let colors = settings.themeSpecificAccentColors[reference.index]
            guard let theme = makePresentationTheme(mediaBox: accountManager.mediaBox, themeReference: reference, baseTheme: baseTheme, accentColor: colors?.colorFor(baseTheme: baseTheme ?? .day), bubbleColors: colors?.customBubbleColors ?? [], baseColor: colors?.baseColor) else {
                return nil
            }
            var wallpaper = (settings.themeSpecificChatWallpapers[coloredThemeIndex(reference: reference, accentColor: colors)] ?? settings.themeSpecificChatWallpapers[reference.index]) ?? theme.chat.defaultWallpaper
            if case .builtin = wallpaper {
                wallpaper = defaultBuiltinWallpaper(data: .legacy, colors: legacyBuiltinWallpaperGradientColors.map(\.rgb))
            }
            return AyuShotAppearance(theme: theme, wallpaper: wallpaper)
        }
        switch theme {
        case .app:
            return currentAppearance
        case .day:
            let reference = settings.theme
            let preferred = settings.themePreferredBaseTheme[reference.index]
            let baseTheme: TelegramBaseTheme? = preferred.flatMap { [.classic, .day].contains($0) ? $0 : nil }
            if let appearance = resolve(reference, baseTheme), !appearance.theme.overallDarkAppearance {
                return appearance
            }
            return resolve(.builtin(.dayClassic), nil) ?? currentAppearance
        case .night:
            let reference = settings.automaticThemeSwitchSetting.theme
            let preferred = settings.themePreferredBaseTheme[reference.index]
            let baseTheme: TelegramBaseTheme = preferred.flatMap { [.night, .tinted].contains($0) ? $0 : nil } ?? .night
            if let appearance = resolve(reference, baseTheme), appearance.theme.overallDarkAppearance {
                return appearance
            }
            return resolve(.builtin(.night), .night) ?? currentAppearance
        }
    }
}
