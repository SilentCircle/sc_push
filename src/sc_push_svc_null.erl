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
    get_session_pid/1,
    send/2,
    send/3
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

%%--------------------------------------------------------------------
%% @doc `Opts' is a list of proplists.
%% Each proplist is a session definition containing
%% name, mod, and config keys.
%% @end
%%--------------------------------------------------------------------
start_link(Opts) when is_list(Opts) ->
    case supervisor:start_link({local, ?SERVER}, ?MODULE, Opts) of
        {ok, _} = Res ->
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

-spec start_session(Opts::list()) ->
    {ok, pid()} | {error, already_started} | {error, Reason::term()}.
start_session(Opts) when is_list(Opts) ->
    Timeout = sc_util:val(start_timeout, Opts, 5000),
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
    gen_server:call(Name, {send, Notification, Opts}).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

%%--------------------------------------------------------------------
%% @doc `Opts' is a list of proplists.
%% Each proplist is a session definition containing
%% name, mod, and config keys.
%% @end
%%--------------------------------------------------------------------
-type init_opts() :: [session_config()].
-type session_config() :: [session_opt()].
-type session_opt() :: {mod, atom()} |
                       {name, atom()} |
                       {config, proplists:proplist()}.
-spec init(Opts) -> Result
    when Opts :: init_opts(),
         Result :: {ok, {SupFlags, Children}},
         SupFlags :: {'one_for_one', non_neg_integer(), non_neg_integer()},
         Children :: [{_,
                       {Mod :: atom(), 'start_link', Args :: [any()]},
                       'permanent', non_neg_integer(), 'worker', [atom()]
                      }].
init(Opts) ->
    RestartStrategy    = one_for_one,
    MaxRestarts        = 10, % If there are more than this many restarts
    MaxTimeBetRestarts = 60, % In this many seconds, then terminate supervisor
    Timeout = sc_util:val(start_timeout, Opts, 5000),

    SupFlags = {RestartStrategy, MaxRestarts, MaxTimeBetRestarts},
    Children = [sc_util:make_child_spec(Sess, Timeout) || Sess <- Opts],
    {ok, {SupFlags, Children}}.

