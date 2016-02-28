%%%----------------------------------------------------------------
%%% Purpose: Test suite for the 'sc_push' module.
%%%-----------------------------------------------------------------

-module(sc_push_SUITE).

-include_lib("common_test/include/ct.hrl").

-compile(export_all).

-define(assertMsg(Cond, Fmt, Args),
    case (Cond) of
        true ->
            ok;
        false ->
            ct:fail("Assertion failed: ~p~n" ++ Fmt, [??Cond] ++ Args)
    end
).

-define(assert(Cond), ?assertMsg((Cond), "", [])).
-define(assertThrow(Expr, Class, Reason),
    begin
            ok = (fun() ->
                    try (Expr) of
                        Res ->
                            {unexpected_return, Res}
                    catch
                        C:R ->
                            case {C, R} of
                                {Class, Reason} ->
                                    ok;
                                _ ->
                                    {unexpected_exception, {C, R}}
                            end
                    end
            end)()
    end
).

-define(ALERT_MSG, <<"sc_push_SUITE test message">>).

%%--------------------------------------------------------------------
%% COMMON TEST CALLBACK FUNCTIONS
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% Function: suite() -> Info
%%
%% Info = [tuple()]
%%   List of key/value pairs.
%%
%% Description: Returns list of tuples to set default properties
%%              for the suite.
%%
%% Note: The suite/0 function is only meant to be used to return
%% default data values, not perform any other operations.
%%--------------------------------------------------------------------
suite() -> [
        {timetrap, {seconds, 30}},
        {require, services},
        {require, registration},
        {require, wm_config}
    ].

%%--------------------------------------------------------------------
%% Function: init_per_suite(Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%%
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%% Reason = term()
%%   The reason for skipping the suite.
%%
%% Description: Initialization before the suite.
%%
%% Note: This function is free to add any key/value pairs to the Config
%% variable, but should NOT alter/remove any existing entries.
%%--------------------------------------------------------------------
init_per_suite(Config) ->
    ensure_started(sasl),
    ok = ssl:start(),
    ensure_started(inets),
    inets:start(httpc, [{profile, ?MODULE}]),

    Registration = ct:get_config(registration),
    ct:pal("Registration: ~p~n", [Registration]),

    Services = ct:get_config(services),
    ct:pal("Services: ~p~n", [Services]),

    WmConfig = template_replace(ct:get_config(wm_config), Config),
    ct:pal("WmConfig : ~p~n", [WmConfig]),

    [{registration, Registration},
     {services, Services},
     {wm_config, WmConfig} | Config].

%%--------------------------------------------------------------------
%% Function: end_per_suite(Config0) -> void() | {save_config,Config1}
%%
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%%
%% Description: Cleanup after the suite.
%%--------------------------------------------------------------------
end_per_suite(_Config) ->
    inets:stop(httpc, ?MODULE),
    ok = application:stop(inets),
    ok = ssl:stop(),
    ok = application:stop(sasl),
    ok.

%%--------------------------------------------------------------------
%% Function: init_per_group(GroupName, Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%%
%% GroupName = atom()
%%   Name of the test case group that is about to run.
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding configuration data for the group.
%% Reason = term()
%%   The reason for skipping all test cases and subgroups in the group.
%%
%% Description: Initialization before each test case group.
%%--------------------------------------------------------------------
init_per_group(_GroupName, Config) ->
    application:load(lager),
    [ok = application:set_env(lager, K, V) || {K, V} <- lager_config(Config)],
    {ok, _Started} = application:ensure_all_started(lager),
    Config.

%%--------------------------------------------------------------------
%% Function: end_per_group(GroupName, Config0) ->
%%               void() | {save_config,Config1}
%%
%% GroupName = atom()
%%   Name of the test case group that is finished.
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding configuration data for the group.
%%
%% Description: Cleanup after each test case group.
%%--------------------------------------------------------------------
end_per_group(_GroupName, _Config) ->
    application:stop(lager),
    application:stop(goldrush),
    application:stop(syntax_tools),
    application:stop(compiler),
    %ok = application:unload(lager),
    %code:purge(lager_console_backend), % ct gives error otherwise
    ok.

%%--------------------------------------------------------------------
%% Function: init_per_testcase(TestCase, Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%%
%% TestCase = atom()
%%   Name of the test case that is about to run.
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%% Reason = term()
%%   The reason for skipping the test case.
%%
%% Description: Initialization before each test case.
%%
%% Note: This function is free to add any key/value pairs to the Config
%% variable, but should NOT alter/remove any existing entries.
%%--------------------------------------------------------------------
init_per_testcase(start_and_stop_from_config_test, Config) ->
    init_per_testcase_common(Config);
init_per_testcase(start_and_stop_service_test, Config) ->
    init_per_testcase_no_start_services(Config);
init_per_testcase(_Case, Config0) ->
    Config = init_per_testcase_common(Config0),
    OverrideConfig = lists:keystore(services, 1, Config, {services, []}), % Will not pre-start services
    {ok, _FakeAppPid} = fake_app_start(OverrideConfig),
    Services = value(services, Config),
    start_services(Services),
    Config.

%%--------------------------------------------------------------------
%% Function: end_per_testcase(TestCase, Config0) ->
%%               void() | {save_config,Config1} | {fail,Reason}
%%
%% TestCase = atom()
%%   Name of the test case that is finished.
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%% Reason = term()
%%   The reason for failing the test case.
%%
%% Description: Cleanup after each test case.
%%--------------------------------------------------------------------
end_per_testcase(start_and_stop_from_config_test, Config) ->
    end_per_testcase_common(Config),
    Config;
end_per_testcase(start_and_stop_service_test, Config) ->
    end_per_testcase_no_start_services(Config);
end_per_testcase(_Case, Config) ->
    Services = value(services, Config),
    stop_services(Services),
    ok = fake_app_stop(sc_push_suite_fake_app),
    end_per_testcase_common(Config).

%%--------------------------------------------------------------------
%% Function: groups() -> [Group]
%%
%% Group = {GroupName,Properties,GroupsAndTestCases}
%% GroupName = atom()
%%   The name of the group.
%% Properties = [parallel | sequence | Shuffle | {RepeatType,N}]
%%   Group properties that may be combined.
%% GroupsAndTestCases = [Group | {group,GroupName} | TestCase]
%% TestCase = atom()
%%   The name of a test case.
%% Shuffle = shuffle | {shuffle,Seed}
%%   To get cases executed in random order.
%% Seed = {integer(),integer(),integer()}
%% RepeatType = repeat | repeat_until_all_ok | repeat_until_all_fail |
%%              repeat_until_any_ok | repeat_until_any_fail
%%   To get execution of cases repeated.
%% N = integer() | forever
%%
%% Description: Returns a list of test case group definitions.
%%--------------------------------------------------------------------
groups() ->
    [
        {
            service,
            [],
            [
                {group, clients},
                {group, rest_api}
            ]
        },
        {
            clients,
            [],
            [
                start_and_stop_from_config_test,
                start_and_stop_service_test,
                send_msg_test,
                send_msg_fail_test,
                send_msg_no_reg_test
            ]
        },
        {
            rest_api,
            [],
            [
                get_reg_id_test,
                reg_device_id_test
            ]
        }
    ].

%%--------------------------------------------------------------------
%% Function: all() -> GroupsAndTestCases | {skip,Reason}
%%
%% GroupsAndTestCases = [{group,GroupName} | TestCase]
%% GroupName = atom()
%%   Name of a test case group.
%% TestCase = atom()
%%   Name of a test case.
%% Reason = term()
%%   The reason for skipping all groups and test cases.
%%
%% Description: Returns the list of groups and test cases that
%%              are to be executed.
%%--------------------------------------------------------------------
all() ->
    [
        {group, service}
    ].

%%--------------------------------------------------------------------
%% TEST CASES
%%--------------------------------------------------------------------

% t_1(doc) -> ["t/1 should return 0 on an empty list"];
% t_1(suite) -> [];
% t_1(Config) when is_list(Config)  ->
%     ?line 0 = t:foo([]),
%     ok.

start_and_stop_from_config_test() ->
    [].

start_and_stop_from_config_test(doc) ->
    ["Start and stop top-level supervisor with preconfigured services"];
start_and_stop_from_config_test(suite) ->
    [];
start_and_stop_from_config_test(Config) ->
    ok = fake_app_stop(sc_push_suite_fake_app),
    Config.

start_and_stop_service_test() ->
    [].

start_and_stop_service_test(doc) ->
    ["Start and stop push services"];
start_and_stop_service_test(suite) ->
    [];
start_and_stop_service_test(Config) ->
    Services = value(services, Config),
    start_services(Services),
    stop_services(Services),
    RegPL = value(registration, Config),
    deregister_ids(RegPL),
    Config.

send_msg_test(doc) ->
    ["sc_push:send/1 should send a message to push"];
send_msg_test(suite) ->
    [];
send_msg_test(Config) ->
    RegPL = value(registration, Config),
    ok = sc_push:register_ids([RegPL]),
    Services = value(services, Config),
    Notification0 = [
        {alert, ?ALERT_MSG},
        {tag, value(tag, RegPL)},
        {return, success} % Will only work with sc_push_svc_null!
    ],
    [
        begin
                Svc = value(name, Service),
                Notification = [{service, Svc} | Notification0],
                Res = sc_push:send(Notification),
                ct:pal("Sent notification, result = ~p~n", [Res])
        end || Service <- Services
    ],
    deregister_ids(RegPL),
    ok.

send_msg_fail_test(doc) ->
    ["sc_push:send/1 should fail"];
send_msg_fail_test(suite) ->
    [];
send_msg_fail_test(Config) ->
    RegPL = value(registration, Config),
    ok = sc_push:register_ids([RegPL]),
    Services = value(services, Config),
    Notification0 = [
        {alert, ?ALERT_MSG},
        {tag, value(tag, RegPL)},
        {return, {error, forced_test_failure}} % Will only work with sc_push_svc_null!
    ],
    [
        begin
                Svc = value(name, Service),
                Notification = [{service, Svc} | Notification0],
                ct:pal("Sending notification: ~p~n", [Notification]),
                [{error, forced_test_failure}] = sc_push:send(Notification),
                ct:pal("Expected failure to send notification~n", [])
        end || Service <- Services
    ],
    deregister_ids(RegPL),
    ok.

send_msg_no_reg_test(doc) ->
    ["sc_push:send/1 should fail with tag not found"];
send_msg_no_reg_test(suite) ->
    [];
send_msg_no_reg_test(Config) ->
    RegPL = value(registration, Config),
    ok = sc_push:register_ids([RegPL]),
    Services = value(services, Config),
    FakeTag = <<"$$Completely bogus tag$$">>,
    Notification0 = [
        {alert, ?ALERT_MSG},
        {tag, FakeTag}
    ],
    [
        begin
                Svc = value(name, Service),
                Notification = [{service, Svc} | Notification0],
                Results = sc_push:send(Notification),
                Errors = proplists:get_value(error, Results),
                [{reg_not_found_for_tag, FakeTag}] = Errors,
                ct:pal("Got expected error (reg_not_found_for_tag) from send notification~n", [])
        end || Service <- Services
    ],
    deregister_ids(RegPL),
    ok.

%%====================================================================
%% REST API tests
%%====================================================================
get_reg_id_test(doc) -> [];
get_reg_id_test(suite) -> [];
get_reg_id_test(Config) ->
    %% Register IDs
    RegPL = value(registration, Config),
    ok = sc_push:register_ids([RegPL]),

    Service = value(service, RegPL),
    Token = value(token, RegPL),
    WmConfig = value(wm_config, Config),
    IP = value(ip, WmConfig),
    Port = value(port, WmConfig),
    URL = make_url(http, IP, Port,
                   ["registration", "service", Service,
                   "token", Token]),
    %% Look up registration
    ct:pal("Using URL ~p~n", [URL]),
    Resp = httpc:request(URL),
    ct:pal("Got response from HTTP req: ~p~n", [Resp]),

    %% Check response (which is an array of dicts)
    [JSON] = check_reg_http('GET', Resp),
    Service = sc_util:to_atom(value(<<"service">>, JSON)),
    Token = value(<<"token">>, JSON),

    %% Deregister
    deregister_ids(RegPL).

reg_device_id_test(doc) -> [];
reg_device_id_test(suite) -> [];
reg_device_id_test(Config) ->
    RegPL0 = value(registration, Config),

    DeviceId = value(device_id, RegPL0),
    Tag = value(tag, RegPL0),
    RegPL = lists:foldl(fun(K, Acc) -> lists:keydelete(K, 1, Acc) end,
                        RegPL0, [device_id, tag]),
    WmConfig = value(wm_config, Config),
    IP = value(ip, WmConfig),
    Port = value(port, WmConfig),

    URL = make_url(http, IP, Port,
                   ["registration", "device", DeviceId, "tag", Tag]),
    Headers = [{"X-SCPush-Debug", "true"}],
    ContentType = "application/json",
    Body = jsx:encode(RegPL),
    Req = {URL, Headers, ContentType, Body},
    %% Register with PUT
    ct:pal("PUT using URL ~p~nJSON Data:~p~n", [URL, Body]),
    Resp = httpc:request(put, Req, [], []),
    ct:pal("Got response from HTTP req: ~p~n", [Resp]),

    %% Check response
    check_reg_http('PUT', Resp),

    %% Deregister
    deregister_ids(RegPL0).

%%====================================================================
%% Internal helper functions
%%====================================================================
init_per_testcase_no_start_services(Config0) ->
    (catch end_per_testcase_no_start_services(Config0)),
    Config = init_per_testcase_common(Config0),
    OverrideConfig = lists:keystore(services, 1, Config, {services, []}), % Will not pre-start services
    {ok, _FakeAppPid} = fake_app_start(OverrideConfig),
    Config.

end_per_testcase_no_start_services(Config) ->
    ok = fake_app_stop(sc_push_suite_fake_app),
    end_per_testcase_common(Config).

init_per_testcase_common(Config) ->
    (catch end_per_testcase_common(Config)),
    ok = mnesia:create_schema([node()]),
    ok = mnesia:start(),
    ensure_started(xmerl),
    ensure_started(mochiweb),
    ensure_started(webmachine),
    ensure_started(unsplit),
    ensure_started(jsx),
    ensure_started(sc_util),
    ensure_started(sc_push_lib),
    Config.

end_per_testcase_common(Config) ->
    application:stop(sc_push_lib),
    application:stop(sc_util),
    application:stop(jsx),
    application:stop(unsplit),
    application:stop(webmachine),
    application:stop(mochiweb),
    ensure_started(xmerl),
    stopped = mnesia:stop(),
    ok = mnesia:delete_schema([node()]),
    Config.

start_service(Opts) when is_list(Opts) ->
    Name = value(name, Opts),
    {ok, Cwd} = file:get_cwd(),
    ct:pal("Current directory is ~p~n", [Cwd]),
    ct:pal("Starting service ~p with opts ~p~n", [Name, Opts]),
    sc_push:start_service(Opts).

stop_service(Opts) ->
    Name = value(name, Opts),
    ct:pal("Stopping service ~p~n", [Name]),
    sc_push:stop_service(Name).

start_services(Services) ->
    [
        begin
                ct:pal("About to start service with opts ~p", [Service]),
                {ok, Pid} = start_service(Service),
                ?assert(is_pid(Pid)),
                Pid
        end || Service <- Services
    ].

stop_services(Services) ->
    [ok = stop_service(Service) || Service <- Services].

deregister_id(RegPL) ->
    ID = sc_push_reg_api:make_id(value(device_id, RegPL),
                                 value(tag, RegPL)),
    ok = sc_push:deregister_id(ID),
    ct:pal("Deregistered ID ~p~n", [ID]).

deregister_ids(RegPL) ->
    ID = sc_push_reg_api:make_id(value(device_id, RegPL),
                                 value(tag, RegPL)),
    IDs = [ID],
    ok = sc_push:deregister_ids(IDs),
    ct:pal("Deregistered IDs ~p~n", [IDs]).

%%--------------------------------------------------------------------
%% This fake app is the parent of the top-level supervisor. It jumps
%% through some hoops because each test phase runs in its own process,
%% so we have to start an independent process to act as the application
%% process.
%%--------------------------------------------------------------------
fake_app_start(Config) ->
    Opts = [KV || K <- [services, wm_config], begin KV = lists:keyfind(K, 1, Config), KV /= false end],
    Pid = proc_lib:spawn(?MODULE, fake_app, [self(), Opts]),
    register(sc_push_suite_fake_app, Pid),
    ct:pal("Starting fake app (~p)~n", [Pid]),
    receive
        {Pid, started} ->
            ct:pal("Fake app confirmed started (~p)~n", [Pid]),
            {ok, Pid};
        {Pid, Error} ->
            ct:pal("Fake app error ~p~n", [Error]),
            Error
    after 5000 ->
            ct:pal("Fake app startup timeout (~p)~n", [Pid]),
            throw({wait_timeout, {fake_app, Pid}})
    end.

fake_app_stop(FakeApp) when is_atom(FakeApp) ->
    case erlang:whereis(FakeApp) of
        undefined ->
            ct:pal("Ignoring stop, not running: ~p~n", [FakeApp]),
            ok;
        Pid ->
            fake_app_stop(Pid)
    end;
fake_app_stop(Pid) when is_pid(Pid) ->
    ct:pal("Stopping fake app (~p)~n", [Pid]),
    Pid ! {self(), stop},
    receive
        {Pid, stopped} ->
            ct:pal("Fake app stopped~n", []),
            ok;
        Other ->
            ct:pal("Fake app received unexpected data while stopping: ~p~n", [Other]),
            {error, {got_unexpected_data, Other}}
    after 5000 ->
            ct:pal("Fake app timed out while stopping~n", []),
            {error, timeout}
    end.

fake_app(ParentPid, Config) ->
    process_flag(trap_exit, true),
    ct:pal("Fake app starting sc_push_sup with Config:~n~p~n", [Config]),
    Res = try
        sc_push_sup:start_link(Config)
    catch
        Class:Reason ->
            ct:pal("Fake app: sc_push_sup:start_link threw exception ~p:~p",
                    [Class, Reason]),
            ct:pal("Fake app: sc_push_sup:start_link stack trace:~n~p",
                   [erlang:get_stacktrace()]),
            ParentPid ! {self(), {exception, {Class, Reason}}},
            exit(Class, Reason)
    end,

    ct:pal("Fake app: sc_push_sup:start_link returned ~p", [Res]),

    case Res of
        {ok, SupPid} ->
            ParentPid ! {self(), started},
            ct:pal("Fake app started supervisor ~p~n", [SupPid]),
            fake_app_loop(SupPid);
        Error ->
            ct:pal("Fake app got error: ~p~n", [Error]),
            ParentPid ! {self(), Error}
    end.

fake_app_loop(SupPid) ->
    receive
        {From, stop} when is_pid(From) ->
            ct:pal("Fake app sending ~p to ~p~n", [{self(), stopped}, From]),
            From ! {self(), stopped},
            ct:pal("Fake app stopping sup pid ~p~n", [SupPid]),
            {dictionary, Dict} = process_info(SupPid, dictionary),
            [[ParentPid|_]] = [A || {'$ancestors', A} <- Dict],
            SupPid ! {'EXIT', ParentPid, shutdown};
        Data ->
            ct:pal("Fake app received unexpected data ~p~n", [Data]),
            fake_app_loop(SupPid)
    end.

%%====================================================================
%% Lager support
%%====================================================================
lager_config(Config) ->
    PrivDir = value(priv_dir, Config), % Standard CT variable
    [
     {handlers, [
                 {lager_console_backend, info},
                 {lager_file_backend, [
                                       {file, filename:join(PrivDir, "error.log")},
                                       {level, error}
                                      ]
                 },
                 {lager_file_backend, [
                                       {file, filename:join(PrivDir, "console.log")},
                                       {level, debug}
                                      ]
                 }
                ]
     },
     %% Whether to write a crash log, and where. Undefined means no crash logger.
     {crash_log, filename:join(PrivDir, "crash.log")}
    ].

%%====================================================================
%% General helper functions
%%====================================================================
value(Key, Config) when is_list(Config) ->
    V = proplists:get_value(Key, Config),
    ?assertMsg(V =/= undefined, "Required key missing: ~p~n", [Key]),
    V.

maybe_get_pid(X) when is_pid(X) ->
    X;
maybe_get_pid(X) when is_atom(X) ->
    erlang:whereis(X).

ensure_started(App) ->
    case application:start(App) of
        ok ->
            ok;
        {error, {already_started, App}} ->
            ok
    end.

make_url(http, IP, Port, PathList) when is_list(IP) ->
    SPathList = [sc_util:to_list(X) || X <- PathList],
    L = ["http://", IP, $:, sc_util:to_list(Port), $/,
         string:join(SPathList, "/")],
    binary_to_list(list_to_binary(L)).

check_reg_http(Method, {ok, {StatusLine, _Headers, Body}}) ->
    {_HttpVersion, StatusCode, ReasonPhrase} = StatusLine,
    ct:log("HTTP ~p ~B ~s", [Method, StatusCode, ReasonPhrase]),
    true = (StatusCode >= 200 andalso StatusCode =< 299),
    ct:log("Body = ~s", [Body]),
    jsx:decode(list_to_binary(Body));
check_reg_http(Method, {ok, {StatusCode, Body}}) ->
    ct:log("HTTP ~p ~B", [Method, StatusCode]),
    true = (StatusCode >= 200 andalso StatusCode =< 299),
    ct:log("Body = ~s", [Body]),
    jsx:decode(list_to_binary(Body));
check_reg_http(Method, {error, Reason} = Error) ->
    ct:log("HTTP ~p failed with error: ~p", [Method, Reason]),
    throw(Error).

template_replace(PropList, Config) ->
    [template_prop_replace(K, V, Config) || {K, V} <- PropList].

template_prop_replace(K, V, Config) when is_list(V) ->
    NewV = try find_template(V) of
        {ok, NameList} ->
            replace_multiple(NameList, V, Config);
        _ ->
            V
    catch
        _:_ ->
            V
    end,
    {K, NewV};
template_prop_replace(K, V, _Config) ->
    {K, V}.

replace_multiple([Name|Names], V, Config) ->
    NewV = replace_one(Name, V, Config),
    replace_multiple(Names, NewV, Config);
replace_multiple([], V, _Config) ->
    V.

replace_one(Name, V, Config) ->
    NameAtom = list_to_atom(Name),
    Replacement = val_s(NameAtom, Config),
    replace_template(Name, V, Replacement).

find_template(V) ->
    Res = re:run(V, "\\{\\{([A-Za-z0-9_]+)\\}\\}", [global, {capture, all_but_first, list}]),
    case Res of
        {match, Captures} ->
            {ok, lists:usort(lists:append(Captures))};
        nomatch ->
            nomatch
    end.

replace_template(Name, V, Replacement) ->
    re:replace(V, "\\{\\{" ++ Name ++ "\\}\\}", Replacement, [global, {return, list}]).

val_s(Key, PL) ->
    case lists:keyfind(Key, 1, PL) of
        {Key, Val} ->
            sc_util:to_list(Val);
        false ->
            ""
    end.

