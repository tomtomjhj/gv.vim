function! gv#sbs#show(all)
    if empty(g:gv_file) | return | endif
    let [sha, tab, file] = [gv#sha(), tabpagenr() - 1, g:gv_file]
    tabclose

    "open current file in a new tab
    exe tab."tabedit" fnameescape(file)
    silent! let g:xtabline.Tabs[tab].locked = 1
    silent! let g:xtabline.Tabs[tab].buffers.valid = [bufnr('%')]
    let ft = &ft
    diffthis

    if a:all
      "all revisions to locations list
      vsplit
      wincmd l
      0Gllog
      set nofoldenable
    else
      "get commit message
      let msg = system('git log -1 --pretty=format:%s '.sha)
      "open revision in a split and set it ready for diff/scrollbind
      vsplit
      wincmd l
      exe "0Git! show" sha.":".tr(file, '\', '/')
      setlocal bt=nofile bh=wipe noswf nobl noma nofoldenable
      let &ft = ft
      diffthis
      let b:XTbuf = {'name': 'Revision', 'icon': ''}
      redraw
      let &l:statusline = " " .file." %#DiffDelete# ".sha." %#Statusline# ".msg
    endif
endfunction
