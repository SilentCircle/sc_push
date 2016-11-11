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
%%%
%%% == Push Notification Format ==
%%%
%%% The notification format is very flexible. There is a simple format
%%% and a more elaborate, canonical format.
%%%
%%% The simple format requires push tokens
%%% to have been registered using the registration API, so that the
%%% push tag can be used as a destination for thte notification.
%%%
%%% The canonical format requires a list of receivers to be provided for
%%% each notification. This allows a notification to be sent to multiple
%%% recipients on different services, specifying the destination in a
%%% number of possible formats.
%%%
%%% === Simple notification format ===
%%%
%%% ```
%%% [{alert, <<"Hello there.">>},
%%%  {tag, <<"foo@example.com">>}]
%%% '''
%%%
%%% === Canonical notification format ===
%%%
%%% The canonical format is as follows. Any or all of the receiver types may be specified,
%%% but at least one, for example `svc_tok', **must** be provided.
%%%
%%% ```
%%% [{alert, <<"Hello there.">>},
%%%  {receivers, [{tag, [Tag]},
%%%               {svc_tok, [{Service, Token}]},
%%%               {svc_appid_tok, [{Service, AppId, Token}]},
%%%               {device_id, [DeviceId]}]}]
%%% '''
%%%
%%% More formally, the notification specification is defined in
%%% {@link notification()}.
%%%
%%% === Example ===
%%%
%%% ```
%%% AppId = <<"com.example.MyApp">>,
%%% Tok = <<"4df5676af4307b3e0366da63e8854752d9219d8b9848f7c31bbab8741730fda6">>,
%%% [{alert,<<"Hello">>},
%%%  {aps,[{badge,22}]},
%%%  {receivers,[{svc_appid_tok,[{apns, AppId, Tok}]}]}]
%%% '''
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
-type alert() :: binary().
-type tag() :: binary().
-type token() :: binary().
-type service() :: atom(). % e.g. apns, gcm
-type app_id() :: binary().
-type dist() :: binary().

-type std_proplist() :: sc_types:proplist(atom(), term()).
-type reg_api_func_name() :: 'get_registration_info_by_device_id' |
                             'get_registration_info_by_svc_tok' |
                             'get_registration_info_by_tag'.

-type reg_info_prop() :: {service, service()}
                       | {token, token()}
                       | {app_id, app_id()}
                       | {dist, dist()}.

-type reg_info() :: [reg_info_prop()].
-type reg_info_list() :: [reg_info()].
-type reg_ok() :: {ok, reg_info_list()}.
-type reg_err_term() :: term().
-type reg_err_list() :: [reg_err_term()].
-type reg_err() :: {error, reg_err_term()}.
-type reg_result() :: reg_ok() | reg_err().
-type reg_results() :: [reg_result()].
-type filtered_result() :: {reg_info_list(), reg_err_list()}.

%%  -type receiver_t() :: tag | svc_tok | svc_appid_tok | device_id.
%%  -type receiver() :: {receiver_t(), list()}.
%%  -type receivers() :: [receiver()].
-type receiver_regs() :: filtered_result().

-type tags() :: [tag()].
-type alert_spec() :: {'alert', alert()}.
-type tag_spec() :: {'tag', tag()}.
-type svc_tok() :: {service(), token()}.
-type svc_toks() :: [svc_tok()].
-type svc_appid_tok() :: {service(), app_id(), token()}.
-type svc_appid_toks() :: [svc_appid_tok()].
-type device_id() :: binary().
-type device_ids() :: [device_id()].

-type tag_spec_mult() :: {'tag', tags()}.
-type svc_tok_spec() :: {'svc_tok', svc_toks()}.
-type svc_appid_tok_spec() :: {'svc_appid_tok', svc_appid_toks()}.
-type device_id_spec() :: {'device_id', device_ids()}.
-type receiver_spec() :: tag_spec_mult()
                       | svc_tok_spec()
                       | svc_appid_tok_spec()
                       | device_id_spec().

-type receiver_specs() :: [receiver_spec()].
-type receivers() :: {'receivers', receiver_specs()}.
-type service_specific_spec() :: {service(), std_proplist()}.
-type notification() :: [alert_spec() |
                         tag_spec() |
                         service_specific_spec() |
                         receivers()].

-type uuid() :: binary(). % A raw uuid in the form `<<_:128>>'.
-type props() :: proplists:proplist().

-type sync_send_result() :: {ok, {uuid(), props()}} | {error, term()}.
-type sync_send_results() :: [sync_send_result()].

-type async_status() :: submitted | queued.
-type async_send_result() :: {ok, {async_status(), uuid()}} | {error, term()}.
-type async_send_results() :: [async_send_result()].

-type send_result() :: sync_send_result() | async_send_result().

-type mode() :: sync | async.

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
        quiesce_service/1,
        quiesce_all_services/0,
        start_session/2,
        stop_session/2,
        quiesce_session/2,
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
        get_all_service_configs/0,
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
%% @doc Quiesce a service. This instructs the service not to accept any more
%% service requests to allow pending requests to drain.  This call does not
%% return until all pending service requests have completed.
%% @end
%%--------------------------------------------------------------------
-spec quiesce_service(Service) -> Result when
      Service :: atom() | pid(), Result :: ok | {error, term()}.
quiesce_service(Service) when is_atom(Service) ->
    case get_service_config(Service) of
        {ok, SvcConfig} ->
            ApiMod = sc_util:req_val(mod, SvcConfig),
            Name = sc_util:req_val(name, SvcConfig),
            ApiMod:quiesce_session(Name);
        Error ->
            Error
    end.

%%--------------------------------------------------------------------
%% @doc Quiesce all services.
%% @see quiesce_service/1
%% @end
%%--------------------------------------------------------------------
-spec quiesce_all_services() -> ok.
quiesce_all_services() ->
    Cfgs = get_all_service_configs(),
    _ = [begin
            Name = sc_util:req_val(name, Cfg),
            Mod = sc_util:req_val(mod, Cfg),
            ok = Mod:quiesce_session(Name)
         end || Cfg <- Cfgs],
    ok.

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
-spec get_service_config(Service::term()) ->
    {ok, std_proplist()} | {error, term()}.
get_service_config(Service) ->
    sc_push_lib:get_service_config(Service).

%%--------------------------------------------------------------------
%% @doc Get all service configurations
%% @end
%%--------------------------------------------------------------------
-spec get_all_service_configs() -> [std_proplist()].
get_all_service_configs() ->
    sc_push_lib:get_all_service_configs().

%%--------------------------------------------------------------------
%% @doc Start named session as described in the options proplist `Opts'.
%% `config' is service-dependent.
%%
%% == IMPORTANT NOTE ==
%%
%% `name' <strong>must</strong> be in the format `service-api_key'.  For
%% example, if the service name is `apns', and the `api_key' is, in this case,
%% `com.example.SomeApp', then the session name must be
%% `apns-com.example.SomeApp'.
%%
%% === APNS Service ===
%%
%% Note that the v2 service, `sc_push_svc_apns', is **deprecated**.
%% Use `sc_push_svc_apnsv3' instead.
%%
%% ```
%% [
%%  {mod, 'sc_push_svc_apnsv3'},
%%  {name, 'apnsv3-com.example.MyApp'},
%%  {config,
%%   [{host, "api.push.apple.com"},
%%    {port, 443},
%%    {apns_env, prod},
%%    {bundle_seed_id, <<"com.example.MyApp">>},
%%    {apns_topic, <<"com.example.MyApp">>},
%%    {retry_delay, 1000},
%%    {disable_apns_cert_validation, true},
%%    {ssl_opts,
%%     [{certfile, "/some/path/com.example.MyApp.cert.pem"},
%%      {keyfile, "/some/path/com.example.MyApp.key.unencrypted.pem"},
%%      {cacertfile, "/some/path/cacerts.crt"},
%%      {honor_cipher_order, false},
%%      {versions, ['tlsv1.2']},
%%      {alpn_preferred_protocols, [<<"h2">>]}
%%     ]
%%    }
%%   ]
%%  }
%% ]
%% '''
%%
%% === GCM Service ===
%%
%% ```
%% [
%%  {mod, 'sc_push_svc_gcm'},
%%  {name, 'gcm-com.example.SomeApp'},
%%  {config,
%%   [
%%    %% Required GCM API key
%%    {api_key, <<"ahsgdblahblahfjkjkjfdk">>},
%%    %% Required, even if empty list. Defaults shown.
%%    {ssl_opts, [
%%                {verify, verify_peer},
%%                {reuse_sessions, true}
%%               ]},
%%    %% Optional, defaults as shown.
%%    {uri, "https://gcm-http.googleapis.com/gcm/send"},
%%    %% Optional, omitted if missing.
%%    {restricted_package_name, <<"my-android-pkg">>},
%%    %% Maximum times to try to send and then give up.
%%    {max_attempts, 10},
%%    %% Starting point in seconds for exponential backoff.
%%    %% Optional.
%%    {retry_interval, 1},
%%    %% Maximum seconds for a request to live in a retrying state.
%%    {max_req_ttl, 3600},
%%    %% Reserved for future use
%%    {failure_action, fun(_)}
%%   ]}
%% ]
%% '''
%%
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
            ApiMod:start_session(SessionName, ChildSpec);
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
            ApiMod:stop_session(Name);
        Error ->
            Error
    end.

%%--------------------------------------------------------------------
%% @doc Quiesce session. This puts the session in a state that rejects new
%% push requests, but continues to service in-flight requests.  Once there are
%% no longer any in-flight requests, the session is stopped.
%% @end
%%--------------------------------------------------------------------
-spec quiesce_session(atom(), atom()) -> ok | {error, Reason::term()}.
quiesce_session(Service, Name) when is_atom(Service), is_atom(Name) ->
    case get_service_config(Service) of
        {ok, SvcConfig} ->
            ApiMod = sc_util:req_val(mod, SvcConfig),
            ApiMod:quiesce_session(Name);
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
%%
%% Providing a UUID as shown is not required, but is recommended for tracking
%% purposes.
%%
%% ```
%% Notification = [
%%     {uuid, <<"4091b3a2-df6a-443e-a119-8f1d430ed53c">>},
%%     {alert, <<"Notification to be sent">>},
%%     {tag, <<"user@domain.com">>},
%%     % ... other generic options ...
%%     {aps, [APSOpts]},
%%     {gcm, [GCMOpts]},
%%     {etc, [FutureOpts]} % Obviously etc is not a real service.
%% ].
%% '''
%% @see sync_send_results()
%% @end
%%--------------------------------------------------------------------
-spec send(Notification) -> Result when
      Notification :: notification(), Result :: sync_send_results().
send(Notification) when is_list(Notification) ->
    send_notification(sync, Notification, []).

-spec send(Notification, Opts) -> Result when
      Notification :: notification(), Opts :: std_proplist(),
      Result :: sync_send_results().
send(Notification, Opts) ->
    send_notification(sync, Notification, Opts).

%%--------------------------------------------------------------------
%% @doc Asynchronously sends a notification specified by proplist
%% `Notification'.  The contents of the proplist differ depending on the push
%% service used (see {@link notification()}).
%%
%% The asynchronous response is sent to the calling pid's mailbox as a tuple.
%% The tuple is defined as  `async_message()' as shown below.
%%
%% ```
%% -type svc_response_id() :: apns_response | gcm_response | atom().
%% -type version() :: atom(). % For example, `` 'v1' ''.
%% -type async_message() :: {svc_response_id(), version(), gen_send_result()}.
%% '''
%% @end
%%--------------------------------------------------------------------
-spec async_send(Notification) -> Result when
      Notification :: notification(), Result :: async_send_results().
async_send(Notification) when is_list(Notification) ->
    send_notification(async, Notification, []).

-spec async_send(Notification, Opts) -> Result when
      Notification :: notification(), Opts :: std_proplist(),
      Result ::  async_send_results().
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
%% @private
-spec send_notification(Mode, Notification, Opts) -> Result when
      Mode :: mode(), Notification :: notification(),
      Opts :: std_proplist(), Result :: [send_result()].
send_notification(Mode, Notification, Opts) ->
    {RegOKs, RegErrs} = lookup_reg_info(Notification),
    lager:debug("[~p:~B] RegOKs=~p, RegErrs=~p",
                [send_notification, ?LINE, RegOKs, RegErrs]),
    CleanN = remove_props([service, token], Notification),
    Sends = [send_registered_one(Mode, CleanN, Reg, Opts) || Reg <- RegOKs],
    Sends ++ case RegErrs of
                 [] ->
                     [];
                 _ ->
                     [{error, RegErrs}]
             end.

%%--------------------------------------------------------------------
%% @private
-spec send_registered_one(Mode, Notification, RegInfo, Opts) -> Result when
      Mode :: mode(), Notification :: notification(), RegInfo :: reg_info(),
      Opts :: std_proplist(), Result :: send_result().
send_registered_one(Mode, Notification, RegInfo, Opts) ->
    Service = sc_util:req_val(service, RegInfo),
    Token = sc_util:req_val(token, RegInfo),
    AppId = sc_util:req_val(app_id, RegInfo),
    Dist = sc_util:opt_val(dist, RegInfo, <<"">>),
    Nf = lists:keystore(token, 1, Notification, {token, Token}),
    send_one(Mode, Nf, Service, AppId, Dist, Opts).

%%--------------------------------------------------------------------
%% @private
-spec send_one(Mode, Notification, Service, AppId, Dist, Opts) -> Result when
      Mode :: mode(), Notification :: std_proplist(), Service :: service(),
      AppId :: app_id(), Dist :: dist(), Opts :: std_proplist(),
      Result :: send_result().
send_one(Mode, Notification, Service, AppId, Dist, Opts) ->
    case get_service_config(Service) of
        {ok, SvcConfig} ->
            ApiMod = sc_util:req_val(mod, SvcConfig),
            Name = get_service_name(Service, AppId, Dist),
            api_send(Mode, ApiMod, Name, Notification, Opts);
        {error, _} = Error ->
            Error
    end.

%%--------------------------------------------------------------------
%% @private
-spec api_send(Mode, ApiMod, Name, Notification, Opts) -> Result when
      Mode :: mode(), ApiMod :: module(), Name :: atom(),
      Notification :: std_proplist(), Opts :: std_proplist(),
      Result :: send_result().
api_send(sync, ApiMod, Name, Notification, Opts) ->
    ApiMod:send(Name, Notification, Opts);
api_send(async, ApiMod, Name, Notification, Opts) ->
    ApiMod:async_send(Name, Notification, Opts).

%%--------------------------------------------------------------------
-compile({inline, [{get_service_name, 3}]}).
%% @private
get_service_name(Service, AppId, <<"">>) ->
    iolist_to_latin1_atom([sc_util:to_bin(Service), $-, sc_util:to_bin(AppId)]);
get_service_name(Service, AppId, <<"prod">>) ->
    get_service_name(Service, AppId, <<"">>);
get_service_name(Service, AppId, Dist) ->
    UDist = sc_util:to_bin(string:to_upper(sc_util:to_list(Dist))),
    iolist_to_latin1_atom([sc_util:to_bin(Service), $-, sc_util:to_bin(AppId),
                          $-, $-, UDist]).

%%--------------------------------------------------------------------
-compile({inline, [{iolist_to_latin1_atom, 1}]}).
%% @private
iolist_to_latin1_atom(IOList) ->
    binary_to_atom(list_to_binary(IOList), latin1).

%%--------------------------------------------------------------------
%% @private
ensure_started(App) ->
    case application:start(App) of
        ok ->
            ok;
        {error, {already_started, App}} ->
            ok
    end.

%%--------------------------------------------------------------------
%% @private
remove_props(Unwanted, PL) ->
    [KV || {K, _} = KV <- PL, not lists:member(K, Unwanted)].

%%--------------------------------------------------------------------
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
%% @private
lookup_reg_info(Notification) ->
    Receivers = case sc_util:val(receivers, Notification) of
        undefined ->
            default_receivers(Notification);
        L when is_list(L) ->
            L
    end,
    get_receiver_regs(Receivers).

%%--------------------------------------------------------------------
%% @private
default_receivers(Notification) ->
    case sc_util:val(tag, Notification) of
        undefined ->
            throw({missing_info, "tag or receivers"});
        Tag ->
            [{tag, [Tag]}]
    end.

%%--------------------------------------------------------------------
%% Notification v2
%% [
%%     {alert, <<"">>},
%%     {receivers, [
%%             {tag, [Tag1, Tag2]},
%%             {svc_tok, [{apns, Tok1},{gcm, Tok2}]},
%%             {svc_appid_tok, [{apns, AppId1, Tok1},{gcm,AppId2,Tok2}]},
%%             {device_id, [ID1, ID2]}
%%         ]
%%     }
%% ].
%%
%%--------------------------------------------------------------------
%% @private
-spec get_receiver_regs(Receivers) -> ReceiverRegs when
      Receivers :: receiver_specs(), ReceiverRegs :: receiver_regs().
get_receiver_regs(Receivers) ->
    filter_regs(lists:foldr(fun(Receiver, Acc) ->
                                get_receiver_reg(Receiver) ++ Acc
                            end, [], Receivers)).

%%--------------------------------------------------------------------
%% @private
-spec get_receiver_reg(Receiver) -> RegResults when
      Receiver :: receiver_spec(), RegResults :: reg_results().
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

%%--------------------------------------------------------------------
%% @private
-spec get_tags(Tags) -> RegResults when
      Tags :: [Tag], RegResults :: reg_results(), Tag :: binary().
get_tags(Tags) ->
    [get_reg(get_registration_info_by_tag,
             Tag,
             reg_not_found_for_tag) || Tag <- Tags].

%%--------------------------------------------------------------------
%% @private
-spec get_svc_toks(SvcToks) -> RegResults when
    SvcToks :: [{Svc, Tok}], RegResults :: reg_results(),
    Svc :: atom(), Tok :: binary().
get_svc_toks(SvcToks) ->
    [get_reg(get_registration_info_by_svc_tok,
             SvcTok,
             reg_not_found_for_svc_tok) || SvcTok <- SvcToks].

%%--------------------------------------------------------------------
%% Fake getting a registration since we have all the required reg info already
%% (service, app_id, token).
%% @private
-spec get_svc_appid_toks([{Service, AppID, Token}]) -> Result
    when Service :: atom(), AppID :: binary(), Token :: binary(),
         Result :: reg_results().
get_svc_appid_toks(SvcAppIDToks) ->
    [make_reg_resp(Svc, AppID, Token) || {Svc, AppID, Token} <- SvcAppIDToks].

%%--------------------------------------------------------------------
%% @private
-spec get_device_ids(IDs) -> RegResults when
      IDs :: [binary()], RegResults :: reg_results().
get_device_ids(IDs) ->
    [get_reg(get_registration_info_by_device_id,
             ID,
             reg_not_found_for_device_id) || ID <- IDs].

%%--------------------------------------------------------------------
%% @private
-spec get_reg(FuncName, RegQuery, ErrType) -> RegResult when
      FuncName :: reg_api_func_name(), RegQuery :: term(), ErrType :: atom(),
      RegResult :: reg_result().
get_reg(FuncName, RegQuery, ErrType) ->
    case sc_push_reg_api:FuncName(RegQuery) of
        notfound ->
            {error, {ErrType, RegQuery}};
        [_|_] = Reg ->
            {ok, Reg}
    end.

%%--------------------------------------------------------------------
%% @private
-spec make_reg_resp(Svc, AppID, Token) -> RegResp when
      Svc :: atom(), AppID :: binary(), Token :: binary(),
      RegResp :: reg_ok().
make_reg_resp(Svc, AppID, Token) ->
    PL = [{service, Svc},
          {app_id, AppID},
          {token, Token}],
    {ok, [PL]}. %% Requires list of proplists

%%--------------------------------------------------------------------
%% @private
-spec filter_regs(RegResults) -> FilteredResult when
      RegResults :: reg_results(), FilteredResult :: filtered_result().
filter_regs(RegResults) ->
    {OKs, Errs} = lists:partition(fun({ok, _}) -> true;
                                     ({error, _}) -> false
                                  end, RegResults),
    FiltOKs = lists:usort(fun compare_tokens/2, flatten_results(OKs)),
    FiltErrs = lists:usort([Err || {error, Err} <- Errs]),
    {FiltOKs, FiltErrs}.

%%--------------------------------------------------------------------
-compile({inline, [{flatten_results, 1}]}).
%% @doc Convert [{ok | error, term()}] to [term()]
%% @private
-spec flatten_results(Results) -> FlattenedResults when
      Results :: [{atom(), list()}],
      FlattenedResults :: list().
flatten_results(Results) ->
    lists:append([L || {_, L} <- Results]).

-compile({inline, [{compare_tokens, 2}]}).
%% @private
compare_tokens(PL1, PL2) ->
    get_svc_tok(PL1) =< get_svc_tok(PL2).

-compile({inline, [{get_svc_tok, 1}]}).
%% @private
get_svc_tok(PL) ->
    {sc_util:req_val(service, PL), sc_util:req_val(token, PL)}.

