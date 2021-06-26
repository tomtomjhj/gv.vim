let s:begin = '^[^0-9]*[0-9]\{4}-[0-9]\{2}-[0-9]\{2}\s\+'

"------------------------------------------------------------------------------
" Setup
"------------------------------------------------------------------------------

function! gv#sha(...)
  " Commit sha at current line {{{1
  return matchstr(get(a:000, 0, getline('.')), s:begin.'\zs[a-f0-9]\+')
endfunction "}}}

function! gv#start(bang, visual, line1, line2, args) abort
  " Entry point {{{1
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
      let [opts1, paths1] = s:log_opts(fugitive_repo, a:bang, a:visual, a:line1, a:line2)
      let [opts2, paths2] = s:split_pathspec(s:shellwords(a:args))
      let log_opts = opts1 + opts2 + paths1 + paths2
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

function! s:to_location_list(buf, visual) "{{{1
  if !exists(':Gllog')
    return
  endif
  -tab split
  silent execute a:visual ? "'<,'>" : "" 'Gllog'
  call setloclist(0, insert(getloclist(0), {'bufnr': a:buf}, 0))
  noautocmd b #
  lopen
  xnoremap <silent> <nowait> <buffer> o   :call <sid>gl('open', 0)<cr>
  nnoremap <silent> <nowait> <buffer> o   <cr><c-w><c-w>
  nnoremap <silent> <nowait> <buffer> O   :call <sid>gl('open', 1)<cr>
  nnoremap <silent> <nowait> <buffer> a   :call <sid>gl('rev', 0)<cr>
  nnoremap <silent> <nowait> <buffer> A   :call <sid>gl('rev', 1)<cr>
  xnoremap <silent> <nowait> <buffer> d   :call <sid>gl('diff', 1)<cr>
  nnoremap <silent> <nowait> <buffer> d   :call <sid>gl('diff', 1)<cr>
  nnoremap <silent> <nowait> <buffer> q   :tabclose<cr>
  nnoremap <silent> <nowait> <buffer> gq  :tabclose<cr>

  xnoremap <silent> <nowait> <buffer> v   V
  nnoremap <silent> <nowait> <buffer> v   V

  call matchadd('Conceal', '^fugitive://.\{-}\.git//')
  call matchadd('Conceal', '^fugitive://.\{-}\.git//\x\{7}\zs.\{-}||')
  setlocal concealcursor=nv conceallevel=3 nowrap
  let w:quickfix_title = 'o: open / o (in visual): diff / O: open (tab) / q: quit'
endfunction

function! s:gl(type, tab) range "{{{1
  let [to, from] = map([a:firstline, a:lastline], 'split(getline(v:val), "|")[0]')

  " escape spaces
  let [from, to, fn] = map([from, to, split(getline(1), '|')[0]], 'escape(v:val, " ")')

  if a:tab
    -tabnew
    call s:scratch()
  else
    1wincmd w
  endif

  " older revision is always put to the right, newest to the left

  if a:type == 'open'
    if from !=# to
      execute '0Git diff' from . '..' . to . ' -- ' . fn
    else
      execute '0Git diff' to . ' -- ' . fn
    endif

  elseif a:type == 'rev'
    if a:tab
      execute 'Gedit' to . ':' . fn
    else
      silent! pclose
      execute 'botright Gvsplit' to . ':' . fn
      set previewwindow
    endif

  elseif a:type == 'diff'
    execute 'Gedit' from . ':' . fn
    if from !=# to
      execute 'Gvsplit' to . ':' . fn
    else
      execute 'Gvsplit HEAD:' . fn
    endif
    windo diffthis

  endif
  silent! 2wincmd w
endfunction "}}}


"------------------------------------------------------------------------------
" GV command
"------------------------------------------------------------------------------

function! s:setup(git_dir, git_origin) "{{{1
  -tabnew
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
    echohl Label | echo g:gv_file."\t"
    echohl None  | echon 'o: open split / O: open tab / s: show revision / S: to tab / d: diff / L: GV? / q: quit / g?: help'
  else
    echo 'o: open split / O: open tab / q: quit / g?: help'
  endif
endfunction

function! s:open(visual, tab, ...) "{{{1
  let [type, target, statusline] = a:0 ? a:000 : s:type(a:visual)

  if empty(type)
    return s:shrug()
  elseif type == 'link'
    return s:browse(target)
  endif

  call s:split(a:tab)
  call s:fill_side_buffer(type, target, statusline)
  let bang = a:tab ? '!' : ''
  if exists('#User#GV'.bang)
    execute 'doautocmd <nomodeline> User GV'.bang
  endif
  wincmd p
  let s:windows.diff = line('.')
  echo
  if !a:tab && s:windows.summary
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

function! s:fill_side_buffer(type, target, statusline) "{{{1
  call s:scratch()
  if a:type == 'commit'
    execute 'e' escape(a:target, ' ')
    set fdm=syntax
    silent! normal! ggzxzjzo
    nnoremap <silent> <buffer> gb :GBrowse<cr>
  elseif a:type == 'diff'
    call s:fill(a:target . s:gv_file(1))
    setfiletype git
    set fdm=syntax
    normal! ggzx
    let &l:statusline = ' ' . a:statusline
    nnoremap <silent> <nowait> <buffer>      J          :<c-u>call <sid>folds(1)<cr>
    nnoremap <silent> <nowait> <buffer>      K          :<c-u>call <sid>folds(0)<cr>
  endif
  nnoremap <silent> <nowait> <buffer>        q          :call <sid>quit()<cr>
  nnoremap <silent> <nowait> <buffer>        <leader>q  :call <sid>quit()<cr>
  nnoremap <silent> <nowait> <buffer>        <tab>      <c-w><c-h>
  nnoremap <silent> <nowait> <buffer>        [          :<c-u>call <sid>folds(0)<cr>
  nnoremap <silent> <nowait> <buffer>        ]          :<c-u>call <sid>folds(1)<cr>
  let b:gv_diff = 1
endfunction

function! s:syntax() "{{{1
  setfiletype GV
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
  nnoremap <silent> <nowait> <buffer>        gq         :call <sid>quit()<cr>
  nnoremap <silent> <nowait> <buffer>        <leader>q  :call <sid>quit()<cr>
  nnoremap <silent> <nowait> <buffer>        <tab>      <c-w><c-l>
  nnoremap <silent> <nowait> <buffer>        gb         :call <sid>gbrowse()<cr>
  nnoremap <silent> <nowait> <buffer>        <cr>       :call <sid>open(0, 0)<cr>
  nnoremap <silent> <nowait> <buffer>        o          :call <sid>open(0, 0)<cr>
  nnoremap <silent> <nowait> <buffer>        O          :call <sid>open(0, 1)<cr>
  xnoremap <silent> <nowait> <buffer>        <cr>       :<c-u>call <sid>open(1, 0)<cr>
  xnoremap <silent> <nowait> <buffer>        o          :<c-u>call <sid>open(1, 0)<cr>
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
  nnoremap <silent> <nowait> <buffer>        v          V
  xnoremap <silent> <nowait> <buffer>        v          V

  nnoremap <silent> <nowait> <buffer>        J          :<c-u>call <sid>scroll(1)<cr>
  nnoremap <silent> <nowait> <buffer>        K          :<c-u>call <sid>scroll(0)<cr>

  nmap              <nowait> <buffer> <C-n> jo
  nmap              <nowait> <buffer> <C-p> ko
  xmap              <nowait> <buffer> <C-n> ]ogv
  xmap              <nowait> <buffer> <C-p> [ogv

  nnoremap <silent> <buffer> <nowait> d :call <sid>diff_normal(0)<cr>
  xnoremap <silent> <buffer> <nowait> d <esc>:call <sid>diff_visual(0)<cr>
  nnoremap <silent> <buffer> <nowait> D :call <sid>diff_normal(1)<cr>
  xnoremap <silent> <buffer> <nowait> D <esc>:call <sid>diff_visual(1)<cr>

  if exists('g:gv_file')
    nnoremap <silent> <buffer> <nowait> a :<C-u>call <sid>file_at_revision(0)<cr>
    nnoremap <silent> <buffer> <nowait> A :<C-u>call <sid>file_at_revision(1)<cr>
    nnoremap <silent> <buffer> <nowait> L :call <sid>to_location_list(bufnr(gv_file), 0)<cr><cr>
  else
    nnoremap <silent> <buffer> <nowait> a :echo 'not in GV'<cr>
    nnoremap <silent> <buffer> <nowait> A :echo 'not in GV'<cr>
  endif

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

function! s:diff_visual(tab) "{{{1
  if exists('g:gv_file')
    normal! '<
    let s1 = gv#sha() . ':' . escape(g:gv_file, ' ')
    normal! '>
    let s2 = gv#sha() . ':' . escape(g:gv_file, ' ')
    exe '-Gtabedit' s1
    diffthis
    exe 'Gvsplit' s2
    diffthis
  else
    call s:open(1, a:tab)
  endif
endfunction

function! s:diff_normal(tab) "{{{1
  if exists('g:gv_file')
    exe '-Gtabedit' gv#sha() . ':' . escape(g:gv_file, ' ')
    exe 'vsplit' escape(g:gv_file, ' ')
    windo diffthis
    wincmd p
  else
    let cmd = 'git diff ' . gv#sha()
    call s:open(0, a:tab, 'diff', cmd, cmd)
  endif
endfunction

function! s:file_at_revision(tab) "{{{1
  if a:tab
    exe '-Gtabedit' gv#sha() . ':' . escape(g:gv_file, ' ')
  else
    set lz
    silent! pclose
    try
      execute 'botright Gvsplit' gv#sha() . ':' . escape(g:gv_file, ' ')
      set previewwindow
    catch
    finally
      1wincmd w
      set nolz
    endtry
  endif
endfunction

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

function! s:scroll(down) "{{{1
  let w = s:diff_winnr()
  if w
    exe w.'wincmd w'
    call clearmatches()
    exe "normal"  ( a:down ? "Jzt" : "Kzt" )
    call matchaddpos('Pmenu', [line('.')])
    wincmd p
  endif
endfunction

function! s:folds(down) "{{{1
  if !s:diff_winnr()
    let s:windows.diff = 0
  endif
  let [was_gv, diff_open] = [&ft == 'GV', s:windows.diff]
  if was_gv && s:windows.diff != line('.')
    normal o
    let diff_open = 0
  endif
  exe s:diff_winnr() . 'wincmd w'
  if &fdm != 'syntax'
    setl fdm=syntax
  endif
  if diff_open
    if a:down
      silent! normal! zczjzo[zzt
    else
      silent! normal! zczkzo[zzt
    endif
  else
    silent! normal! ggzjzo
  endif
  if was_gv
    1wincmd w
  endif
endfunction "}}}

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
  call s:scratch()
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
  echohl Special | echo 'q' | echohl None | echon "\tquit"
  echohl Special | echo 'r' | echohl None | echon "\trefresh"
  echohl Special | echo 'yy' | echohl None | echon "\tcopy commit hash"
  echohl Special | echo 'gb' | echohl None | echon "\tGbrowse"
  echohl Special | echo '<tab>' | echohl None | echon "\tchange window"
  echohl Special | echo '<cr>' | echohl None | echon "\tshow diff panel"
  echohl Special | echo 'o' | echohl None | echon "\tshow diff panel"
  echohl Special | echo 'O' | echohl None | echon "\topen diff in new tab"
  echohl Special | echo '.' | echohl None | echon "\t:Git | sha"
  echohl Special | echo 'R' | echohl None | echon "\t:Git rebase -i| sha"
  echohl Special | echo '~' | echohl None | echon "\tset gitgutter_diff_base to commit"
  echohl Special | echo '[' | echohl None | echon "\tprevious fold in side window"
  echohl Special | echo ']' | echohl None | echon "\tnext fold in side window"
  if exists('g:gv_file')
    echohl Special | echo 'a' | echohl None | echon "\tshow revision"
    echohl Special | echo 'A' | echohl None | echon "\tshow revision in new tab"
    echohl Special | echo 'd' | echohl None | echon "\tdiff with file at HEAD"
    echohl Special | echo 'L' | echohl None | echon "\t:GV? (all commits in location list)"
  else
    echohl Special | echo 'J' | echohl None | echon "\tnext hunk in commit window"
    echohl Special | echo 'K' | echohl None | echon "\tprevious hunk in commit window"
    echohl Special | echo 'd' | echohl None | echon "\tdiff revision with HEAD"
    echohl Special | echo 'D' | echohl None | echon "\tdiff revision with HEAD in new tab"
  endif
  echohl Special | echo 'i' | echohl None | echon "\tshow info panel"
  echohl Special | echo 'I' | echohl None | echon "\tshow info and diff panels"
  echohl Special | echo '<C-n>' | echohl None | echon "\topen next"
  echohl Special | echo '<C-p>' | echohl None | echon "\topen previous"
  echohl Special | echo '<cr>' | echohl None | echon "\t[V] diff between commits range"
  echohl Special | echo 'o' | echohl None | echon "\t[V] diff between commits range"
  echohl Special | echo 'O' | echohl None | echon "\t[V] open in new tab"
  if exists('g:gv_file')
    echohl Special | echo 'd' | echohl None | echon "\t[V] diff file between revisions in range"
  endif
  echo "\n"
endfunction


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
    1wincmd w

  elseif s:windows.diff
    $wincmd w
    bdelete!
    let s:windows.diff = 0
    1wincmd w

  elseif winnr() == 1 && winnr('$') > 1
    $wincmd w
    bdelete!
    1wincmd w

  else
    bdelete!

  endif
endfunction

function! s:gv_file(esc) "{{{1
  return !exists('g:gv_file') ? '' :
        \ a:esc ? ' -- ' . escape(g:gv_file, ' ')
        \       : ' -- ' . g:gv_file
endfunction

function! s:move(flag) "{{{1
  let [l, c] = searchpos(s:begin, a:flag)
  return l ? printf('%dG%d|', l, c) : ''
endfunction

function! s:browse(url) "{{{1
  call netrw#BrowseX(b:git_origin.a:url, 0)
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
    return a:visual ? [[printf('-L%d,%d:%s', a:line1, a:line2, g:gv_file)], []] : [['--follow'], ['--', g:gv_file]]
  else
    silent! unlet g:gv_file
  endif
  return [['--graph'], []]
endfunction

function! s:diff_winnr() "{{{1
  for w in range(1, winnr('$'))
    if getbufvar(winbufnr(w), 'gv_diff')
      return w
    endif
  endfor
  return 0
endfunction

function! s:split_pathspec(args) "{{{1
  let split = index(a:args, '--')
  if split < 0
    return [a:args, []]
  elseif split == 0
    return [[], a:args]
  endif
  return [a:args[0:split-1], a:args[split:]]
endfunction

function! s:type(visual) "{{{1
  if a:visual
    let shas = filter(map(getline("'<", "'>"), 'gv#sha(v:val)'), '!empty(v:val)')
    if len(shas) < 2
      return [0, 0, '']
    endif
    let statusline = 'git diff ' . shas[-1] . ' ' . shas[0] . s:gv_file(0)
    return ['diff', fugitive#repo().git_command('diff', shas[-1], shas[0]), statusline]
  endif

  if exists('b:git_origin')
    let syn = synIDattr(synID(line('.'), col('.'), 0), 'name')
    if syn == 'gvGitHub'
      return ['link', '/issues/'.expand('<cword>')[1:], '']
    elseif syn == 'gvTag'
      let tag = matchstr(getline('.'), '(tag: \zs[^ ,)]\+')
      return ['link', '/releases/'.tag, '']
    endif
  endif

  let sha = gv#sha()
  if !empty(sha)
    return ['commit', FugitiveFind(sha, b:git_dir), '']
  endif
  return [0, 0, '']
endfunction

function! s:split(tab) "{{{1
  if a:tab
    -tabnew
  elseif getwinvar(winnr('$'), 'gv')
    $wincmd w
    enew
  else
    vertical botright new
  endif
  let w:gv = 1
endfunction "}}}

" vim: ft=vim et ts=2 sw=2 sts=2 fdm=marker
