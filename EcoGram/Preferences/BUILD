load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "EcoPreferences",
    module_name = "EcoPreferences",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Swiftgram/SGSimpleSettings:SGSimpleSettings",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
