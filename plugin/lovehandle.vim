""
" Don't load this plugin if the user has it disabled, or it's already been
" loaded, or if there are errors in the error list.
if exists('g:lovehandle_loaded') || &cp
  finish
endif
let g:lovehandle_loaded = 1

""
" IF the user hasn't defined which table is the default, assume 'development'.
if !exists('g:lovehandle_default_database')
  let g:lovehandle_default_database = 'development'
endif

""
" If g:db isn't set, but g:lovehandle_list is, set g:db to
" g:lovehandle_default_database. If that key doesn't exist, set g:db to the
" first db in the list.
if !exists('g:db') && exists('g:lovehandle_list')
  let g:db = lovehandle#FindDBByKey(g:lovehandle_default_database, 0, g:lovehandle_list[0][1])
endif

""
" Provide a command to call the switch db function.
" If no arg is passed, defaults to g:lovehandle_default_database.
" Example: `:LHSwitch test`
"       => Switching to test database: postgres://postgres:password@db/fasttrac_test
command! -bang -nargs=? -complete=custom,lovehandle#ListCompletions
      \ LHSwitch call lovehandle#DBSwitch(<bang>0, <f-args>)

""
" Provide a command to show the current db url. Add ! to show actual URL
" Example: `:LHList!`
"       => g:db is set to development: postgres://user@host/database
command! -bang LHList call lovehandle#DBList(<bang>0)

""
" Open database file.
command! -nargs=+ -complete=custom,lovehandle#FileCompletion
      \ LHFile call lovehandle#File(<f-args>)

""
" Creates the SQL dir.
" If ! is used, will silence warnings.
command! -bang LHCreateSQLDir call database#CreateSQLDir(<bang>0)

""
" Provide a command to generate SQL. Add ! to place above cursor.
" Example: `:LHGenerateSQL users`
"       => Default SQL queries for 'users' would be added to file.
command! -bang -nargs=? LHGenerateSQL call lovehandle#GenerateSQL(<bang>0, <f-args>)
