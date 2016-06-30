" Location:     plugin/dispatch-vimproc.vim
" Maintainer:   Alex Rodionov <https://github.com/p0deje>
" Version:      0.1

if exists('g:loaded_dispatch_vimproc')
  finish
endif
let g:loaded_dispatch_vimproc = 1

augroup dispatch-vimproc
  autocmd!
  autocmd VimEnter *
        \ if index(get(g:, 'dispatch_handlers', ['vimproc']), 'vimproc') < 0 |
        \   call insert(g:dispatch_handlers, 'vimproc', index(g:dispatch_handlers, 'screen')+1) |
        \ endif
augroup END
