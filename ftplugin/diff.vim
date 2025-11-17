setlocal foldexpr=getline(v:lnum)=~'^diff'?'>1':getline(v:lnum)=~'^@@'?'>2':'='
setlocal foldmethod=expr
setlocal foldenable

nnoremap <silent> <buffer> gd :GtdEdit<CR>
nnoremap <silent> <buffer> <C-w>d :GtdNew<CR>

command! GtdEdit :call <SID>GtdEdit("edit")
command! GtdPedit :call <SID>GtdEdit("pedit")
command! GtdNew :call <SID>GtdEdit("split")

command! GtdLoclist call <SID>GtdLoclist()
command! GtdQflist :call <SID>GtdQflist()

function! s:GtdQflist()
  let l:lines = <SID>DiffToGrepAt(v:false)
  if empty(l:lines)
    echo "No changed lines found"
    return
  endif

  let l:save_efm = &l:errorformat
  try
    setlocal errorformat=%f:%l:%m
    silent cgetexpr l:lines
  finally
    let &l:errorformat = l:save_efm
  endtry
endfunction

function! s:GtdLocation() abort
  let l:lines = <SID>DiffToGrepAt(v:false)
  if empty(l:lines)
    echo "No changed lines found"
    return
  endif

  let l:save_efm = &l:errorformat
  try
    setlocal errorformat=%f:%l:%m
    " Populate the current window's location list from the list
    silent lgetexpr l:lines
  finally
    let &l:errorformat = l:save_efm
  endtry
endfunction

function! s:GtdEdit(cmd) abort
  " `- 1` for one line for the diff indicator gutter
  let l:destcol = col('.') - 1
  " Will produce an error if the file is too large from the `getline(1,'$')`,
  " there's no way to suppress this error
  " let l:grep = system('~/.bin/t_diff_grep '.line('.').' | tail -n1 | cut -d: -f1,2', join(getline(1,'$'), "\n"))
  let l:grep = <SID>DiffToGrep(v:true)
  let l:parts = split(l:grep, ':')
  let l:destlnum = str2nr(l:parts[1])
  exec a:cmd.' '.'+call\ cursor('.l:destlnum.','.l:destcol.') '.fnameescape(l:parts[0])
endfunction

function! s:DiffToGrep(cursor_only) abort
  let cursor_lnum  = line('.')
  let cursor_grep  = ''
  let results      = []

  let a_path       = ''
  let b_path       = ''
  let old_ln       = 0
  let new_ln       = 0
  let hunk_active  = 0

  for lnum in range(1, line('$'))
    let l = getline(lnum)

    " diff --git a/... b/...
    if l =~# '^diff --git a/.\+ b/.\+$'
      let m = matchlist(l, '^diff --git a/\(.\{-}\)\s\+b/\(.\+\)$')
      if len(m) >= 3
        let a_path = m[1]
        let b_path = m[2]
      endif
      let hunk_active = 0
      continue

    " --- a/...
    elseif l =~# '^--- \(a/\)\?\(.*\)$'
      let m = matchlist(l, '^--- \(a/\)\?\(.*\)$')
      if len(m) >= 2
        let a_path = m[1]
      endif
      continue

    " +++ b/...
    elseif l =~# '^+++ \(b/\)\?\(.*\)$'
      let m = matchlist(l, '^+++ \(b/\)\?\(.*\)$')
      if len(m) >= 2
        let b_path = m[1]
      endif
      continue

    " @@ -old,+new @@
    elseif l =~# '^@@ '
      let m = matchlist(l,
            \ '^@@ \+-\(\d\+\)\%(,\d\+\)\? \+[+]\(\d\+\)\%(,\d\+\)\? \+@@')
      if len(m) >= 3
        let old_ln = str2nr(m[1])
        let new_ln = str2nr(m[2])
        let hunk_active = 1
      else
        let hunk_active = 0
      endif
      continue
    endif

    if !hunk_active
      continue
    endif

    " Inside a hunk.
    if l =~# '^ '
      " context line → only interesting for cursor mode
      if lnum == cursor_lnum
        let path = (b_path !=# '' ? b_path : a_path)
        if path !=# '' && path !=# '/dev/null'
          let text = strpart(l, 1)
          let cursor_grep = printf('%s:%d:%s', path, new_ln, text)
          if a:cursor_only
            return cursor_grep
          endif
        endif
      endif
      let old_ln += 1
      let new_ln += 1

    elseif l =~# '^+'
      " added line in new file
      let path = (b_path !=# '' ? b_path : a_path)
      if path !=# '' && path !=# '/dev/null'
        let text = strpart(l, 1)
        if !a:cursor_only
          call add(results, printf('%s:%d:%s', path, new_ln, text))
        endif
        if lnum == cursor_lnum
          let cursor_grep = printf('%s:%d:%s', path, new_ln, text)
          if a:cursor_only
            return cursor_grep
          endif
        endif
      endif
      let new_ln += 1

    elseif l =~# '^-'
      " removed line from old file
      let path = (a_path !=# '' ? a_path : b_path)
      if path !=# '' && path !=# '/dev/null'
        let text = strpart(l, 1)
        if !a:cursor_only
          call add(results, printf('%s:%d:%s', path, old_ln, text))
        endif
        if lnum == cursor_lnum
          let cursor_grep = printf('%s:%d:%s', path, old_ln, text)
          if a:cursor_only
            return cursor_grep
          endif
        endif
      endif
      let old_ln += 1
    endif
  endfor

  if a:cursor_only
    return cursor_grep
  else
    return results
  endif
endfunction
