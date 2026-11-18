load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AyuBadges",
    module_name = "AyuBadges",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//EcoGram/Ayu/Settings:AyuSettings",
    ],
    visibility = [
        "//visibility:public",
    ],
)
