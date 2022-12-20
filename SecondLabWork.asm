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
    buffer db 512 dup(?)
    helpMessage db "Enter file names upon launching program.$", 10, 13, 13
    fileError db "File not found$"
    lowerCaseOutput db 13, 10, "Lower case letters : $"
	capitalsOutput db 13, 10, "Capital letters : $"
	symbolsOutput db 13, 10, "Symbols : $"
	wordsOutput db 13, 10, "Words : $"
    newLine db 13, 10, '$'

.code

START:
    mov ax, @data
    mov ds, ax

    mov bx, 82h 
    mov si, offset fileName

    cmp byte ptr es:[80h], 0 
    je helpCall

    mov cl, byte ptr es:[80h] 

    readFileName:
        loop1:
            cmp byte ptr es:[bx], 32
            je openFile

            cmp byte ptr es:[bx], 13
            je openFile

            mov dl, byte ptr es:[bx]
            mov [si], dl

            inc si
            inc fileNameLength
            jmp sameFile

            continue:
                pop bx
                pop cx
            sameFile:
                inc bx

            loop loop1
            jmp close1

    openFile:
        push cx
        push bx

        mov dx, offset fileName
        mov ax, 3d00h 
        int 21h
        jc error 

        mov [h], ax
        mov bx, ax

        read: 
            mov ah, 3fh
            mov cx, 200h
            mov dx, offset buffer
            int 21h

            jc finish

            or ax, ax
            jz finish ; EOF

            call countLowerCaseLetters		
            call countCapitalLetters		
            call countWords					
            call countSymbols
            jmp read

    finish:
        cmp symbolsCount, 0
        jne skipNull
        mov WordsCount, 0

        skipNull:
            mov dl, 36
            mov [si], dl
            mov dx, offset fileName
            call print
            mov dl, 48
            mov [si], dl

            mov dx, offset lowerCaseOutput
            call print
            mov ax, lowerCaseCount
            call printProc
            mov lowerCaseCount, 0

            mov dx, offset capitalsOutput
            call print
            mov ax, capitalsCount
            call printProc
            mov capitalsCount, 0

            mov dx, offset symbolsOutput
            call print
            mov ax, symbolsCount
            call printProc
            mov symbolsCount, 0

            mov dx, offset wordsOutput
            call print
            mov ax, wordsCount
            call printProc
            mov wordsCount, 0

            mov dx, offset newLine
            call print
            mov dx, offset newLine
            call print

            mov bx, [h]
            or bx, bx
            jz close1
            mov ah, 3eh
            int 21h

    reset:
        mov dl, 48
        mov [si], dl

        cmp fileNameLength, 0
        je continue

        dec fileNameLength
        dec si

        jmp reset

    close1:
        mov ax, 4c00h
        int 21h

    helpCall:
        mov dx, offset helpMessage
        call print
        call close1

    error:
        mov dl, 36
	    mov [si], dl
        mov dx, offset fileName
        call print
        mov dl, 48
	    mov [si], dl
        mov dx, offset newLine
        call print
        mov dx, offset fileError
        call print
        mov dx, offset newLine
        call print
        mov dx, offset newLine
        call print
        jmp reset

    print:
        mov ah, 09h
        int 21h
        RET

    countLowerCaseLetters proc		
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
                
                inc lowerCaseCount
                
                skip1:
                inc bx
            loop countingLowerLetters
            
        pop cx
        pop bx
        pop ax
        ret

    countLowerCaseLetters ENDP

    countCapitalLetters proc
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
                
                inc capitalsCount
                
                skip2:
                inc bx
            loop countingUpperLetters
                    
        pop cx
        pop bx
        pop ax
        ret 
    countCapitalLetters endp

    countWords proc		
        push ax
        push bx
        push cx
            
            mov cx, ax
            
            xor bx, bx
            mov spaceCount, 0
            countingWords:
                mov al, [buffer + bx]
                cmp al, 32	
                je space
                cmp al, 13	
                je newWord
                jmp skip3	

                cont:
                newWord:
                    cmp spaceCount, 1
                    ja skip3
                    cmp [buffer + bx - 1], 32
                    je skip3 
                    inc wordsCount
                    mov spaceCount, 0
                    
                skip3:
                    inc bx	
            loop countingWords		
                    
        pop cx
        pop bx
        pop ax
        ret 
    countWords endp

    space:
        inc spaceCount
        jmp cont

    countSymbols proc		
        push ax
        push bx
        push cx
            
            mov cx, ax
            xor bx, bx
            countSymbolsLoop:	
                mov al, [buffer + bx]
                cmp al, 10		
                je skip4
                cmp al, 13		
                je skip4
                cmp al, 32
                je skip4
                inc symbolsCount	
                skip4:
                inc bx		
            loop countSymbolsLoop

        pop cx
        pop bx
        pop ax
        ret 
    countSymbols endp

    printProc proc
        mov dx, 0
        mov cx, 0
        
        cmp ax, 9
        mov dx, ax
        ja division
        add dx, 48
        mov ah, 02h
        int 21h
        jmp exitPrinting
        
        division:
            xor dx, dx
            cmp ax, 0
            je printing
            mov bx, 10
            div bx
            
            push dx
            inc cx
        jmp division
        
        printing:
            cmp cx, 0
            je exitPrinting
            
            pop dx
            mov ah, 02h
            add dx, 48
            int 21h
            
            dec cx
            jmp printing
        
        exitPrinting:
        ret
    printProc endp

    end start