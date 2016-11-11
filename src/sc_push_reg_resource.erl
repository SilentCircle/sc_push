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
%% @doc webmachine resource that handles the push registration component
%% of the REST API.
%%
%% See [https://github.com/basho/webmachine/wiki/Resource-Functions] for a
%% description of the resource functions used in this module.

-module(sc_push_reg_resource).
-author('Edwin Fine <efine@silentcircle.com>').

%% Webmachine callback exports
-export([
    init/1,
    allowed_methods/2,
    content_types_provided/2,
    content_types_accepted/2,
    malformed_request/2,
    delete_resource/2,
    delete_completed/2,
    finish_request/2,
    post_is_create/2,
    create_path/2
    ]).

%% Functions advertised in content_types_(provided|accepted)
-export([
        to_json/2,
        to_html/2,
        to_text/2,
        from_json/2
    ]).

-include_lib("lager/include/lager.hrl").
-include_lib("webmachine/include/webmachine.hrl").
-include_lib("sc_util/include/sc_util_assert.hrl").

-define(SC_DEBUG_LOG(IsDebug, Fmt, Args),
    (IsDebug andalso make_true(lager:info(Fmt, Args)))).

-define(SC_ERROR_LOG(Fmt, Args), lager:error(Fmt, Args)).

-record(ctx, {
        svc_id, % For GET and DELETE
        tag,    % For GET and DELETE
        cfg = [],
        req = [],
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
    PathTokens = string:tokens(wrq:path(ReqData), "/"),
    _ = lager:info("PathTokens: ~p", [PathTokens]),
    Allowed = allowed_methods_for_path(PathTokens),
    {Allowed, ReqData, Ctx}.

allowed_methods_for_path([_, "service", S, "token", T]) ->
    case sc_push_wm_helper:is_valid_service_id(S, T) of
        true ->
            ['GET', 'PUT', 'DELETE'];
        false ->
            []
    end;
allowed_methods_for_path([_, "tag", Tag]) when Tag =/= [] ->
    ['GET'];
allowed_methods_for_path([_]) ->
    ['GET', 'POST'];
allowed_methods_for_path(_) ->
    [].

%% @doc Define the acceptable `Content-Type's in a list. This is used similarly
%% to {@link content_types_provided/2}, except that it is for incoming resource
%% representations - for example, `PUT' requests. Handler functions usually
%% want to use `wrq:req_body(ReqData)' to access the incoming request body.
%%
%% === Example return value ===
%% ```
%% {[{"application/json", from_json}], ReqData, Ctx}
%% '''
-spec content_types_accepted(sc_push_wm_helper:wrq(), ctx()) -> {list(), sc_push_wm_helper:wrq(), ctx()}.
content_types_accepted(ReqData, Ctx) ->
    {[{"application/json", from_json}], ReqData, Ctx}.

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

%% @doc If POST requests should be treated as a request to put content into a
%% (potentially new) resource as opposed to being a generic submission for
%% processing, then this function should return true. If it does return true,
%% then create_path will be called and the rest of the request will be treated
%% much like a PUT to the Path entry returned by that call.
-spec post_is_create(sc_push_wm_helper:wrq(), ctx()) -> sc_push_wm_helper:wbool_ret().
post_is_create(ReqData, Ctx) ->
    {true, ReqData, Ctx}.

%% @doc This will be called on a POST request if post_is_create returns true.
%% It is an error for this function to not produce a Path if post_is_create
%% returns true. The Path returned should be a valid URI part following the
%% dispatcher prefix. That Path will replace the previous one in the return
%% value of wrq:disp_path(ReqData) for all subsequent resource function calls
%% in the course of this request.
-spec create_path(sc_push_wm_helper:wrq(), ctx()) -> sc_push_wm_helper:wiolist_ret().
create_path(ReqData, #ctx{req = Proplist} = Ctx) ->
    Path = binary_to_list(sc_push_wm_helper:make_service_id_path(Proplist)),
    {Path, ReqData, Ctx}.

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
    case sc_push_reg_api:deregister_id(Ctx#ctx.svc_id) of
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
to_json(ReqData, #ctx{svc_id = SvcId, tag = Tag, cfg = Cfg} = Ctx) ->
    Debug = sc_push_wm_helper:is_debug(ReqData, Cfg),
    ?SC_DEBUG_LOG(Debug, "~p:to_json called", [?MODULE]),
    Result = if
        SvcId =:= undefined andalso Tag =:= undefined ->
            Urls = sc_push_wm_helper:make_service_id_urls(ReqData, sc_push_reg_api:all_registration_info()),
            [jsx:encode(Urls)];
        SvcId =/= undefined ->
            Res = sc_push_reg_api:get_registration_info_by_id(SvcId),
            sc_push_wm_helper:check_reg_lookup(Res);
        Tag =/= undefined ->
            Res = sc_push_reg_api:get_registration_info(Tag),
            sc_push_wm_helper:check_reg_lookup(Res)
    end,
    {Result, ReqData, Ctx}.

from_json(ReqData, #ctx{req = EJSON} = Ctx) ->
    case sc_push_reg_api:register_id(EJSON) of
        ok ->
            {true, ReqData, Ctx};
        {error, _} = Error ->
            {Error, ReqData, Ctx}
    end.

-spec to_html(sc_push_wm_helper:wrq(), ctx()) -> sc_push_wm_helper:wiolist_ret().
to_html(ReqData, Ctx) ->
    {"<html><body>Hello, new world</body></html>", ReqData, Ctx}.

%%%====================================================================
%%% Helper functions
%%%====================================================================
-spec check_if_malformed_req(atom(), sc_push_wm_helper:wrq(), #ctx{}) ->
    {boolean(), sc_push_wm_helper:wrq(), #ctx{}}.

check_if_malformed_req('GET', ReqData, Ctx) ->
    case {sc_push_wm_helper:get_svc_id(ReqData), wrq:path_info(tag, ReqData)} of
        {undefined, undefined} -> % Top-level get
            {false, ReqData, Ctx};
        {{ok, SvcId}, undefined} ->
            {false, ReqData, Ctx#ctx{svc_id = SvcId}};
        {undefined, Tag} ->
            {false, ReqData, Ctx#ctx{tag = Tag}}
    end;

check_if_malformed_req('PUT', ReqData, Ctx) ->
    ContentType = wrq:get_req_header("content-type", ReqData),
    case {sc_push_wm_helper:get_svc_id(ReqData), ContentType} of
        {{ok, SvcId}, "application/json"} ->
            malformed_reg_json(ReqData, Ctx#ctx{svc_id = SvcId});
        _ ->
            Msg = <<"Invalid path or content type">>,
            {true, malformed_err(Msg, ReqData), Ctx}
    end;

check_if_malformed_req('POST', ReqData, Ctx) ->
    case wrq:get_req_header("content-type", ReqData) of
        "application/json" ->
            malformed_reg_json(ReqData, Ctx);
        _ ->
            Msg = <<"Invalid content type">>,
            {true, malformed_err(Msg, ReqData), Ctx}
    end;

check_if_malformed_req('DELETE', ReqData, Ctx) ->
    case {sc_push_wm_helper:get_svc_id(ReqData), wrq:path_info(tag, ReqData)} of
        {undefined, undefined} ->
            Msg = <<"Invalid path">>,
            {true, malformed_err(Msg, ReqData), Ctx};
        {{ok, SvcId}, undefined} ->
            {false, ReqData, Ctx#ctx{svc_id = SvcId}};
        {undefined, Tag} ->
            {false, ReqData, Ctx#ctx{tag = Tag}};
        _ ->
            {true, ReqData, Ctx}
    end;

check_if_malformed_req(_Method, ReqData, Ctx) ->
    {true, ReqData, Ctx}.

%% @doc Return `{true, ReqData, Ctx}' if JSON body is malformed.
%% As a side-effect, set `#ctx.req' to the parsed JSON as a proplist.
-spec malformed_reg_json(sc_push_wm_helper:wrq(), ctx()) -> sc_push_wm_helper:wbool_ret().
malformed_reg_json(ReqData, Ctx) ->
    case sc_push_wm_helper:parse_json(wrq:req_body(ReqData)) of
        {ok, EJSON} ->
            PropList = sc_push_wm_helper:ejson_to_props(EJSON),
            IsMalformed = not is_valid_reg_req(PropList),
            {IsMalformed, ReqData, Ctx#ctx{req = PropList}};
        {bad_json, ErrorMsg} ->
            {true, malformed_err(ErrorMsg, ReqData), Ctx}
    end.

-spec malformed_err(binary(), sc_push_wm_helper:wrq()) -> sc_push_wm_helper:wrq().
malformed_err(Error, ReqData) when is_binary(Error) ->
    RD = wrq:set_resp_body(Error, ReqData),
    wrq:set_resp_header("Content-Type", "text/plain; charset=UTF-8", RD).

-spec is_valid_reg_req(sc_push_wm_helper:ejson()) -> boolean().
is_valid_reg_req(EJSON) ->
    sc_push_reg_api:is_valid_push_reg(EJSON).

-spec to_text(sc_push_wm_helper:wrq(), ctx()) -> sc_push_wm_helper:wiolist_ret().
to_text(ReqData, Ctx) ->
    Path = wrq:disp_path(ReqData),
    Body = io_lib:format("Hello ~s from Webmachine.~n", [Path]),
    {Body, ReqData, Ctx}.

-compile({inline, [{make_true, 1}]}).
make_true(_X) -> true.

