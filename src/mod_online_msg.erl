%%%----------------------------------------------------------------------
%%% File    : mod_online_msg.erl
%%% Author  : Darren Ferguson <darren.ferguson@openband.net>
%%% Purpose : Send msg to user every time they come online
%%% Id      : $Id: mod_online_msg.erl
%%%----------------------------------------------------------------------

-module(mod_online_msg).
-author('darren.ferguson@openband.net').
-version("0.1").

-behaviour(gen_mod).

% API for the module
-export([start/2,
         stop/1,
         msg_send/2,
         on_server_login/1]).

% will only use for debugging purposes, will remove the line once finished
-define(ejabberd_debug, true).

% including the ejabberd main header file
-include("ejabberd.hrl").
-include("jlib.hrl").

-define(PROCNAME, ejabberd_mod_online_msg).

% variable with _ i.e. _Opts will not bring a compiler unused error if not used
start(Host, Opts) ->
    % Retrieving the message we shall use for message of the day
    Subject = gen_mod:get_opt(subject, Opts, "Message Subject"),
    Msg = gen_mod:get_opt(msg, Opts, "Message of the Day"),

    % adding hooks for the presence handlers so our function will be called
    ejabberd_hooks:add(user_available_hook, Host,
                       ?MODULE, on_server_login, 50),

    % spawning a background process so we can use these variables later (erlang no global variables)
    register(gen_mod:get_module_proc(Host, ?PROCNAME),
             spawn(mod_online_msg, msg_send, [Subject, Msg])),
    ok.

stop(Host) ->
    % removing the hooks for the presence handlers when the server is stopped
    ejabberd_hooks:delete(user_available_hook, Host,
                          ?MODULE, on_server_login, 50),
    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    Proc ! stop,
    ok.

% listener function that will send the packet with pertinent information
% to the adminjid and resource that has been specified in the configuration
msg_send(Subject, Msg) ->
    receive
        {LServer, JID} ->
                Packet = build_online_message(Subject, Msg),
                Local = jlib:make_jid("", LServer, ""),
                ejabberd_router:route(Local, JID, Packet),
                msg_send(Subject, Msg);
        stop ->
                exit(normal)
    end.


% function called when we have a presence update and the user is staying online
on_server_login(#jid{luser = _LUser, lserver = LServer} = JID) ->
    Proc = gen_mod:get_module_proc(LServer, ?PROCNAME),
    Proc ! {LServer, JID}.

build_online_message(Subject, Body) ->
    {xmlelement, "message",
     [{"type", "headline"}],
     [{xmlelement, "subject", [], [{xmlcdata, Subject}]},
      {xmlelement, "body", [], [{xmlcdata, Body}]}
     ]
    }.
