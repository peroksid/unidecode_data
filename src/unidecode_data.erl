-module('unidecode_data').

-export([init/1]).

-spec init(rebar_state:t()) -> {ok, rebar_state:t()}.
init(State) ->
    {ok, State1} = 'unidecode_data_prv':init(State),
    {ok, State1}.
