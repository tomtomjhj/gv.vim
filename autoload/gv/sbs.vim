function! gv#sbs#show()
    if empty(g:gv_file) | return | endif
    let s:sha = gv#sha()
    let gv_tab = tabpagenr() - 1

    "get commit message
    let s:comm_msg = system('git log -1 --pretty=format:%s '.s:sha)

    "open current file in a new tab
    exe gv_tab."tabedit" g:gv_file
    silent! let g:xtabline.Tabs[gv_tab].locked = 1
    silent! let g:xtabline.Tabs[gv_tab].buffers.valid = [bufnr('%')]
    let ft = &ft
    diffthis

    "open also other revisions
    0Glog
    buffer #

    "open revision in a split and set it ready for diff/scrollbind
    vsplit
    wincmd l
    exe "Git! show ".s:sha.":".g:gv_file
    setlocal bt=nofile bh=wipe noswf nobl noma
    let &ft = ft
    diffthis
    let b:XTbuf = {'name': 'Revision', 'icon': ''}
    autocmd BufEnter <buffer> call s:msg()
    exe "normal! \<C-w>h\<C-w>=<C-l>"
    call s:msg()
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:msg(...)
    redraw!
    echohl Label      | echon g:gv_file."\t"
    echohl WarningMsg | echon s:sha
    echohl Special    | echon "\t".s:comm_msg
    echohl None
endfunction

