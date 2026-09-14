-module(scheme_bridge).
-export([process_region/2]).

%% Domain: A region and execution configuration
%% Codomain: { ok, ProcessedRegion } or { error, Reason }

process_region(Region, Configuration) ->
    case create_worker_paths(maps:get(id, Region)) of
        { ok, WorkerPaths } ->
            Result = case ppm:write(maps:get(input, WorkerPaths), region_image(maps:get(pixels, Region))) of
                ok ->
                    Arguments = build_arguments(
                        Region,
                        Configuration,
                        WorkerPaths
                    ),
                    case run_scheme(Arguments, WorkerPaths) of
                        { ok, _ } ->
                            read_result(
                                maps:get(output, WorkerPaths),
                                Region
                            );
                        SchemeError -> SchemeError
                    end;
                WriteError -> WriteError
            end,
            cleanup_worker_files(WorkerPaths),
            Result;
        WorkerPathError -> WorkerPathError
    end.

%% Domain: A region identifier
%% Codomain: { ok, WorkerPaths } or { error, Reason }

create_worker_paths(Id) ->
    Directory = filename:join(
        "/tmp",
        lists:concat([
            "parallel_image_processor_",
            integer_to_list(Id),
            "_",
            integer_to_list(erlang:unique_integer([positive]))
        ])
    ),
    case file:make_dir(Directory) of
        ok ->
            { ok,
                #{
                    directory => Directory,
                    input => filename:join(Directory, "scheme_worker_input"),
                    output => filename:join(Directory, "scheme_worker_output"),
                    status => filename:join(Directory, "scheme_worker_status")
                }
            };
        { error, _ } -> { error, "Could not create temporary worker directory" }
    end.

%% Domain: Pixel rows
%% Codomain: An image

region_image(Pixels) ->
    [FirstRow | _] = Pixels,
    { length(FirstRow), length(Pixels), Pixels }.

%% Domain: A region, configuration and worker paths
%% Codomain: Scheme command-line arguments

build_arguments(
    #{
        top_left := { Left, Top },
        bottom_right := { Right, Bottom },
        halo_top_left := { HaloLeft, HaloTop }
    },
    #{ filter := { gaussian, KernelSize, Sigma } },
    #{ input := InputPath, output := OutputPath, status := StatusPath }
) ->
    [
        InputPath,
        OutputPath,
        StatusPath,
        "gaussian",
        integer_to_list(KernelSize),
        float_to_list(Sigma + 0.0),
        integer_to_list(Left - HaloLeft),
        integer_to_list(Top - HaloTop),
        integer_to_list(Right - HaloLeft),
        integer_to_list(Bottom - HaloTop)
    ];

build_arguments(
    #{
        top_left := { Left, Top },
        bottom_right := { Right, Bottom },
        halo_top_left := { HaloLeft, HaloTop }
    },
    #{ filter := grayscale },
    #{ input := InputPath, output := OutputPath, status := StatusPath }
) ->
    [
        InputPath,
        OutputPath,
        StatusPath,
        "grayscale",
        integer_to_list(Left - HaloLeft),
        integer_to_list(Top - HaloTop),
        integer_to_list(Right - HaloLeft),
        integer_to_list(Bottom - HaloTop)
    ].

%% Domain: Scheme command-line arguments and worker paths
%% Codomain: { ok, Diagnostics } or { error, Reason }

run_scheme(Arguments, #{ status := StatusPath }) ->
    Diagnostics = os:cmd(build_command(Arguments)),
    case file:read_file(StatusPath) of
        { ok, <<"ok">> } -> { ok, Diagnostics };
        _ -> { error, lists:flatten(["Scheme worker failed: ", Diagnostics]) }
    end.

%% Domain: Scheme command-line arguments
%% Codomain: A shell command

build_command(Arguments) ->
    lists:flatten([
        "racket 'scheme/worker.scm' ",
        string:join(
            [lists:flatten(["'", Argument, "'"]) || Argument <- Arguments],
            " "
        )
    ]).

%% Domain: A Scheme output path and region
%% Codomain: { ok, ProcessedRegion } or { error, Reason }

read_result(OutputPath, Region) ->
    case ppm:read(OutputPath) of
        { ok, { Width, Height, Pixels } } ->
            #{
                id := Id,
                top_left := { Left, Top },
                bottom_right := { Right, Bottom }
            } = Region,
            case { Width, Height } =:= { Right - Left + 1, Bottom - Top + 1 } of
                true ->
                    { ok,
                        #{
                            id => Id,
                            top_left => { Left, Top },
                            bottom_right => { Right, Bottom },
                            pixels => Pixels
                        }
                    };
                false -> { error, "Scheme output dimensions do not match region" }
            end;
        ReadError -> ReadError
    end.

%% Domain: Worker paths
%% Codomain: ok

cleanup_worker_files(#{
    directory := Directory,
    input := InputPath,
    output := OutputPath,
    status := StatusPath
}) ->
    file:delete(InputPath),
    file:delete(OutputPath),
    file:delete(StatusPath),
    file:del_dir(Directory),
    ok.
