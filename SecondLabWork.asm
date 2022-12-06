.model small
.386
.stack 100h
.data
    lowerCaseCount dw 0
    capitalsCount dw 0
    symbolsCount dw 0
    WordsCount dw 1
    spaceCount dw 0
    h dw 0
    fileNameLength db 0
    dataNames db 20 dup(?)
    fileName db 256 dup(0)
    buffer db 255 dup(?)
    helpMessage db "When launching the program please enter the names of files you wish to work with.$", 10, 13
    fileError db "Unable to open specified file. File might not exist.$"
    lowerCaseOutput db 13, 10, "Lower case letters count: $"
	capitalsOutput db 13, 10, "Capital letters count: $"
	symbolsOutput db 13, 10, "Symbols count: $"
	wordsOutput db 13, 10, "Words count: $"
    newLine db 13, 10, '$'

.code
START:
    mov ax, @data
    mov ds, ax

    mov bx, 82h ;address where text saved from command line is saved
    mov si, offset fileName

    CMP byte ptr es:[80h], 0 ; checks if there are any arguments
    JE helpCall

    mov cl, byte ptr es:[80h] ; save the length of the argument

    readFileName:
        loop1:
            CMP byte ptr es:[bx], 32
            JE openFile

            CMP byte ptr es:[bx], 13
            JE openFile

            mov dl, byte ptr es:[bx]
            mov [si], dl

            INC si
            INC fileNameLength
            JMP sameFile

            continue:
                pop bx
                pop cx
            sameFile:
                INC bx

            LOOP loop1
            JMP close1

    openFile:
        push cx
        push bx

        mov dx, offset fileName
        mov ax, 3d00h ;opens a file, zero isn't needed at the end because the buffer is full of them
        int 21h
        jc error ; if unable to open file

        mov [h], ax
        mov bx, ax

        read: 
            mov ah, 3fh
            mov cx, 100h
            mov dx, offset buffer
            int 21h

            jc finish

            OR ax, ax
            JZ finish ; EOF

            call countLowerCaseLetters		;nuskaitome mazasias raides
            call countCapitalLetters		;nuskaitome didziasias raides
            call countWords					;skaiciuojame zodzius
            call countSymbols
            jmp read

    finish:
        CMP symbolsCount, 0
        JNE skipNull
        mov WordsCount, 0

        skipNull:
        mov dl, 36
	    mov [si], dl
        mov dx, offset fileName
        CALL print
        mov dl, 48
	    mov [si], dl

        mov dx, offset lowerCaseOutput
        CALL print
        mov ax, lowerCaseCount
        CALL printProc
        mov lowerCaseCount, 0

        mov dx, offset capitalsOutput
        CALL print
        mov ax, capitalsCount
        CALL printProc
        mov capitalsCount, 0

        mov dx, offset symbolsOutput
        CALL print
        mov ax, symbolsCount
        CALL printProc
        mov symbolsCount, 0

        mov dx, offset wordsOutput
        CALL print
        mov ax, wordsCount
        CALL printProc
        mov wordsCount, 0

        mov dx, offset newLine
        CALL print
        mov dx, offset newLine
        CALL print

        mov bx, [h]
        OR bx, bx
        jz close1
        mov ah, 3eh
        int 21h

    reset:
        mov dl, 48
        mov [si], dl

        CMP fileNameLength, 0
        JE continue

        dec fileNameLength
        dec si

        JMP reset

    close1:
        mov ax, 4c00h
        int 21h

    helpCall:
        mov dx, offset helpMessage
        CALL print
        CALL close1

    error:
        mov dx, offset fileError
        CALL print
        CALL close1

    print:
        mov ah, 09h
        int 21h
        RET
countLowerCaseLetters proc		;skaiciuojam mazasias raides
	push ax
	push bx
	push cx
		
		mov cx, ax
		
		xor bx, bx
		countingLowerLetters:
			mov al, [buffer + bx]
			cmp al, 'a'
			jb skip1
			cmp al, 'z'
			ja skip1
			
			;jei yra rezyje tarp a ir z tai padidinam skaiciu vienu
			inc lowerCaseCount
			
			skip1:
			inc bx
		loop countingLowerLetters
		
    pop cx
    pop bx
	pop ax
	ret

countLowerCaseLetters ENDP
countCapitalLetters proc			;skaiciuojam didziasias raides
	push ax
	push bx
	push cx
		
		mov cx, ax
		
		xor bx, bx
		countingUpperLetters:
			mov al, [buffer + bx]
			cmp al, 'A'
			jb skip2
			cmp al, 'Z'
			ja skip2
			
			;jei yra rezyje tarp A ir Z tai padidinam skaiciu vienu
			inc capitalsCount
			
			skip2:
			inc bx
		loop countingUpperLetters
				
    pop cx
    pop bx
	pop ax
	ret 
countCapitalLetters endp
countWords proc		;skaicuojam zodzius(nera tobula)
	push ax
	push bx
	push cx
		
		mov cx, ax
		
		xor bx, bx
        mov spaceCount, 0
		countingWords:
			mov al, [buffer + bx]
			cmp al, 32	;jei tarpas, tai nauajas zodis
			je space
			cmp al, 13	;jei carriage return tai naujas zodis
			je newWord
			jmp skip3	;jei nei to nei to nebuvo, sokam iki skip3 ir

            cont:
			newWord:
                CMP spaceCount, 1
                JA skip3
                CMP [buffer + bx - 1], 32
                JE skip3 
                inc wordsCount
                mov spaceCount, 0
                
			skip3:
			    inc bx	;padidinam bx vienu kad skaitytume kita elementa
		loop countingWords		
				
    pop cx
    pop bx
	pop ax
	ret 
countWords endp

space:
    INC spaceCount
    JMP cont

countSymbols proc		;skaiciuojam simboliu skaiciu
	push ax
	push bx
	push cx
		
		mov cx, ax
		xor bx, bx
		countSymbolsLoop:	
			mov al, [buffer + bx]
			cmp al, 10		;jie nera nauja eilute arba
			je skip4
			cmp al, 13		;carriage return
			je skip4
            cmp al, 32
            je skip4
			inc symbolsCount	;pridedam prie simboliu skaiciaus viena
			skip4:
			inc bx		;padidinam bx vienu kad skaitytume kita elementa
		loop countSymbolsLoop

    pop cx
	pop bx
	pop ax
	ret 
countSymbols endp

printProc proc		;printinimas vienazenkliu ir keleziankliu skaiciu
	mov dx, 0
	mov cx, 0
	
	CMP ax, 9	;jei skaicius vieno skaitmens
	mov dx, ax
	JA division
	add dx, 48
	mov ah, 02h
	int 21h
	JMP exitPrinting
	
	;jei keliu skaitmenu, atlliekam veiksmus kad ji isspausdint
	division:
		XOR dx, dx
		CMP ax, 0
		JE printing
		mov bx, 10
		DIV bx
		
		push dx
		INC cx
	JMP division
	
	printing:	;jo spausdinimas
		CMP cx, 0
		JE exitPrinting
		
		pop dx
		mov ah, 02h
		add dx, 48
		int 21h
		
		DEC cx
		JMP printing
	
	exitPrinting:
	RET
printProc ENDP

END START