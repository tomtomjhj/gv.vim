let s:begin = '^[^0-9]*[0-9]\{4}-[0-9]\{2}-[0-9]\{2}\s\+'

"------------------------------------------------------------------------------
" Setup
"------------------------------------------------------------------------------

function! gv#sha(...)
  " Commit sha at current line {{{1
  return matchstr(get(a:000, 0, getline('.')), s:begin.'\zs[a-f0-9]\+')
endfunction "}}}

function! gv#start(bang, visual, line1, line2, args) abort
  " Start the command {{{1
  if !exists('g:loaded_fugitive')
    return s:warn('fugitive not found')
  endif

  let git_dir = FugitiveGitDir()
  if empty(git_dir)
    return s:warn('not in git repo')
  endif

  let fugitive_repo = fugitive#repo(git_dir)
  let root = fugitive_repo.tree()
  try
    if getcwd() !=# root
      execute 'lcd' escape(root, ' ')
    endif
    if a:args =~ '?$'
      if len(a:args) > 1
        return s:warn('invalid arguments')
      endif
      call s:check_buffer(fugitive_repo, expand('%'))
      call s:to_location_list(bufnr(''), a:visual)
    else
      let log_opts = extend(s:shellwords(a:args), s:log_opts(fugitive_repo, a:bang, a:visual, a:line1, a:line2))
      call s:setup(git_dir, fugitive_repo.config('remote.origin.url'))
      call s:create_gv_buffer(fugitive_repo, log_opts)
      call FugitiveDetect(@#)
    endif
  catch
    return s:warn(v:exception)
  endtry
endfunction "}}}



"------------------------------------------------------------------------------
" GV? command (current buffer to location list)
"------------------------------------------------------------------------------

function! s:to_location_list(buf, visual)
  " Load commits affecting current file in location list {{{1
  if !exists(':Gllog')
    return
  endif
  -1tab split
  silent execute a:visual ? "'<,'>" : "" 'Gllog'
  call setloclist(0, insert(getloclist(0), {'bufnr': a:buf}, 0))
  noautocmd b #
  lopen
  xnoremap <buffer> o :call <sid>gld()<cr>
  nnoremap <buffer> o <cr><c-w><c-w>
  nnoremap <buffer> O :call <sid>gld()<cr>
  nnoremap <buffer> q :tabclose<cr>
  nnoremap <buffer> gq :tabclose<cr>
  call matchadd('Conceal', '^fugitive://.\{-}\.git//')
  call matchadd('Conceal', '^fugitive://.\{-}\.git//\x\{7}\zs.\{-}||')
  setlocal concealcursor=nv conceallevel=3 nowrap
  let w:quickfix_title = 'o: open / o (in visual): diff / O: open (tab) / q: quit'
endfunction "}}}

function! s:gld() range
  " Open revision(s) in new tab, with diff if run from visual mode {{{1
  let [to, from] = map([a:firstline, a:lastline], 'split(getline(v:val), "|")[0]')
  let fn = split(getline(1), '|')[0]
  execute (tabpagenr()-1).'Gtabedit' escape(to, ' ') . ':' . escape(fn, ' ')
  if from !=# to
    execute 'Gvsplit' escape(from, ' ') . ':' . escape(fn, ' ')
    windo diffthis
  endif
endfunction "}}}



"------------------------------------------------------------------------------
" GV command
"------------------------------------------------------------------------------

function! s:setup(git_dir, git_origin) "{{{1
  call s:tabnew()
  call s:scratch()

  if exists('g:fugitive_github_domains')
    let domain = join(map(extend(['github.com'], g:fugitive_github_domains),
          \ 'escape(substitute(split(v:val, "://")[-1], "/*$", "", ""), ".")'), '\|')
  else
    let domain = '.*github.\+'
  endif
  " https://  github.com  /  junegunn/gv.vim  .git
  " git@      github.com  :  junegunn/gv.vim  .git
  let pat = '^\(https\?://\|git@\)\('.domain.'\)[:/]\([^@:/]\+/[^@:/]\{-}\)\%(.git\)\?$'
  let origin = matchlist(a:git_origin, pat)
  if !empty(origin)
    let scheme = origin[1] =~ '^http' ? origin[1] : 'https://'
    let b:git_origin = printf('%s%s/%s', scheme, origin[2], origin[3])
  endif
  let b:git_dir = a:git_dir
endfunction

function! s:create_gv_buffer(fugitive_repo, log_opts) "{{{1
  let default_opts = ['--color=never', '--date=short', '--format=%cd %h%d %s (%an)']
  let git_args = ['log'] + default_opts + a:log_opts
  let git_log_cmd = call(a:fugitive_repo.git_command, git_args, a:fugitive_repo)

  let repo_short_name = fnamemodify(substitute(a:fugitive_repo.dir(), '[\\/]\.git[\\/]\?$', '', ''), ':t')
  let bufname = repo_short_name.' '.join(a:log_opts)
  silent exe (bufexists(bufname) ? 'buffer' : 'file') fnameescape(bufname)

  call s:fill(git_log_cmd)
  setlocal nowrap tabstop=8 cursorline iskeyword+=#
  let s:windows = {'diff': 0, 'summary': 0}

  if !exists(':GBrowse')
    doautocmd <nomodeline> User Fugitive
  endif
  call s:maps(git_log_cmd)
  call s:syntax()
  call s:cmdline_help()
endfunction

function! s:cmdline_help() "{{{1
  redraw
  if exists('g:gv_file')
    nnoremap <silent> <buffer> <nowait> d :-1Gtabedit <C-r>=gv#sha()<CR>:<C-r>=gv_file<CR><cr>:vsplit <C-r>=gv_file<CR><CR>:windo diffthis<cr><C-w>p
    nnoremap <silent> <buffer> <nowait> s :set lz<cr>:Gvsplit <C-r>=gv#sha()<CR>:<C-r>=gv_file<CR><cr><C-w>L:set nolz<cr>
    nnoremap <silent> <buffer> <nowait> S :-1Gtabedit <C-r>=gv#sha()<CR>:<C-r>=gv_file<CR><cr><C-w>L
    nnoremap <silent> <buffer> <nowait> L :call <sid>to_location_list(bufnr(gv_file), 0)<cr><cr>
    echohl Label | echo g:gv_file."\t"
    echohl None  | echon 'o: open split / O: open tab / s: show revision / S: to tab / d: diff / L: GV? / q: quit / g?: help'
  else
    echo 'o: open split / O: open tab / q: quit / g?: help'
  endif
endfunction

function! s:open(visual, ...) "{{{1
  let [type, target] = s:type(a:visual)

  if empty(type)
    return s:shrug()
  elseif type == 'link'
    return s:browse(target)
  endif

  call s:split(a:0)
  call s:scratch()
  if type == 'commit'
    execute 'e' escape(target, ' ')
    nnoremap <silent> <buffer> gb :GBrowse<cr>
  elseif type == 'diff'
    call s:fill(target)
    setfiletype diff
  endif
  nnoremap <silent> <nowait> <buffer>        q          :call <sid>quit()<cr>
  nnoremap <silent> <nowait> <buffer>        <leader>q  :call <sid>quit()<cr>
  nnoremap <silent> <nowait> <buffer>        <tab>      <c-w><c-h>
  nnoremap <silent> <nowait> <buffer>        [          :<c-u>call <sid>folds(0)<cr>
  nnoremap <silent> <nowait> <buffer>        ]          :<c-u>call <sid>folds(1)<cr>
  let bang = a:0 ? '!' : ''
  if exists('#User#GV'.bang)
    execute 'doautocmd <nomodeline> User GV'.bang
  endif
  wincmd p
  let s:windows.diff = line('.')
  echo
  if s:windows.summary
    call s:show_summary(0, 0)
  endif
endfunction "}}}

"------------------------------------------------------------------------------
" Create buffers
"------------------------------------------------------------------------------

function! s:scratch() "{{{1
  setlocal buftype=nofile bufhidden=wipe noswapfile nomodeline
endfunction

function! s:fill(cmd, ...) "{{{1
  setlocal modifiable
  if a:0 | %d_ | endif
  silent execute 'read' escape('!'.a:cmd, '%')
  1d_
  setlocal nomodifiable
  if a:0 | call s:cmdline_help() | endif
endfunction

function! s:syntax() "{{{1
  setf GV
  syn clear
  syn match gvInfo    /^[^0-9]*\zs[0-9-]\+\s\+[a-f0-9]\+ / contains=gvDate,gvSha nextgroup=gvMessage,gvMeta
  syn match gvDate    /\S\+ / contained
  syn match gvSha     /[a-f0-9]\{6,}/ contained
  syn match gvMessage /.* \ze(.\{-})$/ contained contains=gvTag,gvGitHub,gvJira nextgroup=gvAuthor
  syn match gvAuthor  /.*$/ contained
  syn match gvMeta    /([^)]\+) / contained contains=gvTag nextgroup=gvMessage
  syn match gvTag     /(tag:[^)]\+)/ contained
  syn match gvGitHub  /\<#[0-9]\+\>/ contained
  syn match gvJira    /\<[A-Z]\+-[0-9]\+\>/ contained
  hi def link gvDate   Number
  hi def link gvSha    Identifier
  hi def link gvTag    Constant
  hi def link gvGitHub Label
  hi def link gvJira   Label
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

function! s:maps(cmd) "{{{1
  nnoremap <silent> <nowait> <buffer>        q          :call <sid>quit()<cr>
  nnoremap <silent> <nowait> <buffer>        <leader>q  :call <sid>quit()<cr>
  nnoremap <silent> <nowait> <buffer>        <tab>      <c-w><c-l>
  nnoremap <silent> <nowait> <buffer>        gb         :call <sid>gbrowse()<cr>
  nnoremap <silent> <nowait> <buffer>        <cr>       :call <sid>open(0)<cr>
  nnoremap <silent> <nowait> <buffer>        o          :call <sid>open(0)<cr>
  nnoremap <silent> <nowait> <buffer>        O          :call <sid>open(0, 1)<cr>
  xnoremap <silent> <nowait> <buffer>        <cr>       :<c-u>call <sid>open(1)<cr>
  xnoremap <silent> <nowait> <buffer>        o          :<c-u>call <sid>open(1)<cr>
  xnoremap <silent> <nowait> <buffer>        O          :<c-u>call <sid>open(1, 1)<cr>
  nnoremap          <nowait> <buffer> <expr> .          <sid>dot()
  nnoremap          <nowait> <buffer> <expr> R          <sid>rebase()
  nnoremap          <nowait> <buffer> <expr> ~          <sid>tilde()
  nnoremap <silent> <nowait> <buffer> <expr> j          <sid>move('')
  nnoremap <silent> <nowait> <buffer> <expr> k          <sid>move('b')
  nnoremap <silent> <nowait> <buffer>        [          :<c-u>call <sid>folds(0)<cr>
  nnoremap <silent> <nowait> <buffer>        ]          :<c-u>call <sid>folds(1)<cr>
  nnoremap <silent> <nowait> <buffer>        yy         0WW"+ye:echo 'sha' gv#sha() 'copied'<cr>
  nnoremap <silent> <nowait> <buffer>        I          :<c-u>call <sid>show_summary(1, 0)<cr>
  nnoremap <silent> <nowait> <buffer>        i          :<c-u>call <sid>show_summary(0, 1)<cr>
  nnoremap <silent> <nowait> <buffer>        g?         :<c-u>call <sid>show_help()<cr>

  nmap              <nowait> <buffer> <C-n> jo
  nmap              <nowait> <buffer> <C-p> ko
  xmap              <nowait> <buffer> <C-n> ]ogv
  xmap              <nowait> <buffer> <C-p> [ogv

  exe 'nnoremap <silent><buffer> r :<c-u>call <sid>fill('. string(a:cmd) .', 1)<cr>'
endfunction "}}}

"------------------------------------------------------------------------------
" Git helpers
"------------------------------------------------------------------------------

function! s:is_tracked(fugitive_repo, file) "{{{1
  call system(a:fugitive_repo.git_command('ls-files', '--error-unmatch', a:file))
  return !v:shell_error
endfunction

function! s:check_buffer(fugitive_repo, current) "{{{1
  if empty(a:current)
    throw 'untracked buffer'
  elseif !s:is_tracked(a:fugitive_repo, a:current)
    throw a:current.' is untracked'
  endif
endfunction "}}}

"------------------------------------------------------------------------------
" Actions
"------------------------------------------------------------------------------

function! s:gbrowse() "{{{1
  let sha = gv#sha()
  if empty(sha)
    return s:shrug()
  endif
  execute 'GBrowse' sha
endfunction

function! s:dot() "{{{1
  let sha = gv#sha()
  return empty(sha) ? '' : ':Git  '.sha."\<s-left>\<left>"
endfunction

function! s:rebase() "{{{1
  let sha = gv#sha()
  return empty(sha) ? '' : ':Git rebase -i '.sha."\<s-left>\<left>"
endfunction

function! s:tilde() "{{{1
  if !exists('g:loaded_gitgutter')
    call s:warn('GitGutter not loaded.')
    return
  endif
  let sha = gv#sha()
  let g:gitgutter_diff_base = sha
  GitGutter
  call s:warn('GitGutter diff base set to commit '.sha)
endfunction

function! s:show_summary(diff, toggle) "{{{1
  if a:diff
    if s:windows.diff
      call s:quit()
    endif
    normal o]
  endif
  if s:windows.summary
    pclose!
    if a:toggle
      return
    endif
  endif
  let sha = gv#sha()
  let changes = systemlist('git log --stat -1 '.sha)
  let n = len(changes)
  exe n.'new'
  setlocal bt=nofile bh=wipe noswf nobl
  silent put =changes
  1d _
  setfiletype git
  set previewwindow
  let s:windows.summary = 1
  let b:sha = sha
  nnoremap <buffer><nowait><silent> q     :pclose!<cr>
  nmap     <buffer><nowait><silent> <tab> <c-w><c-w>
  au BufUnload <buffer> let s:windows.summary = 0
  1wincmd w
endfunction

function! s:show_help() abort "{{{1
  echo 'q'     . "\t\tquit"
  echo 'r'     . "\t\trefresh"
  echo '<tab>' . "\t\tchange window"
  echo '<cr>'  . "\t\tshow diff panel"
  echo 'o'     . "\t\tshow diff panel"
  echo 'O'     . "\t\topen diff in new tab"
  echo '.'     . "\t\t:Git | sha"
  echo 'R'     . "\t\t:Git rebase -i| sha"
  echo '~'     . "\t\tset gitgutter_diff_base to commit"
  echo '['     . "\t\tprevious fold in side window"
  echo ']'     . "\t\tnext fold in side window"
  echo 'yy'    . "\t\tcopy commit hash"
  if exists('g:gv_file')
    echo 's'   . "\t\tshow revision"
    echo 'S'   . "\t\tshow revision in new tab"
    echo 'd'   . "\t\tdiff with file at HEAD"
    echo 'L'   . "\t\tdiff with file at HEAD (all commits in location list)"
  endif
  echo 'i'     . "\t\tshow info panel"
  echo 'I'     . "\t\tshow info and diff panels"
  echo 'gb'    . "\t\tGbrowse"
  echo '<C-n>' . "\t\topen next"
  echo '<C-p>' . "\t\topen previous"
  echo '<cr>'  . "\t\t[V] open"
  echo 'o'     . "\t\t[V] open"
  echo 'O'     . "\t\t[V] open in new tab"
endfunction

function! s:folds(down) "{{{1
  let was_diff_win = s:windows.diff && winnr() == winnr('$')
  if !s:windows.diff || !was_diff_win && s:windows.diff != line('.')
    1wincmd w
    normal o
  endif
  $wincmd w
  if &fdm != 'syntax'
    setl fdm=syntax
  endif
  if a:down
    silent! normal! zczjzo[z
  else
    silent! normal! zczkzo[z
  endif
  silent! exe "normal! z\<cr>"
  if !was_diff_win
    1wincmd w
  endif
endfunction "}}}

"------------------------------------------------------------------------------
" Helpers
"------------------------------------------------------------------------------

function! s:warn(message) "{{{1
  echohl WarningMsg | echom a:message | echohl None
endfunction

function! s:shrug() "{{{1
  call s:warn('¯\_(ツ)_/¯')
endfunction

function! s:quit() "{{{1
  if s:windows.summary
    pclose!
    let s:windows.summary = 0

  elseif s:windows.diff
    $wincmd w
    bdelete!
    let s:windows.diff = 0

  elseif winnr() == 1 && winnr('$') > 1
    $wincmd w
    bdelete!

  else
    bdelete!

  endif
endfunction

function! s:move(flag) "{{{1
  let [l, c] = searchpos(s:begin, a:flag)
  return l ? printf('%dG%d|', l, c) : ''
endfunction

function! s:browse(url) "{{{1
  call netrw#BrowseX(b:git_origin.a:url, 0)
endfunction

function! s:tabnew() "{{{1
  execute (tabpagenr()-1).'tabnew'
endfunction

function! s:shellwords(arg) "{{{1
  let words = []
  let contd = 0
  for token in split(a:arg, '\%(\%(''\%([^'']\|''''\)\+''\)\|\%("\%(\\"\|[^"]\)\+"\)\|\%(\%(\\ \|\S\)\+\)\)\s*\zs')
    let trimmed = s:trim(token)
    if contd
      let words[-1] .= trimmed
    else
      call add(words, trimmed)
    endif
    let contd = token !~ '\s\+$'
  endfor
  return words
endfunction

function! s:trim(arg) "{{{1
  let arg = substitute(a:arg, '\s*$', '', '')
  return arg =~ "^'.*'$" ? substitute(arg[1:-2], "''", '', 'g')
        \ : arg =~ '^".*"$' ? substitute(substitute(arg[1:-2], '""', '', 'g'), '\\"', '"', 'g')
        \ : substitute(substitute(arg, '""\|''''', '', 'g'), '\\ ', ' ', 'g')
endfunction

function! s:log_opts(fugitive_repo, bang, visual, line1, line2) "{{{1
  if a:visual || a:bang
    let g:gv_file = expand('%')
    call s:check_buffer(a:fugitive_repo, g:gv_file)
    return a:visual ? [printf('-L%d,%d:%s', a:line1, a:line2, current)] : ['--follow', '--', current]
  else
    silent! unlet g:gv_file
  endif
  return ['--graph']
endfunction

function! s:type(visual) "{{{1
  if a:visual
    let shas = filter(map(getline("'<", "'>"), 'gv#sha(v:val)'), '!empty(v:val)')
    if len(shas) < 2
      return [0, 0]
    endif
    return ['diff', fugitive#repo().git_command('diff', shas[-1], shas[0])]
  endif

  if exists('b:git_origin')
    let syn = synIDattr(synID(line('.'), col('.'), 0), 'name')
    if syn == 'gvGitHub'
      return ['link', '/issues/'.expand('<cword>')[1:]]
    elseif syn == 'gvTag'
      let tag = matchstr(getline('.'), '(tag: \zs[^ ,)]\+')
      return ['link', '/releases/'.tag]
    endif
  endif

  let sha = gv#sha()
  if !empty(sha)
    return ['commit', FugitiveFind(sha, b:git_dir)]
  endif
  return [0, 0]
endfunction

function! s:split(tab) "{{{1
  if a:tab
    call s:tabnew()
  elseif getwinvar(winnr('$'), 'gv')
    $wincmd w
    enew
  else
    vertical botright new
  endif
  let w:gv = 1
endfunction "}}}

" vim: ft=vim et ts=2 sw=2 sts=2 fdm=marker
