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
- visual `o` or `<cr>` on commits to display the diff in the range
- `O` opens a new tab instead
- `gb` for `:Gbrowse`
- `Tab` to switch window
- `j` and `k` to move between commits
- `]` and `[` to browse folds in the second window
- `.` to start command-line with `:Git [CURSOR] SHA` à la fugitive
- `~` to set GitGutter diff base to the commit
- `i` to show the commit info in a preview window
- `I` to open both summary and diff panels
- `yy` to copy sha to clipboard
- `q` or `gq` to close

`GV!`/`GV?` extra mappings:

- `d` to diff the revision in a new tab
- visual `d` to diff between the revisions in the range
- `a` to show the revision in a vertical split
- `A` to show the revision in a new tab
- `L` like `GV?` for the current file


Customization
-------------

`¯\_(ツ)_/¯`
