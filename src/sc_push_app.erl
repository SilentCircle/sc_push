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

-module(sc_push_app).

-behaviour(application).

%% Application callbacks
-export([start/2, prep_stop/1, stop/1, config_change/3]).

-type start_type() :: normal
    | {takeover, Node :: node()}
    | {failover, Node :: node()}.

-include_lib("lager/include/lager.hrl").

%% ===================================================================
%% Application callbacks
%% ===================================================================

%%--------------------------------------------------------------------
%% @doc Start the `sc_push' application.
%% @end
%%--------------------------------------------------------------------
-spec start(StartType::start_type(), StartArgs::term()) ->
    {ok, pid(), list()} | {error, term()}.
start(_StartType, _StartArgs) ->
    {ok, App} = application:get_application(?MODULE),
    Opts = application:get_all_env(App),
    lager:info("Starting supervisor"),

    {ok, Pid} = sc_push_sup:start_link(Opts),

    lager:info("Started sc_push_sup, pid ~p", [Pid]),
    {ok, Pid, [{sup_pid, Pid}, {env, Opts}]}.

%%--------------------------------------------------------------------
%% @doc
%% This function is called when an application is about to be stopped, before
%% shutting down the processes of the application. State is the state returned
%% from Module:start/2, or [] if no state was returned. NewState is any term
%% and will be passed to Module:stop/1. The function is optional. If it is not
%% defined, the processes will be terminated and then Module:stop(State) is
%% called.
%% @end
%%--------------------------------------------------------------------
-spec prep_stop(State::term()) -> NewState::term().
prep_stop(State) ->
    {ok, App} = application:get_application(?MODULE),
    lager:info("Preparing to shut down application ~p", [App]),
    %SupPid = sc_util:req_val(sup_pid, State),
    Env = sc_util:req_val(env, State),
    Services = sc_util:val(services, Env, []),
    lager:info("Quiescing services ~p",
               [sc_util:req_val(name, Svc) || Svc <- Services]),
    _ = [sc_push:quiesce_service(Svc) || Svc <- Services],
    lager:info("Services quiesced, shutting down application ~p", [App]),
    State.

%%--------------------------------------------------------------------
%% @doc Stop the `sc_push' application.
%% @end
%%--------------------------------------------------------------------
-spec stop(State::term()) -> any().
stop(_State) ->
    ok.

%%--------------------------------------------------------------------
%% @doc
%% This function is called by an application after a code replacement, if there
%% are any changes to the configuration parameters. Changed is a list of
%% parameter-value tuples with all configuration parameters with changed
%% values, New is a list of parameter-value tuples with all configuration
%% parameters that have been added, and Removed is a list of all parameters
%% that have been removed.
%% @end
%%--------------------------------------------------------------------
-type pv_tuple() :: {term(), term()}.
-type pv_list() :: [pv_tuple()].
-spec config_change(Changed::pv_list(),
                    New::pv_list(),
                    Removed::list()) -> ok.
config_change(_Changed, _New, _Removed) ->
    ok.

