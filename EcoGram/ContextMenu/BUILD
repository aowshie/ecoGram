load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "EcoContextMenu",
    module_name = "EcoContextMenu",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//EcoGram/Preferences:EcoPreferences",
        "//EcoGram/Strings:EcoStrings",
        "//Swiftgram/SGStrings:SGStrings",
        "//submodules/ContextUI:ContextUI",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
    ],
    visibility = [
        "//visibility:public",
    ],
)
