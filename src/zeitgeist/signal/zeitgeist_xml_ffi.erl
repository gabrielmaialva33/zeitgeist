-module(zeitgeist_xml_ffi).
-export([http_get/2, parse_rss/1]).

%% http_get(Url, TimeoutMs) -> {ok, Body} | {error, Reason}
http_get(Url, TimeoutMs) ->
    case inets:start() of
        ok -> ok;
        {error, {already_started, inets}} -> ok;
        _ -> ok
    end,
    case ssl:start() of
        ok -> ok;
        {error, {already_started, ssl}} -> ok;
        _ -> ok
    end,
    UrlStr = binary_to_list(Url),
    HttpOpts = [{timeout, TimeoutMs}, {connect_timeout, TimeoutMs}],
    Opts = [{body_format, binary}],
    case httpc:request(get, {UrlStr, []}, HttpOpts, Opts) of
        {ok, {{_, 200, _}, _Headers, Body}} ->
            {ok, Body};
        {ok, {{_, StatusCode, Reason}, _Headers, _Body}} ->
            ErrMsg = io_lib:format("HTTP ~p: ~s", [StatusCode, Reason]),
            {error, list_to_binary(ErrMsg)};
        {error, Reason} ->
            ErrMsg = io_lib:format("~p", [Reason]),
            {error, list_to_binary(ErrMsg)}
    end.

%% parse_rss(XmlBin) -> [{Title, Link, Description}]
%% Uses regex extraction, NOT a DOM parser — works on both RSS 2.0 and Atom
parse_rss(XmlBin) ->
    Xml = to_list(XmlBin),
    %% Detect Atom vs RSS
    IsAtom = (re:run(Xml, "<feed", [{capture, none}]) == match),
    case IsAtom of
        true  -> parse_atom(Xml);
        false -> parse_rss2(Xml)
    end.

%% Convert to list regardless of input type
to_list(B) when is_binary(B) -> binary_to_list(B);
to_list(L) when is_list(L)   -> L.

%% --- RSS 2.0 ---
parse_rss2(Xml) ->
    Items = split_tags(Xml, "<item", "</item>"),
    [extract_rss_item(I) || I <- Items].

extract_rss_item(Item) ->
    Title = first_tag(Item, "title"),
    Link  = first_tag(Item, "link"),
    Desc  = first_tag(Item, "description"),
    {list_to_binary(strip_html(Title)),
     list_to_binary(strip_html(Link)),
     list_to_binary(strip_html(Desc))}.

%% --- Atom ---
parse_atom(Xml) ->
    Entries = split_tags(Xml, "<entry", "</entry>"),
    [extract_atom_entry(E) || E <- Entries].

extract_atom_entry(Entry) ->
    Title   = first_tag(Entry, "title"),
    Link    = atom_link(Entry),
    Summary = first_tag_fallback(Entry, "summary", first_tag(Entry, "content")),
    {list_to_binary(strip_html(Title)),
     list_to_binary(Link),
     list_to_binary(strip_html(Summary))}.

%% Extract href from <link href="..." /> or <link ...>URL</link>
atom_link(Entry) ->
    case re:run(Entry, "<link[^>]+href=[\"']([^\"']+)[\"']", [{capture, [1], list}]) of
        {match, [Href]} -> Href;
        _ ->
            first_tag(Entry, "link")
    end.

%% --- Helpers ---

%% split_tags(Xml, OpenTag, CloseTag) -> [String]
split_tags(Xml, OpenTag, CloseTag) ->
    case re:split(Xml, OpenTag, [{return, list}]) of
        [_ | Parts] ->
            lists:filtermap(fun(Part) ->
                case re:split(Part, CloseTag, [{return, list}]) of
                    [Inner | _] -> {true, OpenTag ++ Inner ++ CloseTag};
                    _ -> false
                end
            end, Parts);
        _ -> []
    end.

%% first_tag(Xml, Tag) -> string — content of first <Tag>...</Tag> (handles CDATA)
first_tag(Xml, Tag) ->
    %% Try CDATA first
    CDataPat = "<" ++ Tag ++ "[^>]*><!\\[CDATA\\[([\\s\\S]*?)\\]\\]></" ++ Tag ++ ">",
    PlainPat = "<" ++ Tag ++ "[^>]*>([^<]*)</" ++ Tag ++ ">",
    case re:run(Xml, CDataPat, [{capture, [1], list}, dotall]) of
        {match, [CData]} ->
            string:strip(CData);
        _ ->
            case re:run(Xml, PlainPat, [{capture, [1], list}, dotall]) of
                {match, [Plain]} -> string:strip(Plain);
                _                -> ""
            end
    end.

first_tag_fallback(Xml, Tag, Default) ->
    R = first_tag(Xml, Tag),
    case R of
        "" -> Default;
        _  -> R
    end.

%% strip_html(Str) -> Str with HTML tags and common entities removed
strip_html(Str) ->
    %% Remove tags
    NoTags = re:replace(Str, "<[^>]+>", "", [global, {return, list}]),
    %% Decode common HTML entities using string:replace (literal, not regex)
    %% Order matters: amp last to avoid double-decode
    Pairs = [{"&lt;", "<"}, {"&gt;", ">"}, {"&quot;", "\""}, {"&apos;", "'"},
             {"&#39;", "'"}, {"&nbsp;", " "}, {"&amp;", "&"}],
    Result = lists:foldl(fun({Entity, Replacement}, Acc) ->
        string:replace(Acc, Entity, Replacement, all)
    end, NoTags, Pairs),
    string:strip(lists:flatten(Result)).
