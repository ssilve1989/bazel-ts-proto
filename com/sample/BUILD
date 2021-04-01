load("@rules_proto//proto:defs.bzl", "proto_library")
load("//bazel_tools:typescript.bzl", "typescript_proto_library")


proto_library(
  name = "sample",
  srcs = glob(["*.proto"]),
  deps = [
    "@com_google_protobuf//:empty_proto",
  ]
)

typescript_proto_library(
  name = "sample_ts",
  proto = ":sample"
)
