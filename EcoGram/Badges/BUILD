load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "EcoBadges",
    module_name = "EcoBadges",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//EcoGram/Ayu/Badges:AyuBadges",
        "//EcoGram/Preferences:EcoPreferences",
        "//EcoGram/Strings:EcoStrings",
    ],
    visibility = [
        "//visibility:public",
    ],
)
