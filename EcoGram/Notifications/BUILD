load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "EcoNotifications",
    module_name = "EcoNotifications",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//EcoGram/Preferences:EcoPreferences",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AppLockState:AppLockState",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/LocalizedPeerData:LocalizedPeerData",
    ],
    visibility = [
        "//visibility:public",
    ],
)
