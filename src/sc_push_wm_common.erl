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
-module(sc_push_wm_common).

-export([
        send_push/1,
        parse_json/1,
        get_media_type/1,
        add_result/2,
        results_to_json/1,
        result_to_json/1,
        error_to_json/1,
        encode_ref/1,
        store_props/2,
        store_prop/2,
        bad_request/3,
        ensure_path_items/2,
        ensure_path_items/3,
        ensure_path_item/2
    ]).

-include_lib("lager/include/lager.hrl").

-spec send_push(sc_types:proplist(atom(), string() | binary()))
    -> {ok, term()} | {error, binary()}.
send_push(Props) ->
    % Opts = [{callback,
    % fun(Nf,Req,Res) ->
    %          io:format("~p\n~p\n~p\n", [Nf,Req,Res]) end}]
    Opts = [],
    Res = try
              sc_push:async_send(Props, Opts)
          catch
              _Class:Reason ->
                  Msg = list_to_binary(io_lib:format("~p", [Reason])),
                  {error, Msg}
          end,

    lager:debug("[~p,~p] send_push, result: ~p~nprops: ~p",
                [?MODULE, ?LINE, Res, Props]),

    case Res of
        [{ok, {Sts, <<_:128>> = UUID}}] when is_atom(Sts) ->
            {ok, [{ok, [{status, Sts},
                        {uuid, uuid_to_str(UUID)}]}]};
        [{error, {Sts, <<_:128>> = UUID}}] when is_atom(Sts) ->
            {ok, [{error, [{status, Sts},
                           {uuid, uuid_to_str(UUID)}]}]};
        [{error, _Reason}] = Error  ->
            {ok, Error};
        Results ->
            {ok, Results}
    end.

-spec parse_json(binary()) ->
    {ok, sc_types:proplist(atom(), string() | binary())} |
    {error, binary()}.
parse_json(ReqBody) ->
    case sc_push_wm_helper:parse_json(ReqBody) of
        {ok, EJSON} ->
            {ok, sc_push_wm_helper:ejson_to_props(EJSON)};
        {bad_json, Msg} ->
            {error, sc_util:to_bin(Msg)}
    end.

-spec get_media_type(string()) -> string().
get_media_type(CT) ->
    {MT, _Params} = webmachine_util:media_type_to_detail(CT),
    MT.

-spec add_result(sc_push_wm_helper:wrq(), list()) -> sc_push_wm_helper:wrq().
add_result(ReqData, Results) ->
    JSON = results_to_json(Results),
    RD = wrq:set_resp_body(JSON, ReqData),
    wrq:set_resp_header("Content-Type", "application/json", RD).

results_to_json(Results) ->
    Objects = [result_to_json(R) || R <- Results],
    sc_push_wm_helper:encode_props([{results, Objects}]).

result_to_json(ok) ->
    <<"queued">>;
result_to_json({ok, [{_,_}|_]=EJSON}) ->
    EJSON;
result_to_json({ok, Ref}) ->
    [{id, encode_ref(Ref)}];
result_to_json({error, Error}) ->
    [{error, error_to_json(Error)}].

error_to_json([]) ->
    [];
error_to_json([{_,_}|_] = L) ->
    [error_to_json(Err) || Err <- L];
error_to_json({error, {What, Why}}) ->
    list_to_binary(io_lib:format("~p: ~p", [What, Why]));
error_to_json({What, Why}) ->
    list_to_binary(io_lib:format("~p: ~p", [What, Why])).

-spec encode_ref(Ref::term()) -> binary().
encode_ref(Ref) ->
    base64:encode(term_to_binary(Ref)).

store_props(Props, PL) ->
    lists:foldl(fun(Prop, NewPL) -> store_prop(Prop, NewPL) end, PL, Props).

store_prop({Key, _NewVal} = NewProp, PL) ->
    lists:keystore(Key, 1, PL, NewProp).

bad_request(ReqData, Ctx, Msg) ->
    RD2 = sc_push_wm_helper:malformed_err(sc_util:to_bin(Msg), ReqData),
    {{halt, 400}, RD2, Ctx}.

ensure_path_items(Keys, ReqData) ->
    ensure_path_items(Keys, ReqData, []).

ensure_path_items([Key | Rest], ReqData, Acc) ->
    case ensure_path_item(Key, ReqData) of
        {ok, Res} ->
            ensure_path_items(Rest, ReqData, [Res | Acc]);
        Error ->
            Error
    end;
ensure_path_items([], _ReqData, Acc) ->
    {ok, lists:reverse(Acc)}.

ensure_path_item(Key, ReqData) ->
    case wrq:path_info(Key, ReqData) of
        undefined ->
            Msg = [<<"'">>, sc_util:to_bin(Key), <<"' missing from path">>],
            {error, Msg};
        Val ->
            {ok, {Key, sc_util:to_bin(Val)}}
    end.

uuid_to_str(<<_:128>> = UUID) ->
    uuid:uuid_to_string(UUID, binary_standard).

