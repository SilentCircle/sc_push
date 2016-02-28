

# Module sc_push_svc_null_srv #
* [Description](#description)
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

Null push service.

Copyright (c) (C) 2012,2013 Silent Circle LLC

__Behaviours:__ [`gen_server`](gen_server.md).

__Authors:__ Edwin Fine ([`efine@silentcircle.com`](mailto:efine@silentcircle.com)).

<a name="description"></a>

## Description ##

This is a do-nothing module that provides the
required interfaces. Push notifications will always succeed (and,
of course, not go anywhere) unless otherwise configured in the
notification. This supports standalone testing.

Sessions must have unique names within the node because they are
registered. If more concurrency is desired, a session may elect to
become a supervisor of other session, or spawn a pool of processes,
or whatever it takes.

<a name="types"></a>

## Data Types ##




### <a name="type-opt">opt()</a> ###


<pre><code>
opt() = {log_dest, {file, string()}} | {log_level, off | info}
</code></pre>

default = info

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#send-2">send/2</a></td><td>Equivalent to <a href="#send-3"><tt>send(SvrRef, Notification, [])</tt></a>.</td></tr><tr><td valign="top"><a href="#send-3">send/3</a></td><td>Send a notification specified by <code>Notification</code> via <code>SvrRef</code>
with options <code>Opts</code>.</td></tr><tr><td valign="top"><a href="#start-2">start/2</a></td><td>Start a named session as described by the options <code>Opts</code>.</td></tr><tr><td valign="top"><a href="#start_link-2">start_link/2</a></td><td>Start a named session as described by the options <code>Opts</code>.</td></tr><tr><td valign="top"><a href="#stop-1">stop/1</a></td><td>Stop session.</td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="send-2"></a>

### send/2 ###

<pre><code>
send(SvrRef::term(), Notification::list()) -&gt; {ok, Ref::term()} | {error, Reason::term()}
</code></pre>
<br />

Equivalent to [`send(SvrRef, Notification, [])`](#send-3).

<a name="send-3"></a>

### send/3 ###

<pre><code>
send(SvrRef::term(), Notification::list(), Opts::list()) -&gt; {ok, Ref::term()} | {error, Reason::term()}
</code></pre>
<br />

Send a notification specified by `Notification` via `SvrRef`
with options `Opts`.


#### <a name="Notification_format">Notification format</a> ####

[
{return, success | {error, term()}}, % default = success
]


#### <a name="Options">Options</a> ####

Not currently supported, will accept any list.

<a name="start-2"></a>

### start/2 ###

<pre><code>
start(Name::atom(), Opts::[<a href="#type-opt">opt()</a>]) -&gt; term()
</code></pre>
<br />

Start a named session as described by the options `Opts`.  The name
`Name` is registered so that the session can be referenced using the name to
call functions like send/2. Note that this function is only used
for testing; see start_link/2.

<a name="start_link-2"></a>

### start_link/2 ###

<pre><code>
start_link(Name::atom(), Opts::[<a href="#type-opt">opt()</a>]) -&gt; term()
</code></pre>
<br />

Start a named session as described by the options `Opts`.  The name
`Name` is registered so that the session can be referenced using the name to
call functions like send/2.

<a name="stop-1"></a>

### stop/1 ###

<pre><code>
stop(SvrRef::term()) -&gt; term()
</code></pre>
<br />

Stop session.

