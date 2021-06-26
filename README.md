gv.vim
======

A git commit browser.

![gv](https://cloud.githubusercontent.com/assets/700826/12355378/8bbf0834-bbdf-11e5-9389-1aba7cd1fec1.png)

[gv](https://github.com/junegunn/gv.vim) is nice. But I wanted some more features.


Installation
------------

Requires fugitive.

Using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'tpope/vim-fugitive'
Plug 'mg979/gv.vim'
```

Usage
-----

### Commands

- `:GV` to open commit browser
    - You can pass `git log` options to the command, e.g. `:GV -S foobar -- plugins`.
- `:GV!` will only list commits that affected the current file
- `:GV?` fills the location list with the revisions of the current file
- `:GS` to open stash browser

Visual mode can be used to run diffs for commits in the selected lines.
From `GV!` and `GV?`, diffs are relative to the tracked file only.

`:GS` can be used to browse/operate on stashes, but not to create them.


### Mappings

`GV` mappings:

- `g?` for help
- `o` or `<cr>` on a commit to display the content of it
- _visual_ `o` or `<cr>` on commits to display the diff for the selected range
- `O` opens a new tab instead
- `d/D` to diff the revision against `HEAD`
- `gb` for `:Gbrowse`
- `Tab` to switch window
- `j` and `k` to move between commits
- `.` to start command-line with `:Git [CURSOR] SHA` à la fugitive
- `~` to set GitGutter diff base to the commit
- `i` to show the commit info in a preview window
- `yy` to copy sha to clipboard
- `q` or `gq` to close

`GV!`/`GV?` extra mappings:

- `d` to diff the file at revision in a new tab
- visual `d` to diff the file between the revisions in the selected range
- `a` to show the file at revision in a vertical split
- `A` to show the file at revision in a new tab

From any window (`GV` or `GV!`):

- `]` and `[` to browse folds in the commit/diff window
- `J` and `K` to move between hunks in the commit window


Customization
-------------

`¯\_(ツ)_/¯`
