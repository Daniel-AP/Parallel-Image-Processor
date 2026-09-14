-module(ppm).
-export([read/1, write/2]).

%% Domain: A PPM file path
%% Codomain: { ok, { Width, Height, Rows } } or { error, Reason }

read(Path) ->
    case file:read_file(Path) of
        { ok, Binary } ->
            Tokens = string:tokens(binary_to_list(Binary), " \n\r\t"),
            parse_tokens(Tokens);
        { error, _ } -> { error, "Could not read input file" }
    end.

%% Domain: A PPM file path and an image
%% Codomain: ok or { error, Reason }

write(Path, { Width, Height, Rows }) ->
    PixelLines = [[integer_to_list(Red), " ", integer_to_list(Green), " ", integer_to_list(Blue), "\n"] || Row <- Rows, { Red, Green, Blue } <- Row],
    Contents = [
            "P3\n",
            integer_to_list(Width),
            " ",
            integer_to_list(Height),
            "\n255\n",
            PixelLines
        ],
    case file:write_file(Path, Contents) of
        ok -> ok;
        { error, _ } -> { error, "Could not write output file" }
    end.

%% Domain: Valid PPM tokens
%% Codomain: { ok, { Width, Height, Rows } }

parse_tokens(["P3", WidthText, HeightText, "255" | PixelTokens]) ->
    Width = list_to_integer(WidthText),
    Height = list_to_integer(HeightText),
    { ok, Pixels } = parse_pixels(PixelTokens),
    { ok, Rows } = group_rows(Pixels, Width),
    { ok, { Width, Height, Rows } }.

%% Domain: Valid RGB component strings
%% Codomain: { ok, Pixels }

parse_pixels([]) ->
    { ok, [] };

parse_pixels([RedText, GreenText, BlueText | Rest]) ->
    Red = list_to_integer(RedText),
    Green = list_to_integer(GreenText),
    Blue = list_to_integer(BlueText),
    { ok, Pixels } = parse_pixels(Rest),
    { ok, [{ Red, Green, Blue } | Pixels] }.

%% Domain: Pixels and a row width
%% Codomain: { ok, Rows }

group_rows([], _Width) ->
    { ok, [] };

group_rows(Pixels, Width) ->
    { Row, Rest } = lists:split(Width, Pixels),
    { ok, Rows } = group_rows(Rest, Width),
    { ok, [Row | Rows] }.

