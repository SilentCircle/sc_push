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
-module(sc_push_sup).

-behaviour(supervisor).

%% API
-export([
        start_link/1,
        % For testing only
        start/1,
        stop/1
    ]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type, Args, Timeout),
    {I, {I, start_link, Args}, permanent, Timeout, Type, [I]}
).

-define(NAMED_CHILD(I, Mod, Type, Args, Timeout),
    {I, {Mod, start_link, Args}, permanent, Timeout, Type, [Mod]}
).

%% ===================================================================
%% API functions
%% ===================================================================

start_link(Opts) when is_list(Opts) ->
    check_mnesia_running(),
    ok = sc_push_reg_api:init(),
    case supervisor:start_link({local, ?SERVER}, ?MODULE, Opts) of
        {ok, _} = Res ->
            _ = register_services(Opts),
            Res;
        Error ->
            Error
    end.


start(Opts) when is_list(Opts) ->
    case start_link(Opts) of
        {ok, Pid}  = Res ->
            unlink(Pid),
            Res;
        Other ->
            Other
    end.

stop(SupRef) ->
    exit(SupRef, shutdown).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init(Opts) ->
    RestartStrategy    = one_for_one,
    MaxRestarts        = 10, % If there are more than this many restarts
    MaxTimeBetRestarts = 60, % In this many seconds, then terminate supervisor

    SupFlags = {RestartStrategy, MaxRestarts, MaxTimeBetRestarts},

    Children = [?CHILD(sc_push_wm_sup, supervisor, [Opts], infinity)] ++
               service_child_specs(Opts),

    {ok, {SupFlags, Children}}.

service_child_specs(Opts) ->
    Services = proplists:get_value(services, Opts, []),
    [sc_push:make_service_child_spec(Svc) || Svc <- Services].

register_services(Opts) ->
    Services = proplists:get_value(services, Opts, []),
    [sc_push:register_service(Svc) || Svc <- Services].

check_mnesia_running() ->
    Apps = application:which_applications(),
    case lists:keysearch(mnesia, 1, Apps) of
        {value, _} ->
            ok;
        false ->
            throw({?MODULE, mnesia_not_started})
    end.

