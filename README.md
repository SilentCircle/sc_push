

# Push Notification Service Erlang API #

Copyright (c) 2016 Silent Circle

__Version:__ 1.1.6

__Authors:__ Edwin Fine ([`efine@silentcircle.com`](mailto:efine@silentcircle.com)).

__References__* For Apple Push technical information, see
[Local and Push Notification Programming Guide](https://developer.apple.com/library/ios/#documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/).
* For Google Cloud Messaging technical information, see
[Google Cloud Messaging](http://developer.android.com/guide/google/gcm/index.md).


### <a name="Notification_Properties">Notification Properties</a> ###

Each notification service supports different capabilities. Given the choice
between having a lowest common denominator interface for ease of use but
little flexibility, or allowing access to all service-specific features,
this API has chosen to do mostly the latter, with one ease-of-use exception:
the `alert` property, which is common to all services and will map to
the proper service-specific API. This carries the actual message text
to be displayed in the notification.

All other features such as badges, expiry times, and so on, must be provided
in a service-specific container.


#### <a name="Apple_Push_Service_(APNS)">Apple Push Service (APNS)</a> ####

<strong>TODO</strong>
: Add APNS documentation.


#### <a name="Google_Cloud_Messaging">Google Cloud Messaging</a> ####

The description given is basically to show how to format the
properties in Erlang.


<dt><code>registration_ids</code></dt>



<dd>List of binary strings. Each binary is a registration id
     for an Android device+application. <strong>Required</strong>.</dd>



<dt><code>collapse_key</code></dt>



<dd><code>binary()</code>. (Binary string). Optional.</dd>



<dt><code>delay_while_idle</code></dt>



<dd><code>boolean()</code>. Optional.</dd>



<dt><code>time_to_live</code></dt>



<dd><code>integer()</code>. Optional.</dd>



<dt><code>restricted_package_name</code></dt>



<dd><code>binary()</code>. (Binary string). Overrides default on server. Optional.</dd>



<dt><code>dry_run</code></dt>



<dd><code>boolean()</code>. Optional (defaults to false)</dd>



<dt><code>data</code></dt>



<dd>Message payload data, which must be an
         object (Erlang proplist) that is convertible to JSON. The correspondence between
         the JSON and Erlang types are described in the table below.<table class="with-borders"><tr><th class="with-borders"><strong>JSON</strong></th><th class="with-borders"><strong>erlang</strong></th></tr><tr><td class="with-borders"> <code>number</code> </td><td class="with-borders"> <code>integer()</code> and <code>float()</code></td></tr><tr><td class="with-borders"> <code>string</code> </td><td class="with-borders"> <code>binary()</code> </td></tr><tr><td class="with-borders"> <code>true</code>, <code>false</code> and <code>null</code></td><td class="with-borders"> <code>true</code>, <code>false</code> and <code>null</code></td></tr><tr><td class="with-borders"> <code>array</code> </td><td class="with-borders"> <code>[]</code> and <code>[json()]</code></td></tr><tr><td class="with-borders"> <code>object</code> </td><td class="with-borders"> <code>[{}]</code> and <code>[{binary()</code> or <code>atom(), json()}]</code></td></tr></table></dd>




<h5><a name="Examples_of_GCM_Notification_proplists">Examples of GCM Notification proplists</a></h5>


* Simplest Possible properties


```
Notification = [
    {'registration_ids', [<<"Your android app reg id">>]},
    {'data', [{msg, <<"Would you like to play a game?">>}]}
].
```

* TODO - Add more examples



## Modules ##


<table width="100%" border="0" summary="list of modules">
<tr><td><a href="http://github.com/SilentCircle/sc_push/blob/master/doc/sc_push.md" class="module">sc_push</a></td></tr>
<tr><td><a href="http://github.com/SilentCircle/sc_push/blob/master/doc/sc_push_app.md" class="module">sc_push_app</a></td></tr>
<tr><td><a href="http://github.com/SilentCircle/sc_push/blob/master/doc/sc_push_reg_resource.md" class="module">sc_push_reg_resource</a></td></tr>
<tr><td><a href="http://github.com/SilentCircle/sc_push/blob/master/doc/sc_push_reg_wm_device.md" class="module">sc_push_reg_wm_device</a></td></tr>
<tr><td><a href="http://github.com/SilentCircle/sc_push/blob/master/doc/sc_push_reg_wm_service.md" class="module">sc_push_reg_wm_service</a></td></tr>
<tr><td><a href="http://github.com/SilentCircle/sc_push/blob/master/doc/sc_push_reg_wm_tag.md" class="module">sc_push_reg_wm_tag</a></td></tr>
<tr><td><a href="http://github.com/SilentCircle/sc_push/blob/master/doc/sc_push_sup.md" class="module">sc_push_sup</a></td></tr>
<tr><td><a href="http://github.com/SilentCircle/sc_push/blob/master/doc/sc_push_svc_null.md" class="module">sc_push_svc_null</a></td></tr>
<tr><td><a href="http://github.com/SilentCircle/sc_push/blob/master/doc/sc_push_svc_null_srv.md" class="module">sc_push_svc_null_srv</a></td></tr>
<tr><td><a href="http://github.com/SilentCircle/sc_push/blob/master/doc/sc_push_wm_common.md" class="module">sc_push_wm_common</a></td></tr>
<tr><td><a href="http://github.com/SilentCircle/sc_push/blob/master/doc/sc_push_wm_helper.md" class="module">sc_push_wm_helper</a></td></tr>
<tr><td><a href="http://github.com/SilentCircle/sc_push/blob/master/doc/sc_push_wm_send_device.md" class="module">sc_push_wm_send_device</a></td></tr>
<tr><td><a href="http://github.com/SilentCircle/sc_push/blob/master/doc/sc_push_wm_send_svc_appid_tok.md" class="module">sc_push_wm_send_svc_appid_tok</a></td></tr>
<tr><td><a href="http://github.com/SilentCircle/sc_push/blob/master/doc/sc_push_wm_send_svc_tok.md" class="module">sc_push_wm_send_svc_tok</a></td></tr>
<tr><td><a href="http://github.com/SilentCircle/sc_push/blob/master/doc/sc_push_wm_send_tag.md" class="module">sc_push_wm_send_tag</a></td></tr>
<tr><td><a href="http://github.com/SilentCircle/sc_push/blob/master/doc/sc_push_wm_sup.md" class="module">sc_push_wm_sup</a></td></tr></table>

