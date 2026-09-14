-module(partition).
-export([halo_width/1, split/3]).

%% Domain: A filter configuration
%% Codomain: A halo width

halo_width(grayscale) ->
    0;

halo_width({ gaussian, KernelSize, _ }) ->
    (KernelSize - 1) div 2.

%% Domain: An image, process count and halo width
%% Codomain: { ok, Regions } or { error, Reason }

split(Image, ProcessCount, HaloWidth) ->
    { _, Height, _ } = Image,
    case ProcessCount > Height of
        true ->
            { error, "Process count cannot exceed image height" };
        false ->
            BaseSize = Height div ProcessCount,
            ExtraRows = Height rem ProcessCount,
            Ranges = build_ranges(1, ProcessCount, 0, BaseSize, ExtraRows),
            Regions = build_regions(Ranges, Image, HaloWidth),
            { ok, Regions }
    end.

%% Domain: Identifier, remaining ranges, row, base size and extra rows
%% Codomain: Ranges

build_ranges(_, 0, _, _, _) ->
    [];

build_ranges(Id, Remaining, NextRow, BaseSize, 0) ->
    Bottom = NextRow + BaseSize - 1,
    [
        { Id, NextRow, Bottom } |
        build_ranges(
            Id + 1,
            Remaining - 1,
            Bottom + 1,
            BaseSize,
            0
        )
    ];

build_ranges(Id, Remaining, NextRow, BaseSize, ExtraRows) ->
    Bottom = NextRow + BaseSize,
    [
        { Id, NextRow, Bottom } |
        build_ranges(
            Id + 1,
            Remaining - 1,
            Bottom + 1,
            BaseSize,
            ExtraRows - 1
        )
    ].

%% Domain: Ranges, an image and halo width
%% Codomain: Regions

build_regions([], _, _) ->
    [];

build_regions([Range | Rest], Image, HaloWidth) ->
    Region = build_region(Range, Image, HaloWidth),
    [Region | build_regions(Rest, Image, HaloWidth)].

%% Domain: A range, an image and halo width
%% Codomain: A region

build_region({ Id, Top, Bottom }, { Width, Height, Rows }, HaloWidth) ->
    HaloTop = max(0, Top - HaloWidth),
    HaloBottom = min(Height - 1, Bottom + HaloWidth),
    HaloHeight = HaloBottom - HaloTop + 1,
    Pixels = lists:sublist(Rows, HaloTop + 1, HaloHeight),
    #{
        id => Id,
        top_left => { 0, Top },
        bottom_right => { Width - 1, Bottom },
        halo_top_left => { 0, HaloTop },
        halo_bottom_right => { Width - 1, HaloBottom },
        pixels => Pixels
    }.
