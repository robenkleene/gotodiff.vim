setlocal foldexpr=getline(v:lnum)=~'^diff'?'>1':getline(v:lnum)=~'^@@'?'>2':'='
setlocal foldmethod=expr
setlocal foldenable

nnoremap <silent> <buffer> gd :GtdEdit<CR>
nnoremap <silent> <buffer> <C-w>d :GtdNew<CR>
nnoremap <silent> <buffer> gyd :GtdYank<CR>
nnoremap <silent> <buffer> gC :GtdCompile<CR>

command! GtdYank :call <SID>GtdYank()
function! s:GtdYank() abort
  " Will produce an error if the file is too large from the `getline(1,'$')`,
  " there's no way to suppress this error
  let l:grep = system('~/.bin/t_diff_grep '.line('.').' | tail -n1 | cut -d: -f1,2 | perl -p -e "chomp if eof"', join(getline(1,'$'), "\n"))
  let l:register=v:register
  " Use termporary buffer to force `YankTextPost` to trigger
  echom l:grep
  let @@ = l:grep
  new
  setlocal buftype=nofile bufhidden=hide noswapfile
  exe 'silent keepjumps normal! VPgg"'.l:register.'yG'
  bd!
endfunction

command! GtdEdit :call <SID>GtdEdit("edit")
command! GtdPedit :call <SID>GtdEdit("pedit")
command! GtdNew :call <SID>GtdEdit("split")
function! s:GtdEdit(cmd) abort
  " `- 1` for one line for the diff indicator gutter
  let l:destcol = col('.') - 1
  " Will produce an error if the file is too large from the `getline(1,'$')`,
  " there's no way to suppress this error
  let l:grep = system('~/.bin/t_diff_grep '.line('.').' | tail -n1 | cut -d: -f1,2', join(getline(1,'$'), "\n"))
  let l:parts = split(l:grep, ':')
  let l:destlnum = str2nr(l:parts[1])
  exec a:cmd.' '.'+call\ cursor('.l:destlnum.','.l:destcol.') '.fnameescape(l:parts[0])
endfunction

command! GtdCompile :call <SID>GtdCompile()
function! s:GtdCompile()
  cgetexpr systemlist('~/.bin/t_diff_grep +', join(getline(1,'$'), "\n"))
endfunction

function! s:DiffToGrepAtCursor() abort
  let lnum = line('.')
  let line_text = getline(lnum)

  let hunk_lnum = search('^@@\@!\|^@@', 'bnW') " first @@ above, do not move cursor
  if hunk_lnum == 0
    return ''
  endif
  let hunk = getline(hunk_lnum)

  " Capture old and new starts (and optional lengths)
  " Examples: @@ -12,7 +34,9 @@  or @@ -12 +34 @@
  let m = matchlist(hunk, '^@@\s\+-\(\d\+\)\%(,\d\+\)\?\s\+\+\(\d\+\)\%(,\d\+\)\?\s\+@@')
  if len(m) == 0
    return ''
  endif
  let old_start = str2nr(m[1])
  let new_start = str2nr(m[2])

  " Find the file paths for this hunk.
  " Prefer a/b from nearest preceding 'diff --git a/... b/...'
  let a_path = ''
  let b_path = ''
  let hdr_lnum = search('^diff --git a/.\+ b/.\+$', 'bnW')
  if hdr_lnum > 0
    let hdr = getline(hdr_lnum)
    let m2 = matchlist(hdr, '^diff --git a/\(.\{-}\)\s\+b/\(.\+\)$')
    if len(m2) >= 3
      let a_path = m2[1]
      let b_path = m2[2]
    endif
  endif

  " Fall back to ---/+++ lines if needed (git may show /dev/null)
  if b_path ==# ''
    let plus3_lnum = search('^\+\+\+ \(b/\)\?\(.*\)$', 'bnW')
    if plus3_lnum > 0
      let m3 = matchlist(getline(plus3_lnum), '^\+\+\+ \(?:b/\)\?\(.*\)$')
      if len(m3) >= 2 | let b_path = m3[1] | endif
    endif
  endif
  if a_path ==# ''
    let minus3_lnum = search('^--- \(a/\)\?\(.*\)$', 'bnW')
    if minus3_lnum > 0
      let m4 = matchlist(getline(minus3_lnum), '^--- \(?:a/\)\?\(.*\)$')
      if len(m4) >= 2 | let a_path = m4[1] | endif
    endif
  endif

  " Initialize counters at the starts given by the hunk header.
  let old_ln = old_start
  let new_ln = new_start

  " Walk the hunk from the header down to the cursor line,
  " updating old/new line counters and stop on the target.
  let i = hunk_lnum + 1
  let target_sign = ''
  let target_body = ''
  let target_lnum = 0
  while i <= lnum
    let l = getline(i)
    " context line
    if l =~# '^ '
      if i == lnum
        let target_sign = ' '
        let target_body = strpart(l, 1)
        let target_lnum = new_ln
      endif
      let old_ln += 1
      let new_ln += 1
    elseif l =~# '^\+'
      " added in new file
      if i == lnum
        let target_sign = '+'
        let target_body = strpart(l, 1)
        let target_lnum = new_ln
      endif
      let new_ln += 1
    elseif l =~# '^\-'
      " removed from old file
      if i == lnum
        let target_sign = '-'
        let target_body = strpart(l, 1)
        let target_lnum = old_ln
      endif
      let old_ln += 1
    elseif l =~# '^@@'
      " a new hunk unexpectedly before cursor; reset
      let m = matchlist(l, '^@@\s\+-\(\d\+\)\%(,\d\+\)\?\s\+\+\(\d\+\)\%(,\d\+\)\?\s\+@@')
      if len(m) >= 3
        let old_ln = str2nr(m[1])
        let new_ln = str2nr(m[2])
      endif
    endif
    let i += 1
  endwhile

  if target_sign ==# ''
    return ''
  endif

  " Choose the path to report:
  " - use new path for additions and context
  " - use old path for deletions
  let path =
        \ target_sign ==# '-' ? (a_path !=# '' ? a_path : b_path) :
        \                         (b_path !=# '' ? b_path : a_path)

  " Handle /dev/null (added or deleted files)
  if path ==# '/dev/null' || path ==# ''
    return ''
  endif

  " Build grep-style string
  return printf('%s:%d:%s', path, target_lnum, target_body)
endfunction
