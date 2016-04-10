-module('unidecode_data_prv').

-export([init/1, do/1, format_error/1]).

-define(PROVIDER, 'unidecode_data').
-define(DEPS, [app_discovery]).

%% ===================================================================
%% Public API
%% ===================================================================
-spec init(rebar_state:t()) -> {ok, rebar_state:t()}.
init(State) ->
    Provider = providers:create([
            {name, ?PROVIDER},            % The 'user friendly' name of the task
            {module, ?MODULE},            % The module implementation of the task
            {bare, true},                 % The task can be run by the user, always true
            {deps, ?DEPS},                % The list of dependencies
            {example, "rebar3 unidecode_data"}, % How to use the plugin
            {opts, []},                   % list of options understood by the plugin
            {short_desc, "one-off rebar3 plugin preparing data modules for unidecode"},
            {desc, "one-off rebar3 plugin preparing data modules for unidecode"}
    ]),
    {ok, rebar_state:add_provider(State, Provider)}.


-spec do(rebar_state:t()) -> {ok, rebar_state:t()} | {error, string()}.
do(State) ->
    rebar_api:info("Running unidecode_data...", []),
    Repo = "https://www.tablix.org/~avian/git/unidecode.git",
    Cwd = rebar_dir:get_cwd(),
    RepoName = "unidecode_tmp",
    RepoDir = filename:join(rebar_dir:base_dir(State), RepoName),
    case filelib:is_dir(RepoDir) of
        true ->
            file:set_cwd(RepoDir),
            rebar_api:info("Pulling updates in ~p~n", [RepoDir]),
            os:cmd("git pull origin"),
            file:set_cwd(Cwd);
        false ->
            rebar_api:info("Cloning ~p to ~p~n", [Repo, RepoDir]),
            os:cmd("git clone " ++ Repo ++ " " ++ RepoDir)
    end,
    SrcDir = filename:join(RepoDir, "unidecode"),
    rebar_api:info("Translating unidecode files ...", []),
    DataRegex = "^x[0-9a-f]{3}\.py$",
    TargetDir = filename:join(Cwd, "src"),
    filelib:fold_files(SrcDir, DataRegex, false, fun translate_file/2, {target, TargetDir}),
    rebar_api:info("Finished translation.", []),
    {ok, State}.


translate_file(F, Acc = {target, TargetDir}) ->
    rebar_api:debug("Got: ~p,~p~n", [F, Acc]),
    Basename = filename:basename(F),
    ModuleName = "unidecode_data_" ++ string:substr(Basename, 2, 3),
    ModuleFilename = ModuleName ++ ".erl",
    {ok, In} = file:open(F, [read]),
    {ok, Out} = file:open(filename:join(TargetDir, ModuleFilename), [write]),
    process_lines(file:read_line(In), In, Out, ModuleName, {}),
    Acc.

process_lines(eof, In, Out, _ModuleName, _LineState) ->
    file:close(In),
    file:close(Out);
process_lines({ok, InputLine}, In, Out, ModuleName, LineState) ->
    {OutputLines, NewLineState} = translate_line(InputLine, ModuleName, LineState),
    write_lines(OutputLines, Out),
    process_lines(file:read_line(In), In, Out, ModuleName, NewLineState).

-spec write_lines(list(), file:io_device()) -> ok.
write_lines([], _Out) ->
    ok;
write_lines([H|T], Out) ->
    io:fwrite(Out, "~s~n", [H]),
    write_lines(T, Out).

translate_line("data = (\n", ModuleName, _State) ->
    {[io_lib:format("-module(~p).", [ModuleName]),
     "-export([translate/1]).",
     "translate(Position) ->",
     "    element(Position, {"], first};
translate_line(")\n", _ModuleName, _State) ->
    {["})."], {}};
translate_line("\n", _ModuleName, State) ->
    {[], State};
translate_line(Line, ModuleName, State) ->
    case re:run(Line, "(.*)#(.+)?") of
        {match, [_, {Start, Len}, {CommentStart, CommentLen}]} ->
            case Len of
                0 -> DataStr = "";
                _ -> DataStr = string:substr(Line, Start + 1, Len)
            end,
            case CommentLen of
                0 -> CommentStr = "";
                _ -> CommentStr = [io_lib:format(
                                     "%% ~s", 
                                     [string:substr(Line, CommentStart + 1, CommentLen)])]
            end;
        nomatch ->
            DataStr = Line,
            CommentStr = []
    end,
    Lines = case DataStr of
                "" -> [];
                _ -> case re:run(DataStr, "'([^']*)'", [global]) of
                         {match, Matches} ->
                             [format_regular_line(DataStr, XStart, XLen, State) 
                              || [_, {XStart, XLen}] <- Matches];
                         nomatch ->
                             []
                     end
            end,
    Result = CommentStr ++ Lines,
    {Result, {}}.

format_regular_line(Str, Start, Len, State) ->
    io_lib:format("    ~s\"~s\"", [case State of
                                       first -> "";
                                       _ -> ","
                                   end,
                                   string:substr(Str, Start + 1, Len)]).

-spec format_error(any()) ->  iolist().
format_error(Reason) ->
    io_lib:format("~p", [Reason]).
