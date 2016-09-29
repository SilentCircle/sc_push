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

%%%-------------------------------------------------------------------
%%% @author Edwin Fine <efine@silentcircle.com>
%%% @doc
%%% Null push service. This is a do-nothing module that provides the
%%% required interfaces. Push notifications will always succeed (and,
%%% of course, not go anywhere) unless otherwise configured in the
%%% notification. This supports standalone testing.
%%%
%%% Sessions must have unique names within the node because they are
%%% registered. If more concurrency is desired, a session may elect to
%%% become a supervisor of other session, or spawn a pool of processes,
%%% or whatever it takes.
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(sc_push_svc_null_srv).

-behaviour(gen_server).

%% gen_server callbacks
-export([init/1,
        handle_call/3,
        handle_cast/2,
        handle_info/2,
        terminate/2,
        code_change/3]).

-include_lib("lager/include/lager.hrl").
-include_lib("sc_push_lib/include/sc_push_lib.hrl").

-define(SERVER, ?MODULE).

-define(assert(Cond),
    case (Cond) of
        true ->
            true;
        false ->
            throw({assertion_failed, ??Cond})
    end).

-define(assertList(Term), begin ?assert(is_list(Term)), Term end).
-define(assertInt(Term), begin ?assert(is_integer(Term)), Term end).
-define(assertPosInt(Term), begin ?assert(is_integer(Term) andalso Term > 0), Term end).
-define(assertBinary(Term), begin ?assert(is_binary(Term)), Term end).

-define(DEFAULT_LOG_FILE_NAME, "/tmp/" ++ atom_to_list(?MODULE) ++ ".log").
-define(LOG(S, Level, Fmt, Msg), ((S#state.log_fun)(S#state.log_h, Level, Fmt, Msg))).

-type terminate_reason() :: normal |
                            shutdown |
                            {shutdown, term()} |
                            term().

-record(state, {
        seq_no    = 0                       :: integer(),
        name      = undefined               :: atom()
    }).

%%%===================================================================
%%% API
%%%===================================================================
-export([start/2,
         start_link/2,
         stop/1,
         send/2,
         send/3,
         async_send/2,
         async_send/3,
         get_state/1]).

%%--------------------------------------------------------------------
%% @doc Start a named session as described by the options `Opts'.  The name
%% `Name' is registered so that the session can be referenced using the name to
%% call functions like send/2. Note that this function is only used
%% for testing; see start_link/2.
%% @end
%%--------------------------------------------------------------------
-type opt() ::  {log_dest, {file, string()}} | % default = "/tmp/sc_push_svc_null.log"
                {log_level, off | info}. % default = info
-spec start(Name::atom(), Opts::[opt()]) -> term().
start(Name, Opts) when is_atom(Name), is_list(Opts) ->
    gen_server:start({local, Name}, ?MODULE, [Name, Opts], []).

%%--------------------------------------------------------------------
%% @doc Start a named session as described by the options `Opts'.  The name
%% `Name' is registered so that the session can be referenced using the name to
%% call functions like send/2.
%% @end
%%--------------------------------------------------------------------
-spec start_link(Name::atom(), Opts::[opt()]) -> term().
start_link(Name, Opts) when is_atom(Name), is_list(Opts) ->
    gen_server:start_link({local, Name}, ?MODULE, [Name, Opts], []).

%%--------------------------------------------------------------------
%% @doc Stop session.
%% @end
%%--------------------------------------------------------------------
-spec stop(SvrRef::term()) -> term().
stop(SvrRef) ->
    gen_server:cast(SvrRef, stop).

%%--------------------------------------------------------------------
%% @equiv async_send(SvrRef, Notification, [])
-spec async_send(SvrRef::term(), Notification::list()) ->
       ok | {error, Reason::term()}.
async_send(SvrRef, Notification) when is_list(Notification) ->
    async_send(SvrRef, Notification, []).

%%--------------------------------------------------------------------
%% @doc Asynchronously send a notification specified by `Notification' via
%% `SvrRef' with options `Opts'.
%%
%% === Parameters ===
%%
%% For parameter descriptions, see {@link send/3}.
%% @end
%%--------------------------------------------------------------------
-spec async_send(term(), list(), list()) ->
       ok | {error, Reason::term()}.
async_send(SvrRef, Notification, Opts) when is_list(Notification),
                                            is_list(Opts) ->
    gen_server:cast(SvrRef, {async_send, Notification, Opts}).

%%--------------------------------------------------------------------
%% @equiv send(SvrRef, Notification, [])
-spec send(SvrRef::term(), Notification::list()) ->
       {ok, Ref::term()} | {error, Reason::term()}.
send(SvrRef, Notification) when is_list(Notification) ->
    send(SvrRef, Notification, []).

%%--------------------------------------------------------------------
%% @doc Send a notification specified by `Notification' via `SvrRef'
%% with options `Opts'.
%%
%% === Notification format ===
%%
%% ```
%% [
%%     {return, success | {error, term()}}, % default = success
%% ]
%% '''
%%
%% === Options ===
%%
%% Not currently supported, will accept any list.
%%
%% @end
%%--------------------------------------------------------------------
-spec send(term(), list(), list()) ->
       {ok, Ref::term()} | {error, Reason::term()}.
send(SvrRef, Notification, Opts) when is_list(Notification), is_list(Opts) ->
    gen_server:call(SvrRef, {send, Notification, Opts}).

%% @doc Schedule a callback if requested
schedule_cb(SvrRef, Opts, Ref, Status) when is_list(Opts) ->
    gen_server:cast(SvrRef, {do_callback, {Opts, Ref, Status}}).

%%--------------------------------------------------------------------
%% @private
%%--------------------------------------------------------------------
get_state(SvrRef) ->
    gen_server:call(SvrRef, get_state).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @end
%%--------------------------------------------------------------------
-spec init(term()) -> {ok, State::term()} |
                      {ok, State::term(), Timeout::timeout()} |
                      {ok, State::term(), 'hibernate'} |
                      {stop, Reason::term()} |
                      'ignore'
                      .

init([Name, Opts]) ->
    try validate_args(Name, Opts) of
        #state{} = State ->
            {ok, State}
    catch
        _What:Why ->
            {stop, {Why, erlang:get_stacktrace()}}
    end.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handle gen_server:call messages
%% @end
%%--------------------------------------------------------------------
-spec handle_call(Request::term(),
                  From::{pid(), Tag::term()},
                  State::term()) ->
    {reply, Reply::term(), NewState::term()} |
    {reply, Reply::term(), NewState::term(), Timeout::timeout()} |
    {reply, Reply::term(), NewState::term(), 'hibernate'} |
    {noreply, NewState::term()} |
    {noreply, NewState::term(), 'hibernate'} |
    {noreply, NewState::term(), Timeout::timeout()} |
    {stop, Reason::term(), Reply::term(), NewState::term()} |
    {stop, Reason::term(), NewState::term()}
    .

handle_call({send, Notification, Opts}, _From, #state{seq_no = Seq} = State) ->
    _ = lager:debug("send, Notification=~p, Opts=~p", [Notification, Opts]),
    Self = self(),
    Resp = case sc_util:val(return, Notification, success) of
        success ->
            NewSeq = Seq + 1,
            Reply = {ok, NewSeq},
            schedule_cb(Self, Opts, NewSeq, ok),
            {reply, Reply, State#state{seq_no = NewSeq}};
        Error ->
            schedule_cb(Self, Opts, undefined, Error),
            {reply, Error, State}
    end,
    _ = lager:info("send, response = ~p", [Resp]),
    Resp;

handle_call(get_state, _From, State) ->
    Reply = State,
    {reply, Reply, State};

handle_call(Request, _From, State) ->
    Reply = {error, {unknown_request, Request}},
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
-spec handle_cast(Request::term(),
                  State::term()) ->
    {noreply, NewState::term()} |
    {noreply, NewState::term(), 'hibernate'} |
    {noreply, NewState::term(), Timeout::timeout()} |
    {stop, Reason::term(), NewState::term()}
    .

handle_cast({async_send, Notification, Opts},
            #state{seq_no = Seq} = State0) ->
    _ = lager:debug("async_send, Notification=~p, Opts=~p",
                    [Notification, Opts]),
    Self = self(),
    State = case sc_util:val(return, Notification, success) of
        success ->
            NewSeq = Seq + 1,
            _ = lager:info("async_send success, new seq: ~B", [NewSeq]),
            schedule_cb(Self, Opts, NewSeq, ok),
            State0#state{seq_no = NewSeq};
        Error ->
            _ = lager:info("async_send error: ~p", [Error]),
            schedule_cb(Self, Opts, undefined, Error),
            State0
    end,
    {noreply, State};

handle_cast({do_callback, {Opts, Ref, Status}}, State) when is_list(Opts) ->
    ok = case proplists:get_value(callback, Opts) of
             {Pid, WhenToCallback} when is_pid(Pid),
                                        is_list(WhenToCallback) ->
                 case lists:member(completion, WhenToCallback) of
                     true ->
                         Pid ! {null, completion, Ref, Status},
                         ok;
                     false ->
                         ok
                 end;
             undefined -> % do nothing
                 ok
         end,
    {noreply, State};

handle_cast(stop, State) ->
    {stop, shutdown, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @end
%%--------------------------------------------------------------------
-spec handle_info(Request::term(),
                  State::term()) ->
    {noreply, NewState::term()} |
    {noreply, NewState::term(), 'hibernate'} |
    {noreply, NewState::term(), Timeout::timeout()} |
    {stop, Reason::term(), NewState::term()}
    .
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @end
%%--------------------------------------------------------------------
-spec terminate(Reason::terminate_reason(),
                State::term()) -> no_return().
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @end
%%--------------------------------------------------------------------
-spec code_change(OldVsn::term() | {down, term()},
                  State::term(),
                  Extra::term()) ->
    {ok, NewState::term()} |
    {error, Reason::term()}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

validate_args(Name, _Opts) ->
    #state{
        name = Name
    }.
