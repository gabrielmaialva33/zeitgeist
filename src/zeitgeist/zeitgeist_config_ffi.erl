-module(zeitgeist_config_ffi).
-export([get_env_string/2, get_env_int/2]).

get_env_string(Name, Default) ->
    case os:getenv(binary_to_list(Name)) of
        false -> Default;
        Value -> list_to_binary(Value)
    end.

get_env_int(Name, Default) ->
    case os:getenv(binary_to_list(Name)) of
        false -> Default;
        Value ->
            case catch list_to_integer(Value) of
                I when is_integer(I) -> I;
                _ -> Default
            end
    end.
