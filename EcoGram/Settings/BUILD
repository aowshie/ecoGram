load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "EcoSettingsUI",
    module_name = "EcoSettingsUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//EcoGram/Preferences:EcoPreferences",
        "//EcoGram/Strings:EcoStrings",
        "//EcoGram/Badges:EcoBadges",
        "//EcoGram/Ayu/Badges:AyuBadges",
        "//EcoGram/Ayu/Settings:AyuSettings",
        "//EcoGram/Ayu/SettingsUI:AyuSettingsUI",
        "//EcoGram/ListUI:EcoListUI",
        "//Swiftgram/SGStrings:SGStrings",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/AppBundle:AppBundle",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/AccountContext:AccountContext",
        "//submodules/SettingsUI:SettingsUI",
        "//submodules/UndoUI:UndoUI",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/TelegramUI/Components/AlertComponent:AlertComponent",
        "//submodules/TelegramUI/Components/AlertComponent/AlertHeaderComponent:AlertHeaderComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
