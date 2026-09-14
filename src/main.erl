-module(main).
-export([main/1]).

%% Domain: Command-line arguments
%% Codomain: No return

main(Arguments) ->
    case parse_arguments(Arguments) of
        { ok, Configuration } ->
            case coordinator:run(Configuration) of
                { ok, ElapsedSeconds } ->
                    io:format("Completed in ~p seconds.~n", [ElapsedSeconds]),
                    erlang:halt(0);
                { error, Reason } ->
                    io:format("Error: ~s~n", [Reason]),
                    erlang:halt(1)
            end;
        { error, Reason } ->
            io:format("Error: ~s~n", [Reason]),
            erlang:halt(1)
    end.

%% Domain: Command-line arguments
%% Codomain: { ok, Configuration } or { error, Reason }

parse_arguments([InputPath, OutputPath, ProcessText]) ->
    case parse_positive_integer(ProcessText, "Process count") of
        { ok, ProcessCount } ->
            case InputPath =:= OutputPath of
                true -> { error, "Input and output paths must be different" };
                false ->
                    {
                        ok,
                        #{
                            input_path => InputPath,
                            output_path => OutputPath,
                            process_count => ProcessCount,
                            filter => { gaussian, 3, 0.8493 }
                        }
                    }
            end;
        ProcessError -> ProcessError
    end;

parse_arguments([InputPath, OutputPath, ProcessText, FilterText]) ->
    case parse_filter(FilterText) of
        { ok, grayscale } ->
            case parse_positive_integer(ProcessText, "Process count") of
                { ok, ProcessCount } ->
                    case InputPath =:= OutputPath of
                        true -> { error, "Input and output paths must be different" };
                        false ->
                            {
                                ok,
                                #{
                                    input_path => InputPath,
                                    output_path => OutputPath,
                                    process_count => ProcessCount,
                                    filter => grayscale
                                }
                            }
                    end;
                ProcessError -> ProcessError
            end;
        { ok, gaussian } -> { error, "Gaussian requires a kernel size and sigma" };
        FilterError -> FilterError
    end;

parse_arguments([InputPath, OutputPath, ProcessText, FilterText, KernelText, SigmaText]) ->
    case parse_filter(FilterText) of
        { ok, gaussian } ->
            case parse_positive_integer(ProcessText, "Process count") of
                { ok, ProcessCount } ->
                    case parse_positive_integer(KernelText, "Kernel size") of
                        { ok, KernelSize } when KernelSize >= 3, KernelSize rem 2 =:= 1 ->
                            case parse_positive_number(SigmaText, "Sigma") of
                                { ok, Sigma } ->
                                    case InputPath =:= OutputPath of
                                        true -> { error, "Input and output paths must be different" };
                                        false ->
                                            {
                                                ok,
                                                #{
                                                    input_path => InputPath,
                                                    output_path => OutputPath,
                                                    process_count => ProcessCount,
                                                    filter => { gaussian, KernelSize, Sigma }
                                                }
                                            }
                                    end;
                                SigmaError -> SigmaError
                            end;
                        { ok, _ } -> { error, "Kernel size must be odd and at least 3" };
                        KernelError -> KernelError
                    end;
                ProcessError -> ProcessError
            end;
        { ok, grayscale } -> { error, "Grayscale does not use a kernel size or sigma" };
        FilterError -> FilterError
    end;

parse_arguments(_) ->
    { error, "Invalid argument count" }.

%% Domain: Text and field name
%% Codomain: { ok, PositiveInteger } or { error, Reason }

parse_positive_integer(Text, FieldName) ->
    case string:to_integer(Text) of
        { Integer, [] } when Integer > 0 -> { ok, Integer };
        _ -> { error, lists:concat(["Invalid positive integer for ", FieldName]) }
    end.

%% Domain: Text and field name
%% Codomain: { ok, PositiveNumber } or { error, Reason }

parse_positive_number(Text, FieldName) ->
    case string:to_float(Text) of
        { Number, [] } when Number > 0 -> { ok, Number };
        _ ->
            case string:to_integer(Text) of
                { Integer, [] } when Integer > 0 -> { ok, Integer };
                _ -> { error, lists:concat(["Invalid positive number for ", FieldName]) }
            end
    end.

%% Domain: Filter name
%% Codomain: { ok, gaussian | grayscale } or { error, Reason }

parse_filter("gaussian") ->
    { ok, gaussian };

parse_filter("grayscale") ->
    { ok, grayscale };

parse_filter(Text) ->
    { error, lists:concat(["Unsupported filter: ", Text]) }.
