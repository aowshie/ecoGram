load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AyuSettingsUI",
    module_name = "AyuSettingsUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//EcoGram/Ayu/Settings:AyuSettings",
        "//EcoGram/Ayu/History:AyuHistory",
        "//EcoGram/Strings:EcoStrings",
        "//EcoGram/ListUI:EcoListUI",
        "//Swiftgram/SGItemListUI:SGItemListUI",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Display:Display",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/ItemListPeerItem:ItemListPeerItem",
        "//submodules/ItemListPeerActionItem:ItemListPeerActionItem",
        "//submodules/SettingsUI:SettingsUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/AccountContext:AccountContext",
        "//submodules/LocalizedPeerData:LocalizedPeerData",
        "//submodules/ContextUI:ContextUI",
        "//submodules/AppBundle:AppBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)
