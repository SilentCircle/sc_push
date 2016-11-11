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
%% @doc webmachine resource that handles the push registration tag
%% resource of the REST API.
%%
%% See [https://github.com/basho/webmachine/wiki/Resource-Functions] for a
%% description of the resource functions used in this module.

-module(sc_push_reg_wm_tag).
-author('Edwin Fine <efine@silentcircle.com>').

%% Webmachine callback exports
-export([
    init/1,
    allowed_methods/2,
    resource_exists/2,
    content_types_provided/2,
    malformed_request/2,
    delete_resource/2,
    delete_completed/2,
    finish_request/2
    ]).

%% Functions advertised in content_types_(provided|accepted)
-export([
        to_json/2
    ]).

-include_lib("lager/include/lager.hrl").
-include_lib("webmachine/include/webmachine.hrl").
-include_lib("sc_util/include/sc_util_assert.hrl").

-define(SC_DEBUG_LOG(IsDebug, Fmt, Args),
    (IsDebug andalso make_true(lager:info(Fmt, Args)))).

-define(SC_ERROR_LOG(Fmt, Args), lager:error(Fmt, Args)).

-record(ctx, {
        tag,
        cfg = [],
        rsp = []
    }).

-type ctx() :: #ctx{}. % Context record.

%%====================================================================
%% Webmachine request callback functions
%%====================================================================
%% Note: Config comes from dispatch.conf, NOT environment!
%% @doc webmachine initialization resource function.
-spec init(sc_push_wm_helper:config()) ->
    {sc_push_wm_helper:debug_info(), ctx()}.
init(Config) ->
    {sc_push_wm_helper:config_debug(Config), #ctx{cfg = Config}}.
    %{{trace,"/tmp"}, #ctx{cfg = Config}}.

%% @doc Define the allowed HTTP methods in a list.  If a Method not in this
%% list is requested, then a `405 Method Not Allowed' will be sent. Note that
%% Methods (`` 'PUT' '', `` 'GET' '', etc.) are all-caps and are atoms
%% (single-quoted).
%%
%% === Example return value ===
%% ```
%% {['GET', 'PUT', 'DELETE'], ReqData, Ctx}
%% '''
-spec allowed_methods(sc_push_wm_helper:wrq(), ctx()) -> {AllowedMethods::list(), sc_push_wm_helper:wrq(), ctx()}.
allowed_methods(ReqData, Ctx) ->
    _ = lager:info("~s ~s", [wrq:method(ReqData), wrq:path(ReqData)]),
    {['GET', 'DELETE'], ReqData, Ctx}.

-spec resource_exists(sc_push_wm_helper:wrq(), ctx()) ->
    {Exists::boolean(), sc_push_wm_helper:wrq(), ctx()}.
resource_exists(ReqData, #ctx{tag = Tag} = Ctx) ->
    Debug = sc_push_wm_helper:is_debug(ReqData, Ctx#ctx.cfg),
    ?SC_DEBUG_LOG(Debug, "~p:resource_exists called", [?MODULE]),
    BTag = sc_util:to_bin(Tag),
    case sc_push_reg_api:get_registration_info_by_tag(BTag) of
        notfound ->
            {false, ReqData, Ctx};
        Info ->
            {true, ReqData, Ctx#ctx{rsp = Info}}
    end.

%% @doc This should return a list of pairs where each pair is of the form
%% `{Mediatype, Handler}' where `Mediatype' is a string of content-type format and
%% the `Handler' is an atom naming the function which can provide a resource
%% representation in that media type. Content negotiation is driven by this
%% return value. For example, if a client request includes an `Accept' header
%% with a value that does not appear as a first element in any of the return
%% tuples, then a `406 Not Acceptable' will be sent.
%%
%% === Example return value ===
%% ```
%% {[{"application/json", to_json}], ReqData, Ctx}
%% '''
-spec content_types_provided(sc_push_wm_helper:wrq(), ctx()) -> {list(), sc_push_wm_helper:wrq(), ctx()}.
content_types_provided(ReqData, Ctx) ->
   {[{"application/json", to_json}], ReqData, Ctx}.

%% @doc This function is called very early on, and checks the incoming request
%% to determine if it is malformed. For example, a `GET' request that has a
%% missing or badly-formed required path component is malformed.
%%
%% This returns `true' if the request is malformed, resulting in a `400 Bad
%% Request' HTTP status code.
%% === Example return value ===
%% ```
%% {false, ReqData, Ctx} % Request is not malformed.
%% '''
-spec malformed_request(sc_push_wm_helper:wrq(), ctx()) -> sc_push_wm_helper:wbool_ret().
malformed_request(ReqData, Ctx) ->
    Method = wrq:method(ReqData),
    check_if_malformed_req(Method, ReqData, Ctx).

%% @doc This function, if exported, is called just before the final response is
%% constructed and sent. The `Result' is ignored, so any effect of this function
%% must be by returning a modified `ReqData'.
%% === Example return value ===
%% ```
%% {true, NewReqData, Ctx}
%% '''
-spec finish_request(sc_push_wm_helper:wrq(), ctx()) -> sc_push_wm_helper:wbool_ret().
finish_request(ReqData, Ctx) ->
    Headers = [
            %% TODO: Add etags later
            %% {"Cache-Control", "must-revalidate,no-cache,no-store"}
            ],
    NewReqData = wrq:set_resp_headers(sc_push_wm_helper:enc_headers(Headers), ReqData),
    {true, NewReqData, Ctx}.

%% @doc This is called when a `DELETE' request should be enacted, and should
%% return `true' if the deletion succeeded.
%% === Example return value ===
%% ```
%% {true, ReqData, Ctx}
%% '''
-spec delete_resource(sc_push_wm_helper:wrq(), ctx()) -> sc_push_wm_helper:wbool_ret().
delete_resource(ReqData, Ctx) ->
    Debug = sc_push_wm_helper:is_debug(ReqData, Ctx#ctx.cfg),
    ?SC_DEBUG_LOG(Debug, "~p:delete_resource called", [?MODULE]),
    BTag = sc_util:to_bin(Ctx#ctx.tag),
    case sc_push_reg_api:deregister_tag(BTag) of
        ok ->
            {true, ReqData, Ctx};
        {error, _} = Error ->
            {Error, ReqData, Ctx}
    end.

%% @doc This is only called after a successful delete_resource call, and should
%% return `false' if the deletion was accepted but cannot yet be guaranteed to
%% have finished.  A `false' return results in a `202 Accepted' HTTP status code,
%% while a `true' return may cause a `200 OK' or a `204 No Content' or possibly
%% others, depending on subsequent processing.
%% === Example returns ===
%% ```
%% {true, ReqData, Ctx} % Deletes are immediate
%% '''
-spec delete_completed(sc_push_wm_helper:wrq(), ctx()) -> sc_push_wm_helper:wbool_ret().
delete_completed(ReqData, Ctx) ->
    Debug = sc_push_wm_helper:is_debug(ReqData, Ctx#ctx.cfg),
    ?SC_DEBUG_LOG(Debug, "~p:delete_completed called", [?MODULE]),
    {true, ReqData, Ctx}. % Deletes are immediate

%% @doc Get registration data as JSON. The Body should be either an iolist() or {stream,streambody()}
-spec to_json(sc_push_wm_helper:wrq(), ctx()) -> {[sc_push_wm_helper:json()], sc_push_wm_helper:wrq(), ctx()}.
to_json(ReqData, #ctx{rsp = Info} = Ctx) ->
    Debug = sc_push_wm_helper:is_debug(ReqData, Ctx#ctx.cfg),
    ?SC_DEBUG_LOG(Debug, "~p:to_json called", [?MODULE]),
    Result = sc_push_wm_helper:check_reg_lookup(Info),
    {Result, ReqData, Ctx}.

%%%====================================================================
%%% Helper functions
%%%====================================================================
-spec check_if_malformed_req(atom(), sc_push_wm_helper:wrq(), #ctx{}) ->
    {boolean(), sc_push_wm_helper:wrq(), #ctx{}}.

check_if_malformed_req(M, ReqData, Ctx) when M =:= 'GET'; M =:= 'DELETE' ->
    Tag = wrq:path_info(tag, ReqData),
    Malformed = Tag =:= undefined orelse Tag =:= "",
    {Malformed, ReqData, Ctx#ctx{tag = Tag}};
check_if_malformed_req(_Method, ReqData, Ctx) ->
    {true, ReqData, Ctx}.

-compile({inline, [{make_true, 1}]}).
make_true(_X) -> true.
