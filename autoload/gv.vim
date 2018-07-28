function! gv#tilde()
    if !exists('g:loaded_gitgutter')
        call s:warn('GitGutter not loaded.')
        return
    endif
    let sha = gv#sha()
    let g:gitgutter_diff_base = sha
    GitGutter
    call s:warn('GitGutter diff base set to commit '.sha)
endfunction

function! gv#folds(down)
    if len(tabpagebuflist()) == 1
        normal o
    endif
    wincmd l
    if a:down
        if foldlevel('.') > 0 | normal! zczj
        else                  | normal! zj
        endif                 | normal! zo
    else
        if foldlevel('.') > 0 | normal! zczkzkzj
        else                  | normal! zkzkzj
        endif                 | normal! zo[z
    endif
    wincmd h
    exe "normal! z\<cr>"
endfunction

function! s:warn(message)
  echohl WarningMsg | echom a:message | echohl None
endfunction

