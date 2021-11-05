# LoveHandle
A vim plugin that extends [Tim Pope](https://github.com/tpope)'s
[vim-dadbod](https://github.com/tpope/vim-dadbod) to make it easier to work in
various databases across different projects. It provides commands for easily
switching between database URLs, creating and editing SQL files kept in
projects, setting DB URLs based on file name and path, and generating common SQL
queries within these files. See [below](#usage) for examples.

Note that this guide is helpful to get started and understand what the plugin
does, but should you install this plugin, please read the authoritative
documentation (`:help lovehandle`) after generating helptags.

## Installation
I recommend installing a modern version of vim (8.0+) and using its built-in
packages system (`:help packages`).

Clone the repository in your `pack` directory. Note, `evanthegrayt/` is
used as the package directory in this example, but you can put it in whichever
package directory you want.

```sh
mkdir -p ~/.vim/pack/evanthegrayt/start/

git clone https://github.com/evanthegrayt/vim-lovehandle.git \
    ~/.vim/pack/evanthegrayt/start/vim-lovehandle
```

Don't forget the documentation. Run `:helptags` on the `doc/` directory. Or, to
update all your plugins' documentation:

```
:helptags ~/.vim/pack/evanthegrayt/start/vim-lovehandle/doc
" OR
:helptags ALL
```

## Initial Setup
This plugin was written to make it easier to set DB URLs for different projects.
Because of this, it's helpful to have a different set of variables defined for
each project. There are several ways to accomplish this. Note that the variables
referenced in this section will be covered in the [next
section](#project-specific-setup).

First, it's worth noting that if you `set exrc`, you can just set the variables
in the project's local `.vimrc` file. This option is **not** recommended. For
reasoning, see `:help 'exrc'`.


If you like the idea of keeping a local `.vimrc` (or other file name) in each
project so that team members will have the same config, but don't want to `set
exrc`, you can define a dictionary with the key/value pairs being the directory
of the project and the file to source for that project. Note that the keys must
be full paths to the directory, with no slash at the end.

```vim
let g:lovehandle_projects = {
        \   '/home/me/project_one': '.vimrc',
        \   '/home/me/project_two': '.lovehandle.vim'
        \ }
```

If you prefer not to create a file in the project, or aren't able to do so, the
values can be set via a sub-dictionary, with the key/value pairs being the
variable to set (minus the `g:lovehandle_` prefix) and the variable's value.

```vim
let g:lovehandle_projects = {
        \   '/home/me/project_one': {
        \     'list': [
        \       ['development', 'postgres://user:password@host:port/database'],
        \       ['staging', 'postgres://user:password@host:port/database']
        \     ],
        \     'sql_directory': 'db/sql',
        \     'default_database': 'development',
        \     'switch_confirm_production': 1,
        \     'switch_silently': 0
        \   },
        \   '/home/me/project_two': '.lovehandle.vim'
        \ }
```

If you want to source a project's local vimrc, but also override some of the
variables, you can add a `'file'` key to the project's sub-dictionary. The file
will be sourced first, and then the remaining variables in the dictionary will
be (re)set.

```vim
let g:lovehandle_projects = {
        \   '/home/me/project_one': {
        \     'sql_directory': 'db/sql',
        \     'switch_confirm_production': 1,
        \     'switch_silently': 0,
        \     'file': '.vimrc'
        \   },
        \   '/home/me/project_two': '.lovehandle.vim'
        \ }
```

## Project-Specific Setup
This section defines the variables to configure for the plugin to work properly.
They should be defined for each project, either in the file to be sourced for
that project, or in the project's sub-dictionary of `g:lovehandle_projects`.
It's worth noting that `g:lovehandle_list` is the only required variable, as the
rest have defaults.

### Defining handles and URLs
You will need to define a two-dimensional list called `g:lovehandle_list`. The
handles will be used as an identifier when setting the URLs. They will also be
used for tab-completion. The values should be database URLs to those databases.
Here's an example:

```vim
" Obviously, in a real-world example, all the URLs would be different.
let g:lovehandle_list = [
      \   ['testing', 'postgres://user:password@host:port/database'],
      \   ['development', 'postgres://user:password@host:port/database'],
      \   ['staging', 'postgres://user:password@host:port/database'],
      \   ['production', 'postgres://user:password@host:port/database'],
      \ ]
```

There is a benefit to using the handle names in the example, which will be
explained shortly.

You can define a default database by setting `g:lovehandle_default_database` in
the project's `.vimrc`.

```vim
let g:lovehandle_default_database = 'development'
```

If `g:lovehandle_default_database` is not defined, but 'development' exists as a
handle, it will be the default database. Otherwise, the first database in the
list will be the default. This is why we use a 2-D list instead of a dictionary;
dictionaries are not ordered in vimscript.

It's important to note, when setting the default URL, `g:db` will be set
(global). Any time a URL is changed after that, it will be set `b:db` (local to
the *buffer*). There's currently [an open
issue](https://github.com/evanthegrayt/vim-lovehandle/issues/4) to be able to
customize this behavior, so feel free to leave your thoughts in a comment.

## Usage
### Listing current and available handles
If, at any time, you want to see which database is being used, use the `:LHList`
command. If you use the naming convention previously explained, if the current
DB URL is set to a production database, it will be in red. Calling with
`:verbose` will also show the actual DB URL.

```
:LHList
"=> b:db is set to development

:verbose LHList
"=> b:db is set to development: 'postgres://user:password@host:port/database'
```

### Switching between database URLs
Still assuming the above example list, switching DBs is now as easy as calling
`:LHSwitch production`. This feature has tab-completion, so you can type
`:LHSwitch <tab>` and it will show/cycle the options. `LHSwitch` with no
arguments will switch to the default handle.

If you attempt to switch to a production database, and assuming you named your
handles correctly, you will be asked to confirm the switch. To avoid this
confirmation, use the bang version of the command.

```
:LHSwitch! production
```

To disable the confirmation permanently, the following can be set.

```vim
let g:lovehandle_switch_confirm_production = 0
```

To silence the "Switching to X database" message when switching, the following
can be set.

```vim
let g:lovehandle_switch_silently = 1
```

Tip: To learn about database URLs, read the [help
documentation](https://github.com/tpope/vim-dadbod/blob/master/doc/dadbod.txt)
for `DadBod`.

### SQL Files and Automatic Database URLs
This feature is for people who keep commonly-used SQL queries in their projects.

You can define a directory for storing SQL files (with `.sql` extension) by
setting `g:lovehandle_sql_directory` to a string.

```vim
let g:lovehandle_sql_directory = 'db/sql'
```

If this variable is not set, it will default to `db/sql/` if `db/` exists,
`database/sql/` if `database/` exists, or finally, `sql/` if neither exist.

When opened, files in this directory with a `.sql` extension, will automatically
be set to the default database (either "development" if it exists, or the first
database listed in `g:lovehandle_list`).

If, however, the file is in a sub-directory, and that sub-directory name matches
a handle in `g:lovehandle_list`, the database URL will be set to that handle's
value.

Assuming the directory `db/` exists, and a project's `.vimrc` contains the
following:

```vim
let g:lovehandle_list = [
      \   ['development',       'postgres://user@host/database'],
      \   ['mysql_development', 'mysql://user:password@host:port/database']
      \ ]
```

A file called `db/sql/users.sql` would point to `postgres://user@host/database`.
This would *also* be true if the file were called
`db/sql/development/users.sql`.

If we want the URL to point to `mysql://user:password@host:port/database`, we'd
need to call the file `db/sql/mysql_development/users.sql`. If you call the
sub-directory `mysql` instead of `mysql_development`, the `_development` suffix
will be implied.

Note that you can still change the database URL anytime with `:LHSwitch`.

### Automatic Query Generation for SQL Files
Any new or empty `db/sql/**/*.sql` file opened with vim will automatically have
default queries generated in the file. It is assumed that the file name will be
the table name to query. These queries are even adapter aware, which as we've
learned, are based off the directory in which they reside. Assuming the file
name is `users.sql`:

If the adapter is postgres, the following contents will be placed in the file:

```sql
-- SQL for 'users' table generated by lovehandle.
-- Sun Feb 23 08:23:53 2020

-- List all tables in the database.
\dt;

-- Describe 'users' table's attributes.
\d users;

-- Count records in 'users'.
SELECT count(1) FROM users;

-- List all records from the 'users' table.
SELECT * FROM users;
```

If the adapter is mysql, the following contents will be placed in the file:

```sql
-- SQL for 'users' table generated by lovehandle.
-- Sun Feb 23 08:23:53 2020

-- List all tables in the database.
show tables;

-- Describe 'users' table's attributes.
describe users;

-- Count records in 'users'.
SELECT count(1) FROM users;

-- List all records from the 'users' table.
SELECT * FROM users;
```

There are also commands provided for generating this sql at-will. Using the `!`
form will place text *above* current cursor position. Note that a database URL
must be set.

```
:LHGenerateSQL[!] [TABLE]
```

## Dependencies and Recommended Plugins
Lovehandles was originally written around
[DadBod](https://github.com/tpope/vim-dadbod), so it sets variables specific to
that plugin. However, you can use any plugin that can communicate with a
database.  You may just have to change the variables it uses for database URLs
(`g:db` and `b:db`).

LoveHandle assumes you open vim from the root of a project to look for
project-specific vimrc files, and to determine the projects SQL directory. If
you're not in this habit, I recommend installing
[Rooter](https://github.com/airblade/vim-rooter).

## Issues and Feature Requests
If you find a bug or would like to request a feature, please [create an
issue](https://github.com/evanthegrayt/vim-lovehandle/issues/new).
Just make sure the topic doesn't already exist. Or, better yet, feel free to
submit a pull request.

## Self-Promotion
I do these projects for fun, and I enjoy knowing that they're helpful to people.
Consider starring [the
repository](https://github.com/evanthegrayt/vim-lovehandle) if you like it! If
you love it, follow me [on github](https://github.com/evanthegrayt)!
