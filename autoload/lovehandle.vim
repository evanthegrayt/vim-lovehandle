""
" Map adapters to query snippets.
let s:ShowTablesDictionary = {
      \   'postgres': '\dt',
      \   'mysql':    'SHOW TABLES'
      \ }
let s:DescribeTablesDictionary = {
      \   'postgres': '\d',
      \   'mysql':    'DESCRIBE',
      \ }

""
" List which database the b:db or g:db url points to. If ! is used, Also show
" the actual URL.
function! lovehandle#DBList(show_url) abort
  if !s:validate() | return | endif

  let l:db = lovehandle#GetURL()

  for [l:key, l:value] in g:lovehandle_list
    if l:value ==# l:db
      let l:string = lovehandle#GetDBVar() . ' is set to ' . l:key
      if a:show_url | let l:string .= ': ' . l:db | endif

      if match(l:key, 'production') >= 0
        call lovehandle#Warn(l:string)
      else
        echo l:string
      endif

      return
    endif
  endfor

  call lovehandle#Warn('No database set!')
endfunction

""
" Function that switches the database URL.
" NOTE that this only changes it for the current BUFFER, not globally!
function! lovehandle#DBSwitch(force, ...) abort
  if !s:validate() | return | endif

  let l:database = a:0 == 1 ? a:1 : g:lovehandle_default_database

  for [l:key, l:value] in g:lovehandle_list
    if l:key ==# l:database
      let l:string = 'Switching to ' . l:database . ' database: ' . l:value

      if match(l:key, 'production') >= 0
        if !a:force && s:ConfirmProduction() != 1
          return
        endif
        if (!exists('g:lovehandle_switch_silently') || !g:lovehandle_switch_silently)
          call lovehandle#Warn(l:string)
        endif
      else
        if (!exists('g:lovehandle_switch_silently') || !g:lovehandle_switch_silently)
          echo l:string
        endif
      endif

      let b:db = l:value
      return
    endif
  endfor

  call lovehandle#Warn('No DB defined for ' . l:database)
endfunction

""
" Finds the database by 'key' in g:db list. If not found, returns the defualt.
function! lovehandle#FindDBByKey(key, use_dev_suffix, default) abort
  if !s:validate() | return | endif

  for [l:key, l:value] in g:lovehandle_list
    if l:key ==# a:key ||
          \ (a:use_dev_suffix && l:key ==# a:key . '_' . g:lovehandle_default_database)
      return l:value
    endif
  endfor

  return a:default
endfunction

""
" Generates SQL based argument passed, or off current file name if no args.
" If `place_above_cursor` is 1, will insert text above corser position.
function! lovehandle#GenerateSQL(place_above_cursor, ...) abort
  if !s:validate() | return | endif

  let l:table = a:0 ? a:1 : expand('%:t:r')
  let l:adapter = lovehandle#GetAdapter()
  let l:cursor_pos = line('.')

  if a:place_above_cursor | let l:cursor_pos -= 1 | endif

  call append(l:cursor_pos, [
        \   "-- SQL for '" . l:table . "' table generated by lovehandle.",
        \   "-- " . strftime('%c'),
        \   '',
        \   '-- List all tables in the database.',
        \   s:ShowTablesDictionary[l:adapter] . ';',
        \   '',
        \   "-- Describe '" . l:table . "' table's attributes.",
        \   s:DescribeTablesDictionary[l:adapter] . ' ' . l:table . ';',
        \   '',
        \   "-- Count records in '" . l:table . "'.",
        \   'SELECT count(*) FROM ' . l:table . ';',
        \   '',
        \   "-- List all records from the '" . l:table . "' table.",
        \   'SELECT * FROM ' . l:table . ';',
        \ ])

  let &modified = 1
endfunction

""
" Opens/creates a sql file.
function! lovehandle#File(table) abort
  let l:dir = lovehandle#GetSQLDirectory()

  if !isdirectory(l:dir)
    call lovehandle#CreateSQLDir(0)
  endif

  let l:file = l:dir . a:table

  if l:file !~#  '\.sql$' | let l:file = l:file . '.sql' | endif

  execute 'edit' l:file
endfunction

""
" Creates the sql directory.
function! lovehandle#CreateSQLDir(fail_silently) abort
  let l:dir = lovehandle#GetSQLDirectory()

  if isdirectory(l:dir)
    if !a:fail_silently
      call lovehandle#Warn("Directory '" . l:dir . "' already exists.")
    endif
    return 0
  endif

  echom l:dir
  return 1
endfunction

""
" Returns the adapter from URL.
function! lovehandle#GetAdapter() abort
  return split(lovehandle#GetURL(), ':')[0]
endfunction

""
" Returns the current value of b:db, or g:db.
function! lovehandle#GetURL() abort
  for l:var in ['b:db', 'g:db']
    if exists(l:var) | return eval(l:var) | endif
  endfor
endfunction

""
" Returns the sql directory.
function! lovehandle#GetSQLDirectory()
  if exists('g:lovehandle_sql_directory')
    let l:dir = g:lovehandle_sql_directory
  elseif isdirectory('db')
    let l:dir = 'db/sql'
  elseif isdirectory('database')
    let l:dir = 'database/sql'
  else
    let l:dir = 'sql'
  endif

  return resolve(expand(l:dir)) . '/'
endfunction

""
" Returns the current b:db, or g:db.
function! lovehandle#GetDBVar() abort
  for l:var in ['b:db', 'g:db']
    if exists(l:var) | return l:var | endif
  endfor
endfunction

""
" Completions for SQL Files.
function! lovehandle#FileCompletion(arg_lead, cmd_line, cursor_pos)
  let l:dir = lovehandle#GetSQLDirectory()
  if !isdirectory(l:dir) | call lovehandle#CreateSQLDir(1) | endif
  let l:olddir = chdir(l:dir)
  let l:list = glob('**/*.sql', 0, 1)
  call chdir(l:olddir)
  return join(l:list, "\n")
endfunction

""
" Function for returning completion options, which are the keys to g:lovehandle_list.
function! lovehandle#ListCompletions(arg_lead, cmd_line, cursor_pos) abort
  if !s:validate() | return | endif

  let l:copy = deepcopy(g:lovehandle_list)

  return join(map(l:copy, 'v:val[0]'), "\n")
endfunction

"============="
" PRIVATE API "
"============="

""
" Makes sure g:lovehandle_list exists.
function! s:validate() abort
  if exists('g:lovehandle_list') && !empty(g:lovehandle_list) | return 1 | endif

  call lovehandle#Warn('g:lovehandle_list is not set! Please set in `.vimrc` file!')
  return 0
endfunction

function! s:ConfirmProduction()
  if exists('g:lovehandle_switch_confirm_production') && !g:lovehandle_switch_confirm_production
    return 1
  endif
  return confirm(
          \ 'PRODUCTION, ARE YOU SURE?', "&Yes\n&No\n&Cancel", 2, 'Question'
        \ )
endfunction

""
" Print an error message (red).
function! lovehandle#Warn(message) abort
  echohl ErrorMsg | echomsg 'Lovehandle: ' . a:message | echohl None
endfunction