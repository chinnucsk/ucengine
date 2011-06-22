%%
%%  U.C.Engine - Unified Colloboration Engine
%%  Copyright (C) 2011 af83
%%
%%  This program is free software: you can redistribute it and/or modify
%%  it under the terms of the GNU Affero General Public License as published by
%%  the Free Software Foundation, either version 3 of the License, or
%%  (at your option) any later version.
%%
%%  This program is distributed in the hope that it will be useful,
%%  but WITHOUT ANY WARRANTY; without even the implied warranty of
%%  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%%  GNU Affero General Public License for more details.
%%
%%  You should have received a copy of the GNU Affero General Public License
%%  along with this program.  If not, see <http://www.gnu.org/licenses/>.
%%
-module(presence_controller).

-export([init/0, delete/4, get/4, add/4]).

-include("uce.hrl").

init() ->
    [#uce_route{method='POST',
                regexp="/presence",
                callback={?MODULE, add,
                          [{"name", required, string},
                           {"credential", "", string},
                           {"timeout", 0, integer},
                           {"metadata", [], dictionary}]}},

     #uce_route{method='GET',
                regexp="/presence/([^/]+)",
                callback={?MODULE, get, []}},

     #uce_route{method='DELETE',
                regexp="/presence/([^/]+)",
                callback={?MODULE, delete,
                          [{"uid", required, string},
                           {"sid", required, string}]}}].

add(Domain, [], [Name, Credential, Timeout, Metadata], _) ->
    {ok, #uce_user{id = {Id, Domain}} = User} = uce_user:get(Domain, Name),
    {ok, true} = uce_access:assert(Domain, Id, "", "presence", "add"),
    {ok, true} = ?AUTH_MODULE(User#uce_user.auth):assert(User, Credential),
    {ok, Sid} = uce_presence:add(Domain,
                                 #uce_presence{id=none,
                                               user=User#uce_user.id,
                                               timeout=Timeout,
                                               auth=User#uce_user.auth,
                                               metadata=Metadata}),
    {ok, _} = uce_event:add(Domain,
                            #uce_event{id={none, Domain},
                                       from=User#uce_user.id,
                                       location={"", Domain},
                                       type="internal.presence.add"}),
    {Id, _} = User#uce_user.id,
    json_helpers:json(Domain, 201, {struct, [{uid, Id}, {sid, Sid}]}).

get(Domain, [Id], [], _) ->
    {ok, Presence} = uce_presence:get(Domain, Id),
    json_helpers:json(Domain, presence_helpers:to_json(Domain, Presence)).

delete(Domain, [Id], [Uid, Sid], _) ->
    {ok, true} = uce_presence:assert(Domain, Uid, Sid),
    {ok, #uce_presence{} = Presence} = uce_presence:get(Domain, Id),
    {ok, true} = uce_access:assert(Domain, Uid, "", "presence", "delete",
                                   [{"id", Presence#uce_presence.id}]),

    ok = presence_helpers:clean(Domain, Presence),
    {ok, deleted} = uce_presence:delete(Domain, Id),

    json_helpers:ok(Domain).
