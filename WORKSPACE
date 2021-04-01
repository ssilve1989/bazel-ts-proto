workspace(
    name = "bazel-ts",
    managed_directories = {"@npm": ["node_modules"]},
)

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "build_bazel_rules_nodejs",
    sha256 = "55a25a762fcf9c9b88ab54436581e671bc9f4f523cb5a1bd32459ebec7be68a8",
    urls = ["https://github.com/bazelbuild/rules_nodejs/releases/download/3.2.2/rules_nodejs-3.2.2.tar.gz"],
)

load("@build_bazel_rules_nodejs//:index.bzl", "node_repositories", "yarn_install")

node_repositories(
    node_repositories = {
        "14.15.1-darwin_amd64": ("node-v14.15.1-darwin-x64.tar.gz", "node-v14.15.1-darwin-x64", "9154d9c3f598d3efe6d163d160a7872ddefffc439be521094ccd528b63480611"),
        "14.15.1-linux_amd64": ("node-v14.15.1-linux-x64.tar.xz", "node-v14.15.1-linux-x64", "608732c7b8c2ac0683fee459847ad3993a428f0398c73555b9270345f4a64752"),
        "14.15.1-linux_arm64": ("node-v14.15.1-linux-arm64.tar.xz", "node-v14.15.1-linux-arm64", "32fa27df17194397c2ee931992e8a2fe41806fe790bd4083dece2b92679e4946"),
        "14.15.1-windows_amd64": ("node-v14.15.1-win-x64.zip", "node-v14.15.1-win-x64", "cb1ec98baf6f19e432250573c9aba9faa6b4104517b6a49b05aa5f507f6763fd"),
    },
    node_urls = [
        "https://nodejs.org/dist/v{version}/{filename}",
        "https://mirror.bazel.build/nodejs.org/dist/v{version}/{filename}",
    ],
    node_version = "14.15.1",
)

yarn_install(
    name = "npm",
    package_json = "//:package.json",
    yarn_lock = "//:yarn.lock",
)


http_archive(
    name = "com_google_protobuf",
    sha256 = "bf0e5070b4b99240183b29df78155eee335885e53a8af8683964579c214ad301",
    strip_prefix = "protobuf-3.14.0",
    urls = ["https://github.com/protocolbuffers/protobuf/archive/v3.14.0.zip"],
)

load("@com_google_protobuf//:protobuf_deps.bzl", "protobuf_deps")
protobuf_deps()
