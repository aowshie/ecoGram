load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "EcoStorage",
    module_name = "EcoStorage",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//EcoGram/Ayu/Settings:AyuSettings",
        "//EcoGram/Strings:EcoStrings",
        "//EcoGram/AppIcon:EcoAppIcon",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/AccountContext:AccountContext",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/Components/ViewControllerComponent:ViewControllerComponent",
        "//submodules/Components/MultilineTextComponent:MultilineTextComponent",
        "//submodules/TelegramUI/Components/AnimatedTextComponent",
        "//submodules/TelegramUI/Components/SliderComponent",
        "//submodules/TelegramUI/Components/EdgeEffect",
        "//submodules/TelegramUI/Components/ListSectionComponent",
        "//submodules/TelegramUI/Components/ListActionItemComponent",
        "//submodules/TelegramUI/Components/StorageUsageScreen",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/RadialStatusNode",
        "//submodules/ContextUI",
        "//submodules/UndoUI",
        "//submodules/Markdown",
        "//submodules/AppBundle:AppBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)
