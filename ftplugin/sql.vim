let s:lovehandle_sql_directory = lovehandle#GetSQLDirectory()
let s:dir_name = fnamemodify(resolve(expand('%:p')), ':h') . '/'

if match(s:dir_name, s:lovehandle_sql_directory) >= 0
  if !exists('g:lovehandle_list')
    call lovehandle#Warn("g:lovehandle_list not set. Can't set URL.")
  else
    if !isdirectory(s:dir_name) | call mkdir(s:dir_name, 'p') | endif
    let b:db = lovehandle#FindDBByKey(split(s:dir_name, '/')[-1], 1, g:db)
    if getfsize(@%) <= 0 | call lovehandle#GenerateSQL(1) | endif
  endif
endif
