%%% ==========================================================================
%%% Copyright 2016 Silent Circle
%%%
%%% Licensed under the Apache License, Version 2.0 (the "License");
%%% you may not use this file except in compliance with the License.
%%% You may obtain a copy of the License at
%%%
%%%     http://www.apache.org/licenses/LICENSE-2.0
%%%
%%% Unless required by applicable law or agreed to in writing, software
%%% distributed under the License is distributed on an "AS IS" BASIS,
%%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%% See the License for the specific language governing permissions and
%%% limitations under the License.
%%% ==========================================================================

%% @author Edwin Fine <efine@silentcircle.com>
%% @doc webmachine helper functions.
%%
%% See [https://github.com/basho/webmachine/wiki/Resource-Functions] for a
%% description of the resource functions used in this module.

-module(sc_push_wm_helper).
-author('Edwin Fine <efine@silentcircle.com>').

%% API
-export([
    config_debug/1,
    check_reg_lookup/1,
    malformed_err/2,
    get_svc_id/1,
    get_device_id/1,
    parse_json/1,
    bad_json_error/0,
    is_valid_reg_req/1,
    enc_headers/1,
    pv/3,
    is_debug/2,
    get_req_hdr/2,
    get_req_hdr/3,
    make_service_id_urls/2,
    make_service_id_url/2,
    make_service_id_path/1,
    add_seps/2,
    sanctify/1,
    encode_props/1,
    ejson_to_props/1,
    is_valid_service_id/2
    ]).

%% Types exports
-export_type([
        wrq/0,
        werr/0,
        wret/1,
        wbool_ret/0,
        wiolist_ret/0,
        pl/2,
        config/0,
        filepath/0,
        debug_info/0,
        json/0,
        unicode/0,
        ejson/0,
        ejson_term/0,
        ejson_scalar/0,
        ejson_collection/0,
        ejson_list/0,
        ejson_dict/0,
        ejson_empty_dict/0,
        ejson_field/0,
        ejson_field_name/0
        ]).

-include_lib("webmachine/include/webmachine.hrl").
-include_lib("sc_util/include/sc_util_assert.hrl").

-type wrq() :: #wm_reqdata{}. % Webmachine: request data record.
-type werr() :: {error, iolist()}. % Webmachine: dispatch function returns this
                                   % to signal 500 error.
-type wret(T) :: {T | werr(), wrq(), any()}. % Webmachine: dispatch functions
                                             % return this.
-type wbool_ret() :: wret(boolean()). % Webmachine: boolean dispatch function return type.
-type wiolist_ret() :: wret(iolist()).% Webmachine: iolist dispatch function return type.

-type pl(KT, VT) :: list({KT, VT}). % Property list.
-type config() :: pl(atom(), term()). % A config property list.
-type filepath() :: string().
-type debug_info() :: ok | {trace, filepath()}. % Webmachine: possible returns from init/1.

-type json() :: binary().

%% JSON as decoded from JSON string by jsx
-type unicode() :: binary().
-type ejson() :: ejson_term().
-type ejson_term() :: ejson_scalar() | ejson_collection().
-type ejson_scalar() :: boolean() | 'null' | number() | unicode().
-type ejson_collection() :: ejson_list() | ejson_dict().
-type ejson_list() :: list(ejson_term()).
-type ejson_dict() :: ejson_empty_dict() | list(ejson_field()).
-type ejson_empty_dict() :: [{}].
-type ejson_field() :: {ejson_field_name(), ejson_term()}.
-type ejson_field_name() :: atom() | unicode().

%% @doc Check if config contains `{debug, TraceFilePath}' and
%% return {trace, TraceFilePath} if so, `ok' if not.
-spec config_debug(config()) -> debug_info().
config_debug(Config) ->
    case pv(debug, Config, false) of
        false ->
            ok;
        true ->
            ok;
        [_|_] = DbgFilePath ->
            {trace, DbgFilePath}
    end.

%% @doc Check the return of the sc_push_reg_api lookup
check_reg_lookup(notfound) ->
    {halt, 404};
check_reg_lookup({error, disconnected}) ->
    {halt, 503};
check_reg_lookup({error, _}=Error) ->
    Error;
check_reg_lookup(Props) when is_list(Props) ->
    [encode_props(Props)].

-spec malformed_err(iolist() | binary(), wrq()) -> wrq().
malformed_err(Error, ReqData) ->
    RD = wrq:set_resp_body(sc_util:to_bin(Error), ReqData),
    wrq:set_resp_header("Content-Type", "text/plain; charset=UTF-8", RD).

-spec get_svc_id(wrq()) -> {ok, any()} | undefined.
get_svc_id(ReqData) ->
    case {wrq:path_info(service, ReqData), wrq:path_info(token, ReqData)} of
        {Svc, Token} when Svc =/= undefined, Token =/= undefined ->
            {ok, sc_push_reg_api:make_svc_tok(Svc, Token)};
        _ ->
            undefined
    end.

-spec get_device_id(wrq()) -> {ok, any()} | undefined.
get_device_id(ReqData) ->
    case wrq:path_info(device_id, ReqData) of
        undefined ->
            undefined;
        DeviceId ->
            {ok, DeviceId}
    end.

-spec parse_json(json()) -> {ok, ejson()} | {bad_json, string()}.
parse_json(<<JSON/binary>>) ->
    try jsx:decode(JSON) of
        EJ when is_list(EJ) ->
            {ok, EJ};
        _ ->
            bad_json_error()
    catch
        _:_ ->
            bad_json_error()
    end.

bad_json_error() ->
    {bad_json, <<"JSON_PARSING_ERROR: Invalid JSON">>}.

-spec is_valid_reg_req(ejson()) -> boolean().
is_valid_reg_req(EJSON) ->
    sc_push_reg_api:is_valid_push_reg(EJSON).

enc_headers([{Tag, Val}|T]) when is_atom(Tag) ->
    [{atom_to_list(Tag), enc_header_val(Val)} | enc_headers(T)];
enc_headers([{Tag, Val}|T]) when is_list(Tag) ->
    [{Tag, enc_header_val(Val)} | enc_headers(T)];
enc_headers([]) ->
    [].

enc_header_val(Val) when is_atom(Val) ->
    atom_to_list(Val);
enc_header_val(Val) when is_integer(Val) ->
    integer_to_list(Val);
enc_header_val(Val) ->
    Val.

pv(K, PL, Def) ->
    proplists:get_value(K, PL, Def).

-spec is_debug(wrq(), list()) -> boolean().
is_debug(ReqData, Cfg) when is_list(Cfg) ->
    get_req_hdr("X-SCPush-Debug", ReqData, "false") =:= "true" orelse
    pv(debug, Cfg, false) =:= true.

-spec get_req_hdr(string(), wrq()) -> string() | 'undefined'.
get_req_hdr(HeaderName, ReqData) ->
    wrq:get_req_header(string:to_lower(HeaderName), ReqData).

-spec get_req_hdr(string(), wrq(), string()) -> string().
get_req_hdr(HeaderName, ReqData, Default) when is_list(Default) ->
    case get_req_hdr(HeaderName, ReqData) of
        undefined ->
            Default;
        Val ->
            Val
    end.

%% @doc Create a list of binary resource URLs from the property lists
%% to be returned. The URLs will be urlencoded.
make_service_id_urls(ReqData, Proplists) ->
    BaseURI = list_to_binary(wrq:base_uri(ReqData)),
    [make_service_id_url(BaseURI, Proplist) || Proplist <- Proplists].

%% @doc Return service/token URL as binary string.
make_service_id_url(BaseURI, Proplist) ->
    Service = sanctify(sc_util:req_val(service, Proplist)),
    Token = sanctify(sc_util:req_val(token, Proplist)),
    list_to_binary(add_seps([BaseURI, <<"registration">>, <<"service">>,
                             Service, <<"token">>, Token], $/)).

make_service_id_path(Proplist) ->
    Service = sanctify(sc_util:req_val(service, Proplist)),
    Token = sanctify(sc_util:req_val(token, Proplist)),
    list_to_binary(add_seps([<<"service">>, Service, <<"token">>, Token], $/)).

add_seps(List, Sep) ->
    add_seps(List, Sep, []).

add_seps([], _Sep, Acc) ->
    lists:reverse(Acc);
add_seps([H], Sep, Acc) ->
    add_seps([], Sep, [H | Acc]);
add_seps([H|T], Sep, Acc) ->
    add_seps(T, Sep, [Sep, H | Acc]).

sanctify(PathComponent) ->
    list_to_binary(http_uri:encode(sc_util:to_list(PathComponent))).

%% Encode all proplist atom values to string binary to avoid any
%% misinterpretations, and convert to JSON
encode_props(Props) ->
    jsx:encode([maybe_encode_prop(Prop) || Prop <- Props]).

maybe_encode_prop({K, V}) when is_atom(V) ->
    {K, sc_util:to_bin(V)};
maybe_encode_prop({K, V}) when is_list(V) ->
    {K, maybe_encode_prop(V)};
maybe_encode_prop({K, {M, S, U}}) when is_integer(M),
                                       is_integer(S),
                                       is_integer(U) -> % Prob now() value
   {K, sc_util:to_bin(integer_to_list(((M * 1000000) + S) * 1000000 + U))};
maybe_encode_prop(V) when is_list(V) ->
    [maybe_encode_prop(P) || P <- V];
maybe_encode_prop(V) ->
    V.

%% Convert all binary keys to atoms
ejson_to_props(EJSON) ->
    [maybe_atomize_key(KV) || KV <- EJSON].

maybe_atomize_key({<<K/binary>>, V}) ->
    maybe_atomize_key({sc_util:to_atom(K), V});
maybe_atomize_key({K, V}) when is_list(V) ->
    {K, [maybe_atomize_key(Prop) || Prop <- V]};
maybe_atomize_key(Prop) ->
    Prop.

is_valid_service_id(Svc, Token) ->
    try
        _ = sc_push_reg_api:make_svc_tok(Svc, Token),
        true
    catch
        _:_ ->
            false
    end.

