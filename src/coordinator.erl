-module(coordinator).
-export([run/1]).

%% Domain: An execution configuration
%% Codomain: { ok, ElapsedSeconds } or { error, Reason }

run(Configuration) ->
    StartTime = erlang:monotonic_time(microsecond),
    case ppm:read(maps:get(input_path, Configuration)) of
        { ok, Image } ->
            Filter = maps:get(filter, Configuration),
            ProcessCount = maps:get(process_count, Configuration),
            HaloWidth = partition:halo_width(Filter),
            case partition:split(Image, ProcessCount, HaloWidth) of
                { ok, Regions } ->
                    PendingWorkers = spawn_workers(Regions, Configuration),
                    case collect_results(PendingWorkers, []) of
                        { ok, ProcessedRegions } ->
                            case reconstruct(Image, ProcessedRegions) of
                                { ok, ProcessedImage } ->
                                    case ppm:write(maps:get(output_path, Configuration), ProcessedImage) of
                                        ok ->
                                            {
                                                ok,
                                                (
                                                    erlang:monotonic_time(microsecond) - StartTime
                                                ) / 1000000
                                            };
                                        WriteError -> WriteError
                                    end;
                                ReconstructionError -> ReconstructionError
                            end;
                        WorkerError -> WorkerError
                    end;
                PartitionError -> PartitionError
            end;
        ReadError -> ReadError
    end.

%% Domain: Regions and an execution configuration
%% Codomain: Pending workers

spawn_workers([], _) ->
    [];

spawn_workers([Region | Rest], Configuration) ->
    [spawn_worker(Region, Configuration) | spawn_workers(Rest, Configuration)].

%% Domain: A region and execution configuration
%% Codomain: A pending worker

spawn_worker(Region, Configuration) ->
    CoordinatorPid = self(),
    { Pid, Reference } = spawn_monitor(
        fun() -> worker:run(CoordinatorPid, Region, Configuration) end
    ),
    { maps:get(id, Region), Pid, Reference }.

%% Domain: Pending workers and processed regions
%% Codomain: { ok, ProcessedRegions } or { error, Reason }

collect_results([], Results) ->
    { ok, Results };

collect_results(PendingWorkers, Results) ->
    receive
        { region_completed, Id, ProcessedRegion } ->
            case remove_pending_worker(Id, PendingWorkers) of
                { { Id, _, Reference }, RemainingWorkers } ->
                    erlang:demonitor(Reference, [flush]),
                    collect_results(
                        RemainingWorkers,
                        [ProcessedRegion | Results]
                    );
                false ->
                    cancel_workers(PendingWorkers),
                    { error, "Received an invalid worker result" }
            end;
        { 'DOWN', _, process, _, Reason } ->
            cancel_workers(PendingWorkers),
            {
                error,
                lists:flatten(io_lib:format("Worker failed: ~p", [Reason]))
            }
    end.

%% Domain: A region identifier and pending workers
%% Codomain: { PendingWorker, RemainingWorkers } or false

remove_pending_worker(_, []) ->
    false;

remove_pending_worker(Id, [{ Id, Pid, Reference } | Rest]) ->
    { { Id, Pid, Reference }, Rest };

remove_pending_worker(Id, [PendingWorker | Rest]) ->
    case remove_pending_worker(Id, Rest) of
        { FoundWorker, RemainingWorkers } -> { FoundWorker, [PendingWorker | RemainingWorkers] };
        false -> false
    end.

%% Domain: Pending workers
%% Codomain: ok

cancel_workers([]) ->
    ok;

cancel_workers([{ _, Pid, Reference } | Rest]) ->
    exit(Pid, kill),
    erlang:demonitor(Reference, [flush]),
    cancel_workers(Rest).

%% Domain: The original image and processed regions
%% Codomain: { ok, Image } or { error, Reason }

reconstruct({ Width, Height, _ }, ProcessedRegions) ->
    OrderedRegions = order_results(ProcessedRegions),
    case collect_rows(OrderedRegions, 0, Height) of
        { ok, Rows } -> { ok, { Width, Height, Rows } };
        CollectionError -> CollectionError
    end.

%% Domain: Processed regions
%% Codomain: Processed regions ordered by row

order_results(ProcessedRegions) ->
    lists:sort(
        fun(Left, Right) ->
            { _, LeftTop } = maps:get(top_left, Left),
            { _, RightTop } = maps:get(top_left, Right),
            LeftTop < RightTop
        end,
        ProcessedRegions
    ).

%% Domain: Ordered regions, expected row and height
%% Codomain: { ok, Rows } or { error, Reason }

collect_rows([], Height, Height) ->
    { ok, [] };

collect_rows([], _, _) ->
    { error, "Processed regions do not cover image" };

collect_rows(
    [
        #{
            top_left := { _, Top },
            bottom_right := { _, Bottom },
            pixels := Rows
        } | Rest
    ],
    NextTop,
    Height
) ->
    case Top =:= NextTop of
        true ->
            case collect_rows(Rest, Bottom + 1, Height) of
                { ok, RemainingRows } ->
                    { ok, Rows ++ RemainingRows };
                CollectionError -> CollectionError
            end;
        false -> { error, "Processed regions are not in order" }
    end.
