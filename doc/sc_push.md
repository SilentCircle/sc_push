

# Module sc_push #
* [Description](#description)
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

This module is the Erlang API for Silent Circle push notifications
and registrations.

__Authors:__ Edwin Fine ([`efine@silentcircle.com`](mailto:efine@silentcircle.com)).

<a name="types"></a>

## Data Types ##




### <a name="type-child_id">child_id()</a> ###


<pre><code>
child_id() = term()
</code></pre>

Not a pid().



### <a name="type-reg_id_keys">reg_id_keys()</a> ###


<pre><code>
reg_id_keys() = [<a href="sc_push_reg_db.md#type-reg_id_key">sc_push_reg_db:reg_id_key()</a>]
</code></pre>




### <a name="type-std_proplist">std_proplist()</a> ###


<pre><code>
std_proplist() = <a href="sc_types.md#type-proplist">sc_types:proplist</a>(atom(), term())
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#async_send-1">async_send/1</a></td><td>Asynchronously sends a notification specified by proplist <code>Notification</code>.</td></tr><tr><td valign="top"><a href="#async_send-2">async_send/2</a></td><td></td></tr><tr><td valign="top"><a href="#deregister_device_ids-1">deregister_device_ids/1</a></td><td>Deregister multiple registered device IDs.</td></tr><tr><td valign="top"><a href="#deregister_id-1">deregister_id/1</a></td><td>Deregister a registered ID.</td></tr><tr><td valign="top"><a href="#deregister_ids-1">deregister_ids/1</a></td><td>Deregister multiple registered IDs.</td></tr><tr><td valign="top"><a href="#get_registration_info_by_id-1">get_registration_info_by_id/1</a></td><td>Get registration info corresponding to a device ID.</td></tr><tr><td valign="top"><a href="#get_registration_info_by_svc_tok-2">get_registration_info_by_svc_tok/2</a></td><td>Get registration info corresponding to service and reg id.</td></tr><tr><td valign="top"><a href="#get_registration_info_by_tag-1">get_registration_info_by_tag/1</a></td><td>Get registration info corresponding to a tag.</td></tr><tr><td valign="top"><a href="#get_service_config-1">get_service_config/1</a></td><td>Get service configuration.</td></tr><tr><td valign="top"><a href="#get_session_pid-1">get_session_pid/1</a></td><td>Get pid of named session.</td></tr><tr><td valign="top"><a href="#make_service_child_spec-1">make_service_child_spec/1</a></td><td>Make a supervisor child spec for a service.</td></tr><tr><td valign="top"><a href="#register_id-1">register_id/1</a></td><td>
Register to receive push notifications.</td></tr><tr><td valign="top"><a href="#register_ids-1">register_ids/1</a></td><td>Perform multiple registrations.</td></tr><tr><td valign="top"><a href="#register_service-1">register_service/1</a></td><td>Register a service in the service configuration registry.</td></tr><tr><td valign="top"><a href="#send-1">send/1</a></td><td>Send a notification specified by proplist <code>Notification</code>.</td></tr><tr><td valign="top"><a href="#send-2">send/2</a></td><td></td></tr><tr><td valign="top"><a href="#start-0">start/0</a></td><td></td></tr><tr><td valign="top"><a href="#start_service-1">start_service/1</a></td><td>Start a push service.</td></tr><tr><td valign="top"><a href="#start_session-2">start_session/2</a></td><td>Start named session as described in the options proplist <code>Opts</code>.</td></tr><tr><td valign="top"><a href="#stop_service-1">stop_service/1</a></td><td>Stops a service and all sessions for that service.</td></tr><tr><td valign="top"><a href="#stop_session-2">stop_session/2</a></td><td>Stop named session.</td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="async_send-1"></a>

### async_send/1 ###

<pre><code>
async_send(Notification::<a href="sc_types.md#type-proplist">sc_types:proplist</a>(atom(), term())) -&gt; [ok | {error, Reason::term()}]
</code></pre>
<br />

Asynchronously sends a notification specified by proplist `Notification`.
The contents of the proplist differ depending on the push service used.
Do the same as [`send/1`](#send-1) and [`send/2`](#send-2) appart from returning
only 'ok' or {'error', Reason} for each registered services.

<a name="async_send-2"></a>

### async_send/2 ###

`async_send(Notification, Opts) -> any()`

<a name="deregister_device_ids-1"></a>

### deregister_device_ids/1 ###

<pre><code>
deregister_device_ids(IDs::[binary()]) -&gt; ok | {error, term()}
</code></pre>
<br />

Deregister multiple registered device IDs.

<a name="deregister_id-1"></a>

### deregister_id/1 ###

<pre><code>
deregister_id(ID::<a href="sc_push_reg_db.md#type-reg_id_key">sc_push_reg_db:reg_id_key()</a>) -&gt; ok | {error, term()}
</code></pre>
<br />

Deregister a registered ID.

<a name="deregister_ids-1"></a>

### deregister_ids/1 ###

<pre><code>
deregister_ids(IDs::<a href="#type-reg_id_keys">reg_id_keys()</a>) -&gt; ok | {error, term()}
</code></pre>
<br />

Deregister multiple registered IDs.

<a name="get_registration_info_by_id-1"></a>

### get_registration_info_by_id/1 ###

<pre><code>
get_registration_info_by_id(ID::<a href="sc_push_reg_db.md#type-reg_id_key">sc_push_reg_db:reg_id_key()</a>) -&gt; notfound | [<a href="sc_types.md#type-reg_proplist">sc_types:reg_proplist()</a>]
</code></pre>
<br />

Get registration info corresponding to a device ID. Note that
multiple results should not be returned, although the returned
value is a list for consistency with the other APIs.

<a name="get_registration_info_by_svc_tok-2"></a>

### get_registration_info_by_svc_tok/2 ###

<pre><code>
get_registration_info_by_svc_tok(Service::string() | atom(), RegId::binary() | string()) -&gt; notfound | <a href="sc_types.md#type-reg_proplist">sc_types:reg_proplist()</a>
</code></pre>
<br />

Get registration info corresponding to service and reg id.

<a name="get_registration_info_by_tag-1"></a>

### get_registration_info_by_tag/1 ###

<pre><code>
get_registration_info_by_tag(Tag::binary()) -&gt; notfound | [<a href="sc_types.md#type-reg_proplist">sc_types:reg_proplist()</a>]
</code></pre>
<br />

Get registration info corresponding to a tag. Note that multiple
results may be returned if multiple registrations are found for the
same tag.

<a name="get_service_config-1"></a>

### get_service_config/1 ###

<pre><code>
get_service_config(Service::term()) -&gt; {ok, <a href="#type-std_proplist">std_proplist()</a>} | {error, term()}
</code></pre>
<br />

Get service configuration

__See also:__ [start_service/1](#start_service-1).

<a name="get_session_pid-1"></a>

### get_session_pid/1 ###

<pre><code>
get_session_pid(Name::atom()) -&gt; pid() | undefined
</code></pre>
<br />

Get pid of named session.

<a name="make_service_child_spec-1"></a>

### make_service_child_spec/1 ###

<pre><code>
make_service_child_spec(Opts::<a href="sc_types.md#type-proplist">sc_types:proplist</a>(atom(), term())) -&gt; <a href="supervisor.md#type-child_spec">supervisor:child_spec()</a>
</code></pre>
<br />

Make a supervisor child spec for a service. The name of the
supervisor module is obtained from the API module, and is what will
be started. Obviously, it must be a supervisor.

__See also:__ [start_service/1](#start_service-1).

<a name="register_id-1"></a>

### register_id/1 ###

<pre><code>
register_id(Props::<a href="sc_types.md#type-reg_proplist">sc_types:reg_proplist()</a>) -&gt; <a href="sc_types.md#type-reg_result">sc_types:reg_result()</a>
</code></pre>
<br />

Register to receive push notifications.

`Props` is a proplist with the following elements, all of which are
required:



<dt><code>{service, string()}</code></dt>




<dd>A name that denotes the push service for which the
caller is registering. Currently this includes <code>apns</code> for
Apple Push, and <code>gcm</code> for Android (Google Cloud Messaging) push.
</dd>




<dt><code>{token, string()}</code></dt>




<dd>The "token" identifying the destination for a push notification
- for example, the APNS push token or the GCM registration ID.
</dd>




<dt><code>{tag, string()}</code></dt>




<dd>The identification for this registration. Need not be
unique, but note that multiple entries with the same tag
will all receive push notifications. This is one way to
support pushing to a user with multiple devices.
</dd>




<dt><code>{device_id, string()}</code></dt>




<dd>The device identification for this registration. MUST be
unique, so a UUID is recommended.
</dd>




<dt><code>{app_id, string()}</code></dt>




<dd>The application ID for this registration, e.g. <code>com.example.MyApp</code>.
The exact format of application ID varies between services.
</dd>




<dt><code>{dist, string()}</code></dt>




<dd>The distribution for this registration. This optional value
must be either <code>"prod"</code> or <code>"dev"</code>. If omitted, <code>"prod"</code> is assumed.
This affects how pushes are sent, and behaves differently for each
push service. For example, in APNS, this will select between using
production or development push certificates. It currently has no effect
on Android push, but it is likely that this may change to select
between using "production" or "development" push servers.
</dd>



<a name="register_ids-1"></a>

### register_ids/1 ###

<pre><code>
register_ids(ListOfProplists::[<a href="sc_types.md#type-reg_proplist">sc_types:reg_proplist()</a>]) -&gt; ok | {error, term()}
</code></pre>
<br />

Perform multiple registrations. This takes a list of proplists,
where the proplist is defined in register_id/1.

__See also:__ [register_id/1](#register_id-1).

<a name="register_service-1"></a>

### register_service/1 ###

<pre><code>
register_service(Svc::<a href="sc_types.md#type-proplist">sc_types:proplist</a>(atom(), term())) -&gt; ok
</code></pre>
<br />

Register a service in the service configuration registry.

__See also:__ [start_service/1](#start_service-1).

<a name="send-1"></a>

### send/1 ###

<pre><code>
send(Notification::<a href="sc_types.md#type-proplist">sc_types:proplist</a>(atom(), term())) -&gt; [{ok, Ref::term()} | {error, Reason::term()}]
</code></pre>
<br />

Send a notification specified by proplist `Notification`. The
contents of the proplist differ depending on the push service used.

Notifications have generic and specific sections.
The specific sections are for supported push services,
and contain options that only make sense to the service
in question.

<h5><a name="Example">Example</a></h5>


```
  Notification = [
      {alert, <<"Notification to be sent">>},
      {tag, <<"user@domain.com">>},
      % ... other generic options ...
      {aps, [APSOpts]},
      {gcm, [GCMOpts]},
      {etc, [FutureOpts]} % Obviously etc is not a real service.
  ].
```

<a name="send-2"></a>

### send/2 ###

`send(Notification, Opts) -> any()`

<a name="start-0"></a>

### start/0 ###

`start() -> any()`

<a name="start_service-1"></a>

### start_service/1 ###

<pre><code>
start_service(ServiceOpts::<a href="sc_types.md#type-proplist">sc_types:proplist</a>(atom(), term())) -&gt; {ok, pid()} | {error, term()}
</code></pre>
<br />

Start a push service.


#### <a name="Synopsis">Synopsis</a> ####


```
  Cfg = [
      {name, 'null'},
      {mod, 'sc_push_svc_null'},
      {description, "Null Push Service"},
      {sessions, [
              [
                  {name, 'null-com.silentcircle.SCPushSUITETest'},
                  {mod, sc_push_svc_null},
                  {config, []}
              ]
          ]}
  ],
  {ok, Pid} = sc_push:start_service(Cfg).
```



<dt><code>{name, atom()}</code></dt>




<dd>
A name that denotes the push service for which the
caller is registering. Currently this includes <code>apns</code> for
Apple Push, and <code>gcm</code> for Android (Google Cloud Messaging) push.
There is also a built-in <code>null</code> service for testing.
</dd>




<dt><code>{mod, atom()}</code></dt>




<dd>
All calls to a service are done via the service-specific
API module, which must be on the code path. This is the name
of that API module. All API modules have the same public interface
and are top-level supervisors. They must therefore implement the
Erlang supervisor behavior.
</dd>




<dt><code>{description, string()}</code></dt>




<dd>
A human-readable description of the push service.
</dd>




<dt><code>{sessions, list()}</code></dt>




<dd>
A list of proplists. Each proplist describes a session to be
started. See <code>start_session/1</code> for details.
</dd>




<a name="start_session-2"></a>

### start_session/2 ###

<pre><code>
start_session(Service::atom(), Opts::list()) -&gt; {ok, pid()} | {error, already_started} | {error, Reason::term()}
</code></pre>
<br />

Start named session as described in the options proplist `Opts`.
`config` is service-dependent.


### <a name="IMPORTANT_NOTE">IMPORTANT NOTE</a> ###

`name` 
<strong>must</strong>
 be in the format `service-api_key`, for
example, if the service name is `apns`, and the api_key is, in this case,
`com.silentcircle.SilentText`, then the session name must be
`apns-com.silentcircle.SilentText`.


#### <a name="APNS_Service">APNS Service</a> ####


```
  [
      {mod, 'sc_push_svc_apns'},
      {name, 'apns-com.silentcircle.SilentText'},
      {config, [
          {host, "gateway.push.apple.com"},
          {bundle_seed_id, <<"com.silentcircle.SilentText">>},
          {bundle_id, <<"com.silentcircle.SilentText">>},
          {ssl_opts, [
              {certfile, "/etc/ejabberd/certs/com.silentcircle.SilentText.cert.pem"},
              {keyfile,  "/etc/ejabberd/certs/com.silentcircle.SilentText.key.unencrypted.pem"}
          ]}
      ]}
  ]
```



#### <a name="GCM_Service">GCM Service</a> ####


```
  [
      {mod, 'sc_push_svc_gcm'},
      {name, 'gcm-com.silentcircle.silenttext'},
      {config, [
          {api_key, <<"AIzaSyCUIZhzjEQvb4wSlg6Uhi3OqLaC5vyv73w">>},
          {ssl_opts, [
              {verify, verify_none},
              {reuse_sessions, true}
          ]}
          % Optional properties, showing default values
          %{uri, "https://android.googleapis.com/gcm/send"}
          %{restricted_package_name, <<>>}
          %{max_attempts, 5}
          %{retry_interval, 1}
          %{max_req_ttl, 120}
      ]}
  ]
```

<a name="stop_service-1"></a>

### stop_service/1 ###

<pre><code>
stop_service(Id::pid() | <a href="#type-child_id">child_id()</a>) -&gt; ok | {error, term()}
</code></pre>
<br />

Stops a service and all sessions for that service.

<a name="stop_session-2"></a>

### stop_session/2 ###

<pre><code>
stop_session(Service::atom(), Name::atom()) -&gt; ok | {error, Reason::term()}
</code></pre>
<br />

Stop named session.

