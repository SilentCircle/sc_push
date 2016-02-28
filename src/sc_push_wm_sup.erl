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
%% @doc Supervisor for the webmachine part of the sc_push application.

-module(sc_push_wm_sup).
-author('Edwin Fine <efine@silentcircle.com>').

-behaviour(supervisor).

%% External exports
-export([start_link/0, start_link/1, upgrade/0]).

%% supervisor callbacks
-export([init/1]).

-include_lib("lager/include/lager.hrl").

%% @spec start_link() -> ServerRet
%% @doc API for starting the supervisor.
start_link() ->
    start_link([]).

%% @spec start_link(Env) -> ServerRet
%% @doc API for starting the supervisor.
start_link(Env) when is_list(Env) ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, Env).

%% @spec upgrade() -> ok
%% @doc Add processes if necessary.
upgrade() ->
    {ok, {_, Specs}} = init([]),

    Old = sets:from_list(
            [Name || {Name, _, _, _} <- supervisor:which_children(?MODULE)]),
    New = sets:from_list([Name || {Name, _, _, _, _, _} <- Specs]),
    Kill = sets:subtract(Old, New),

    sets:fold(fun (Id, ok) ->
                      _ = supervisor:terminate_child(?MODULE, Id),
                      _ = supervisor:delete_child(?MODULE, Id),
                      ok
              end, ok, Kill),

    _ = [supervisor:start_child(?MODULE, Spec) || Spec <- Specs],
    ok.

%% @spec init([]) -> SupervisorTree
%% @doc supervisor callback.
init([]) ->
    init([{wm_config, default_wm_config()}]);
init([_|_] = Env) ->
    WmConfig0 = proplists:get_value(wm_config, Env, default_wm_config()),
    Dispatch = get_dispatch_list(WmConfig0),
    _ = lager:info("Using dispatch list = ~p", [Dispatch]),
    WmConfig1 = lists:keystore(dispatch, 1, WmConfig0, {dispatch, Dispatch}),
    WmConfig2 = ensure_required_props(WmConfig1,
                                      [{ip, default_ip()},
                                       {port, default_port()}]),
    Web = {webmachine_mochiweb,
           {webmachine_mochiweb, start, [WmConfig2]},
           permanent, 5000, worker, [mochiweb_socket_server]},
    Processes = [Web],
    {ok, { {one_for_one, 10, 10}, Processes} }.

default_wm_config() ->
    Ip = default_ip(),
    Port = default_port(),

    Dispatch = get_dispatch_list([]),

    [
        {ip, Ip},
        {port, Port},
        {log_dir, "priv/log"},
        {dispatch, Dispatch}
    ].

ensure_required_props(PL, ReqVals) ->
    lists:foldl(fun({K, DefVal}, Acc) -> ensure_property(K, Acc, DefVal) end,
                PL,
                ReqVals).

ensure_property(Key, PL, DefaultVal) ->
    case proplists:get_value(Key, PL) of
        undefined ->
            [{Key, DefaultVal}|PL];
        _ ->
            PL
    end.

default_ip() ->
    case os:getenv("WEBMACHINE_IP") of
        false -> "0.0.0.0";
        Any -> Any
    end.

default_port() ->
    case os:getenv("WEBMACHINE_PORT") of
        false -> 8000;
        AnyPort -> AnyPort
    end.

get_dispatch_list(Env) ->
    App = case application:get_application(?MODULE) of
        {ok, A} ->
            A;
        _ ->
            ?MODULE
    end,
    PrivDir = priv_dir(App),

    CurDir = case file:get_cwd() of
        {ok, Cwd} ->
            Cwd;
        _ ->
            "."
    end,

    _ = lager:info("Current dir = ~p", [CurDir]),

    _ = lager:info("PrivDir = ~s", [PrivDir]),

    Dispatch = proplists:get_value(dispatch, Env, "dispatch.conf"),

    case find_file([Dispatch, {PrivDir, Dispatch}]) of
        {ok, File} ->
            {ok, DispatchList} = file:consult(File),
            DispatchList;
        false ->
            Dispatch % Hopefully is dispatch list
    end.

find_file([{Base, Name}|Rest]) ->
    try filename:join(Base, Name) of
        Joined ->
            find_file([Joined|Rest])
    catch
        _:_ ->
            find_file(Rest)
    end;
find_file([File|Rest]) ->
    case filelib:is_file(File) of
        true ->
            {ok, File};
        false ->
            find_file(Rest)
    end;
find_file([]) ->
    false.

%% @doc return the priv dir
priv_dir(Mod) ->
    case code:priv_dir(Mod) of
        {error, bad_name} ->
            Ebin = filename:dirname(code:which(Mod)),
            _ = lager:info("code:priv_dir(~p) returned {error,bad_name}, so "
                           "we will use ebin dir ~s", [Mod, Ebin]),
            filename:join(filename:dirname(Ebin), "priv");
        PrivDir ->
            _ = lager:info("code:priv_dir(~p) returned ~s", [Mod, PrivDir]),
            PrivDir
    end.

