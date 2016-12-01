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
%% @doc webmachine resource that handles the version endpoint.
%%
%% See [https://github.com/basho/webmachine/wiki/Resource-Functions] for a
%% description of the resource functions used in this module.

-module(sc_push_wm_version).
-author('Edwin Fine <efine@silentcircle.com>').

%% Webmachine callback exports
-export([
    init/1,
    content_types_provided/2,
    allowed_methods/2,
    resource_exists/2
    ]).

%% Functions advertised in content_types_(provided|accepted)
-export([
        to_json/2
    ]).

-include_lib("lager/include/lager.hrl").
-include_lib("webmachine/include/webmachine.hrl").
-include_lib("sc_util/include/sc_util_assert.hrl").

-record(ctx, {
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

-spec content_types_provided(sc_push_wm_helper:wrq(), ctx()) ->
    {list(), sc_push_wm_helper:wrq(), ctx()}.
content_types_provided(ReqData, Ctx) ->
   {[{"application/json", to_json}], ReqData, Ctx}.

%%

-spec allowed_methods(sc_push_wm_helper:wrq(), ctx()) ->
    {list(), sc_push_wm_helper:wrq(), ctx()}.
allowed_methods(ReqData, Ctx) ->
    {['GET'], ReqData, Ctx}.

%%

-spec resource_exists(sc_push_wm_helper:wrq(), ctx())
    -> sc_push_wm_helper:wbool_ret().
resource_exists(ReqData, Ctx) ->
   {true, ReqData, Ctx}.

%%

-spec to_json(sc_push_wm_helper:wrq(), ctx()) ->
    {sc_push_wm_helper:json(), sc_push_wm_helper:wrq(), ctx()}.
to_json(ReqData, Ctx) ->
    JSON = jsx:encode([{version, sc_push:get_version()}]),
    {JSON, ReqData, Ctx}.

%%

%%%====================================================================
%%% Helper functions
%%%====================================================================
