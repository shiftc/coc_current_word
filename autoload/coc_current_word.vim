let g:coc_current_word_disabled_by_insert_mode = 0
let g:coc_current_word_timer_id = 0


" Setup needed autocommands for this plugin to work in the current buffer
function! coc_current_word#setup_autocommands()
  augroup coc_current_word_buffer
    autocmd! * <buffer>
    autocmd BufEnter <buffer> call coc_current_word#handle_buf_enter()
    autocmd BufLeave <buffer> call coc_current_word#handle_buf_leave()
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

function! coc_current_word#handle_buf_enter()
  call coc_current_word#pre_highlight()
  call s:RestorePersistentHighlights()
endfunction

function! coc_current_word#handle_buf_leave()
  call s:ClearWindowHighlights()
endfunction

" Toggle persistent highlight for current word
function! coc_current_word#toggle_persistent_highlight()
  " Use b: variable for ranges data source, w: variable for current active matches
  let l:highlight_groups = get(b:, 'coc_persistent_highlight_groups', [])
  let l:active_matches = get(w:, 'coc_persistent_active_matches', [])
  
  " Check if cursor is on an existing highlight group
  let l:cursor_pos = getpos('.')
  let l:cursor_line = l:cursor_pos[1]
  let l:cursor_col = l:cursor_pos[2]
  let l:found_index = -1
  
  let l:idx = 0
  for l:item in l:highlight_groups
    for l:range in l:item['ranges']
       " range format: [line, col, len]
       let l:r_line = l:range[0]
       let l:r_col = l:range[1]
       let l:r_len = l:range[2]
       
       if l:cursor_line == l:r_line && l:cursor_col >= l:r_col && l:cursor_col < (l:r_col + l:r_len)
         let l:found_index = l:idx
         break
       endif
    endfor
    if l:found_index != -1
      break
    endif
    let l:idx += 1
  endfor

  if l:found_index != -1
    " Case 1: Cursor is on an already highlighted word -> Remove ONLY this highlight group
    
    " Remove from data source
    call remove(l:highlight_groups, l:found_index)
    let b:coc_persistent_highlight_groups = l:highlight_groups
    
    " Remove match from window (find corresponding ID)
    " This is tricky because indices match IF we keep them synced.
    " It's safer to clear all window matches and re-render b: groups.
    call s:ClearWindowHighlights()
    call s:RestorePersistentHighlights()
    
    echo "Persistent highlight cleared"
  else
    " Case 2: New highlight -> Add it
    call CocActionAsync('symbolRanges', function('s:HandleSymbolRanges'))
  endif
endfunction

function! s:ClearWindowHighlights()
  " Clear visual matches from current window using IDs stored in w:
  let l:active_matches = get(w:, 'coc_persistent_active_matches', [])
  for l:match in l:active_matches
    try
      call matchdelete(l:match['id'])
    catch /^Vim\%((\a\+)\)\=:E803/
    endtry
  endfor
  let w:coc_persistent_active_matches = []
endfunction

function! s:RestorePersistentHighlights()
  " Re-render matches for current buffer in current window
  
  " Safety check: Clear any residual matches in this window from previous buffers
  " This handles cases where BufLeave might have failed or not triggered
  call s:ClearWindowHighlights()

  let l:groups = get(b:, 'coc_persistent_highlight_groups', [])
  let l:active_matches = []
  
  for l:group in l:groups
    let l:ranges = l:group['ranges']
    if !empty(l:ranges)
      let l:id = matchaddpos('CurrentWord', l:ranges, 10)
      call add(l:active_matches, { 'id': l:id })
    endif
  endfor
  
  let w:coc_persistent_active_matches = l:active_matches
endfunction

function! s:ClearPersistentHighlight()
  " Legacy helper, keep for compatibility or manual reset
  call s:ClearWindowHighlights()
  let b:coc_persistent_highlight_groups = []
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
  for l:range in a:ranges
    let l:start_line = l:range['start']['line'] + 1
    let l:start_col = l:range['start']['character'] + 1
    let l:end_line = l:range['end']['line'] + 1
    let l:end_col = l:range['end']['character'] + 1
    
    if l:start_line == l:end_line
        let l:len = l:end_col - l:start_col
        call add(l:matches, [l:start_line, l:start_col, l:len])
    endif
  endfor

  if empty(l:matches)
    return
  endif

  " 1. Add to Buffer data source
  let l:groups = get(b:, 'coc_persistent_highlight_groups', [])
  call add(l:groups, { 'ranges': l:matches })
  let b:coc_persistent_highlight_groups = l:groups
  
  " 2. Render in current Window
  let l:id = matchaddpos('CurrentWord', l:matches, 10)
  
  " 3. Track active ID in Window
  let l:active_matches = get(w:, 'coc_persistent_active_matches', [])
  call add(l:active_matches, { 'id': l:id })
  let w:coc_persistent_active_matches = l:active_matches
  
  echo "Persistent semantic highlight added"
endfunction
