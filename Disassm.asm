.model small
.stack 100h

.data
    ifn db 13 dup (0)   ; Input file name
    ifh dw 0    ; Input file handle
    ofn db 13 dup (0)   ; Output file name
    ofh dw 1    ; Output file handle

    READ_LENGTH dw 1024
    PRINT_LENGTH dw 1024

    in_buff db 1024 dup (?)
    in_buff_end dw 0    ; Input buffer end
    in_buff_length dw 1024  ; Input buffer length

    eof db 0

    out_buff db 1024 dup (?)
    out_buff_i dw 0

	instr_buff db 50 dup (?)
	instr_length db 0   ; Command string lenght
	instr_pointer dw ?

    ; Disassembler logic
    d_val db 0
    w_val db 0
    reg_val db 0
    mod_val db 0
    rm_val db 0
    port_val db 0
    sreg_val db 0
	skip_h db 0

    ; Messages
    newline db 0Dh, 0Ah, 24h
    open_if_error_msg db "Couldn't open input file$"    ; TURI NEBELIKT arba TURI BUT PAPILDYTAS
    create_of_error_msg db "Couldn't create output file$"  ; TURI NEBELIKT arba TURI BUT PAPILDYTAS
    close_if_error_msg db "Couldn't close input file$"
    close_of_error_msg db "Couldn't close output file$"
    read_file_error_msg db "Error reading file$"
    help_msg db "Usage: disasm [input file] [output file]", 0Dh, 0Ah, 24h
    
    ; Instruction constructor
    special_symbols db " ,[]:+?"
    hex_abc db "0123456789ABCDEF"
    registers db "alcldlblahchdhbhaxcxdxbxspbpsidi"
    rm_0_registers db "bx+sibx+dibp+sibp+di"
    rm_4_registers db "sidibpbx"
    segments db "escsssds"
    is_prefix db 0  ; Checks what (if a) segment was used 

    ;Three-letter commands
    com_3_main db "movpopoutlealdsles"
    com_3_lgic db "notshlshrsarrolrorrclrcrandxor"

    ;Four-letter commands
    com_4_main db "pushxchgxlatlahfsahfpopf"

.code
start:
    mov ax, @data
    mov ds, ax
    xor ax, ax
    jmp read_pars

; Print help message
do_help:
    mov ah, 09h
    mov dx, offset help_msg
    int 21h
    
    jmp clean_exit

read_pars:
    ; If no args, print help
    xor ch, ch
    mov cl, es:[80h]
    cmp cl, 0
    je do_help

    ; If /? print help
    dec cl
    mov si, 82h
    cmp word ptr es:[si], "?/"
    je do_help

    ; Looking for input file name
    read_ifn:
        mov di, offset ifn

        read_ifn_loop:
            mov dl, es:[si]

            cmp dl, " "
            je end_read_ifn

            mov ds:[di], dl

            inc si
            inc di
        loop read_ifn_loop

    ; Checking if input file was provided
    end_read_ifn:
        cmp cl, 0
        je skip_read_ofn
        inc si

    ; Looking for output file name
    read_ofn:
        mov di, offset ofn
        read_ofn_loop:
            mov dl, es:[si]

            cmp dl, 0
            je skip_read_ofn

            cmp dl, 0Dh
            je skip_read_ofn

            mov [di], dl
            inc si
            inc di
        loop read_ofn_loop

    skip_read_ofn:
        mov ax, ds
        mov es, ax
        xor ax, ax

; Open input file
open_if:
    mov ax, 3D00h
    lea dx, ifn
    int 21h
    jc open_if_error
    mov ifh, ax
    jmp create_of

; Error if could't open file
open_if_error:
    lea dx, open_if_error_msg
    call PrintText
    mov ax, 4C00h
    int 21h

; Create output file
create_of:
    mov ax, 3C00h
    xor cx, cx
    lea dx, ofn
    int 21h
    jc create_of_error
    mov ofh, ax
    jmp main_logic

; Error if couldn't create output file
create_of_error:
    lea dx, create_of_error_msg
    call PrintText
    mov ah, 09h
    lea dx, newline
    int 21h

main_logic:
    mov si, offset in_buff
	mov di, offset instr_buff
	mov instr_pointer, di
    mov di, offset out_buff
    
    ; Zero all registers
    xor ax, ax
    xor bx, bx
    xor cx, cx
    xor dx, dx

    main_loop:
        ; Inc to next byte
        call IncSi

        ; Quit if nothing else to read
        cmp eof, 1
        je exit_main_loop

        ; Take one byte from output buffer
        xor dh, dh
        mov dl, ds:[si]
        call CheckInstruction

        cmp ofh, 1
        jne skip_pushspace

        mov cx, 1
        call CheckOutBuff

        skip_pushspace:
            push si
            mov cl, instr_length
            lea si, instr_buff
            call PushToOutBuff
            mov instr_length, 0
            lea si, instr_buff
            mov instr_pointer, si
            pop si
            call PushNewline

        ;Increase input buffer iterator (si) address and check for read and print req's
        cont_main_loop:
            cmp out_buff_i, 1024
            jb main_loop
            call Print
    jmp main_loop

; Print buffer
exit_main_loop:
    call Print

; Closing input file
close_if:
    ; Checking if it was open
    cmp ifh, 0
    je close_of

    mov ah, 3Eh
    mov bx, ifh
    int 21h
    jc close_if_error

    ; Closing the file
    jmp close_of

; Error for closing input file
close_if_error:
    lea dx, close_if_error_msg
    call PrintText

; Closing output file
close_of:
    ; Checking if it was open
    cmp ofh, 1
    je clean_exit

    mov ah, 3Eh
    mov bx, ofh
    int 21h
    jc close_of_error

    ; Going to end the program
    jmp clean_exit

; Error for closing output file
close_of_error:
    lea dx, close_of_error_msg
    int 21h

; Exit
clean_exit:
    mov ax, 4C00h
    int 21h

; Checking the byte that is being examined
proc CheckInstruction
    ; Checking if ES is being used
    cmp dl, 26h
    jne skip_es
    mov is_prefix, 0
    jmp was_segment

    ; Checking if CS is being used
    skip_es:
        cmp dl, 2Eh
        jne skip_cs
        mov is_prefix, 1
        jmp was_segment

    ; Checking if SS is being used
    skip_cs:
        cmp dl, 36h
        jne skip_ss
        mov is_prefix, 2
        jmp was_segment

    ; Checking if DS is being used
    skip_ss:
        cmp dl, 3Eh
        jne skip_ds
        mov is_prefix, 3
        jmp was_segment

    ; Prefix wasn't used
    skip_ds:
        mov is_prefix, 4
        jmp was_not_segment

    was_segment:
        call IncSi
        mov dl, byte ptr [si]
    
    ; Checking for 1 mov version
    was_not_segment:
        mov al, dl
        xor al, 10001000b
        cmp al, 4
        jae skip_mov_1
        call parse_mov_1
        ret

    ; Checking for 2 mov version
    skip_mov_1:
        mov al, dl
        xor al, 11000110b
        cmp al, 2
        jae skip_mov_2
        call parse_mov_2
        ret

    ; Checking for 3 mov version
    skip_mov_2:
        mov al, dl
        xor al, 10110000b
        cmp al, 16
        jae skip_mov_3
        call parse_mov_3
        ret

    ; Checking for 4 or 5 mov version
    skip_mov_3:
        mov al, dl
        xor al, 10100000b
        cmp al, 4
        jae skip_mov_45
        call parse_mov_45
        ret

    ; Checking for 6 mov version
    skip_mov_45:
        mov al, dl
        xor al, 10001100b
        shr al, 1
        cmp al, 2
        jae skip_mov_6
        call parse_mov_6
        ret

    ; Checking for 1 out version
    skip_mov_6:
        mov al, dl
        xor al, 11100110b
        cmp al, 2
        jae skip_out_1
        call parse_out_1
        ret

    ; Checking for 2 out version
    skip_out_1:
        mov al, dl
        xor al, 11101110b
        cmp al, 2
        jae skip_out_2
        call parse_out_2
        ret

    ; Checking for not
    skip_out_2:
        mov al, dl
        xor al, 11110110b
        cmp al, 2
        jae skip_not
        call parse_not
        ret

    ; checking for rcr
    skip_not:
        mov al, dl
        xor al, 11010000b
        cmp al, 4
        jae skip_rcr
        call parse_rcr
        ret

    ; checking for xlat
    skip_rcr:
        mov al, dl
        xor al, 11010111b
        cmp al, 1
        jae skip_xlat
        call parse_xlat
        ret

    ; If none of the above program puts ? into buffer
    skip_xlat:
        mov bx, 6
        call PushSpecialSymbol
        ret
endp CheckInstruction

proc Read
    push ax
    push bx
    push cx
    push dx     
    
    ; Reading values from input file
    read_from_file:
        mov ah, 3Fh
        mov bx, ifh
        mov cx, READ_LENGTH
        lea dx, in_buff
        int 21h
        jnc read_file_success

    ; Error for file read
    read_file_error:
        mov ah, 09h
        lea dx, read_file_error_msg
        int 21h

    read_file_success:
        mov si, offset in_buff
        mov in_buff_end, si
        add in_buff_end, ax
        mov in_buff_length, ax
    
    pop dx
    pop cx
    pop bx
    pop ax

    ret
endp Read

; Printing buffer
proc Print
    push ax
    push bx
    push cx
    push dx
    
    ; Print
    mov ah, 40h
    mov bx, ofh
    mov cx, out_buff_i
    lea dx, out_buff
    int 21h

    ; Move cursor to the begining
    mov out_buff_i, 0
    mov di, offset out_buff

    pop dx
    pop cx
    pop bx
    pop ax
    ret
endp Print

; Move on to the next byte
proc IncSi
	push dx
	
    ; If not in buffer end, there is nothing to read anymore
    cmp si, in_buff_end
    jb checkinbuff_skip_read

    ; If we are at the end of buffer we need to read further
    cmp in_buff_length, 1024
    je inc_si_read

    ; Last case this is EOF
    mov eof, 1
    pop dx
    ret

    ; Read new buffer
    inc_si_read:
        call Read
        jmp skip_incsi

    ; Taking next byte
    checkinbuff_skip_read:
        inc si

    skip_incsi:
	    pop dx

    ret
endp IncSi

proc CheckOutBuff
    push ax

    mov ax, out_buff_i
    add ax, cx
    cmp ax, PRINT_LENGTH
    jbe checkoutbuff_skip_print
    call Print

    checkoutbuff_skip_print:
        pop ax
        ret
endp CheckOutBuff

;Push cx characters from ds:si to output buffer (es:di)
proc PushToOutBuff
    call CheckOutBuff
    add out_buff_i, cx
    rep movsb

    ret
endp PushToOutBuff

; Saves string to buffer
proc PushToBuffer
	push di

	add instr_length, cl    ; Increase str length
	mov di, instr_pointer   
	rep movsb
	mov instr_pointer, di

	pop di
    
	ret
endp PushToBuffer

; Puts special symbol into buffer
proc PushSpecialSymbol
    push si

    mov cx, 1
    lea si, special_symbols + bx
    call PushToBuffer

    pop si

    ret
endp PushSpecialSymbol

; Converts ascii hex to hex
proc PushHexValue
    push ax
    xor ah, ah
    push si
	push di
	mov di, instr_pointer

    mov al, dl
    and al, 0F0h
    shr al, 4
    lea si, hex_abc
    add si, ax
    movsb

    mov al, dl
    and al, 0Fh
    lea si, hex_abc
    add si, ax
    movsb

    add instr_length, 2

	cmp skip_h, 1
	je pushhexvalue_skip_h
    mov byte ptr [di], "h"
    inc di
    inc instr_length

    pushhexvalue_skip_h:
        mov instr_pointer, di
        pop di
        pop si
        pop ax

        ret
endp PushHexValue

; Puts newline into file
proc PushNewline
    mov cx, 2
    call CheckOutBuff

    mov byte ptr [di], 13
    inc di
    mov byte ptr [di], 10
    inc di

    add out_buff_i, 2
    ret
endp PushNewline

; Print text until $ and then add a newline
proc PrintText
    push ax

    mov ah, 09h
    int 21h
    lea dx, newline
    int 21h

    pop ax
    ret
endp PrintText

; Puts offset to output buffer
proc PushOffset
    mov bx, 5
    call PushSpecialSymbol
    call read_bytes
    call PushHexValue

    ret
endp PushOffset

proc read_bytes
    xor dh, dh
    call IncSi

    mov dl, [si]
    cmp mod_val, 01b
    je read_b_offset

    call IncSi
    mov dh, [si]

    read_b_offset:
        ret
endp read_bytes

proc read_w_bytes
    xor dh, dh
    call IncSi
    mov dl, [si]
    cmp w_val, 0
    je read_w_b_offset
    call IncSi
    mov dh, [si]
    read_w_b_offset:

    ret
endp read_w_bytes

proc parse_dwmodregrm
    mov al, dl
    and al, 1b
    mov w_val, al

    mov al, dl
    and al, 10b
    shr al, 1
    mov d_val, al
    
    call IncSi
    mov dl, byte ptr [si]

    mov al, dl
    and al, 11000000b
    shr al, 6
    mov mod_val, al

    mov al, dl
    and al, 111000b
    shr al, 3
    mov reg_val, al

    mov al, dl
    and al, 111b
    mov rm_val, al

    ret
endp parse_dwmodregrm

proc parse_reg
    push si
    xor bh, bh

    lea si, registers
    mov bl, reg_val
    cmp w_val, 0
    je parse_reg_skip_add
    add bx, 8
    parse_reg_skip_add:
    add bx, bx
    add si, bx
    mov cx, 2
    call PushToBuffer

    pop si
    ret
endp parse_reg

proc parse_sreg
    push si
    xor bh, bh

    lea si, segments
    mov bl, sreg_val
    add bx, bx
    add si, bx
    mov cx, 2
    call PushToBuffer

    pop si
    ret
endp parse_sreg

proc parse_rm
    cmp mod_val, 11b
    jne parse_rm_skip_mod11
    mov al, rm_val
    mov reg_val, al
    call parse_reg
    ret

    parse_rm_skip_mod11:
        cmp is_prefix, 4
        je parse_rm_no_prefix
        mov al, is_prefix
        mov sreg_val, al
        call parse_sreg
        
        mov bx, 4
        call PushSpecialSymbol

    parse_rm_no_prefix:
        mov bx, 2
        call PushSpecialSymbol

        cmp rm_val, 100b
        jb parse_rm_0

        cmp rm_val, 110b
        jne parse_rm_skip_direct

        cmp mod_val, 00b
        jne parse_rm_skip_direct
        
        call read_bytes
        call PushHexValue
        
        mov bx, 3
        call PushSpecialSymbol
        ret

    parse_rm_skip_direct:
        push si
        xor bh, bh
        mov bl, rm_val
        sub bl, 4
        add bl, bl
        mov cx, 2
        lea si, rm_4_registers+bx
        call PushToBuffer
        pop si
        
        cmp mod_val, 00b
        je parse_rm_4_no_offset
        call PushOffset

    parse_rm_4_no_offset:
        mov bx, 3
        call PushSpecialSymbol
        ret

    parse_rm_0:
        push si
        xor bh, bh
        mov bl, rm_val
        mov cx, 5
        mov al, bl
        mul cl
        mov bl, al
        lea si, rm_0_registers+bx
        call PushToBuffer
        pop si

        cmp mod_val, 00b
        je parse_rm_0_no_offset
        call PushOffset

    parse_rm_0_no_offset:
        mov bx, 3
        call PushSpecialSymbol
        
        ret
endp parse_rm

; Puting MOV into instruction string begining
proc parse_mov
    push si

    ; Put a command name into instuction string
    mov cx, 3
    lea si, com_3_main
    call PushToBuffer

    ; Put a space into instruction string
    mov bx, 0
    call PushSpecialSymbol

    pop si
    ret
endp parse_mov

proc parse_mov_1
    xor bx, bx

    call parse_mov
    call parse_dwmodregrm
    cmp d_val, 1
    je parse_mov_1_d1
    ;parse_mov_1_d0:
    call parse_rm
    mov bx, 1
    call PushSpecialSymbol
    mov bx, 0
    call PushSpecialSymbol
    call parse_reg
    jmp parse_mov_1_end
    parse_mov_1_d1:
    call parse_reg
    mov bx, 1
    call PushSpecialSymbol
    mov bx, 0
    call PushSpecialSymbol
    call parse_rm
    parse_mov_1_end:
    
    ret
endp parse_mov_1

proc parse_mov_2
    call parse_mov
    call parse_dwmodregrm
    call parse_rm
    mov bx, 1
    call PushSpecialSymbol
    mov bx, 0
    call PushSpecialSymbol
    call read_w_bytes
    call PushHexValue
    ret
endp parse_mov_2

proc parse_mov_3
    mov al, dl
    and al, 111b
    mov reg_val, al

    mov al, dl
    and al, 1000b
    shr al, 3
    mov w_val, al

    call parse_mov
    call parse_reg
    mov bx, 1
    call PushSpecialSymbol
    mov bx, 0
    call PushSpecialSymbol
    call read_w_bytes
    call PushHexValue
    ret
endp parse_mov_3

proc parse_mov_45
    mov al, dl
    and al, 1
    mov w_val, al

    mov al, dl
    and al, 10b
    shr al, 1
    mov d_val, al

    mov mod_val, 0
    mov reg_val, 0
    mov rm_val, 110b

    cmp is_prefix, 4
    jne parse_mov_45_already_segment
    dec is_prefix
    parse_mov_45_already_segment:

    call parse_mov
    cmp d_val, 1
    je parse_mov_45_d1
    ;parse_mov_45_d0:
    call parse_reg
    mov bx, 1
    call PushSpecialSymbol
    mov bx, 0
    call PushSpecialSymbol
    call parse_rm
    ret
    parse_mov_45_d1:
    call parse_rm
    mov bx, 1
    call PushSpecialSymbol
    mov bx, 0
    call PushSpecialSymbol
    call parse_reg
    ret
endp parse_mov_45

proc parse_mov_6
    push dx
    call parse_mov
    call parse_dwmodregrm
    pop dx

    mov al, dl
    and al, 10b
    shr al, 1
    mov d_val, al

    mov w_val, 1

    mov al, reg_val
    mov sreg_val, al

    cmp d_val, 0
    jne parse_mov_6_d1
    call parse_rm
    mov bx, 1
    call PushSpecialSymbol
    mov bx, 0
    call PushSpecialSymbol
    call parse_sreg
    ret
    parse_mov_6_d1:
    call parse_sreg
    mov bx, 1
    call PushSpecialSymbol
    mov bx, 0
    call PushSpecialSymbol
    call parse_rm
    ret
endp parse_mov_6

; Puting OUT into instruction string begining
proc parse_out
    push si
    
    ; Put a command name into instuction string
    mov cx, 3
    lea si, com_3_main+6
    call PushToBuffer

    ; Put a space into instruction string
    pop si
    mov bx, 0
    call PushSpecialSymbol

    ret
endp parse_out

proc parse_out_1
    push dx

    mov w_val, 0
    call read_w_bytes
    mov port_val, dl
    pop dx

    mov al, dl
    and al, 1
    mov w_val, al
    mov reg_val, 000
    
    call parse_out
    push dx
    xor dh, dh
    mov dl, port_val
    call PushHexValue
    pop dx
    mov bx, 1
    call PushSpecialSymbol
    mov bx, 0
    call PushSpecialSymbol
    call parse_reg

    ret
endp parse_out_1

proc parse_out_2
    push dx
    call parse_out
    mov w_val, 1
    mov reg_val, 010b
    call parse_reg
    
    pop dx
    mov al, dl
    and al, 1
    mov w_val, al
    
    mov bx, 1
    call PushSpecialSymbol
    mov bx, 0
    call PushSpecialSymbol
    
    mov reg_val, 0
    call parse_reg
    
    ret
endp parse_out_2

; Puting NOT into instruction string begining
proc parse_not
    call parse_dwmodregrm
    
    ; Put a command name into instuction string
    push si
    mov cx, 3
    lea si, com_3_lgic
    call PushToBuffer

    ; Put a space into instruction string
    pop si
    mov bx, 0
    call PushSpecialSymbol
    
    call parse_rm
    
    ret
endp parse_not

; Puting RCR into instruction string begining
proc parse_rcr
    call parse_dwmodregrm
    
    push si

    ; Put a command name into instuction string
    mov cx, 3
    mov si, offset com_3_lgic + 21
    call PushToBuffer

    ; Put a space into instruction string
    pop si
    mov bx, 0
    call PushSpecialSymbol
    
    call parse_rm
    mov bx, 1
    call PushSpecialSymbol
    mov bx, 0
    call PushSpecialSymbol
    cmp d_val, 1
    je parse_rcr_v1
    push di
    mov di, instr_pointer
    mov byte ptr [di], "1"
    inc di
    inc instr_length
    mov instr_pointer, di
    pop di
    ret
    parse_rcr_v1:
    mov w_val, 0
	mov reg_val, 001b
    call parse_reg
    
    ret
endp parse_rcr

; Puting XLAT into instruction string begining
proc parse_xlat
    push si

    ; Move str name into instruction buffer
    mov cx, 4
    mov si, offset com_4_main + 8
    call PushToBuffer

    pop si

    ret
endp parse_xlat

end start