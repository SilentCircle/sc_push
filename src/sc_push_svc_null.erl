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
-module(sc_push_svc_null).

-behaviour(supervisor).

%% API
-export([
    start_link/1,
    start/1, % For testing only
    stop/1,   % For testing only
    start_session/1,
    stop_session/1,
    quiesce_session/1,
    get_session_pid/1,
    send/2,
    send/3,
    async_send/2,
    async_send/3
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

-define(DEFAULT_START_TIMEOUT, 5000).

%% ===================================================================
%% Types
%% ===================================================================
-type session_opt() :: {mod, atom()} |
                       {name, atom()} |
                       {config, proplists:proplist()}.
-type session_config() :: [session_opt()].
-type session_configs() :: [session_config()].

%% ===================================================================
%% API functions
%% ===================================================================

%%--------------------------------------------------------------------
%% @doc `Opts' is a list of proplists.
%% Each proplist is a session definition containing
%% name, mod, and config keys.
%% @end
%%--------------------------------------------------------------------
-spec start_link(Opts) -> Result when
      Opts :: session_configs(), Result :: any().
start_link(Opts) when is_list(Opts) ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, Opts).

-spec start(Opts) -> Result when
      Opts :: session_configs(), Result :: any().
start(Opts) when is_list(Opts) ->
    case start_link(Opts) of
        {ok, Pid}  = Res ->
            unlink(Pid),
            Res;
        Other ->
            Other
    end.

stop(SupRef) ->
    exit(SupRef, quiesce).

-spec start_session(Opts) -> Result when
      Opts :: proplists:proplist(),
      Result :: {ok, pid()} | {error, already_started} | {error, Reason},
      Reason :: term().
start_session(Opts) when is_list(Opts) ->
    Timeout = get_timeout(Opts),
    ChildSpec = sc_util:make_child_spec(Opts, Timeout),
    supervisor:start_child(?MODULE, ChildSpec).

%%--------------------------------------------------------------------
%% @doc Stop named session.
%% @end
%%--------------------------------------------------------------------
-spec stop_session(Name::atom()) -> ok | {error, Reason::term()}.
stop_session(Name) when is_atom(Name) ->
    case supervisor:terminate_child(?MODULE, Name) of
        ok ->
            _ = supervisor:delete_child(?MODULE, Name),
            ok;
        {error, not_found} ->
            ok;
        Error ->
            Error
    end.

%%--------------------------------------------------------------------
%% @doc Quiesce named session.
%% This signals the session to prepare for shutdown by refusing to
%% accept any more notifications, but still servicing in-flight
%% requests.
%% @end
%%--------------------------------------------------------------------

%% TODO: COmplete this function.
-spec quiesce_session(Name) -> Result when
      Name :: atom(), Result:: ok | {error, Reason}, Reason :: term().
quiesce_session(Name) when is_atom(Name) ->
    {error, nyi}.

%%--------------------------------------------------------------------
%% @doc Get pid of named session.
%% @end
%%--------------------------------------------------------------------
-spec get_session_pid(Name::atom()) -> pid() | undefined.
get_session_pid(Name) when is_atom(Name) ->
    erlang:whereis(Name).

%% @doc Send notification to named session.
-spec send(term(), sc_types:proplist(atom(), term())) ->
    {ok, Ref::term()} | {error, Reason::term()}.
send(Name, Notification) when is_list(Notification) ->
    Opts = [],
    send(Name, Notification, Opts).

%% @doc Send notification to named session with options Opts.
-spec send(term(), sc_types:proplist(atom(), term()), list()) ->
    {ok, Ref::term()} | {error, Reason::term()}.
send(Name, Notification, Opts) when is_list(Notification), is_list(Opts) ->
    sc_push_svc_null_srv:send(Name, Notification, Opts).

%% @doc Asynchronously send notification to named session.
-spec async_send(term(), sc_types:proplist(atom(), term())) ->
    ok | {error, Reason::term()}.
async_send(Name, Notification) when is_list(Notification) ->
    Opts = [],
    async_send(Name, Notification, Opts).

%% @doc Asynchronously send notification to named session with options Opts.
-spec async_send(term(), sc_types:proplist(atom(), term()), list()) ->
    ok | {error, Reason::term()}.
async_send(Name, Notification, Opts) when is_list(Notification),
                                          is_list(Opts) ->
    sc_push_svc_null_srv:async_send(Name, Notification, Opts).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

%%--------------------------------------------------------------------
%% @doc `Opts' is a list of proplists.
%% Each proplist is a session definition containing
%% name, mod, and config keys.
%% @end
%%--------------------------------------------------------------------

-spec init(Opts) -> Result
    when Opts :: session_configs(),
         Result :: {ok, {SupFlags, Children}} | ignore,
         SupFlags :: {'one_for_one', non_neg_integer(), pos_integer()},
         Children :: [{_,
                       {Mod :: atom(), 'start_link', Args :: [any()]},
                       'permanent', non_neg_integer(), 'worker', [atom()]
                      }].
init(Opts) ->
    RestartStrategy    = one_for_one,
    MaxRestarts        = 10, % If there are more than this many restarts
    MaxTimeBetRestarts = 60, % In this many seconds, then terminate supervisor
    SupFlags = {RestartStrategy, MaxRestarts, MaxTimeBetRestarts},
    Children = make_child_specs(Opts),
    {ok, {SupFlags, Children}}.

make_child_specs(Cfgs) ->
    [sc_util:make_child_spec(Cfg, get_timeout(Cfg)) || Cfg <- Cfgs].

get_timeout(Cfg) ->
    sc_util:val(start_timeout, Cfg, ?DEFAULT_START_TIMEOUT).
