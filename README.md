unidecode_data
=====

one-off rebar3 plugin preparing data modules for unidecode

Build
-----

    $ rebar3 compile

Use
---

Add the plugin to your rebar config:

    {plugins, [
        { unidecode_data, ".*", {git, "git@host:user/unidecode_data.git", {tag, "0.1.0"}}}
    ]}.

Then just call your plugin directly in an existing application:


    $ rebar3 unidecode_data
    ===> Fetching unidecode_data
    ===> Compiling unidecode_data
    <Plugin Output>
