

# Module sc_push_svc_null #
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

__Behaviours:__ [`supervisor`](supervisor.md).

<a name="types"></a>

## Data Types ##




### <a name="type-init_opts">init_opts()</a> ###


<pre><code>
init_opts() = [<a href="#type-session_config">session_config()</a>]
</code></pre>




### <a name="type-session_config">session_config()</a> ###


<pre><code>
session_config() = [<a href="#type-session_opt">session_opt()</a>]
</code></pre>




### <a name="type-session_opt">session_opt()</a> ###


<pre><code>
session_opt() = {mod, atom()} | {name, atom()} | {config, <a href="proplists.md#type-proplist">proplists:proplist()</a>}
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#get_session_pid-1">get_session_pid/1</a></td><td>Get pid of named session.</td></tr><tr><td valign="top"><a href="#init-1">init/1</a></td><td><code>Opts</code> is a list of proplists.</td></tr><tr><td valign="top"><a href="#send-2">send/2</a></td><td>Send notification to named session.</td></tr><tr><td valign="top"><a href="#send-3">send/3</a></td><td>Send notification to named session with options Opts.</td></tr><tr><td valign="top"><a href="#start-1">start/1</a></td><td></td></tr><tr><td valign="top"><a href="#start_link-1">start_link/1</a></td><td><code>Opts</code> is a list of proplists.</td></tr><tr><td valign="top"><a href="#start_session-1">start_session/1</a></td><td></td></tr><tr><td valign="top"><a href="#stop-1">stop/1</a></td><td></td></tr><tr><td valign="top"><a href="#stop_session-1">stop_session/1</a></td><td>Stop named session.</td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="get_session_pid-1"></a>

### get_session_pid/1 ###

<pre><code>
get_session_pid(Name::atom()) -&gt; pid() | undefined
</code></pre>
<br />

Get pid of named session.

<a name="init-1"></a>

### init/1 ###

<pre><code>
init(Opts) -&gt; Result
</code></pre>

<ul class="definitions"><li><code>Opts = <a href="#type-init_opts">init_opts()</a></code></li><li><code>Result = {ok, {SupFlags, Children}}</code></li><li><code>SupFlags = {one_for_one, non_neg_integer(), non_neg_integer()}</code></li><li><code>Children = [{term(), {Mod::atom(), start_link, Args::[any()]}, permanent, non_neg_integer(), worker, [atom()]}]</code></li></ul>

`Opts` is a list of proplists.
Each proplist is a session definition containing
name, mod, and config keys.

<a name="send-2"></a>

### send/2 ###

<pre><code>
send(Name::term(), Notification::<a href="sc_types.md#type-proplist">sc_types:proplist</a>(atom(), term())) -&gt; {ok, Ref::term()} | {error, Reason::term()}
</code></pre>
<br />

Send notification to named session.

<a name="send-3"></a>

### send/3 ###

<pre><code>
send(Name::term(), Notification::<a href="sc_types.md#type-proplist">sc_types:proplist</a>(atom(), term()), Opts::list()) -&gt; {ok, Ref::term()} | {error, Reason::term()}
</code></pre>
<br />

Send notification to named session with options Opts.

<a name="start-1"></a>

### start/1 ###

`start(Opts) -> any()`

<a name="start_link-1"></a>

### start_link/1 ###

`start_link(Opts) -> any()`

`Opts` is a list of proplists.
Each proplist is a session definition containing
name, mod, and config keys.

<a name="start_session-1"></a>

### start_session/1 ###

<pre><code>
start_session(Opts::list()) -&gt; {ok, pid()} | {error, already_started} | {error, Reason::term()}
</code></pre>
<br />

<a name="stop-1"></a>

### stop/1 ###

`stop(SupRef) -> any()`

<a name="stop_session-1"></a>

### stop_session/1 ###

<pre><code>
stop_session(Name::atom()) -&gt; ok | {error, Reason::term()}
</code></pre>
<br />

Stop named session.
