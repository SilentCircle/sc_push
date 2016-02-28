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
%% @doc webmachine resource that handles the push notification component
%% of the REST API.
%%
%% See [https://github.com/basho/webmachine/wiki/Resource-Functions] for a
%% description of the resource functions used in this module.

-module(sc_push_wm_send_tag).
-author('Edwin Fine <efine@silentcircle.com>').

%% Webmachine callback exports
-export([
    init/1,
    allowed_methods/2,
    allow_missing_post/2,
    malformed_request/2,
    valid_content_headers/2,
    finish_request/2,
    post_is_create/2,
    process_post/2,
    resource_exists/2
    ]).

%% Functions advertised in content_types_(provided|accepted)
-export([
    ]).

-include_lib("lager/include/lager.hrl").
-include_lib("webmachine/include/webmachine.hrl").
-include_lib("sc_util/include/sc_util_assert.hrl").

-define(SC_DEBUG_LOG(IsDebug, Fmt, Args),
        (IsDebug andalso make_true(lager:info(Fmt, Args)))).

-define(SC_ERROR_LOG(Fmt, Args), lager:error(Fmt, Args)).

-record(ctx, {
        method,
        content_type,
        tag,
        send_resp,
        cfg = []
        }).

-type ctx() :: #ctx{}. % Context record.

%%====================================================================
%% Webmachine request callback functions
%%====================================================================
%% Note: Config comes from dispatch.conf, NOT environment!
-spec init(sc_push_wm_helper:config()) ->
    {sc_push_wm_helper:debug_info(), ctx()}.
init(Config) ->
    {sc_push_wm_helper:config_debug(Config), #ctx{cfg = Config}}.
%{{trace,"/tmp"}, #ctx{cfg = Config}}.

%%

-spec allowed_methods(sc_push_wm_helper:wrq(), ctx()) ->
    {list(), sc_push_wm_helper:wrq(), ctx()}.
allowed_methods(ReqData, Ctx) ->
    PathTokens = string:tokens(wrq:path(ReqData), "/"),
    _ = lager:info("PathTokens: ~p", [PathTokens]),
    {['POST'], ReqData, Ctx#ctx{method = wrq:method(ReqData)}}.

%%

-spec valid_content_headers(sc_push_wm_helper:wrq(), ctx())
    -> sc_push_wm_helper:wbool_ret().
valid_content_headers(ReqData, Ctx) ->
    CT = wrq:get_req_header("content-type", ReqData),
    case sc_push_wm_common:get_media_type(CT) of
        "application/json" = MT ->
            {true, ReqData, Ctx#ctx{content_type = MT}};
        _Other ->
            Msg = <<"Invalid media type">>,
            RD2 = sc_push_wm_helper:malformed_err(Msg, ReqData),
            {false, RD2, Ctx}
    end.

-spec resource_exists(sc_push_wm_helper:wrq(), ctx())
    -> sc_push_wm_helper:wbool_ret().
resource_exists(ReqData, Ctx) ->
   {false, ReqData, Ctx}.

%%

-spec allow_missing_post(sc_push_wm_helper:wrq(), ctx())
    -> sc_push_wm_helper:wbool_ret().
allow_missing_post(ReqData, Ctx) ->
    {true, ReqData, Ctx}.

%%

-spec post_is_create(sc_push_wm_helper:wrq(), ctx())
    -> sc_push_wm_helper:wbool_ret().
post_is_create(ReqData, Ctx) ->
    {false, ReqData, Ctx}.

%%
-spec malformed_request(sc_push_wm_helper:wrq(), ctx())
    -> sc_push_wm_helper:wbool_ret().
malformed_request(ReqData, Ctx) ->
    case wrq:path_info(tag, ReqData) of
        undefined ->
            Msg = <<"'tag' missing from path">>,
            {true, sc_push_wm_helper:malformed_err(Msg, ReqData), Ctx};
        Tag ->
            {false, ReqData, Ctx#ctx{tag = sc_util:to_bin(Tag)}}
    end.

-spec finish_request(sc_push_wm_helper:wrq(), ctx()) -> sc_push_wm_helper:wbool_ret().
finish_request(ReqData, #ctx{} = Ctx) ->
    Headers = [
            %% TODO: Add etags later
            %% {"Cache-Control", "must-revalidate,no-cache,no-store"}
            ],
    RD2 = wrq:set_resp_headers(sc_push_wm_helper:enc_headers(Headers), ReqData),
    {true, RD2, Ctx}.

%%

-spec process_post(sc_push_wm_helper:wrq(), ctx())
    -> sc_push_wm_helper:wbool_ret().
process_post(ReqData, #ctx{method = 'POST',
                           content_type = "application/json",
                           tag = Tag} = Ctx) ->
    ParseRes = sc_push_wm_common:parse_json(wrq:req_body(ReqData)),

    Debug = sc_push_wm_helper:is_debug(ReqData, Ctx),
    ?SC_DEBUG_LOG(Debug, "~p:parse_json returned:~n~p", [?MODULE, ParseRes]),

    case ParseRes of
        {ok, Props0} ->
            Props = sc_push_wm_common:store_prop({tag, Tag}, Props0),
            case sc_push_wm_common:send_push(Props) of
                {ok, Results} ->
                    RD2 = sc_push_wm_common:add_result(ReqData, Results),
                    {true, RD2, Ctx#ctx{send_resp = Results}};
                {error, Msg} -> % Bad request
                    sc_push_wm_common:bad_request(ReqData, Ctx, Msg)
            end;
        {error, Msg} ->
            sc_push_wm_common:bad_request(ReqData, Ctx, Msg)
    end.

%%%====================================================================
%%% Helper functions
%%%====================================================================
-compile({inline, [{make_true, 1}]}).
make_true(_X) -> true.
