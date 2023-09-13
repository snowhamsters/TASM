	sound macro freq,duration
	
		mov al, 182         ; Prepare the speaker for the
		out 43h, al         ; note.

		mov ax,freq			; Frequency number (in decimal)for middle C.
		out 42h, al         ; Output low byte.
		mov al, ah          ; Output high byte.
		out 42h, al 

		in  al, 61h         ; Turn on note (get value from port 61h).
		or  al, 00000011b   ; Set bits 1 and 0.
		out 61h, al         ; Send new value.

		mov cx,duration		; Pause for duration of note.
		mov dx,0fh
		mov ah,86h			; CX:DX = how long pause is? I'm not sure exactly how it works but it's working
		int 15h				; Pause for duration of note.

		in  al, 61h         ; Turn off note (get value from
								;  port 61h).
		and al, 11111100b   ; Reset bits 1 and 0.
		out 61h, al         ; Send new value.
		
		mov cx,01h			;Pause to give the notes some separation
		mov dx,08h
		mov ah,86h
		int 15h
	endm