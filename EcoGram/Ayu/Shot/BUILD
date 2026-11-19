load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AyuShot",
    module_name = "AyuShot",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//EcoGram/Strings:EcoStrings",
        "//EcoGram/Ayu/Badges:AyuBadges",
        "//submodules/WallpaperBackgroundNode:WallpaperBackgroundNode",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AccountContext:AccountContext",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/TelegramUI/Components/GlassBarButtonComponent:GlassBarButtonComponent",
        "//submodules/Components/BundleIconComponent:BundleIconComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
