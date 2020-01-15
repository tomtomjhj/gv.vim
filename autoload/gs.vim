let s:begin = '^[^0-9]*[0-9]\{4}-[0-9]\{2}-[0-9]\{2}\s\+'

"------------------------------------------------------------------------------
" Setup {{{1
"------------------------------------------------------------------------------

function! gs#sha(...)
  return matchstr(get(a:000, 0, getline('.')), s:begin.'\zs[a-f0-9]\+')
endfunction

function! gs#start(bang) abort
  if !exists('g:loaded_fugitive')
    return s:gs_warn('fugitive not found')
  endif

  let git_dir = s:git_dir()
  if empty(git_dir)
    return s:gs_warn('not in git repo')
  endif

  let fugitive_repo = fugitive#repo(git_dir)
  let cd = exists('*haslocaldir') && haslocaldir() ? 'lcd' : 'cd'
  let cwd = getcwd()
  let root = fugitive_repo.tree()
  try
    if cwd !=# root
      execute cd escape(root, ' ')
    endif
    let cmd = system('git stash list --date=short '.shellescape('--format=%cd %h %s (%an)'))
    if empty(cmd)
      return s:gs_warn("No stashes for this repo")
    endif
    call s:gs_setup(git_dir)
    call s:gs_list(fugitive_repo, cmd)
    call fugitive#detect(@#)
  catch
    return s:gs_warn(v:exception)
  finally
    if getcwd() !=# cwd
      cd -
    endif
  endtry
endfunction

"------------------------------------------------------------------------------

function! s:gs_setup(git_dir)
  call s:gs_tabnew()
  call s:gs_scratch()
  let b:git_dir = a:git_dir
endfunction

function! s:gs_list(fugitive_repo, cmd)
  let repo_short_name = fnamemodify(substitute(a:fugitive_repo.dir(), '[\\/]\.git[\\/]\?$', '', ''), ':t')
  let bufname = repo_short_name.' Stashes'
  silent exe (bufexists(bufname) ? 'buffer' : 'file') fnameescape(bufname)

  call s:gs_fill(a:cmd)
  setlocal nowrap tabstop=8 cursorline iskeyword+=#

  " if !exists(':Gbrowse')
  "   doautocmd <nomodeline> User Fugitive
  " endif
  call s:gs_maps()
  call s:gs_syntax()
  redraw
  echo 'o: open split / O: open tab / D: drop / A: apply / P: pop / q: quit'
endfunction

"------------------------------------------------------------------------------

function! s:gs_split(tab)
  if a:tab
    call s:gs_tabnew()
  elseif getwinvar(winnr('$'), 'gv_stash_diff', 0)
    $wincmd w
    enew
  else
    vertical botright new
  endif
  let w:gv_stash_diff = 1
endfunction


"------------------------------------------------------------------------------
" Buffers {{{1
"------------------------------------------------------------------------------

function! s:gs_scratch()
  setlocal buftype=nofile bufhidden=wipe noswapfile
endfunction

function! s:gs_fill(cmd)
  setlocal modifiable
  silent put = a:cmd
  normal! gg"_dd
  setlocal nomodifiable
endfunction

function! s:gs_syntax()
  setf GV
  syn clear
  syn match gvInfo    /^[^0-9]*\zs[0-9-]\+\s\+[a-f0-9]\+ / contains=gvDate,gvSha nextgroup=gvBranch,gvMeta
  syn match gvDate    /\S\+ / contained
  syn match gvSha     /[a-f0-9]\{6,}/ contained
  syn match gvMessage /.* \ze(.\{-})$/ contained contains=gvBranch nextgroup=gvAuthor
  syn match gvAuthor  /.*$/ contained
  syn match gvMeta    /([^)]\+) / contained nextgroup=gvMessage
  syn match gvBranch  /On .*:/ nextgroup=gvMessage
  hi def link gvDate   Number
  hi def link gvSha    Identifier
  hi def link gvBranch Label
  hi def link gvMeta   Conditional
  hi def link gvAuthor String

  syn match gvAdded     "^\W*\zsA\t.*"
  syn match gvDeleted   "^\W*\zsD\t.*"
  hi def link gvAdded    diffAdded
  hi def link gvDeleted  diffRemoved

  syn match diffAdded   "^+.*"
  syn match diffRemoved "^-.*"
  syn match diffLine    "^@.*"
  syn match diffFile    "^diff\>.*"
  syn match diffFile    "^+++ .*"
  syn match diffNewFile "^--- .*"
  hi def link diffFile    Type
  hi def link diffNewFile diffFile
  hi def link diffAdded   Identifier
  hi def link diffRemoved Special
  hi def link diffFile    Type
  hi def link diffLine    Statement
endfunction

function! s:gs_maps()
  nnoremap <silent> <nowait> <buffer>        q          :$wincmd l <bar> bdelete!<cr>
  nnoremap <silent> <nowait> <buffer>        <leader>q  :$wincmd l <bar> bdelete!<cr>
  nnoremap <silent> <nowait> <buffer>        <tab>      <c-w><c-w>
  nnoremap <silent> <nowait> <buffer>        <cr>       :call <sid>open()<cr>
  nnoremap <silent> <nowait> <buffer>        o          :call <sid>open()<cr>
  nnoremap <silent> <nowait> <buffer>        O          :call <sid>open(1)<cr>
  nnoremap <silent> <nowait> <buffer>        D          :call <sid>do('drop')<cr>
  nnoremap <silent> <nowait> <buffer>        P          :call <sid>do('pop')<cr>
  nnoremap <silent> <nowait> <buffer>        A          :call <sid>do('apply')<cr>
  nnoremap <silent> <nowait> <buffer>        B          :call <sid>to_branch()<cr>
  nnoremap <silent> <nowait> <buffer>        [          :<c-u>call <sid>folds(0)<cr>
  nnoremap <silent> <nowait> <buffer>        ]          :<c-u>call <sid>folds(1)<cr>
endfunction

"------------------------------------------------------------------------------
" Git {{{1
"------------------------------------------------------------------------------

function! s:git_dir()
  if empty(get(b:, 'git_dir', ''))
    return fugitive#extract_git_dir(expand('%:p'))
  endif
  return b:git_dir
endfunction

"------------------------------------------------------------------------------
" Actions {{{1
"------------------------------------------------------------------------------

function! s:gs_open(...)
  let sha = gs#sha()
  if empty(sha)
    return s:gs_shrug()
  endif

  call s:gs_split(a:0)
  call s:gs_scratch()
  silent put = system('git stash show '.sha)
  call append("$", '')
  normal! <ipG
  call s:gs_fill(system('git stash show -p '.sha))
  setf git
  set foldmethod=syntax
  normal! zm
  nnoremap <silent> <nowait> <buffer>        q          :$wincmd w <bar> bdelete!<cr>
  nnoremap <silent> <nowait> <buffer>        <leader>q  :$wincmd w <bar> bdelete!<cr>
  nnoremap <silent> <nowait> <buffer>        <tab>      <c-w><c-w>
  nnoremap <silent> <nowait> <buffer>        [          :<c-u>call <sid>folds(0)<cr>
  nnoremap <silent> <nowait> <buffer>        ]          :<c-u>call <sid>folds(1)<cr>
  let bang = a:0 ? '!' : ''
  if exists('#User#GV'.bang)
    execute 'doautocmd <nomodeline> User GV'.bang
  endif
  wincmd p
  echo
endfunction

function! <sid>folds(down)
  let diffwin = exists('w:gv_stash_diff')
  if !diffwin
    if len(tabpagebuflist()) == 1 | return | endif
    wincmd l
  endif
  if a:down | silent! normal! zczjzo[z
  else      | silent! normal! zczkzo[z
  endif
  silent! exe "normal! z\<cr>"
  if !diffwin | wincmd h | endif
endfunction

function! s:gs_do(action)
  let sha = gs#sha()
  if s:gs_confirm(a:action, sha)
    call s:gs_system(a:action, sha)
    if a:action != 'apply'
      call s:gs_quit()
    endif
  endif
endfunction

function! s:gs_to_branch()
  let msg = 'Do you want to create a branch from the stash ' . gs#sha() . '?'
  if confirm(msg, "&Yes\n&No", 2) == 1
    let name = input('New branch name? ')
    if empty(name) | return | endif
    call s:gs_system('branch', name)
    call s:gs_quit()
  endif
endfunction

"------------------------------------------------------------------------------
" Helpers {{{1
"------------------------------------------------------------------------------

function! s:gs_warn(message)
  echohl WarningMsg | echom a:message | echohl None
endfunction

function! s:gs_shrug()
  call s:gs_warn('¯\_(ツ)_/¯')
endfunction

function! s:gs_tabnew()
  execute (tabpagenr()-1).'tabnew'
endfunction

function! s:gs_confirm(cmd, sha)
  let msg = 'Do you want to ' . a:cmd . ' the stash ' . a:sha
  return confirm(msg, "&Yes\n&No", 2) == 1
endfunction

fun! s:gs_system(cmd, sha)
  echo "\n\n"
  e | echon system("git stash " . a:cmd . " " . a:sha)
endfun

fun! s:gs_quit()
  if len(tabpagebuflist()) == 1 && !exists('w:gv_stash_diff')
    normal q
  else
    normal qq
  endif
endfun
