; =============================================================================
; Pawmodoro - Synthesized Sound Effects Engine (src/sfx.asm)
;
; Purpose: Audio player detection, non-blocking player process lifecycle via
;          direct Linux system calls (sys_pipe, sys_fork, sys_dup2, sys_execve),
;          pure integer 8-bit unsigned PCM synthesis (11025 Hz, mono) with
;          phase accumulator, square/triangle waveforms, linear decay envelope,
;          volume scaling, and terminal bell fallback per PRD_V2 §9, §11, §13.5.
;
; Constraints:
;   - 32-bit x86 integer instructions only. No FPU, MMX, SSE, libc, or shell.
;   - Direct int 0x80 syscalls with negative return value checks (-4095..-1).
;   - Non-blocking parent process (no waitpid in normal playback).
;   - Reaped child processes via SIGCHLD ignored disposition.
;   - Safe pipe write with SIGPIPE ignored disposition.
; =============================================================================

; =============================================================================
; TEXT SECTION ROUTINES (section .text opened in src/main.asm)
; =============================================================================

;=============================================================================
; Procedure: sfx_init
; Purpose:   Initializes the sound engine at application startup:
;            1. Installs SIG_IGN (1) on SIGPIPE (13) and SIGCHLD (17) via sys_signal
;               (syscall 48) to prevent crash on broken pipe and prevent zombie
;               processes upon player termination.
;            2. Probes for external audio players via sys_access (syscall 33, X_OK = 1):
;               - Tests /usr/bin/paplay first.
;               - If absent/unexecutable, tests /usr/bin/aplay.
;               - Stores PLAYER_PAPLAY, PLAYER_APLAY, or PLAYER_NONE in sfx_player_choice.
;            3. Does not terminate or fail startup if no player exists.
; IN:        None (reads system state)
; OUT:       Updates [sfx_player_choice]
; CLOBBERS:  None (preserves EAX, EBX, ECX, EDX, ESI, EDI)
;=============================================================================
sfx_init:
    save_regs
    push eax

    ; 1. Ignore SIGPIPE (13) so broken pipe returns -EPIPE instead of killing process
    syscall SYS_SIGNAL, SIGPIPE, SIG_IGN

    ; 2. Ignore SIGCHLD (17) so kernel automatically reaps terminated child processes
    syscall SYS_SIGNAL, SIGCHLD, SIG_IGN

    ; 3. Probe preferred audio player: /usr/bin/paplay (PulseAudio raw player)
    syscall SYS_ACCESS, paplay_path, X_OK
    test eax, eax
    jnz .probe_aplay            ; Nonzero return = error / not executable

    ; paplay is available and executable
    mov dword [sfx_player_choice], PLAYER_PAPLAY
    jmp .init_done

.probe_aplay:
    ; 4. Probe fallback audio player: /usr/bin/aplay (ALSA raw player)
    syscall SYS_ACCESS, aplay_path, X_OK
    test eax, eax
    jnz .no_player_found        ; Nonzero return = not available

    ; aplay is available and executable
    mov dword [sfx_player_choice], PLAYER_APLAY
    jmp .init_done

.no_player_found:
    ; Neither player is available: record no-player state (bell fallback will be used)
    mov dword [sfx_player_choice], PLAYER_NONE

.init_done:
    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: synth_note
; Purpose:   Synthesizes a single musical note or rest into sfx_buf using pure
;            integer arithmetic:
;            - Target format: 11025 Hz, 8-bit unsigned PCM, mono, centered at 128.
;            - Computes sample count N = (duration_ms * 11025) / 1000.
;            - Clamps N to remaining capacity in sfx_buf (SFX_BUF_SIZE = 32768).
;            - Derives 32-bit phase increment delta_phase = (freq * 2^32) / 11025.
;            - Applies linear decay envelope: A(t) = A_max * (N - t) / N.
;            - Scales amplitude by [setting_volume] (0..3 via sfx_volume_table).
;            - Generates square or triangle waveform, or silence (128) for rest.
;            - Appends samples to sfx_buf + [sfx_buf_len] and advances [sfx_buf_len].
; IN:        EAX = Frequency in Hz (e.g., 440, 0 = rest/silence)
;            ECX = Duration in milliseconds (e.g., 50, 100)
;            EDX = Waveform ID (WAVE_SQUARE = 0, WAVE_TRIANGLE = 1, WAVE_REST = 2)
; OUT:       EAX = Number of valid PCM samples generated and appended
; CLOBBERS:  EAX (preserves EBX, ECX, EDX, ESI, EDI)
;=============================================================================
synth_note:
    save_regs

    ; Local stack frame variables:
    ;   [esp + 20] = caller's return address
    ;   [esp + 16] = local: frequency_hz
    ;   [esp + 12] = local: waveform_id
    ;   [esp + 8]  = local: sample_count_N
    ;   [esp + 4]  = local: delta_phase
    ;   [esp]      = local: max_amplitude_Amax
    sub esp, 20

    mov [esp + 16], eax         ; frequency_hz
    mov [esp + 12], edx         ; waveform_id

    ; 1. Check for zero or negative duration
    test ecx, ecx
    jle .synth_zero_samples

    ; 2. Compute requested sample count N = (duration_ms * 11025) / 1000
    mov eax, ecx
    mov edx, AUDIO_SAMPLE_RATE  ; 11025
    mul edx                     ; EDX:EAX = duration_ms * 11025
    mov ecx, 1000
    div ecx                     ; EAX = quotient N = (duration_ms * 11025) / 1000
    test eax, eax
    jnz .clamp_to_buffer
    inc eax                     ; Ensure at least 1 sample if duration > 0

.clamp_to_buffer:
    ; 3. Check buffer remaining capacity: remaining = SFX_BUF_SIZE - [sfx_buf_len]
    mov edx, [sfx_buf_len]
    mov ecx, SFX_BUF_SIZE
    sub ecx, edx                ; ECX = remaining capacity in bytes
    jle .synth_zero_samples     ; Buffer full: return 0

    cmp eax, ecx
    jbe .capacity_ok
    mov eax, ecx                ; Clamp N to remaining capacity

.capacity_ok:
    mov [esp + 8], eax          ; Save sample_count_N

    ; 4. Determine base maximum amplitude from setting_volume (0..3)
    ; Digital silence if sound disabled or volume zero
    cmp byte [setting_sound], 1
    jne .force_silence
    cmp dword [esp + 12], WAVE_REST ; Rest note requested?
    je .force_silence
    cmp dword [esp + 16], 0     ; 0 Hz frequency?
    je .force_silence

    movzx eax, byte [setting_volume]
    cmp eax, 3
    jbe .vol_lookup
    mov eax, 3

.vol_lookup:
    movzx eax, byte [sfx_volume_table + eax] ; A_max = 0, 30, 65, or 110
    mov [esp], eax              ; Save max_amplitude_Amax
    jmp .calc_phase_inc

.force_silence:
    mov dword [esp], 0          ; A_max = 0 (produces digital silence: 128)

.calc_phase_inc:
    ; 5. Compute 32-bit phase accumulator increment:
    ;    delta_phase = (freq * 2^32) / 11025
    ;    Using 64-bit dividend EDX:EAX where EDX = freq, EAX = 0.
    ;    To avoid 32-bit division overflow, clamp frequency to 5500 Hz (Nyquist is 5512.5).
    cmp dword [esp], 0          ; If A_max == 0, phase increment is unneeded
    je .zero_delta

    mov edx, [esp + 16]         ; Frequency in Hz
    cmp edx, 5500
    jbe .freq_in_range
    mov edx, 5500

.freq_in_range:
    test edx, edx
    jz .zero_delta

    xor eax, eax                ; EDX:EAX = freq * 2^32
    mov ecx, AUDIO_SAMPLE_RATE  ; 11025
    div ecx                     ; EAX = delta_phase (quotient fits in 32 bits since EDX < 11025)
    mov [esp + 4], eax          ; Save delta_phase
    jmp .start_sample_loop

.zero_delta:
    mov dword [esp + 4], 0

.start_sample_loop:
    ; 6. Set up synthesis loop registers:
    ;    EDI = write pointer in sfx_buf (sfx_buf + [sfx_buf_len])
    ;    ESI = sample index t (0 .. N - 1)
    ;    EBP = 32-bit phase accumulator (starts at 0)
    mov edi, sfx_buf
    add edi, [sfx_buf_len]
    xor esi, esi                ; t = 0
    xor ebp, ebp                ; phase = 0

.sample_loop:
    cmp esi, [esp + 8]          ; t == N?
    jae .loop_finished

    ; Fast path for digital silence (A_max == 0)
    cmp dword [esp], 0
    jne .calc_envelope
    mov al, PCM_CENTER          ; 128 (unsigned 8-bit silence)
    mov [edi], al
    inc edi
    inc esi
    jmp .sample_loop

.calc_envelope:
    ; Linear decay envelope: A(t) = A_max * (N - t) / N
    mov eax, [esp + 8]          ; N
    sub eax, esi                ; N - t
    imul eax, [esp]             ; (N - t) * A_max
    xor edx, edx
    div dword [esp + 8]         ; EAX = current envelope amplitude A(t)
    mov ebx, eax                ; EBX = current amplitude A(t)

    ; Synthesize waveform based on waveform ID
    cmp dword [esp + 12], WAVE_SQUARE
    je .gen_square

    ; --- WAVE_TRIANGLE Synthesis ---
    ; High 16 bits of 32-bit phase: H = phase >> 16 (0..65535)
    mov eax, ebp
    shr eax, 16                 ; EAX = H
    cmp eax, 32768
    jae .tri_descending

    ; Ascending half: v = H - 16384 (range -16384 to +16383)
    sub eax, 16384
    jmp .tri_scale

.tri_descending:
    ; Descending half: v = 49152 - H (range -16383 to +16384)
    mov ecx, 49152
    sub ecx, eax
    mov eax, ecx

.tri_scale:
    ; Scale normalized triangle value (-16384..+16384) by current amplitude EBX:
    ; sample_displacement = (v * A(t)) / 16384
    imul eax, ebx
    sar eax, 14                 ; Signed arithmetic shift right by 14 (divides by 16384)
    jmp .apply_center

.gen_square:
    ; --- WAVE_SQUARE Synthesis ---
    ; Phase accumulator MSB (bit 31): 0 = high (+A), 1 = low (-A)
    test ebp, 0x80000000
    jnz .square_low
    mov eax, ebx                ; +A(t)
    jmp .apply_center

.square_low:
    mov eax, ebx
    neg eax                     ; -A(t)

.apply_center:
    ; Add unsigned 8-bit PCM center (128)
    add eax, PCM_CENTER

    ; Clamp to unsigned 8-bit range [0, 255]
    test eax, eax
    jns .check_upper_clamp
    xor eax, eax                ; Clamp negative values to 0
.check_upper_clamp:
    cmp eax, PCM_MAX
    jbe .store_sample
    mov eax, PCM_MAX            ; Clamp overflow values to 255

.store_sample:
    mov [edi], al
    inc edi

    ; Advance phase accumulator by delta_phase
    add ebp, [esp + 4]

    inc esi
    jmp .sample_loop

.loop_finished:
    ; 7. Advance sfx_buf_len by generated sample count N
    mov eax, [esp + 8]
    add [sfx_buf_len], eax

    ; Clean up local stack frame and return N in EAX
    add esp, 20
    restore_regs
    ret

.synth_zero_samples:
    add esp, 20
    xor eax, eax                ; Return 0 samples
    restore_regs
    ret

;=============================================================================
; Procedure: sfx_play
; Purpose:   Public entry point to synthesize and dispatch a sound effect:
;            1. Validates sound ID (1..SFX_COUNT).
;            2. If sound disabled (setting_sound == 0) or volume zero, returns silently.
;            3. If no external player detected:
;               - Falls back to terminal audio bell (0x07) for important events:
;                 SFX_START_CHIRP, SFX_FOCUS_FANFARE, SFX_BREAK_CHIME.
;               - Stays silent for noncritical events (click, sparkle, error, blip, meow).
;            4. If player available:
;               - Synthesizes complete note sequence from sfx_table into sfx_buf.
;               - Creates a pipe (sys_pipe, syscall 42).
;               - Forks a child process (sys_fork, syscall 2).
;               - Child: redirects pipe read end to fd 0, redirects stdout/stderr to
;                 /dev/null, executes player with raw 11025 Hz U8 args via sys_execve,
;                 or calls sys_exit(127) on any failure (no terminal code).
;               - Parent: closes pipe read end, writes PCM payload to pipe write end
;                 in a single write (32 KB fits in default 64 KB Linux pipe), closes
;                 write end, and returns immediately without waiting for player.
; IN:        EAX = Sound effect ID (SFX_START_CHIRP .. SFX_SHORT_MEOW)
; OUT:       EAX = Status (0 = success/dispatched/silent ok, -1 = system failure)
; CLOBBERS:  EAX (preserves EBX, ECX, EDX, ESI, EDI)
;=============================================================================
sfx_play:
    save_regs
    push eax                    ; [esp] = sound_id

    ; 1. Validate sound ID range: 1..SFX_COUNT
    cmp eax, SFX_NONE
    jle .play_silent_exit
    cmp eax, SFX_COUNT
    ja .play_silent_exit

    ; 2. Check settings: sound enabled?
    cmp byte [setting_sound], 1
    jne .play_silent_exit

    ; Check volume: volume nonzero?
    cmp byte [setting_volume], 0
    je .play_silent_exit

    ; 3. Check player availability
    mov edx, [sfx_player_choice]
    cmp edx, PLAYER_NONE
    jne .synthesize_sound

    ; -------------------------------------------------------------------------
    ; Fallback: Terminal Bell for Important Events Only (PRD_V2 §9, §3.6)
    ; Important events: SFX_START_CHIRP (1), SFX_FOCUS_FANFARE (4), SFX_BREAK_CHIME (5)
    ; -------------------------------------------------------------------------
    mov eax, [esp]              ; Retrieve sound_id
    cmp eax, SFX_START_CHIRP
    je .emit_bell_fallback
    cmp eax, SFX_FOCUS_FANFARE
    je .emit_bell_fallback
    cmp eax, SFX_BREAK_CHIME
    je .emit_bell_fallback

    ; Noncritical event without player: remain completely silent
    jmp .play_silent_exit

.emit_bell_fallback:
    ; Emit single terminal bell byte (0x07) to stdout
    syscall SYS_WRITE, FD_STDOUT, sfx_bell_char, 1
    jmp .play_silent_exit

.synthesize_sound:
    ; -------------------------------------------------------------------------
    ; 4. Synthesize Sound Effect into sfx_buf
    ; -------------------------------------------------------------------------
    ; Reset buffer length tracker to 0 before assembling new sequence
    mov dword [sfx_buf_len], 0

    ; Look up sound step table pointer: sfx_table[sound_id * 4]
    mov eax, [esp]              ; sound_id
    mov esi, [sfx_table + eax*4]
    test esi, esi
    jz .play_silent_exit

.step_loop:
    ; Load step: frequency (dword), duration_ms (dword), waveform_id (dword)
    mov eax, [esi]              ; frequency
    mov ecx, [esi + 4]          ; duration_ms
    mov edx, [esi + 8]          ; waveform_id

    ; Check sentinel: freq == 0 AND duration == 0
    mov ebx, eax
    or ebx, ecx
    jz .synthesis_done

    ; Synthesize step note into sfx_buf
    call synth_note

    ; Advance to next 12-byte step record
    add esi, 12
    jmp .step_loop

.synthesis_done:
    ; Verify that valid PCM samples were generated
    cmp dword [sfx_buf_len], 0
    jle .play_silent_exit

    ; -------------------------------------------------------------------------
    ; 5. External Player Process Launch (PRD_V2 §9, §11)
    ; -------------------------------------------------------------------------
    ; Create unidirectional pipe: fds[0] = read, fds[1] = write
    syscall SYS_PIPE, sfx_pipe_fds
    test eax, eax
    js .play_err_pipe

    ; Fork playback child process
    syscall SYS_FORK
    test eax, eax
    js .play_err_fork
    jz .child_process

    ; -------------------------------------------------------------------------
    ; Parent Process Execution Path
    ; -------------------------------------------------------------------------
    ; Close read end of pipe immediately (owned by child)
    syscall SYS_CLOSE, [sfx_pipe_fds]

    ; Write entire synthesized PCM payload in a single sys_write
    ; (32 KB payload is strictly smaller than standard 64 KB Linux pipe capacity)
    syscall SYS_WRITE, [sfx_pipe_fds + 4], sfx_buf, [sfx_buf_len]

    ; Close write end immediately after write to signal EOF to audio player
    syscall SYS_CLOSE, [sfx_pipe_fds + 4]

    ; Return immediately to main application loop without waiting (non-blocking!)
    pop eax
    xor eax, eax                ; 0 = success
    restore_regs
    ret

; -----------------------------------------------------------------------------
; Child Process Execution Path
; -----------------------------------------------------------------------------
.child_process:
    ; Close unused write end of pipe
    syscall SYS_CLOSE, [sfx_pipe_fds + 4]

    ; Redirect pipe read end to standard input (fd 0)
    syscall SYS_DUP2, [sfx_pipe_fds], FD_STDIN
    test eax, eax
    js .child_fatal_exit

    ; Close original read fd if it wasn't already fd 0
    cmp dword [sfx_pipe_fds], FD_STDIN
    je .child_redirect_outputs
    syscall SYS_CLOSE, [sfx_pipe_fds]

.child_redirect_outputs:
    ; Open /dev/null for write access to discard player terminal output
    syscall SYS_OPEN, dev_null_path, O_WRONLY
    test eax, eax
    js .child_fatal_exit
    mov ebx, eax                ; EBX = null_fd

    ; Duplicate /dev/null to stdout (fd 1) and stderr (fd 2)
    syscall SYS_DUP2, ebx, FD_STDOUT
    syscall SYS_DUP2, ebx, 2

    ; Close redundant /dev/null descriptor if > 2
    cmp ebx, 2
    jbe .child_exec
    syscall SYS_CLOSE, ebx

.child_exec:
    ; Select player executable path and argument vector
    cmp dword [sfx_player_choice], PLAYER_PAPLAY
    jne .child_use_aplay

    mov ebx, paplay_path
    mov ecx, paplay_argv
    jmp .child_invoke_exec

.child_use_aplay:
    mov ebx, aplay_path
    mov ecx, aplay_argv

.child_invoke_exec:
    ; Pass inherited process environment pointer (or empty envp fallback)
    mov edx, [sfx_envp]
    test edx, edx
    jnz .child_do_execve
    mov edx, sfx_default_envp

.child_do_execve:
    syscall SYS_EXECVE, ebx, ecx, edx

.child_fatal_exit:
    ; On ANY child-side failure or execve return: exit directly with code 127
    ; CRITICAL: Never call term_restore or application cleanup from child!
    syscall SYS_EXIT, 127

; -----------------------------------------------------------------------------
; Parent Error Recovery Paths
; -----------------------------------------------------------------------------
.play_err_fork:
    ; Fork failed: close both pipe descriptors
    syscall SYS_CLOSE, [sfx_pipe_fds]
    syscall SYS_CLOSE, [sfx_pipe_fds + 4]

.play_err_pipe:
    ; Pipe failed: fall back to bell if important event
    mov eax, [esp]
    cmp eax, SFX_START_CHIRP
    je .err_bell_fallback
    cmp eax, SFX_FOCUS_FANFARE
    je .err_bell_fallback
    cmp eax, SFX_BREAK_CHIME
    je .err_bell_fallback
    jmp .play_err_exit

.err_bell_fallback:
    syscall SYS_WRITE, FD_STDOUT, sfx_bell_char, 1

.play_err_exit:
    pop eax
    mov eax, -1                 ; -1 = error status
    restore_regs
    ret

.play_silent_exit:
    pop eax
    xor eax, eax                ; 0 = silent/no-op ok
    restore_regs
    ret

;=============================================================================
; Procedure: proc_spawn
; Purpose:   General process spawning helper (Task V9 / PRD_V2 §10).
;            Launches an arbitrary executable with an argument vector
;            asynchronously in a child process.
;            Child process redirects stdin to /dev/null (O_RDONLY), redirects
;            stdout and stderr to /dev/null (O_WRONLY), and calls sys_execve.
;            If execve or redirection fails, child calls sys_exit(127) immediately
;            without invoking terminal cleanup or parent application logic.
;            Parent process does not block and returns 0 on success or -1 on failure.
; IN:        ESI = Pointer to NUL-terminated executable path
;            EDI = Pointer to NULL-terminated argv array
; OUT:       EAX = Status (0 = success, -1 = fork/spawn failure)
; CLOBBERS:  EAX (preserves EBX, ECX, EDX, ESI, EDI)
;=============================================================================
proc_spawn:
    save_regs

    ; Fork child process (sys_fork, syscall 2)
    syscall SYS_FORK
    test eax, eax
    js .spawn_fork_fail
    jz .spawn_child

    ; Parent process: return 0 (asynchronous process created successfully)
    xor eax, eax
    restore_regs
    ret

.spawn_fork_fail:
    mov eax, -1                 ; Fork failure
    restore_regs
    ret

.spawn_child:
    ; 1. Redirect stdin from /dev/null (O_RDONLY = 0)
    syscall SYS_OPEN, dev_null_path, O_RDONLY
    test eax, eax
    js .spawn_child_fail
    mov ebx, eax                ; EBX = null_in_fd
    syscall SYS_DUP2, ebx, FD_STDIN
    cmp ebx, FD_STDIN
    je .spawn_open_out
    syscall SYS_CLOSE, ebx

.spawn_open_out:
    ; 2. Open /dev/null for write access for stdout and stderr (O_WRONLY = 1)
    syscall SYS_OPEN, dev_null_path, O_WRONLY
    test eax, eax
    js .spawn_child_fail
    mov ebx, eax                ; EBX = null_out_fd

    ; Duplicate to stdout (1) and stderr (2)
    syscall SYS_DUP2, ebx, FD_STDOUT
    syscall SYS_DUP2, ebx, 2
    cmp ebx, 2
    jbe .spawn_exec
    syscall SYS_CLOSE, ebx

.spawn_exec:
    ; Pass inherited process environment pointer (or empty envp fallback)
    mov edx, [sfx_envp]
    test edx, edx
    jnz .spawn_do_exec
    mov edx, sfx_default_envp

.spawn_do_exec:
    syscall SYS_EXECVE, esi, edi, edx

.spawn_child_fail:
    ; On ANY child-side failure or execve return: exit directly with code 127
    ; CRITICAL: Never call term_restore or application cleanup from child!
    syscall SYS_EXIT, 127
