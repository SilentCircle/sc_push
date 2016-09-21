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
%%% This module is the Erlang API for Silent Circle push notifications
%%% and registrations.
%%% @end
%%%-------------------------------------------------------------------
-module(sc_push).

%%--------------------------------------------------------------------
%% Includes
%%--------------------------------------------------------------------
-include_lib("sc_push_lib/include/sc_push_lib.hrl").
-include_lib("lager/include/lager.hrl").

%%-----------------------------------------------------------------------
%% Types
%%-----------------------------------------------------------------------
-type reg_api_func_name() :: 'get_registration_info_by_device_id' |
                             'get_registration_info_by_svc_tok' |
                             'get_registration_info_by_tag'.

%%--------------------------------------------------------------------
%% Defines
%%--------------------------------------------------------------------
-define(CHILD(I, Type, Opts, Timeout),
    {I, {I, start_link, Opts}, permanent, Timeout, Type, [I]}
).

-define(NAMED_CHILD(I, Mod, Type, Args, Timeout),
    {I, {Mod, start_link, Args}, permanent, Timeout, Type, [Mod]}
).

%%--------------------------------------------------------------------
%% Records
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------
-export([
        start/0,
        start_service/1,
        stop_service/1,
        start_session/2,
        stop_session/2,
        get_session_pid/1,
        send/1,
        send/2,
        async_send/1,
        async_send/2,
        register_id/1,
        register_ids/1,
        register_service/1,
        deregister_id/1,
        deregister_ids/1,
        deregister_device_ids/1,
        get_registration_info_by_tag/1,
        get_registration_info_by_id/1,
        get_registration_info_by_svc_tok/2,
        get_service_config/1,
        make_service_child_spec/1
    ]).

start() ->
    ensure_started(sasl),
    ensure_started(compiler),
    ensure_started(syntax_tools),
    ensure_started(goldrush),
    ensure_started(lager),
    ensure_started(crypto),
    ensure_started(public_key),
    ensure_started(ssl),
    ensure_started(inets),
    _ = mnesia:create_schema([node()]),
    ensure_started(mnesia),
    ensure_started(unsplit),
    ensure_started(mochiweb),
    ensure_started(webmachine),
    ensure_started(jsx),
    ensure_started(sc_util),
    ensure_started(sc_push_lib),
    ensure_started(sc_push).

%%--------------------------------------------------------------------
%% @doc Start a push service.
%%
%% === Synopsis ===
%% ```
%% Cfg = [
%%     {name, 'null'},
%%     {mod, 'sc_push_svc_null'},
%%     {description, "Null Push Service"},
%%     {sessions, [
%%             [
%%                 {name, 'null-com.silentcircle.SCPushSUITETest'},
%%                 {mod, sc_push_svc_null},
%%                 {config, []}
%%             ]
%%         ]}
%% ],
%% {ok, Pid} = sc_push:start_service(Cfg).
%% '''
%%
%% <dl>
%%   <dt>`{name, atom()}'</dt>
%%      <dd>
%%      A name that denotes the push service for which the
%%      caller is registering. Currently this includes `apns' for
%%      Apple Push, and `gcm' for Android (Google Cloud Messaging) push.
%%      There is also a built-in `null' service for testing.
%%      </dd>
%%   <dt>`{mod, atom()}'</dt>
%%      <dd>
%%      All calls to a service are done via the service-specific
%%      API module, which must be on the code path. This is the name
%%      of that API module. All API modules have the same public interface
%%      and are top-level supervisors. They must therefore implement the
%%      Erlang supervisor behavior.
%%      </dd>
%%   <dt>`{description, string()}'</dt>
%%      <dd>
%%      A human-readable description of the push service.
%%      </dd>
%%   <dt>`{sessions, list()}'</dt>
%%      <dd>
%%      A list of proplists. Each proplist describes a session to be
%%      started. See `start_session/1' for details.
%%      </dd>
%% </dl>
%%
%% TODO: Create a behavior for the API.
%%
%% @end
%%--------------------------------------------------------------------
-spec start_service(sc_types:proplist(atom(), term())) ->
      {ok, pid()} | {error, term()}.
start_service(ServiceOpts) when is_list(ServiceOpts) ->
    Desc = sc_util:req_val(description, ServiceOpts),
    ChildSpec = make_service_child_spec(ServiceOpts),
    _ = lager:info("Starting ~p", [Desc]),
    case supervisor:start_child(sc_push_sup, ChildSpec) of
        {ok, _} = Result ->
            ok = register_service(ServiceOpts),
            Result;
        Err ->
            Err
    end.

%%--------------------------------------------------------------------
%% @doc Stops a service and all sessions for that service.
%% @end
%%--------------------------------------------------------------------
-type child_id() :: term(). % Not a pid().
-spec stop_service(pid() | child_id()) ->
      ok | {error, term()}.
stop_service(Id) ->
    Res = case supervisor:terminate_child(sc_push_sup, Id) of
        ok ->
            supervisor:delete_child(sc_push_sup, Id);
        Err ->
            Err
    end,
    unregister_service(Id),
    Res.

%%--------------------------------------------------------------------
%% @doc Make a supervisor child spec for a service. The name of the
%% supervisor module is obtained from the API module, and is what will
%% be started. Obviously, it must be a supervisor.
%% @see start_service/1
%% @end
%%--------------------------------------------------------------------
-spec make_service_child_spec(sc_types:proplist(atom(), term())) ->
      supervisor:child_spec().
make_service_child_spec(Opts) when is_list(Opts) ->
    Name = sc_util:req_val(name, Opts),
    SupMod = sc_util:req_val(mod, Opts),
    Sessions = sc_util:req_val(sessions, Opts),
    _Description = sc_util:req_val(description, Opts),
    ?NAMED_CHILD(Name, SupMod, supervisor, [Sessions], 5000).


%%--------------------------------------------------------------------
%% @doc Register a service in the service configuration registry.
%% @see start_service/1
%% @end
%%--------------------------------------------------------------------
-spec register_service(sc_types:proplist(atom(), term())) -> ok.
register_service(Svc) when is_list(Svc) ->
    sc_push_lib:register_service(Svc).

%%--------------------------------------------------------------------
%% @doc Unregister a service in the service configuration registry.
%% @see start_service/1
%% @end
%%--------------------------------------------------------------------
-spec unregister_service(ServiceName::atom()) -> ok.
unregister_service(Name) when is_atom(Name) ->
    sc_push_lib:unregister_service(Name).

%%--------------------------------------------------------------------
%% @doc Get service configuration
%% @see start_service/1
%% @end
%%--------------------------------------------------------------------
-type std_proplist() :: sc_types:proplist(atom(), term()).
-spec get_service_config(Service::term()) ->
    {ok, std_proplist()} | {error, term()}.
get_service_config(Service) ->
    sc_push_lib:get_service_config(Service).


%%--------------------------------------------------------------------
%% @doc Start named session as described in the options proplist `Opts'.
%% `config' is service-dependent.
%% == IMPORTANT NOTE ==
%% `name' <strong>must</strong> be in the format `service-api_key', for
%% example, if the service name is `apns', and the api_key is, in this case,
%% `com.silentcircle.SilentText', then the session name must be
%% `apns-com.silentcircle.SilentText'.
%% === APNS Service ===
%% ```
%% [
%%     {mod, 'sc_push_svc_apns'},
%%     {name, 'apns-com.silentcircle.SilentText'},
%%     {config, [
%%         {host, "gateway.push.apple.com"},
%%         {bundle_seed_id, <<"com.silentcircle.SilentText">>},
%%         {bundle_id, <<"com.silentcircle.SilentText">>},
%%         {ssl_opts, [
%%             {certfile, "/etc/ejabberd/certs/com.silentcircle.SilentText.cert.pem"},
%%             {keyfile,  "/etc/ejabberd/certs/com.silentcircle.SilentText.key.unencrypted.pem"}
%%         ]}
%%     ]}
%% ]
%% '''
%% === GCM Service ===
%% ```
%% [
%%     {mod, 'sc_push_svc_gcm'},
%%     {name, 'gcm-com.silentcircle.silenttext'},
%%     {config, [
%%         {api_key, <<"AIzaSyCUIZhzjEQvb4wSlg6Uhi3OqLaC5vyv73w">>},
%%         {ssl_opts, [
%%             {verify, verify_none},
%%             {reuse_sessions, true}
%%         ]}
%%
%%         % Optional properties, showing default values
%%         %{uri, "https://android.googleapis.com/gcm/send"}
%%         %{restricted_package_name, <<>>}
%%         %{max_attempts, 5}
%%         %{retry_interval, 1}
%%         %{max_req_ttl, 120}
%%     ]}
%% ]
%% '''
%% @end
%%--------------------------------------------------------------------
-spec start_session(Service::atom(), Opts::list()) ->
    {ok, pid()} | {error, already_started} | {error, Reason::term()}.
start_session(Service, Opts) when is_atom(Service), is_list(Opts) ->
    case get_service_config(Service) of
        {ok, SvcConfig} ->
            ApiMod = sc_util:req_val(mod, SvcConfig),
            SessionName = sc_util:req_val(name, Opts),
            Timeout = sc_util:val(start_timeout, Opts, 5000),
            ChildSpec = sc_util:make_child_spec(Opts, Timeout),
            ApiMod:start_child(SessionName, ChildSpec);
        Error ->
            Error
    end.

%%--------------------------------------------------------------------
%% @doc Stop named session.
%% @end
%%--------------------------------------------------------------------
-spec stop_session(atom(), atom()) -> ok | {error, Reason::term()}.
stop_session(Service, Name) when is_atom(Service), is_atom(Name) ->
    case get_service_config(Service) of
        {ok, SvcConfig} ->
            ApiMod = sc_util:req_val(mod, SvcConfig),
            ApiMod:stop_child(Name);
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

%%--------------------------------------------------------------------
%% @doc Send a notification specified by proplist `Notification'. The
%% contents of the proplist differ depending on the push service used.
%%
%% Notifications have generic and specific sections.
%% The specific sections are for supported push services,
%% and contain options that only make sense to the service
%% in question.
%%
%% ==== Example ====
%% ```
%% Notification = [
%%     {alert, <<"Notification to be sent">>},
%%     {tag, <<"user@domain.com">>},
%%     % ... other generic options ...
%%     {aps, [APSOpts]},
%%     {gcm, [GCMOpts]},
%%     {etc, [FutureOpts]} % Obviously etc is not a real service.
%% ].
%% '''
%% @end
%%--------------------------------------------------------------------
-spec send(sc_types:proplist(atom(), term())) ->
    list({ok, Ref::term()} | {error, Reason::term()}).
send(Notification) when is_list(Notification) ->
    send_notification(sync, Notification, []).

send(Notification, Opts) ->
    send_notification(sync, Notification, Opts).

%%--------------------------------------------------------------------
%% @doc Asynchronously sends a notification specified by proplist `Notification'.
%% The contents of the proplist differ depending on the push service used.
%% Do the same as {@link send/1} and {@link send/2} appart from returning
%% only 'ok' or {'error', Reason} for each registered services.
%% @end
%%--------------------------------------------------------------------
-spec async_send(sc_types:proplist(atom(), term())) ->
    list(ok | {error, Reason::term()}).
async_send(Notification) when is_list(Notification) ->
    send_notification(async, Notification, []).

async_send(Notification, Opts) ->
    send_notification(async, Notification, Opts).

%%--------------------------------------------------------------------
%% @doc
%% Register to receive push notifications.
%%
%% `Props' is a proplist with the following elements, all of which are
%% required:
%%
%% <dl>
%%   <dt>`{service, string()}'</dt>
%%      <dd>A name that denotes the push service for which the
%%      caller is registering. Currently this includes `apns' for
%%      Apple Push, and `gcm' for Android (Google Cloud Messaging) push.
%%      </dd>
%%   <dt>`{token, string()}'</dt>
%%      <dd>The "token" identifying the destination for a push notification
%%      - for example, the APNS push token or the GCM registration ID.
%%      </dd>
%%   <dt>`{tag, string()}'</dt>
%%      <dd>The identification for this registration. Need not be
%%      unique, but note that multiple entries with the same tag
%%      will all receive push notifications. This is one way to
%%      support pushing to a user with multiple devices.
%%      </dd>
%%   <dt>`{device_id, string()}'</dt>
%%      <dd>The device identification for this registration. MUST be
%%      unique, so a UUID is recommended.
%%      </dd>
%%   <dt>`{app_id, string()}'</dt>
%%      <dd>The application ID for this registration, e.g. `com.example.MyApp'.
%%      The exact format of application ID varies between services.
%%      </dd>
%%   <dt>`{dist, string()}'</dt>
%%      <dd>The distribution for this registration. This optional value
%%      must be either `"prod"' or `"dev"'. If omitted, `"prod"' is assumed.
%%      This affects how pushes are sent, and behaves differently for each
%%      push service. For example, in APNS, this will select between using
%%      production or development push certificates. It currently has no effect
%%      on Android push, but it is likely that this may change to select
%%      between using "production" or "development" push servers.
%%      </dd>
%% </dl>
%% @end
%%--------------------------------------------------------------------
-spec register_id(sc_types:reg_proplist()) -> sc_types:reg_result().
register_id(Props) ->
    sc_push_reg_api:register_id(Props).

%%--------------------------------------------------------------------
%% @doc Perform multiple registrations. This takes a list of proplists,
%% where the proplist is defined in register_id/1.
%% @see register_id/1
%% @end
%%--------------------------------------------------------------------
-spec register_ids([sc_types:reg_proplist()]) -> ok | {error, term()}.
register_ids(ListOfProplists) ->
    sc_push_reg_api:register_ids(ListOfProplists).

%%--------------------------------------------------------------------
%% @doc Deregister a registered ID.
%% @end
%%--------------------------------------------------------------------
-spec deregister_id(sc_push_reg_db:reg_id_key()) -> ok | {error, term()}.
deregister_id(ID) ->
    sc_push_reg_api:deregister_id(ID).

%%--------------------------------------------------------------------
%% @doc Deregister multiple registered IDs.
%% @end
%%--------------------------------------------------------------------
-type reg_id_keys() :: [sc_push_reg_db:reg_id_key()].
-spec deregister_ids(reg_id_keys()) -> ok | {error, term()}.
deregister_ids(IDs) ->
    sc_push_reg_api:deregister_ids(IDs).

%%--------------------------------------------------------------------
%% @doc Deregister multiple registered device IDs.
%% @end
%%--------------------------------------------------------------------
-spec deregister_device_ids([binary()]) -> ok | {error, term()}.
deregister_device_ids(IDs) ->
    sc_push_reg_api:deregister_device_ids(IDs).

%%--------------------------------------------------------------------
%% @doc Get registration info corresponding to a tag. Note that multiple
%% results may be returned if multiple registrations are found for the
%% same tag.
%% @end
%%--------------------------------------------------------------------
-spec get_registration_info_by_tag(binary())
        -> notfound | [sc_types:reg_proplist()].
get_registration_info_by_tag(Tag) ->
    sc_push_reg_api:get_registration_info_by_tag(Tag).

%%--------------------------------------------------------------------
%% @doc Get registration info corresponding to service and reg id.
%% @end
%%--------------------------------------------------------------------
-spec get_registration_info_by_svc_tok(string() | atom(),
                                       binary() | string())
    -> notfound | sc_types:reg_proplist().
get_registration_info_by_svc_tok(Service, RegId) ->
    SvcId = sc_push_reg_api:make_svc_tok(Service, RegId),
    sc_push_reg_api:get_registration_info_by_svc_tok(SvcId).

%%--------------------------------------------------------------------
%% @doc Get registration info corresponding to a device ID. Note that
%% multiple results should not be returned, although the returned
%% value is a list for consistency with the other APIs.
%% @end
%%--------------------------------------------------------------------
-spec get_registration_info_by_id(sc_push_reg_db:reg_id_key())
        -> notfound | [sc_types:reg_proplist()].
get_registration_info_by_id(ID) ->
    sc_push_reg_api:get_registration_info_by_id(ID).

%%--------------------------------------------------------------------
%% Internal functions
%%--------------------------------------------------------------------
send_notification(Mode, Notification, Opts) ->
    {RegOKs, RegErrs} = lookup_reg_info(Notification),
    lager:debug("[~p:~B] RegOKs=~p, RegErrs=~p",
                [send_notification, ?LINE, RegOKs, RegErrs]),
    CleanN = remove_props([service, token], Notification),
    Sends = [send_registered_one(Mode, CleanN, Reg, Opts)
             || Reg <- RegOKs],
    Sends ++ case RegErrs of
        [] ->
            [];
        _ ->
            [{error, RegErrs}]
    end.

send_registered_one(Mode, Notification, RegInfo, Opts) ->
    Service = sc_util:req_val(service, RegInfo),
    Token = sc_util:req_val(token, RegInfo),
    AppId = sc_util:req_val(app_id, RegInfo),
    Dist = sc_util:opt_val(dist, RegInfo, <<"">>),
    send_one(Mode, [{token, Token} | Notification], Service, AppId, Dist, Opts).

send_one(Mode, Notification, Service, AppId, Dist, Opts) ->
    case get_service_config(Service) of
        {ok, SvcConfig} ->
            ApiMod = sc_util:req_val(mod, SvcConfig),
            Name = get_service_name(Service, AppId, Dist),
            api_send(Mode, ApiMod, Name, Notification, Opts);
        Error ->
            Error
    end.

api_send(sync, ApiMod, Name, Notification, Opts) ->
    ApiMod:send(Name, Notification, Opts);
api_send(async, ApiMod, Name, Notification, Opts) ->
    ApiMod:async_send(Name, Notification, Opts).

-compile({inline, [{get_service_name, 3}]}).
get_service_name(Service, AppId, <<"">>) ->
    iolist_to_latin1_atom([sc_util:to_bin(Service), $-, sc_util:to_bin(AppId)]);
get_service_name(Service, AppId, <<"prod">>) ->
    get_service_name(Service, AppId, <<"">>);
get_service_name(Service, AppId, Dist) ->
    UDist = sc_util:to_bin(string:to_upper(sc_util:to_list(Dist))),
    iolist_to_latin1_atom([sc_util:to_bin(Service), $-, sc_util:to_bin(AppId),
                          $-, $-, UDist]).

-compile({inline, [{iolist_to_latin1_atom, 1}]}).
iolist_to_latin1_atom(IOList) ->
    binary_to_atom(list_to_binary(IOList), latin1).

ensure_started(App) ->
    case application:start(App) of
        ok ->
            ok;
        {error, {already_started, App}} ->
            ok
    end.

remove_props(Unwanted, PL) ->
    [KV || {K, _} = KV <- PL, not lists:member(K, Unwanted)].

%% Rec ID  Svc  Token Dist Tag
%%  1   1  apns aaaa  prod alice@domain
%%  2   2  apns aaaa  prod bob@domain
%%  3   3  gcm  bbbb  prod alice@domain
%%  3   4  gcm  bbbb  prod alice@domain
%%  4   5  gcm  cccc  prod bob@domain
%%  5   6  apns dddd  prod carol@domain
%%  6   7  gcm  ffff  prod carol@domain

%% Note: a receiver with service, app_id and token does not
%% require a registration lookup.
lookup_reg_info(Notification) ->
    Receivers = case sc_util:val(receivers, Notification) of
        undefined ->
            default_receivers(Notification);
        L when is_list(L) ->
            L
    end,
    get_receiver_regs(Receivers).

default_receivers(Notification) ->
    case sc_util:val(tag, Notification) of
        undefined ->
            throw({missing_info, "tag or receivers"});
        Tag ->
            [{tag, [Tag]}]
    end.

%% Notification v2
%% [
%%     {alert, <<"">>},
%%     {receivers, [
%%             {tag, [Tag1, Tag2]},
%%             {svc_tok, [{apns, [Tok1, Tok2]}]},
%%             {svc_appid_tok, [{apns, <<"com.silentcircle.enterprisephone.voip">>,[Tok1, Tok2]}]},
%%             {device_id, [ID1, ID2]}
%%         ]
%%     }
%% ].
%%

-type reg_ok() :: {ok, std_proplist()}.
-type reg_err() :: {error, term()}.
-type reg_oks() :: list(reg_ok()).
-type reg_errs() :: list(reg_err()).
-type receiver_t() :: tag | svc_tok | device_id.
-type receiver() :: {receiver_t(), list()}.
-type reg_result() :: reg_ok() | reg_err().
-type filtered_result() :: {reg_oks(), reg_errs()}.

-spec get_receiver_regs(list(receiver())) -> filtered_result().
get_receiver_regs(Receivers) ->
    filter_regs(lists:foldr(fun(Rcv, Acc) ->
                                get_receiver_reg(Rcv) ++ Acc
                            end, [], Receivers)).

-spec get_receiver_reg(receiver()) -> [reg_result()].
get_receiver_reg({tag, Tags}) ->
    get_tags(Tags);
get_receiver_reg({svc_tok, SvcToks}) ->
    get_svc_toks(SvcToks);
get_receiver_reg({svc_appid_tok, SvcAppIDToks}) ->
    get_svc_appid_toks(SvcAppIDToks);
get_receiver_reg({device_id, IDs}) ->
    get_device_ids(IDs);
get_receiver_reg(Invalid) ->
    [{error, {invalid_receiver, Invalid}}].

-spec get_tags([binary()]) -> [reg_result()].
get_tags(Tags) ->
    [get_reg(get_registration_info_by_tag,
             Tag,
             reg_not_found_for_tag) || Tag <- Tags].

-spec get_svc_toks([{atom(), binary()}]) -> [reg_result()].
get_svc_toks(SvcToks) ->
    [get_reg(get_registration_info_by_svc_tok,
             SvcTok,
             reg_not_found_for_svc_tok) || SvcTok <- SvcToks].

%% Fake getting a registration since we have all the required reg info already
%% (service, app_id, token).
-spec get_svc_appid_toks([{Service, AppID, Token}]) -> Result
    when Service :: atom(), AppID :: binary(), Token :: binary(),
         Result :: [reg_result()].
get_svc_appid_toks(SvcAppIDToks) ->
    [make_reg_resp(Svc, AppID, Token) || {Svc, AppID, Token} <- SvcAppIDToks].

-spec get_device_ids([binary()]) -> [reg_result()].
get_device_ids(IDs) ->
    [get_reg(get_registration_info_by_device_id,
             ID,
             reg_not_found_for_device_id) || ID <- IDs].

-spec get_reg(reg_api_func_name(), term(), atom()) -> reg_result().
get_reg(FuncName, RegQuery, ErrType) ->
    case sc_push_reg_api:FuncName(RegQuery) of
        notfound ->
            {error, {ErrType, RegQuery}};
        [_|_] = Reg ->
            {ok, Reg}
    end.

make_reg_resp(Svc, AppID, Token) ->
    PL = [{service, Svc},
          {app_id, AppID},
          {token, Token}],
    {ok, [PL]}. %% Requires list of proplists

-spec filter_regs([reg_result()]) -> filtered_result().
filter_regs(Regs) ->
    {OKs, Errs} = lists:partition(fun({ok, _}) -> true;
                                     ({error, _}) -> false
                                  end, Regs),
    FiltOKs = lists:usort(fun compare_tokens/2, flatten_results(OKs)),
    FiltErrs = lists:usort([Err || {error, Err} <- Errs]),
    {FiltOKs, FiltErrs}.

-compile({inline, [{flatten_results, 1}]}).
flatten_results(Results) ->
    lists:append([L || {_, L} <- Results]).

-compile({inline, [{compare_tokens, 2}]}).
compare_tokens(PL1, PL2) ->
    get_svc_tok(PL1) =< get_svc_tok(PL2).

-compile({inline, [{get_svc_tok, 1}]}).
get_svc_tok(PL) ->
    {proplists:get_value(service, PL), proplists:get_value(token, PL)}.

