-module(zeitgeist_http_ffi).
-export([ensure_inets/0, http_post/4]).

%% Ensure inets/ssl are started (idempotent)
ensure_inets() ->
    case inets:start() of
        ok -> ok;
        {error, {already_started, inets}} -> ok;
        {error, Reason} -> {error, Reason}
    end,
    case ssl:start() of
        ok -> ok;
        {error, {already_started, ssl}} -> ok;
        _ -> ok
    end,
    ok.

%% http_post(Url, Body, ContentType, TimeoutMs) -> {ok, Body} | {error, Reason}
http_post(Url, Body, ContentType, TimeoutMs) ->
    ensure_inets(),
    UrlStr = binary_to_list(Url),
    BodyBin = case is_binary(Body) of
        true -> Body;
        false -> list_to_binary(Body)
    end,
    ContentTypeStr = binary_to_list(ContentType),
    Request = {UrlStr, [], ContentTypeStr, BodyBin},
    HttpOpts = [{timeout, TimeoutMs}, {connect_timeout, TimeoutMs}],
    Opts = [{body_format, binary}],
    case httpc:request(post, Request, HttpOpts, Opts) of
        {ok, {{_, 200, _}, _Headers, RespBody}} ->
            {ok, RespBody};
        {ok, {{_, StatusCode, Reason}, _Headers, RespBody}} ->
            ErrMsg = io_lib:format("HTTP ~p ~s: ~s", [StatusCode, Reason, RespBody]),
            {error, list_to_binary(ErrMsg)};
        {error, Reason} ->
            ErrMsg = io_lib:format("~p", [Reason]),
            {error, list_to_binary(ErrMsg)}
    end.
