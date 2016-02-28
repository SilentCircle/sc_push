#!/usr/bin/escript

%%====================================================================
%% Set a Webmachine route to output debug trace files and support
%% browsing on http(s)://host:port/wm_trace/.
%%
%% This expects support in the wm resource module itself
%% as follows:
%%
%% init(Config) ->
%%    {config_debug(Config), #ctx{cfg = Config}}.
%%
%%  config_debug(Config) ->
%%      case proplists:get_value(debug, Config, false) of
%%          false ->
%%              ok;
%%          [_|_] = DbgFilePath ->
%%              {trace, DbgFilePath}
%%      end.
%%
%%  Routes should be specified as follows:
%%
%%  /foo/bar/:var/baz == ["foo", "bar", var, "baz"]
%%  /foo/bar/:var/baz/* == ["foo", "bar", var, "baz", "*"]
%%
%%====================================================================

main([SNode, SCookie, SRoute, SModule, STracePath]) ->
    RC = try
        run(SNode, SCookie, SRoute, SModule, STracePath),
        0
    catch X:Y ->
        err_msg("***** ~p:~n~p~n", [X, Y]),
        err_msg("~p~n", [erlang:get_stacktrace()]),
        1
    end,
    halt(RC);

main(_) ->
    usage().

run(SNode, SCookie, SRoute, SModule, STracePath) ->
    Node = list_to_atom(SNode),
    connect_to_node(Node, list_to_atom(SCookie)),
    set_trace(Node, SRoute, SModule, STracePath).

connect_to_node(Node, Cookie) ->
    start_distributed(derive_node_name(Node)),
    erlang:set_cookie(node(), Cookie),
    net_kernel:hidden_connect_node(Node).

set_trace(Node, SRoute, SModule, STracePath) ->
    Mod = list_to_atom(SModule),
    Path = tokenized_path(SRoute),
    Route = case string:strip(STracePath) of
        "off" ->
            make_route(Node, Path, Mod, off);
        [_|_] = STP ->
            make_route(Node, Path, Mod, STP)
    end,
    replace_route(Node, Route),
    update_trace_rules(Node, Route).

update_trace_rules(Node, {_,_,L}) when is_list(L) ->
    case proplists:get_value(debug, L) of
        X when X =:= undefined; X =:= "" ->
            do_rpc(Node, wmtrace_resource, remove_dispatch_rules, []);
        Path ->
            do_rpc(Node, wmtrace_resource, add_dispatch_rule, ["wmtrace", Path])
    end.


replace_route(Node, {Path,_Mod,_Opts} = R) ->
    case lookup_route_by_path(Node, Path) of
        undefined ->
            ok;
        CurrRoute ->
            do_rpc(Node, webmachine_router, remove_route, [CurrRoute])
    end,
    do_rpc(Node, webmachine_router, add_route, [R]).

-spec make_route(atom(),[string()|atom()], atom(), string()|off)
    -> {list(), atom(), list()}.
make_route(Node, Path, Mod, TracePath) ->
    case lookup_route_by_path(Node, Path) of
        {Path, Mod, Opts} ->
            {Path, Mod, trace_path(TracePath, Opts)};
        undefined ->
            {Path, Mod, trace_path(TracePath, [])}
    end.

-spec lookup_route_by_path(atom(), list())
    -> {list(), atom(), list()} | undefined.
lookup_route_by_path(Node, Path) ->
    Rs = do_rpc(Node, webmachine_router, get_routes, []),
    case [R || {P, _M, _Opts} = R <- Rs, P =:= Path] of
        [] ->
            undefined;
        [Route] ->
            Route;
        [Route|_] ->
            err_msg("Warning: using first of multiple matching routes for ~p~n",
                    [Path]),
            Route
    end.

tokenized_path(S) ->
    [
        case El of
            ":" ++ Tok ->
                list_to_atom(Tok);
            _ ->
                El
        end || El <- string:tokens(string:strip(S), "/")
    ].

trace_path(off, Opts) ->
    lists:keydelete(debug, 1, Opts);
trace_path(Path, Opts) ->
    [{debug, Path} | lists:keydelete(debug, 1, Opts)].


%%--------------------------------------------------------------------
%% usage
%%--------------------------------------------------------------------
usage() ->
    err_msg("usage: ~s scpf-node cookie route resource-module trace-file-path~n~n"
            "route~n\tresource route in format /first/second/:token/third~n"
            "resource-module~n"
            "\tname of wm resource module used, e.g. my_wm_res~n"
            "trace-file-path~n"
            "\tdirectory in which trace files to be written, or 'off' to remove trace~n",
            [escript:script_name()]),
    err_msg("~nExample:~n~n"
            "~s scpf@127.0.0.1 scpf /registration/tag/:tag sc_push_reg_wm_tag /tmp~n",
            [escript:script_name()]),
    halt(1).

%%--------------------------------------------------------------------
%% err_msg
%%--------------------------------------------------------------------
err_msg(Fmt, Args) ->
    io:format(standard_error, Fmt, Args).

%%--------------------------------------------------------------------
%%% Perform an RPC call and throw on error
%%%--------------------------------------------------------------------
do_rpc(Node, M, F, A) ->
    try rpc:call(Node, M, F, A) of
        {badrpc, Reason} ->
            err_msg("RPC Error: ~p~n", [Reason]),
            throw({rpcerror, {Reason, {Node, M, F, A}}});
        Result ->
            Result
        catch _:Why ->
            throw(Why)
    end.

start_distributed(ThisNode) ->
    case net_kernel:start([ThisNode, longnames]) of
        {ok, _Pid} ->
            ok;
        {error, {already_started, _Pid}} ->
            ok;
        {error, Reason} ->
            err_msg("Cannot start this node (~p) as a distributed node,"
                    " reason:~n~p~n", [ThisNode, Reason]),
            throw(Reason)
    end.

nodehost(Node) when is_atom(Node) ->
    nodehost(atom_to_list(Node));
nodehost(SNode) when is_list(SNode) ->
    [_Name, Host] = string:tokens(SNode, "@"),
    Host.

derive_node_name(Node) ->
    list_to_atom(atom_to_list(?MODULE) ++ "@" ++ nodehost(Node)).

