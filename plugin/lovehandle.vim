""
" Don't load this plugin if the user has it disabled, or it's already been
" loaded, or if there are errors in the error list.
if exists('g:lovehandle_loaded') || &cp
  finish
endif
let g:lovehandle_loaded = 1

call lovehandle#Init()

""
" Provide a command to call the switch db function.
" If no arg is passed, defaults to g:lovehandle_default_database.
" If ! is passed, silence production warning.
" Example: `:LHSwitch test`
"       => Switching to test database: postgres://postgres:password@host/database
command! -bang -nargs=? -complete=custom,lovehandle#ListCompletions
      \ LHSwitch call lovehandle#Switch(<bang>0, <f-args>)

""
" Provide a command to show the current db url. Call with :verbose to show URL
" Example: `:LHList`
"       => g:db is set to development
"          `:verbose LHList`
"       => g:db is set to development: postgres://user@host/database
command! LHList call lovehandle#List()

""
" Open database file.
command! -nargs=+ -complete=custom,lovehandle#FileCompletion
      \ LHFile call lovehandle#File(<f-args>)

""
" Reload the configuration.
command! -nargs=? -complete=file LHReload call lovehandle#Init(<f-args>)

""
" Creates the SQL dir.
" If ! is used, will silence warnings.
command! -bang LHCreateSQLDir call database#CreateSQLDir(<bang>0)

""
" Provide a command to generate SQL. Add ! to place above cursor.
" Example: `:LHGenerateSQL users`
"       => Default SQL queries for 'users' would be added to file.
command! -bang -nargs=? LHGenerateSQL call lovehandle#GenerateSQL(<bang>0, <f-args>)
