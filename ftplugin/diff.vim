setlocal foldexpr=getline(v:lnum)=~'^diff'?'>1':getline(v:lnum)=~'^@@'?'>2':'='
setlocal foldmethod=expr
setlocal foldenable

nnoremap <silent> <buffer> gd :GtdEdit<CR>
nnoremap <silent> <buffer> <C-w>d :GtdNew<CR>
nnoremap <silent> <buffer> gC :GtdQflist<CR>
nnoremap <silent> <buffer> gL :GtdLoclist<CR>

command! GtdEdit :call <SID>GtdEdit("edit")
command! GtdPedit :call <SID>GtdEdit("pedit")
command! GtdNew :call <SID>GtdEdit("split")

command! GtdLoclist :call <SID>GtdLoclist()
command! GtdQflist :call <SID>GtdQflist()

function! s:GtdQflist()
  let l:lines = <SID>DiffToGrep(v:false)
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
  let l:lines = <SID>DiffToGrep(v:false)
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
  if empty(l:grep)
    echo "No file found on this line"
    return
  endif
  let l:parts = split(l:grep, ':')
  if len(l:parts) >= 2 && l:parts[1] !=# ''
    let l:destlnum = str2nr(l:parts[1])
    exec a:cmd.' '.'+call\ cursor('.l:destlnum.','.l:destcol.') '.fnameescape(l:parts[0])
  else
    " Just a filename, open at line 1
    exec a:cmd.' '.fnameescape(l:parts[0])
  endif
endfunction

function! s:DiffToGrep(cursor_only) abort
  let cursor_lnum  = line('.')
  let cursor_grep  = ''
  let results      = []

  let file_path    = ''
  let old_ln       = 0
  let new_ln       = 0
  let hunk_active  = 0

  for lnum in range(1, line('$'))
    let l = getline(lnum)

    " diff --git a/... b/...
    if l =~# '^diff --git a/.\+ b/.\+$'
      let m = matchlist(l, '^diff --git a/\(.\{-}\)\s\+b/\(.\+\)$')
      if len(m) >= 3
        let file_path = m[2]  " Use b_path (new file)
      else
        let file_path = ''
      endif
      let hunk_active = 0
      if lnum == cursor_lnum && a:cursor_only && file_path !=# ''
        return file_path
      endif
      continue
    endif

    " diff --cc file (combined diff header)
    if l =~# '^diff --cc '
      let m = matchlist(l, '^diff --cc \(.\+\)$')
      if len(m) >= 2
        let file_path = m[1]
      endif
      let hunk_active = 0
      if lnum == cursor_lnum && a:cursor_only && file_path !=# ''
        return file_path
      endif
      continue
    endif

    " --- a/...   (only when not inside a hunk)
    " `\s*$` strips trailing tabs that `git diff` can append after filenames
    if !hunk_active && l =~# '^--- '
      let m = matchlist(l, '^--- \%(a/\)\?\(.\{-}\)\s*$')
      if len(m) >= 2 && file_path ==# ''
        let file_path = m[1]
      endif
      if lnum == cursor_lnum && a:cursor_only
        if file_path !=# '' && file_path !=# '/dev/null'
          return file_path
        endif
      endif
      continue
    endif

    " +++ b/...   (only when not inside a hunk)
    " `\s*$` strips trailing tabs that `git diff` can append after filenames
    if !hunk_active && l =~# '^+++ '
      let m = matchlist(l, '^+++ \%(b/\)\?\(.\{-}\)\s*$')
      if len(m) >= 2
        let file_path = m[1]  " Prefer b_path (new file)
      endif
      if lnum == cursor_lnum && a:cursor_only
        if file_path !=# '' && file_path !=# '/dev/null'
          return file_path
        endif
      endif
      continue
    endif

    " @@ -old,+new @@ or @@@ -old1 -old2 +new @@@ (combined diff)
    if l =~# '^@@@\? '
      let m_regular = matchlist(l, '^@@ -\(\d\+\)\%(,\d\+\)\? +\(\d\+\)\%(,\d\+\)\? @@')
      let m_combined = matchlist(l, '^@@@ -\d\+\%(,\d\+\)\? -\d\+\%(,\d\+\)\? +\(\d\+\)\%(,\d\+\)\? @@@')
      if len(m_regular) >= 3
        let old_ln = str2nr(m_regular[1])
        let new_ln = str2nr(m_regular[2])
        let hunk_active = 1
      elseif len(m_combined) >= 2
        let old_ln = str2nr(m_combined[1])
        let new_ln = str2nr(m_combined[1])
        let hunk_active = 1
      else
        let hunk_active = 0
      endif
      if lnum == cursor_lnum && a:cursor_only
        if file_path !=# '' && file_path !=# '/dev/null' && hunk_active
          return printf('%s:%d:', file_path, new_ln)
        endif
      endif
      continue
    endif

    if !hunk_active
      " Not inside a hunk - fallback to file_path if available
      if lnum == cursor_lnum && a:cursor_only && file_path !=# '' && file_path !=# '/dev/null'
        return file_path
      endif
      continue
    endif

    " Ignore the special marker line inside hunks.
    if l =~# '^\\ No newline at end of file'
      continue
    endif

    " ---------- inside a hunk ----------
    " Handle both regular diff and combined diff formats
    " Combined diff uses multiple prefix chars (++, +-, etc.)
    let first_char = strpart(l, 0, 1)
    let second_char = strpart(l, 1, 1)
    
    " Context line: space in regular diff, or space+space in combined diff
    if first_char ==# ' ' || (first_char ==# ' ' && second_char ==# ' ')
      " context
      if lnum == cursor_lnum
        if file_path !=# '' && file_path !=# '/dev/null'
          let text = strpart(l, 1)
          let cursor_grep = printf('%s:%d:%s', file_path, new_ln, text)
          if a:cursor_only
            return cursor_grep
          endif
        endif
      endif
      let old_ln += 1
      let new_ln += 1

    elseif first_char ==# '+'
      " added line in new file (both regular + and combined ++)
      if file_path !=# '' && file_path !=# '/dev/null'
        " Strip all leading + characters for combined diffs
        let text = substitute(l, '^+\+', '', '')
        if !a:cursor_only
          call add(results, printf('%s:%d:%s', file_path, new_ln, text))
        endif
        if lnum == cursor_lnum
          let cursor_grep = printf('%s:%d:%s', file_path, new_ln, text)
          if a:cursor_only
            return cursor_grep
          endif
        endif
      endif
      let new_ln += 1

    elseif first_char ==# '-'
      " removed line from old file (both regular - and combined --)
      if file_path !=# '' && file_path !=# '/dev/null'
        " Strip all leading - characters for combined diffs
        let text = substitute(l, '^-\+', '', '')
        " Don't add deleted lines to results for quickfix/location list
        if lnum == cursor_lnum
          let cursor_grep = printf('%s:%d:%s', file_path, old_ln, text)
          if a:cursor_only
            return cursor_grep
          endif
        endif
      endif
      let old_ln += 1
    endif
  endfor

  return a:cursor_only ? cursor_grep : results
endfunction
