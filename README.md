This plugin adds a [unite.vim](https://github.com/Shougo/unite.vim) source that lists VCS file-lists as candidates.The plugin automatically detects VCS program of the project. Supported VCS programs are `git`, `hg` and `svn`.

Requirements
============
 * [unite.vim](https://github.com/Shougo/unite.vim)
 
 * [vimproc](https://github.com/Shougo/vimproc.vim)

Usage
======

You can add following mapping to your `.vimrc` file.

    nnoremap <leader>fv :<C-u>Unite -start-insert -no-split -buffer-name=file_vcs file/vcs<CR>

Please note that current directory of your vim buffer/tab must be the root directory of the project to get the candidates.
