.model small
.stack 100h

.data
    ifn db 13 dup (0)   ; Input name
    ifh dw 0    ; Input handle
    ofn db 13 dup (0)   ; Output
    ofh dw 1    ; Output file handle

    READ_LENGTH dw 1024
    PRINT_LENGTH dw 1024

    in_buff db 1024 dup (?)
    in_buff_end dw 0    ; Input buff end
    in_buff_length dw 1024  ; Inut buff length

    ip_val dw 0

    eof db 0    ; Marks EOF

    out_buff db 1024 dup (?)    ; Output buff
    out_buff_i dw 0

	instr_buff db 50 dup (?)
	instr_length db 0   ; Legth of the command that is being examined
	instr_pointer dw ?

    ; Disassembler logic
    d_val db 0
    w_val db 0
    reg_val db 0
    mod_val db 0
    rm_val db 0
    port_val db 0
    sreg_val db 0
    force_hex db 0
	skip_h db 0

    ; Messages
    newline db 0Dh, 0Ah, 24h
    open_if_error_msg db "Input file could not be opened$"
    create_of_error_msg db "Output file could not be created$"
    close_if_error_msg db "Couldn't close input file$"
    close_of_error_msg db "Couldn't close output file$"
    read_file_error_msg db "Error reading file$"
    end_msg db "end"
    help_msg db "Usage: disassm.exe input.com output.asm", 0Dh, 0Ah, 24h
    
    ; Instruction constructors
    special_symbols db " ,[]:+"
    hex_abc db "0123456789ABCDEF"
    registers db "alcldlblahchdhbhaxcxdxbxspbpsidi"
    rm_0_registers db "bx+sibx+dibp+sibp+di"
    rm_4_registers db "sidibpbx"
    segments db "escsssds"
    is_prefix db 0  ; Tells what segment and if it was used
    instructions db "movoutnotrcrxlat" ; Instruction set
    unidentified db "???"

.code
start:
    mov ax, @data
    mov ds, ax
    xor ax, ax
    jmp read_pars

; Print help
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

    ; If asks for help
    dec cl
    mov si, 82h
    cmp word ptr es:[si], "?/"
    je do_help

    ; Searching for input file name
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

    ; Searching for a file
    end_read_ifn:
        cmp cl, 0
        je skip_read_ofn
        inc si

    ; Searching or input file name
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

    ; Saving addr
    skip_read_ofn:
        mov ax, ds
        mov es, ax
        xor ax, ax

; Opening input file
open_if:
    mov ax, 3D00h
    mov dx, offset ifn
    int 21h
    jc open_if_error
    mov ifh, ax
    jmp create_of

; jeigu nepavyksta sukurti ivesties failo, tai ismetam klaida, pabaigiam programa
open_if_error:
    mov dx, offset open_if_error_msg
    call PrintText
    mov ax, 4C00h
    int 21h

; sukuriamas isvesties failas
create_of:
    mov ax, 3C00h
    xor cx, cx
    mov dx, offset ofn
    int 21h
    jc create_of_error
    mov ofh, ax
    jmp main_logic

; jeigu nepavyksta sukurti isvesties failo, ismetam klaida, viska spausdinam i konsole
create_of_error:
    mov dx, offset create_of_error_msg
    call PrintText

main_logic:
    ; nustatom kursoriu pradines reiksmes
    mov si, offset in_buff
	mov di, offset instr_buff
	mov instr_pointer, di
    mov di, offset out_buff
    
    ; nunulinam visus reg.
    xor ax, ax
    xor bx, bx
    xor cx, cx
    xor dx, dx

    main_loop:
        ; sokam prie sekancio baito
        call PushIp
        call IncSi

        ; jeigu nebeturim, ka skaityt, einam lauk
        cmp eof, 1
        je exit_main_loop

        ; nuimam viena baita is ivesties buferio
        xor dh, dh
        mov dl, ds:[si]
        call CheckInstruction

        ; cmp ofh, 1
        ; jne skip_pushspace

        mov cx, 1
        call CheckOutBuff

        mov byte ptr [di], " "
        inc di
        inc out_buff_i

        skip_pushspace:
            push si
            mov cl, instr_length
            mov si, offset instr_buff
            call PushToOutBuff
            mov instr_length, 0
            mov si, offset instr_buff
            mov instr_pointer, si
            pop si
            call PushNewline

        ;Increase input buffer iterator (si) address and check for read and print req's
        cont_main_loop:
            cmp out_buff_i, 1024
            jb main_loop
            call Print
    jmp main_loop

; isspausdinam buferi
exit_main_loop:
    mov cx, 3
    mov si, offset end_msg
    call PushToOutBuff
    call Print

; uzdarom ivesties faila
close_if:
    ; tikrinam, ar ivesties failas is viso buvo atidarytas
    cmp ifh, 0
    je close_of

    mov ah, 3Eh
    mov bx, ifh
    int 21h
    jc close_if_error

    ; keliaujam uzdarineti isvesties failo
    jmp close_of

; isvedam zinute, jeigu neisejo uzdaryti ivesties failo
close_if_error:
    mov dx, offset close_if_error_msg
    call PrintText

; uzdarom isvesties faila
close_of:
    ; tikrinam, ar isvesties failas is viso buvo atidarytas
    cmp ofh, 1
    je clean_exit

    mov ah, 3Eh
    mov bx, ofh
    int 21h
    jc close_of_error

    ; keliaujam pabaigineti programa
    jmp clean_exit

; isvedam zinute, jeigu neisejo uzdaryti isvesties failo
close_of_error:
    mov dx, offset close_of_error_msg
    int 21h

; pabaigiam programa
clean_exit:
    mov ax, 4C00h
    int 21h

; funkc., tikrinanti, kas toks yra nagrinejamas baitas
proc CheckInstruction
    ; tikrinam, ar yra naudojamas ES segmentas
    cmp dl, 26h
    jne skip_es
    mov is_prefix, 0
    jmp was_segment

    ; tikrinam, ar yra naudojamas CS segmentas
    skip_es:
        cmp dl, 2Eh
        jne skip_cs
        mov is_prefix, 1
        jmp was_segment

    ; tikrinam, ar yra naudojamas SS segmentas
    skip_cs:
        cmp dl, 36h
        jne skip_ss
        mov is_prefix, 2
        jmp was_segment

    ; tikrinam, ar yra naudojamas DS segmentas
    skip_ss:
        cmp dl, 3Eh
        jne skip_ds
        mov is_prefix, 3
        jmp was_segment

    ; prefiksas nebuvo naudojamas
    skip_ds:
        mov is_prefix, 4
        jmp was_not_segment

    was_segment:
        call IncSi
        mov dl, byte ptr [si]
    
    ; ziurim, ar tai yra 1 MOV'o versija
    was_not_segment:
        mov al, dl
        xor al, 10001000b
        cmp al, 4
        jae skip_mov_1
        call parse_mov_1
        ret

    ; ziurim, ar tai yra 2 MOV'o versija
    skip_mov_1:
        mov al, dl
        xor al, 11000110b
        cmp al, 2
        jae skip_mov_2
        call parse_mov_2
        ret

    ; ziurim, ar tai yra 3 MOV'o versija
    skip_mov_2:
        mov al, dl
        xor al, 10110000b
        cmp al, 16
        jae skip_mov_3
        call parse_mov_3
        ret

    ; ziurim, ar tai yra 4 arba 5 MOV'o versija
    skip_mov_3:
        mov al, dl
        xor al, 10100000b
        cmp al, 4
        jae skip_mov_45
        call parse_mov_45
        ret

    ; ziurim, ar tai yra 6 MOV'o versija
    skip_mov_45:
        mov al, dl
        xor al, 10001100b
        shr al, 1
        cmp al, 2
        jae skip_mov_6
        call parse_mov_6
        ret

    ; ziurim, ar tai yra 1 OUT'o versija
    skip_mov_6:
        mov al, dl
        xor al, 11100110b
        cmp al, 2
        jae skip_out_1
        call parse_out_1
        ret

    ; ziurim, ar tai yra 2 OUT'o versija
    skip_out_1:
        mov al, dl
        xor al, 11101110b
        cmp al, 2
        jae skip_out_2
        call parse_out_2
        ret

    ; ziurim, ar tai yra NOT
    skip_out_2:
        mov al, dl
        xor al, 11110110b
        cmp al, 2
        jae skip_not
        call parse_not
        ret

    ; ziurim, ar tai yra RCR
    skip_not:
        mov al, dl
        xor al, 11010000b
        cmp al, 4
        jae skip_rcr
        call parse_rcr
        ret

    ; ziurim, ar tai yra XLAT
    skip_rcr:
        mov al, dl
        xor al, 11010111b
        cmp al, 1
        jae skip_xlat
        call parse_xlat
        ret

    ; jeigu nei viena komanda is auksciau neatitiko, tai tokios komandos sis disassembleris nesupranta, todel i buferi imetam klaustuko simboli
    skip_xlat:
        push si

        mov cx, 3
        mov si, offset unidentified
        call PushToBuffer

        pop si
        ret
endp CheckInstruction

; funkc., nuskaitanti buferi
proc Read
    push ax
    push bx
    push cx
    push dx     
    
    ; skaitom reiksmes is ivesties failo
    read_from_file:
        mov ah, 3Fh
        mov bx, ifh
        mov cx, READ_LENGTH
        mov dx, offset in_buff
        int 21h
        jnc read_file_success

    ; isspausdinam klaida i konsole
    read_file_error:
        mov ah, 09h
        mov dx, offset read_file_error_msg
        int 21h

    ; nusistatom kursoriu reiksmes
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

; funkc., isspausdinanti buferi
proc Print
    push ax
    push bx
    push cx
    push dx
    
    ; isspausdinam buferi
    mov ah, 40h
    mov bx, ofh
    mov cx, out_buff_i
    mov dx, offset out_buff
    int 21h

    ; nukeliam kursoriu i pradzia
    mov out_buff_i, 0
    mov di, offset out_buff

    pop dx
    pop cx
    pop bx
    pop ax
    ret
endp Print

; nusokam prie sekancio baito
proc IncSi
	push dx
	
    ; ziurim ar mes nesan buferio pabaigoj, jei ne, tai skaityt nieko nereikia
    cmp si, in_buff_end
    jb checkinbuff_skip_read

    ; jeigu mes esam buferio pabaigoj, tai reikia bandyt skaityt dar karta
    cmp in_buff_length, 1024
    je inc_si_read

    ; kitu atveju, tai yra failo pabaiga
    mov eof, 1
    pop dx
    ret

    ; perskaitom nauja buferi
    inc_si_read:
        call Read
        jmp skip_incsi

    ; tiesiog paimam sekanti baita
    checkinbuff_skip_read:
        inc si

    skip_incsi:
        inc ip_val

    xor dh, dh
	mov skip_h, 1
	mov dl, byte ptr [si]
	call PushOutHexValue
	mov skip_h, 0

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

proc PushToOutBuff
    call CheckOutBuff
    add out_buff_i, cx
    rep movsb

    ret
endp PushToOutBuff

; funkc., issauganti str i buferi
proc PushToBuffer
	push di

	add instr_length, cl    ; padidinam einamos instrukcijos str ilgi
	mov di, instr_pointer   ; idedame instrukcijos pradzios adr.
	rep movsb
	mov instr_pointer, di

	pop di
    
	ret
endp PushToBuffer

; funkc., reikalinga ideti spec. simb. i buferi
proc PushSpecialSymbol
    push si

    mov cx, 1
    lea si, special_symbols + bx
    call PushToBuffer

    pop si

    ret
endp PushSpecialSymbol


proc PushOutHexValue
    ;dx is word value to be pushed
    push ax
    xor ah, ah
    push si

	mov cx, 5
	call CheckOutBuff
	
    cmp force_hex, 1
    je pushouthexvalue_force
    cmp dh, 0
    je pushouthexvalue_byte
    pushouthexvalue_force:
    mov al, dh
    and al, 0F0h
    shr al, 4
    lea si, hex_abc
    add si, ax
    movsb
    
    mov al, dh
    and al, 0Fh
    lea si, hex_abc
    add si, ax
    movsb

    add out_buff_i, 2

    pushouthexvalue_byte:
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

    add out_buff_i, 2

    cmp force_hex, 1
    je pushouthexvalue_skip_h
	cmp skip_h, 1
	je pushouthexvalue_skip_h
    mov byte ptr [di], "h"
    inc di
    inc out_buff_i
    pushouthexvalue_skip_h:

    pop si
    pop ax
    ret
endp PushOutHexValue

; funkc. konvertuojanti ascii 16-ainius simbol. i realius 16-ainius simbol.
proc PushHexValue
    push ax
    xor ah, ah
    push si
	push di
	mov di, instr_pointer

    ; patikrinti ar reikia rasyti du baitus
    cmp dh, 0
    je pushhexvalue_byte

    ; konvertuoja pirmaji baita
    pushhexvalue_force:
        mov al, dh
        and al, 0F0h
        shr al, 4
        lea si, hex_abc
        add si, ax
        movsb
    
    mov al, dh
    and al, 0Fh
    lea si, hex_abc
    add si, ax
    movsb

    add instr_length, 2

    ; konvertuojam ascii simb. i hex simb.
    pushhexvalue_byte:
    mov al, dl
    and al, 0F0h
    shr al, 4
    mov si, offset hex_abc
    add si, ax
    movsb

    mov al, dl
    and al, 0Fh
    mov si, offset hex_abc
    add si, ax
    movsb

    add instr_length, 2

    ; pridedam h raide prie 16-ainiu simb.
    mov byte ptr [di], "h"
    inc di
    inc instr_length

    mov instr_pointer, di
    pop di
    pop si
    pop ax

    ret
endp PushHexValue

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

; isspausdinu teksta ir veliau isspausdinu nauja eilute
proc PrintText
    push ax

    mov ah, 09h
    int 21h

    mov dx, offset newline
    int 21h

    pop ax
    ret
endp PrintText

proc PushIp
    push dx
    mov force_hex, 1
    mov dx, ip_val
    call PushOutHexValue
    pop dx
    mov force_hex, 0
    
    mov cx, 2
    call CheckOutBuff
    mov byte ptr [di], ":"
    inc di
    mov byte ptr [di], " "
    inc di
    add out_buff_i, 2

    ret
endp PushIp

; i isvedimo buferi ideda poslinki
proc PushOffset
    ; i buferi idedame pliusa
    mov bx, 5
    call PushSpecialSymbol

    ; nuskaitome poslinki ir idedame ji i isvedimo buferi
    call read_bytes
    call PushHexValue

    ret
endp PushOffset

; funkc., reikalinga perskaityti 2 sekancius baitus
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
    ; nustatome, ar w reiksme
    mov al, dl
    and al, 1b
    mov w_val, al

    ; nustatome, ar w reiksme
    mov al, dl
    and al, 10b
    shr al, 1
    mov d_val, al
    
    ; imam sekanti baita
    call IncSi
    mov dl, byte ptr [si]

    ; nustatome mod reiksme
    mov al, dl
    and al, 11000000b
    shr al, 6
    mov mod_val, al

    ;reg_val
    mov al, dl
    and al, 111000b
    shr al, 3
    mov reg_val, al

    ; nustatome r/m reiksmes
    mov al, dl
    and al, 111b
    mov rm_val, al

    ret
endp parse_dwmodregrm

proc parse_reg
    push si
    xor bh, bh

    ; pasiimam visus reg.
    mov si, offset registers

    ; pasiziurim, kuri registra mes naudosim
    mov bl, reg_val

    ; pasiziurim, kokio dydzio mes registrus naudosim
    cmp w_val, 0
    je parse_reg_skip_add

    ; praleidziam vieno baito registrus
    add bx, 8

    ; nustatom registra
    parse_reg_skip_add:
        add bx, bx
        add si, bx

    ; isprintinam registra i buferi
    mov cx, 2
    call PushToBuffer

    pop si
    ret
endp parse_reg

proc parse_sreg
    push si
    xor bh, bh

    mov si, offset segments
    mov bl, sreg_val
    add bx, bx
    add si, bx
    mov cx, 2
    call PushToBuffer

    pop si
    ret
endp parse_sreg

proc parse_rm
    ; ziurim ar mod nelygus 11, jei tai, tai 
    cmp mod_val, 11b
    jne parse_rm_skip_mod11

    mov al, rm_val
    mov reg_val, al
    call parse_reg
    ret

    ; mod galimos reiksmes: 00, 01, 10
    parse_rm_skip_mod11:
        ; ziurim ar buvo naudojamas prefiksas
        cmp is_prefix, 4
        je parse_rm_no_prefix


        mov al, is_prefix
        mov sreg_val, al
        call parse_sreg
        
        mov bx, 4
        call PushSpecialSymbol

    ; prefiksas nebuvo naudojamas
    parse_rm_no_prefix:
        mov bx, 2
        call PushSpecialSymbol

        cmp rm_val, 100b
        jb parse_rm_0

        cmp rm_val, 110b
        jne parse_rm_skip_direct

        cmp mod_val, 00b
        jne parse_rm_skip_direct
        
        ;parse_rm_direct:
        call read_bytes
        call PushHexValue
        
        mov bx, 3
        call PushSpecialSymbol
        ret

    parse_rm_skip_direct:
        ;parse_rm_4:
        push si
        xor bh, bh
        mov bl, rm_val
        sub bl, 4
        add bl, bl
        mov cx, 2
        lea si, rm_4_registers + bx
        call PushToBuffer
        pop si
        
        cmp mod_val, 00b
        je parse_rm_4_no_offset
        ;parse_rm_4_offset:
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
        lea si, rm_0_registers + bx
        call PushToBuffer
        pop si

        cmp mod_val, 00b
        je parse_rm_0_no_offset
        ;parse_rm_0_offset:
        call PushOffset

    parse_rm_0_no_offset:
        mov bx, 3
        call PushSpecialSymbol
        
        ret
endp parse_rm

; funkc. irasanti MOV i instrukcijos str pradzia
proc parse_mov
    push si

    ; imetam i instrukcijos str komandos pavadinima
    mov cx, 3
    mov si, offset instructions
    call PushToBuffer

    ; imetam i instrukcijos str tarpa
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

; funkc. irasanti OUT i instrukcijos str pradzia
proc parse_out
    push si
    
    ; imetam i instrukcijos str komandos pavadinima
    mov cx, 3
    mov si, offset instructions + 3
    call PushToBuffer

    ; imetam i instrukcijos str tarpa
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

; funkc. irasanti NOT i instrukcijos str pradzia (daugiau nieko ir nebereikes)
proc parse_not
    call parse_dwmodregrm
    
    ; imetam i instrukcijos str komandos pavadinima
    push si
    mov cx, 3
    mov si, offset instructions + 6
    call PushToBuffer

    ; imetam i instrukcijos str tarpa
    pop si
    mov bx, 0
    call PushSpecialSymbol
    
    call parse_rm
    
    ret
endp parse_not

; funkc. irasanti RCR i instrukcijos str pradzia (daugiau nieko ir nebereikes)
proc parse_rcr
    call parse_dwmodregrm
    
    push si

    ; imetam i instrukcijos str komandos pavadinima
    mov cx, 3
    mov si, offset instructions + 9
    call PushToBuffer

    ; imetam i instrukcijos str tarpa
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
    ;parse_rcr_v0:
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

; funkc. irasanti XLAT i instrukcijos str pradzia (daugiau nieko ir nebereikes)
proc parse_xlat
    push si

    ; imetam i instrukcijos str komandos pavadinima
    mov cx, 4
    mov si, offset instructions + 12
    call PushToBuffer

    pop si

    ret
endp parse_xlat

end start