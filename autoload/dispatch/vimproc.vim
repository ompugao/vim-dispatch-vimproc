" dispatch.vim vimproc strategy

if exists('g:autoloaded_dispatch_vimproc')
  finish
endif
let g:autoloaded_dispatch_vimproc = 1

let s:V = vital#of('vim_dispatch_vimproc')
let s:Process = s:V.import('Process')

let s:results = {}
" ------------
let s:oldupdatetime=0
augroup dispatch-vimproc-group
augroup END

" コマンド終了時に呼ばれる関数
function! s:finish(pid)
  let &updatetime=s:oldupdatetime
  execute "buffer " . s:results[a:pid]["bufnum"]
  execute "wincmd q"
  execute "bwipeout! " . s:results[a:pid]["bufnum"]
  call dispatch#complete(s:results[a:pid]["request_file"])
endfunction

function! s:receive_message(pid)
  if !has_key(s:results, a:pid)
    return
  endif
  if !has_key(s:results[a:pid], "vimproc")
    return
  endif

  let vimproc = s:results[a:pid]["vimproc"]
  try
    if !vimproc.stdout.eof
      let message = vimproc.stdout.read()
    endif
    if !vimproc.stderr.eof
      let message = vimproc.stderr.read()
    endif
    call s:append_text(a:pid, message)
    if !(vimproc.stdout.eof && vimproc.stderr.eof)
      return 0
    endif
  catch
    echom v:throwpoint
  endtry

  " 終了時に呼ぶ
  call s:finish(a:pid)
  
  augroup dispatch-vimproc-group
    autocmd!
  augroup END

  call vimproc.stdout.close()
  call vimproc.stderr.close()
  call vimproc.waitpid()
  unlet s:results[a:pid]
endfunction

function! s:system_async(cmd, bufnum, request)
  let s:oldupdatetime=&updatetime
  set updatetime=100
  let cmd = a:cmd
  let vimproc = vimproc#pgroup_open(cmd, 0, 2)
  call vimproc.stdin.close()
  
  let s:vimproc = vimproc
  let s:results[vimproc.pid] = {'vimproc': vimproc, 'bufnum': a:bufnum, 'request_file': a:request.file}

  augroup dispatch-vimproc-group
    execute "autocmd! CursorHold,CursorHoldI * call s:receive_message(". vimproc.pid .")"
  augroup END
  return vimproc.pid
endfunction
" ------------

function! s:append_text(pid, message)
  let lastbufnr = bufnr('%')

  execute 'buffer ' . s:results[a:pid]['bufnum']
  setlocal modifiable

  call append(line("$"), split(a:message, '\r\n\|\r\|\n'))
  normal! G
  setlocal nomodifiable

  execute 'buffer ' . lastbufnr
endfunction

function! s:open_buffer(bufname)
  exe "botright 10new " . a:bufname
  let bufn = bufnr("")
  call append(0, "make")
  setlocal noswapfile
  setlocal nolist
  setlocal buftype=nofile
  setfiletype dispatch_vimproc
  setlocal modifiable
  silent %delete _
  setlocal nomodifiable
  execute 'wincmd k'

  return bufn
endfunction

" ---------------------

function! dispatch#vimproc#handle(request) abort
  "if !a:request.background || &shell !~# 'sh'
  "  return 0
  "endif
  if &shell !~# 'sh'
    return 0
  endif

  if a:request.action ==# 'make'
    let bufname = "make"
    let command = dispatch#prepare_make(a:request)
  elseif a:request.action ==# 'start'
    let bufname = "[dispatch-vimproc]"
    let command = dispatch#prepare_start(a:request)
  else
    return 0
  endif
  let bufnum = s:open_buffer(bufname)

  "if &shellredir =~# '%s'
  "  let redir = printf(&shellredir, '/dev/null')
  "else
  "  let redir = &shellredir . ' ' . '/dev/null'
  "endif
  "system(&shell.' '.&shellcmdflag.' '.shellescape(command).redir.' &')
  let pid = s:system_async(&shell.' '.&shellcmdflag.' '.shellescape(command), bufnum, a:request)
  let a:request.pid = pid

  return 1
endfunction

function! dispatch#vimproc#running(pid) abort
  return has_key(s:results, a:pid)
endfunction

function! dispatch#vimproc#activate(pid) abort
  if s:Process.has_vimproc()
    return 1
  endif
  return 0
endfunction

