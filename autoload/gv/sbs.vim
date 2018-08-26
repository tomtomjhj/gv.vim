function! gv#sbs#show()
    if empty(g:gv_file) | return | endif
    let s:sha = gv#sha()
    let s:gv_tab = tabpagenr()

    "get commit messages, but return if latest revision
    let s:comm_msg2 = system('git log -1 --pretty=format:%s '.s:sha)
    normal! gg
    let latest = gv#sha()
    let is_latest = s:sha == latest

    let s:comm_msg1 = system('git log -1 --pretty=format:%s '.latest)
    exe "normal! \<C-o>"
    " close gv buffer
    normal q

    "open current file in a new tab
    exe "tabedit" g:gv_file
    let synt = &ft

    "replace the real file with the HEAD revision, if not the latest revision
    if !is_latest
        exe "Git! show HEAD:".g:gv_file
        let &ft = synt
        exe "f ".s:fname(s:comm_msg1)
        call s:maps()
    endif

    "open revision in a split and set it ready for diff/scrollbind
    vsplit
    exe "normal! \<C-w>l"
    exe "Git! show ".s:sha.":".g:gv_file
    let &ft = synt
    exe "f ".s:fname(s:comm_msg2)
    diffthis
    call s:maps()
    exe "normal! \<C-w>h\<C-w>="

    if is_latest | call s:msg(1)
    else         | call s:msg() | endif
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:msg(...)
    redraw!
    if !a:0
        echohl Type   | echo "(d) diff  (e) edit  (q) close\t"
    endif
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
    let b:gv_diff = 0
    nnoremap <silent><nowait><buffer> d :call <sid>diff_toggle()<cr>
    nnoremap <silent><nowait><buffer> e :call <sid>edit()<cr>
    nnoremap <silent><nowait><buffer> q :call <sid>close()<cr>
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:diff_toggle()
    exe "normal! \<C-w>l"
    if b:gv_diff
        diffoff
        let b:gv_diff = 0
        exe "normal! \<C-w>h"
        diffoff
        let b:gv_diff = 0
    else
        diffthis
        let b:gv_diff = 1
        exe "normal! \<C-w>h"
        diffthis
        let b:gv_diff = 1
    endif
    call s:msg()
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:edit()
    exe "normal! \<C-w>h"
    exe "edit ".g:gv_file
    call s:msg(1)
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:close()
    tabclose
    exe "normal! ".s:gv_tab."gt"
endfunction

