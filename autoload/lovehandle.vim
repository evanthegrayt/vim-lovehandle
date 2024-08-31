""
" Map adapters to query snippets.
" TODO: Add more adapters. https://github.com/evanthegrayt/vim-lovehandle/issues/5
let s:Sql = {
      \   'postgres': {
      \     'show_tables': '\dt',
      \     'describe': '\d'
      \   },
      \   'mysql': {
      \     'show_tables': 'SHOW TABLES',
      \     'describe': 'DESCRIBE'
      \   }
      \ }

""
" Sets the inital 'g:db' if possible.
function! lovehandle#Init(...)
  if a:0
    let l:file = a:1
    call s:SourceLocalVimrc(l:file)
  else
    if exists('g:lovehandle_projects')
      let l:cwd = getcwd()
      if has_key(g:lovehandle_projects, l:cwd)
        let l:project = g:lovehandle_projects[l:cwd]
        if type(l:project) == v:t_string
          call s:SourceLocalVimrc(l:project)
        elseif type(l:project) == v:t_list
          let g:lovehandle_list = l:project
        elseif type(l:project) == v:t_dict
          if has_key(l:project, 'file')
            call s:SourceLocalVimrc(l:project.file)
          endif
          call s:SetVariables(l:project)
        endif
      endif
    endif
  endif
  if exists('g:lovehandle_list')
    let g:db = lovehandle#FindDBByKey(
          \   s:GetDefaultDatabase(),
          \   0,
          \   g:lovehandle_list[0][1]
          \ )
  endif
endfunction

""
" List which database the b:db or g:db url points to. If ! is used, Also show
" the actual URL.
function! lovehandle#List() abort
  if !lovehandle#Validate() | return | endif
  let l:db = s:GetUrl()
  for [l:key, l:value] in g:lovehandle_list
    if l:value ==# l:db
      let l:string = s:GetDBVar() . ' is set to ' . l:key
      if &verbose | let l:string .= ': ' . l:db | endif
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
" TODO: Revisit this. I'm not sure about always only switching `b:db`.
function! lovehandle#Switch(force, ...) abort
  if !lovehandle#Validate() | return | endif
  let l:database = a:0 == 1 ? a:1 : s:GetDefaultDatabase()
  for [l:key, l:value] in g:lovehandle_list
    if l:key ==# l:database
      let l:string = 'Switching to ' . l:database . ' database'
      if &verbose
        let l:string .= ': ' . l:value
      endif
      if match(l:key, 'production') >= 0
        if !a:force && s:ConfirmProduction() != 1
          return
        endif
        if s:ShouldPrintSwitchMessage()
          call lovehandle#Warn(l:string)
        endif
      else
        if s:ShouldPrintSwitchMessage()
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
" Opens/creates a sql file.
function! lovehandle#File(table) abort
  if !lovehandle#Validate() | return | endif
  let l:dir = lovehandle#GetSQLDirectory()
  call lovehandle#CreateSQLDir(1)
  let l:file = l:dir . a:table
  if l:file !~#  '\.sql$' | let l:file .= '.sql' | endif
  execute 'edit' l:file
endfunction

""
" Generates SQL based argument passed, or off current file name if no args.
" If `place_above_cursor` is 1, will insert text above corser position.
function! lovehandle#GenerateSQL(place_above_cursor, ...) abort
  if !lovehandle#Validate() | return | endif
  let l:table = a:0 ? a:1 : expand('%:t:r')
  let l:adapter = s:GetAdapter()
  let l:cursor_pos = line('.')
  if a:place_above_cursor | let l:cursor_pos -= 1 | endif
  call append(l:cursor_pos, [
        \   "-- SQL for '" . l:table . "' table generated by lovehandle.",
        \   "-- " . strftime('%c'),
        \   '',
        \   '-- List all tables in the database.',
        \   s:Sql[l:adapter].show_tables . ';',
        \   '',
        \   "-- Describe '" . l:table . "' table's attributes.",
        \   s:Sql[l:adapter].describe . ' ' . l:table . ';',
        \   '',
        \   "-- Count records in '" . l:table . "'.",
        \   'SELECT count(1) FROM ' . l:table . ';',
        \   '',
        \   "-- List all records from the '" . l:table . "' table.",
        \   'SELECT * FROM ' . l:table . ';',
        \ ])
  let &modified = 1
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
  call mkdir(l:dir)
  return 1
endfunction

""
" Completion options for LHList, which are the keys to g:lovehandle_list.
function! lovehandle#ListCompletions(arg_lead, cmd_line, cursor_pos) abort
  if !lovehandle#Validate() | return '' | endif
  let l:copy = deepcopy(g:lovehandle_list)
  return join(map(l:copy, 'v:val[0]'), "\n")
endfunction

""
" Completions for SQL Files.
function! lovehandle#FileCompletion(arg_lead, cmd_line, cursor_pos)
  let l:dir = lovehandle#GetSQLDirectory()
  call lovehandle#CreateSQLDir(1)
  let l:list = glob(l:dir . '**/*.sql', 0, 1)
  return join(map(l:list, "substitute(v:val, l:dir, '', '')"), "\n")
endfunction

""
" Returns the sql directory.
function! lovehandle#GetSQLDirectory() abort
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
" Finds the database by 'key' in g:db list. If not found, returns the defualt.
function! lovehandle#FindDBByKey(key, use_dev_suffix, default) abort
  if !lovehandle#Validate() | return | endif
  for [l:key, l:value] in g:lovehandle_list
    if l:key ==# a:key ||
          \ (a:use_dev_suffix && l:key ==# a:key . '_' . s:GetDefaultDatabase())
      return l:value
    endif
  endfor
  return a:default
endfunction

""
" Makes sure g:lovehandle_list exists.
function! lovehandle#Validate() abort
  if exists('g:lovehandle_list') && !empty(g:lovehandle_list) | return 1 | endif
  call lovehandle#Warn('g:lovehandle_list is not set.')
  return 0
endfunction

""
" Print an error message (red).
function! lovehandle#Warn(message) abort
  echohl ErrorMsg | echomsg 'Lovehandle: ' . a:message | echohl None
endfunction

"============="
" PRIVATE API "
"============="

""
" Sources the local vimrc or user-defined file.
function! s:SourceLocalVimrc(file) abort
  if !filereadable(a:file)
    return lovehandle#Warn(a:file . " does not exist.")
  endif
  execute 'source' a:file
endfunction

""
" The adapter from URL.
function! s:GetAdapter() abort
  return split(s:GetUrl(), ':')[0]
endfunction

""
" The current value of b:db, or g:db.
function! s:GetUrl() abort
  for l:var in ['b:db', 'g:db']
    if exists(l:var) | return eval(l:var) | endif
  endfor
endfunction

""
" The current b:db, or g:db.
function! s:GetDBVar() abort
  for l:var in ['b:db', 'g:db']
    if exists(l:var) | return l:var | endif
  endfor
endfunction

function! s:GetDefaultDatabase() abort
  return get(g:, 'lovehandle_default_database', 'development')
endfunction

""
" Confirm if the user is sure they want to switch to production.
function! s:ConfirmProduction() abort
  if exists('g:lovehandle_switch_confirm_production') &&
        \ !g:lovehandle_switch_confirm_production
    return 1
  endif
  return confirm(
        \ 'PRODUCTION, ARE YOU SURE?', "&Yes\n&No\n&Cancel", 2, 'Question'
        \ )
endfunction

function! s:SetVariables(dict) abort
  if has_key(a:dict, 'list')
    let g:lovehandle_list = a:dict.list
  endif
  if has_key(a:dict, 'sql_directory')
    let g:lovehandle_sql_directory = a:dict.sql_directory
  endif
  if has_key(a:dict, 'default_database')
    let g:lovehandle_default_database = a:dict.default_database
  endif
  if has_key(a:dict, 'switch_confirm_production')
    let g:lovehandle_switch_confirm_production =
          \ a:dict.switch_confirm_production
  endif
  if has_key(a:dict, 'switch_silently')
    let g:lovehandle_switch_silentlydefault_database =
          \ a:dict.switch_silentlydefault_database
  endif
endfunction

function! s:ShouldPrintSwitchMessage() abort
  return !exists('g:lovehandle_switch_silently') || !g:lovehandle_switch_silently
endfunction
