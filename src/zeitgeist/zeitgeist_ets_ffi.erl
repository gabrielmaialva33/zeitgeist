-module(zeitgeist_ets_ffi).
-export([new_table/2, insert/3, lookup/2, lookup_all/1,
         delete_key/2, delete_table/1, table_size/1,
         tab_to_file/2, file_to_tab/1,
         fold/3, match_delete/2,
         identity/1, now_ms/0, unix_ms_to_parts/1]).

new_table(Name, Type) ->
    NameAtom = binary_to_atom(Name, utf8),
    TypeAtom = binary_to_atom(Type, utf8),
    ets:new(NameAtom, [TypeAtom, public, named_table, {read_concurrency, true}]),
    {ok, NameAtom}.

insert(Table, Key, Value) ->
    ets:insert(Table, {Key, Value}),
    nil.

lookup(Table, Key) ->
    case ets:lookup(Table, Key) of
        [{_, Value}] -> {ok, Value};
        [] -> {error, nil};
        [First | _] -> {ok, element(2, First)}
    end.

lookup_all(Table) ->
    [Value || {_, Value} <- ets:tab2list(Table)].

delete_key(Table, Key) ->
    ets:delete(Table, Key),
    nil.

delete_table(Table) ->
    ets:delete(Table),
    nil.

table_size(Table) ->
    ets:info(Table, size).

tab_to_file(Table, Path) ->
    case ets:tab2file(Table, binary_to_list(Path)) of
        ok -> {ok, nil};
        {error, Reason} -> {error, list_to_binary(io_lib:format("~p", [Reason]))}
    end.

file_to_tab(Path) ->
    case ets:file2tab(binary_to_list(Path)) of
        {ok, Tab} -> {ok, Tab};
        {error, Reason} -> {error, list_to_binary(io_lib:format("~p", [Reason]))}
    end.

fold(Table, Acc, Fun) ->
    ets:foldl(fun({Key, Value}, A) -> Fun(Key, Value, A) end, Acc, Table).

match_delete(Table, KeyPattern) ->
    ets:match_delete(Table, {KeyPattern, '_'}),
    nil.

identity(X) -> X.

now_ms() ->
    erlang:system_time(millisecond).

unix_ms_to_parts(TimestampMs) ->
    Seconds = TimestampMs div 1000,
    GregorianSeconds = Seconds + 62167219200,
    {{Year, Month, Day}, {Hour, Min, Sec}} = calendar:gregorian_seconds_to_datetime(GregorianSeconds),
    {Year, Month, Day, Hour, Min, Sec}.
