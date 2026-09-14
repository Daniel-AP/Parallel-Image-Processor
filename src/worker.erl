-module(worker).
-export([run/3]).

%% Domain: A coordinator PID, region and configuration
%% Codomain: No return

run(CoordinatorPid, Region, Configuration) ->
    case scheme_bridge:process_region(Region, Configuration) of
        { ok, ProcessedRegion } ->
            CoordinatorPid ! { region_completed,
                maps:get(id, Region),
                ProcessedRegion
            },
            exit(normal);
        { error, Reason } -> exit(Reason)
    end.
