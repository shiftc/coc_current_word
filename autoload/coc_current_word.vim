let g:coc_current_word_disabled_by_insert_mode = 0
let g:coc_current_word_timer_id = 0


" Setup needed autocommands for this plugin to work in the current buffer
function! coc_current_word#setup_autocommands()
  augroup coc_current_word_buffer
    autocmd! * <buffer>
    autocmd BufEnter <buffer> call coc_current_word#pre_highlight()
    autocmd CursorMoved <buffer> call coc_current_word#pre_highlight()
    autocmd InsertEnter <buffer> call coc_current_word#handle_insert_enter()
    autocmd InsertLeave <buffer> call coc_current_word#handle_insert_leave()
  augroup END
endfunction

" Clear previously scheduled highlight
function! coc_current_word#clear_scheduled_highlight()
  if g:coc_current_word_timer_id
    call timer_stop(g:coc_current_word_timer_id)
    let g:coc_current_word_timer_id = 0
  endif
endfunction

" Perform highlight with delay
function! coc_current_word#schedule_highlight()
  call coc_current_word#clear_scheduled_highlight()
  let g:coc_current_word_timer_id = timer_start(g:coc_current_word_highlight_delay, 'coc_current_word#highlight_word_under_cursor')
endfunction

" Schedule highlight or do it instantly
function! coc_current_word#pre_highlight()
  let l:coc_current_word_disabled_in_this_buffer = get(b:, 'coc_current_word_disabled_in_this_buffer', 0)
  if !g:coc_current_word_enabled || l:coc_current_word_disabled_in_this_buffer | return 0 | endif
  if g:coc_current_word_highlight_delay
    call coc_current_word#schedule_highlight()
  else
    call coc_current_word#highlight_word_under_cursor()
  end
endfunction

" Toggle plugin
function! coc_current_word#coc_current_word_toggle()
  if g:coc_current_word_enabled == 1
    call coc_current_word#coc_current_word_disable()
  else
    call coc_current_word#coc_current_word_enable()
  endif
endfunction

" Disable plugin until insert leave
function! coc_current_word#handle_insert_enter()
  if !g:coc_current_word_enabled | return 0 | endif
  let g:coc_current_word_disabled_by_insert_mode = 1
  call coc_current_word#coc_current_word_disable()
endfunction

" Enable plugin after insert leave
function! coc_current_word#handle_insert_leave()
  if !g:coc_current_word_disabled_by_insert_mode | return 0 | endif
  let g:coc_current_word_disabled_by_insert_mode = 0
  call coc_current_word#coc_current_word_enable()
endfunction

" Enable plugin
function! coc_current_word#coc_current_word_enable()
  let g:coc_current_word_enabled = 1
  call coc_current_word#pre_highlight()
endfunction

" Disable plugin
function! coc_current_word#coc_current_word_disable()
  call coc_current_word#clear_scheduled_highlight()
  let g:coc_current_word_enabled = 0
endfunction

" Request word highlighting (depends on coc.nvim highlighting feature)
function! coc_current_word#highlight_word_under_cursor(...)
  call CocActionAsync('highlight')
endfunction

" Toggle persistent highlight for current word
function! coc_current_word#toggle_persistent_highlight()
  let l:current_match_ids = get(w:, 'coc_current_word_persistent_match_ids', [])
  
  " If persistent highlight exists, clear it first
  if !empty(l:current_match_ids)
    for l:id in l:current_match_ids
      try
        call matchdelete(l:id)
      catch /^Vim\%((\a\+)\)\=:E803/
        " Ignore match not found error
      endtry
    endfor
    let w:coc_current_word_persistent_match_ids = []
    echo "Persistent highlight cleared"
    
    " Check if we are toggling off on the same word (simple heuristic)
    " Ideally we should check if current cursor is inside one of the ranges,
    " but clearing is always safe. If user wants to highlight again, they just press again.
    return
  endif

  " If no highlight exists, request symbol ranges from coc.nvim
  call CocActionAsync('symbolRanges', function('s:HandleSymbolRanges'))
endfunction

function! s:HandleSymbolRanges(err, ranges) abort
  if a:err != v:null
    echoerr 'Error getting symbol ranges: ' . a:err
    return
  endif

  if empty(a:ranges)
    echo "No semantic highlights found"
    return
  endif

  let l:matches = []
  " Convert LSP Ranges (0-based) to Vim matchaddpos format [[line, col, len], ...]
  " matchaddpos expects 1-based line and column
  for l:range in a:ranges
    let l:start_line = l:range['start']['line'] + 1
    let l:start_col = l:range['start']['character'] + 1
    let l:end_line = l:range['end']['line'] + 1
    let l:end_col = l:range['end']['character'] + 1
    
    " Handle single line matches only for matchaddpos (limit of vim)
    " Multi-line semantic highlights are rare for 'word' highlighting
    if l:start_line == l:end_line
        let l:len = l:end_col - l:start_col
        call add(l:matches, [l:start_line, l:start_col, l:len])
    endif
  endfor

  if empty(l:matches)
    return
  endif

  " matchaddpos has a limit of 8 positions per call in older vim, but modern vim/neovim supports list
  " To be safe and compatible, we batch them or just pass the list if supported
  " Neovim and recent Vim support passing a large list directly to matchaddpos
  
  let l:id = matchaddpos('CurrentWord', l:matches, 10)
  let w:coc_current_word_persistent_match_ids = [l:id]
  echo "Persistent semantic highlight added"
endfunction
