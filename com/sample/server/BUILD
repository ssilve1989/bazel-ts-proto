load("@npm//@bazel/typescript:index.bzl", "ts_library", "ts_project")
load("@build_bazel_rules_nodejs//:index.bzl", "nodejs_binary")

DEPS = [
    "@npm//@nestjs/core",
    "@npm//@nestjs/common",
    "@npm//@nestjs/microservices",
    "@npm//protobufjs",
    "@npm//@grpc/proto-loader",
    "@npm//grpc",
    "//com/sample/proto:sample_typescript_proto",
]

ts_library(
    name = "typescript-lib",
    srcs = glob(["**/*.ts"]),
    deps = DEPS,
)

nodejs_binary(
    name = "server-with-lib",
    args = ["--bazel_patch_module_resolver"],
    data = [
      ":typescript-lib",
      "//com/sample/proto:sample" # includes the proto in runfiles which is needed for Nest
    ],
    entry_point = ":main.ts",
)

ts_project(
    name = "typescript-project",
    srcs = glob(["**/*.ts"]),
    declaration = True,
    declaration_map = True,
    link_workspace_root = True,
    source_map = True,
    tsconfig = "//:tsconfig.json",
    deps = DEPS,
)

nodejs_binary(
    name = "server-with-project",
    args = ["--bazel_patch_module_resolver"],
    data = [
      ":typescript-project",
      "//com/sample/proto:sample" # includes the proto in runfiles which is needed for Nest
    ],
    entry_point = ":main.ts",
)
