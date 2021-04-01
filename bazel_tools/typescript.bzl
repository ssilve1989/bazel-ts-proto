load("@build_bazel_rules_nodejs//:providers.bzl", "DeclarationInfo", "JSModuleInfo", "JSNamedModuleInfo")
load("@rules_proto//proto:defs.bzl", "ProtoInfo")

typescript_proto_library_aspect = provider(
    fields = {
        "deps_dts": "The transitive dependencies' TS definitions",
        "deps_es5": "The transitive ES5 JS dependencies",
        "dts_outputs": "Ths TS definition files produced directly from the src protos",
        "es5_outputs": "The ES5 JS files produced directly from the src protos",
    },
)

def _proto_path(proto):
    """
    The proto path is not really a file path, it's the path to the proto that was seen when the descriptor file was generated.
    """
    path = proto.path
    root = proto.root.path
    ws = proto.owner.workspace_root
    if path.startswith(root):
        path = path[len(root):]
    if path.startswith("/"):
        path = path[1:]
    if path.startswith(ws) and len(ws) > 0:
        path = path[len(ws):]
    if path.startswith("/"):
        path = path[1:]
    if path.startswith("_virtual_imports/"):
        path = path.split("/")[2:]
        path = "/".join(path)
    return path

# TODO(dan): Replace with |proto_common.direct_source_infos| when
# https://github.com/bazelbuild/rules_proto/pull/22 lands.
# Derived from https://github.com/grpc-ecosystem/grpc-gateway/blob/e8db07a3923d3f5c77dbcea96656afe43a2757a8/protoc-gen-swagger/defs.bzl#L11
# buildifier: disable=function-docstring-header
def _direct_source_infos(proto_info, provided_sources = []):
    """Returns sequence of `ProtoFileInfo` for `proto_info`'s direct sources.
    Files that are both in `proto_info`'s direct sources and in
    `provided_sources` are skipped. This is useful, e.g., for well-known
    protos that are already provided by the Protobuf runtime.
    Args:
      proto_info: An instance of `ProtoInfo`.
      provided_sources: Optional. A sequence of files to ignore.
          Usually, these files are already provided by the
          Protocol Buffer runtime (e.g. Well-Known protos).
    Returns: A sequence of `ProtoFileInfo` containing information about
        `proto_info`'s direct sources.
    """

    source_root = proto_info.proto_source_root
    if "." == source_root:
        return [struct(file = src, import_path = src.path) for src in proto_info.direct_sources]

    offset = len(source_root) + 1  # + '/'.

    infos = []
    for src in proto_info.direct_sources:
        infos.append(struct(file = src, import_path = src.path[offset:]))

    return infos

def _get_protoc_inputs(target, ctx):
    inputs = []
    inputs += target[ProtoInfo].direct_sources
    inputs += target[ProtoInfo].transitive_descriptor_sets.to_list()
    return inputs

def _build_protoc_nestjs_command(target, ctx):
    protoc_command = "%s" % (ctx.executable._protoc.path)
    tsc_command = "%s --declaration --lib es2018" % (ctx.executable._tsc.path)

    protoc_command += " --plugin=protoc-gen-ts_proto=%s" % (ctx.executable._protoc_gen_ts_proto.path)

    protoc_output_dir = ctx.bin_dir.path + "/" + ctx.label.workspace_root
    protoc_command += " --ts_proto_out=generate_package_definition:%s" % (protoc_output_dir)
    protoc_command += " --ts_proto_opt=addGrpcMetadata=true"
    protoc_command += " --ts_proto_opt=nestJs=true"
    protoc_command += " --ts_proto_opt=outputEncodeMethods=true,outputJsonMethods=false,outputClientImpl=false"
    protoc_command += " --ts_proto_opt=addNestjsRestParameter=true"

    descriptor_sets_paths = [desc.path for desc in target[ProtoInfo].transitive_descriptor_sets.to_list()]

    pathsep = ctx.configuration.host_path_separator
    protoc_command += " --descriptor_set_in=\"%s\"" % (pathsep.join(descriptor_sets_paths))

    proto_file_infos = _direct_source_infos(target[ProtoInfo])
    for f in proto_file_infos:
        protoc_command += " %s" % f.import_path
        tsc_command += " %s" % protoc_output_dir + "/" + f.import_path.replace(".proto", ".ts")

    # filter out the DONE response on stderr from protoc
    return "%s 2> >(grep -v DONE >&2) && %s" % (protoc_command, tsc_command)

def _get_outputs(target, ctx):
    """
    Calculates all of the files that will be generated by the aspect.
    """
    js_outputs = []
    dts_outputs = []
    protos = []

    for src in target[ProtoInfo].direct_sources:
        build_dir = "/".join(ctx.build_file_path.split("/")[:-1])

        if ctx.label.workspace_root == "":
            file_name = src.short_path.replace(build_dir + "/", "")[:-len(src.extension) - 1]
            # protos.append(ctx.actions.declare_file(file_name + ".proto"))
        else:
            file_name = _proto_path(src)[:-len(src.extension) - 1]

        output = ctx.actions.declare_file(file_name + ".js")
        js_outputs.append(output)
        output_d_ts = ctx.actions.declare_file(file_name + ".d.ts")
        dts_outputs.append(output_d_ts)

    print(dts_outputs)
    return [js_outputs, dts_outputs, protos]

# buildifier: disable=function-docstring-return
# buildifier: disable=function-docstring-args
# buildifier: disable=uninitialized
def ts_proto_library_nestjs_aspect_(target, ctx):
    """
      A bazel aspect that is applied on every proto_library rule on the transitive set of dependencies of a ts_proto_library rule. Handles running protoc to produce the generated JS and TS files.
    """

    [js_outputs, dts_outputs, protos] = _get_outputs(target, ctx)
    protoc_outputs = dts_outputs + js_outputs + protos

    all_commands = [
        _build_protoc_nestjs_command(target, ctx),
    ]

    tools = []
    tools.extend(ctx.files._protoc)
    tools.extend(ctx.files._protoc_gen_ts_proto)
    tools.extend(ctx.files._tsc)

    if len(protoc_outputs) == 0:
        return [
            typescript_proto_library_aspect(
                dts_outputs = depset([]),
                es5_outputs = depset([]),
                deps_dts = depset(transitive = []),
                deps_es5 = depset(transitive = []),
            ),
        ]

    ctx.actions.run_shell(
        inputs = depset(
            direct = _get_protoc_inputs(target, ctx),
            transitive = [depset(ctx.files._well_known_protos), depset(ctx.files._ts_proto_deps)],
        ),
        outputs = protoc_outputs,
        progress_message = "generating files for NestJS %s" % ctx.label,
        command = " && ".join(all_commands),
        tools = depset(tools),
    )

    dts_outputs = depset(dts_outputs)
    es5_outputs = depset(js_outputs)
    deps_dts = []
    deps_es5 = []

    for dep in ctx.rule.attr.deps:
        aspect_data = dep[typescript_proto_library_aspect]
        deps_dts.append(aspect_data.dts_outputs)
        deps_dts.append(aspect_data.deps_dts)
        deps_es5.append(aspect_data.es5_outputs)
        deps_es5.append(aspect_data.deps_es5)

    return [typescript_proto_library_aspect(
        dts_outputs = dts_outputs,
        es5_outputs = es5_outputs,
        deps_dts = depset(transitive = deps_dts),
        deps_es5 = depset(transitive = deps_es5),
    )]

ts_proto_library_nestjs_aspect = aspect(
    implementation = ts_proto_library_nestjs_aspect_,
    attr_aspects = ["deps"],
    attrs = {
        "_ts_proto_deps": attr.label_list(
            allow_files = True,
            default = [
                "@npm//@nestjs/common",
                "@npm//@nestjs/core",
                "@npm//@nestjs/microservices",
                "@npm//@types/bytebuffer",
                "@npm//@types/node",
                "@npm//axios",
                "@npm//grpc",
                "@npm//long",
                "@npm//protobufjs",
                "@npm//rxjs",
            ],
        ),
        "_protoc": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "host",
            default = Label("@com_google_protobuf//:protoc"),
        ),
        "_protoc_gen_ts_proto": attr.label(
            allow_files = True,
            executable = True,
            cfg = "host",
            default = Label("@npm//ts-proto/bin:protoc-gen-ts_proto"),
        ),
        "_tsc": attr.label(
            allow_files = True,
            executable = True,
            cfg = "host",
            default = Label("@npm//typescript/bin:tsc"),
        ),
        "_well_known_protos": attr.label(
            default = "@com_google_protobuf//:well_known_protos",
            allow_files = True,
        ),
    },
)

# buildifier: disable=rule-impl-return
def _ts_proto_library_nestjs_impl(ctx):
    """
    Handles converting the aspect output into a provider compatible with the rules_typescript rules.
    """
    aspect_data = ctx.attr.proto[typescript_proto_library_aspect]
    dts_outputs = aspect_data.dts_outputs
    transitive_declarations = depset(transitive = [dts_outputs, aspect_data.deps_dts])
    es5_outputs = aspect_data.es5_outputs
    outputs = depset(transitive = [es5_outputs, dts_outputs])

    es5_srcs = depset(transitive = [es5_outputs, aspect_data.deps_es5])
    return struct(
        typescript = struct(
            declarations = dts_outputs,
            transitive_declarations = transitive_declarations,
            es5_sources = es5_srcs,
            transitive_es5_sources = es5_srcs,
            transitive_es6_sources = depset(),
        ),
        providers = [
            DefaultInfo(files = outputs),
            DeclarationInfo(
                declarations = dts_outputs,
                transitive_declarations = transitive_declarations,
                type_blacklisted_declarations = depset([]),
            ),
            JSModuleInfo(
                direct_sources = es5_srcs,
                sources = es5_srcs,
            ),
            JSNamedModuleInfo(
                direct_sources = es5_srcs,
                sources = es5_srcs,
            ),
        ],
    )

typescript_proto_library = rule(
    attrs = {
        "proto": attr.label(
            allow_single_file = True,
            aspects = [ts_proto_library_nestjs_aspect],
            mandatory = True,
            providers = [ProtoInfo],
        ),
    },
    implementation = _ts_proto_library_nestjs_impl,
)
