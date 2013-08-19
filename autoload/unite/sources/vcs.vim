"=============================================================================
" AUTHOR:  Mun Mun Das <m2mdas at gmail.com>
" FILE: vcs.vim
" Last Modified: August 19, 2013
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================
let s:save_cpo = &cpo
set cpo&vim

if !g:loaded_unite
    finish
endif

call unite#util#set_default('g:unite_source_file_vcs_encoding', 'char')

let s:file_vcs = {
      \ 'name'         : 'file/vcs',
      \ 'description'  : 'Gather file candidates via VCS list command.',
      \ 'action_table' : {},
      \ 'default_kind' : 'file',
      \ }

function! s:file_vcs.gather_candidates(args, context) "{{{

  let vcs_type = s:detect_vcs_type()
  if empty(vcs_type)
    call unite#print_source_error(
          \ 'No VCS program found.', s:file_vcs.name)
    return []
  endif

  if !unite#util#has_vimproc()
    call unite#print_source_error(
          \ 'vimproc plugin is not installed.', self.name)
    let a:context.is_async = 0
    return []
  endif

  let cmdline  = s:get_vcs_command(vcs_type)
  let a:context.vcs_type = vcs_type

  if a:context.is_redraw
    let a:context.is_async = 1
  endif

  let save_term = $TERM
  try
    " Disable colors.
    let $TERM = 'dumb'

    let a:context.source__proc = vimproc#plineopen3(
          \ vimproc#util#iconv(cmdline, &encoding, 'char'), 1)
  finally
    let $TERM = save_term
  endtry

  return self.async_gather_candidates(a:args, a:context)
endfunction"}}}

function! s:file_vcs.async_gather_candidates(args, context) "{{{
  let entries = []

  if !has_key(a:context, 'vcs_type')
    let a:context.is_async = 0
    return []
  endif

  if !has_key(a:context, 'source__proc')
    let a:context.is_async = 0
    call unite#print_source_message('Completed.', s:file_vcs.name)
    return []
  endif
  let vcs_type = a:context.vcs_type

  let stderr = a:context.source__proc.stderr
  if !stderr.eof
    " Print error.
    let errors = filter(stderr.read_lines(-1, 100),
          \ "v:val !~ '^\\s*$'")
    if !empty(errors)
      call unite#print_source_error(errors, s:file_vcs.name)
    endif
  endif

  let stdout = a:context.source__proc.stdout
  if stdout.eof
    " Disable async.
    let a:context.is_async = 0
    call unite#print_source_message('Completed.', s:file_vcs.name)
  endif

  let entries = map(stdout.read_lines(-1, 100),
          \ "unite#util#iconv(v:val, g:unite_source_file_vcs_encoding, &encoding)")

  let candidates = []
  for entry in entries
    let filename = s:process_vcs_list_output_line(entry, vcs_type)

    let dict = {
        \ 'word' : filename,
        \ 'abbr' : filename,
        \ 'kind' : isdirectory(filename)? 'directory' : 'file',
        \ 'action__path' : filename,
        \ }

    if isdirectory(filename)
      let dict.action__directory = filename
    endif

    call add(candidates, dict)
  endfor

  return candidates
endfunction"}}}

function! s:detect_vcs_type() "{{{
  if executable('git') && isdirectory('.git/')
    return 'git'
  elseif executable('hg') && isdirectory('.hg/')
    return 'hg'
  elseif executable('svn') && isdirectory('.svn/')
    return 'svn'
  else
    return ''
  endif

  return ''
endfunction "}}}

function! s:get_vcs_command(vcs) "{{{
  let vcs_map = {
        \ 'git' : 'git ls-files -o -m -c --exclude-standard',
        \ 'hg'  : 'hg status -c -m -u',
        \ 'svn' : 'svn list -R'
        \}
  if a:vcs == 'svn'
    let svn_update = 0
    if exists("g:unite_file_vcs_svn_update")
      let svn_update = g:unite_file_vcs_svn_update
    else
      let svn_update = unite#util#input_yesno("Do you want to issue 'svn update' command?")
    endif

    if svn_update
      call system('svn update')
    endif

  endif

  return vcs_map[a:vcs]
endfunction "}}}

function! s:process_vcs_list_output_line(line, vcs) "{{{
  if a:vcs == 'git' || a:vcs == 'svn'
    return unite#util#substitute_path_separator(a:line)
  elseif a:vcs == 'hg'
    return unite#util#substitute_path_separator(
          \ matchstr(a:line, '.\s\zs.*')
          \)
  endif
endfunction "}}}

function! unite#sources#vcs#define() "{{{
  let sources = [ s:file_vcs ]
  return sources
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker sw=2 ts=2 sts=2
