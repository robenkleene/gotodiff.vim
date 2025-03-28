# Goto Diff

Missing script `t_diff_grep`.

## Complementary Customizations

`gotodiff.vim` lets `diff` buffers to be used similar to other buffers that are using primary for navigation like `netrw` buffers and the `quickfix` list. These additional customizations aren't enabled by default (because they might disrupt some workflows), but might be useful:

`ftplugin/diff.vim`:
```
setlocal readonly nomodifiable
setlocal foldlevel=2

" Matches `netrw` `p` to preview file
nnoremap <silent> <buffer> p :GtdPedit<CR>
nnoremap <silent> <buffer> <CR> :GtdEdit<CR>
```

Additionally, for transient diffs, e.g., `git diff | vim -`, this will prevent needing to force quit (`:qa!`), but although be cautious about this because this removes prompting for all transient buffers, not just diff buffers:

```
augroup nofilename_nofile
  autocmd!
  " Don't prompt for saving buffers with no file
  autocmd BufEnter * if eval('@%') == '' && &buftype == '' | setlocal buftype=nofile | end
augroup END
```
