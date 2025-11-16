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
