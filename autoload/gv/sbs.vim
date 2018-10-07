function! gv#sbs#show()
    if empty(g:gv_file) | return | endif
    let s:sha = gv#sha()
    let s:gv_tab = tabpagenr()

    "get commit messages
    let s:comm_msg2 = system('git log -1 --pretty=format:%s '.s:sha)
    normal! gg
    let latest = gv#sha()

    let s:comm_msg1 = system('git log -1 --pretty=format:%s '.latest)
    exe "normal! \<C-o>"
    " close gv buffer
    normal q

    "open current file in a new tab
    silent! let g:xtabline.Vars.tab_properties = {'locked': 1}
    exe "tabedit" g:gv_file
    let synt = &ft

    "open revision in a split and set it ready for diff/scrollbind
    vsplit
    exe "normal! \<C-w>l"
    exe "Git! show ".s:sha.":".g:gv_file
    let &ft = synt
    exe "f ".s:fname(s:comm_msg2)
    let b:XTbuf = {'name': 'Revision', 'icon': ''}
    autocmd BufEnter <buffer> call s:msg()
    diffthis
    call s:maps()
    exe "normal! \<C-w>h\<C-w>="
    call s:msg()
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:msg(...)
    redraw!
    echohl Label      | echon g:gv_file."\t"
    echohl WarningMsg | echon s:sha
    echohl Special    | echon "\t".s:comm_msg2
    echohl None
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:fname(n)
    " replace '/' with unicode symbol U+2044
    return fnameescape(substitute(a:n, '/', '⁄', 'g'))
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:maps()
    set scrollbind
    nnoremap <silent><nowait><buffer> q :call <sid>close()<cr>
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:close()
    tabclose
    exe "normal! ".s:gv_tab."gt"
endfunction

