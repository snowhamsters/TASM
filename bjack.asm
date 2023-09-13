; Blackjack Game
JUMPS
.model small
.stack 100h
.data							; pitch and colors are copy pasted from al5 dice game
	pitch dw 7239, 3619, 4304	; 0=lossing, 2 = win, 4 = draw card
	period dw   3,    3,	1	; duration 
	
	winLossArray db 10 dup (090)						; array showing previous wins and losses
	arrayLabel db 0ah,0dh,'Recent Win/Loss History: $'
	arraySeperator db '-$'
	
	colorA db 1bh			; default color
	colorB db 4fh			; color for lossing
	colorC db 2fh			; color for winning
	colorD db 07h			; DOSBox color on exit
	
	again db ?				; variable for playing again
	choice db ?				; player choices. could use again variable, but this makes it easier to read
	
	roll dw ?				; used for random numbers. Only used in randVal macro, so I put it up here to be hidden
	
	; Many many text outputs informing the play what is happening + inputs
	; Categorized by intial prompts, replies for the player, dealer actions, results, chip results, and small misc messages
	promptA db 0ah,0dh,'Welcome to Blackjack. $'		; all prompts are called once each game. Again variable will make them be called again
	promptB db 0ah,0dh,'Press any key to continue. $'	; used A LOT. Provides a buffer + rng changes as time passes
	promptC db 0ah,0dh,'Chips: $'
	promptD db 0ah,0dh,'Enter a bet: $'
	
	replyA db 0ah,0dh,'You are given a $'					; replyA and replyB called once at the start of a round. Then just replyA called
	replyB db 0ah,0dh,'And a $'
	
	replyC db 0ah,0dh,0ah,0dh,'Total: $'
	replyD db 0ah,0dh,0ah,0dh,'Hit(h), Stand(s), or Double Down(d) $'
	
	replyE db 'You draw a $'
	replyF db 0ah,0dh,0ah,0dh,'Bust! $'
	
	overBalanceMsg db 0ah,0dh,'Insufficient Funds! You can not Double Down$'
	outOfChipsMsg db 0ah,0dh,'You lost all your tokens.$'
	gameOverMsg db 0ah,0dh,'You can',039,'t continue to play without tokens, good bye!$'
	
	dealerA db 0ah,0dh,'The dealer draws a $'				; call dealerA again if the dealer draws more cards
	dealerB db 0ah,0dh,'and a face down card $'				; dealerA and dealerB are called once before the player is given choices. Don't calculate the face down card now, do it after dealerC
	dealerC db 0ah,0dh,0ah,0dh,'The dealers face down card was a $'	; called when a player stands, busts, or after they double down
	dealerD db 0ah,0dh,'The dealer busts $'					; soft 17 where the dealer keeps drawing until at least 17, then they stand.
	dealerE db 0ah,0dh,'The dealer stands. $'				; lets the player know when dealerTotal > 17
	
	resultA db 0ah,0dh,'You win. $'							; win condition: playerTotal > dealerTotal 
	resultB db 0ah,0dh,'The dealer wins. $'
	resultC db 0ah,0dh,'Draw. $'
	resultD db 0ah,0dh,'Your Total: $'
	resultE db 0ah,0dh,'Dealer',039,'s Total: $'
	chipsA db 0ah,0dh,0ah,0dh,'+ $'									; chipsA and chipsB used with chipsC to display how many chips won or lost
	chipsB db 0ah,0dh,0ah,0dh,'- $'									; chips won/lost = bet unless the player double downs. If the player double downs, I multiple the bet by 2
	chipsC db ' chips $'
	chipsD db 0ah,0dh,'New amount of chips is: $'
	chipsE db 0ah,0dh,'No chips gained or lost $'			; called on a tie
	againPrompt db 0ah,0dh,0ah,0dh,'Do you want to play again? (y/n) $'
	
	aceA db 0ah,0dh,'To avoid getting over 21 $'
	aceB db 0ah,0dh,'Your ace is worth 1 instead of 11 now. $'
	aceDealer db 0ah,0dh,'The dealer converted his ace to a 1. $'
	
	cardA db ' of $'	; used to say ex.cardAce of cardSuite. Called for both player and dealer in drawing card macro
	
	cardAce db 'Ace$'		; used for filling in ex. "Ace" "of" "Hearts"
	cardJack db 'Jack$'
	cardQueen db 'Queen$'
	cardKing db 'King$'
	
	suiteHearts db 'Hearts $'
	suiteClubs db 'Clubs $'
	suiteSpades db 'Spades $'
	suiteDiamonds db 'Diamonds $'
	
	; more variables, these are dw and used frequently
	chips dw 250		; this number is starting amount of chips
	bet dw ?		; how much money bet
	
	playerTotal dw ?	; total = values of all cards added up
	dealerTotal dw ?
	
	userDraw dw ?		; 0 = player is drawing a card. 1 = dealer is drawing a card. Must set before using the draw card macro
	
	cardValue dw ?		; where card drawing macro stores the value of a card
	cardSuite dw ?		; 1=hearts, 2=clubs, 3=spades, 4=diamonds
	playerAceNum dw ?			; num of aces (used for calculating 1 or 11)
	dealerAceNum dw ?			; num of aces (used for calculating 1 or 11)
	
.code				; some macros are copy pasted from assignments, don't know if we will use them all.
	extrn indec: proc
	extrn outdec: proc
	main proc
		mov ax,@data	; load the ax register with the address of where the data segment begin
		mov ds,ax		; mov that address into the data segement pointer register
		
		prtStr macro X
			mov dx,offset X	; load the address of where the string begins
			mov ah,09h			; load high order byte of ax with 09h (DOS API to print strings)
			int 21h				; do it now (DOS API operation)	
		endm
		
		readChar macro Y
			; read a ascii character
			mov ah,01h				; load the ah with 01h (DOS API read ascii character operation)
			int 21h
			mov Y,al				; load the ascii character stored in lower byte of ax register
		endm

		exit macro
			clrScr					; clear screen
			chgColor colorD			; change color to default DOS
			mov ah,4ch				; load the high order byte of the ax register with 4ch(return to DOS)
			int 21h					; do it now
		endm
		
		clrScr macro
			mov ax,0002h			; clear screen operation 
			int 10h					; BIOS interrupt
		endm
		
		chgColor macro color
			mov ah,06h
			mov al,0
			mov bh,color
			mov cx,0000h		; paint from row 0 column 0
			mov dx,184fh		; paint to row 23 column 79
			int 10h
		endm
		
		resetVar macro			; reset variables in between new rounds
			mov playerTotal,0
			mov dealerTotal,0
			mov playerAceNum,0
			mov dealerAceNum,0
		endm
		
		genRand4 macro randVal	; === 1 to 4 random number generator
			mov ah,00h			; read real time clock counter
			int 1ah				; real time clock services
			mov ax,dx			; get copy of counter
			xor dx,dx			; zero out dx (where remainder of division goes)
			mov bx,4			; copy a 4 into bx which will divisor
			div bx				; perform modulo operation with remainder in dx
			add dx,1			; shift 0 to 3 range to 1 to 4 range
			mov randVal,dx
		endm
		
		genRand13 macro randVal	; === 1 to 13 random number generator
			mov ah,00h			; read real time clock counter
			int 1ah				; real time clock services
			mov ax,dx			; get copy of counter
			xor dx,dx			; zero out dx (where remainder of division goes)
			mov bx,13			; copy a 13 into bx which will divisor
			div bx				; perform modulo operation with remainder in dx
			add dx,1			; shift 0 to 12 range to 1 to 13 range
			mov randVal,dx
		endm
		
		pScoreMacro macro		; print players total
			prtStr replyC
			mov ax,playerTotal
			call outdec
		endm
		
		dScoreMacro macro		; print players total
			prtStr resultE
			mov ax,dealerTotal
			call outdec
		endm
		
		finalScores macro		; final score macro for printing playerTotal and new amount of chips
			prtStr resultD
			
			mov ax,playerTotal
			call outdec
				
			dScoreMacro
		endm
		
		finalChips macro
			prtStr chipsD			; prints new total amount of chips
			mov ax,chips
			call outdec
		endm
		
		playSound macro				; Plays a beep. 0=lossing, 2 = win, 4 = draw card
			push ax	
		 	sound pitch+bx, period+bx
		 	pop ax
		endm
		
		;------- end of macros ----------
		include sound.asm
		
		jmp start				; jump to real start and not pickCard proc
		
		pickCard proc			; pick a card	
			genRand13 roll		; gets a number between 1-13
			mov ax,roll			; moves number rolled to ax
			mov cardValue,ax	; moves ax to cardValue
			
			cmp cardValue,11	; jumps on face cards to change their value to 10 and print the proper card name
			je drawJack
			cmp cardValue,12
			je drawQueen
			cmp cardValue,13
			je drawKing
			
			cmp cardValue,1		; if ace, then jump to UserOrDealer, avoid printing cardValue
			je userOrDealer
			
			mov ax,cardValue	; sets ax to cardValue for outdec
			call outdec			; prints cardValue
			
			userOrDealer:		; checks wether the user of dealer is getting a new card
				cmp userDraw,0
				je playerDraw
				cmp userDraw,1
				je dealerDraw
				
			drawJack:
				prtStr cardJack		; prints proper card name
				mov cardValue,10	; makes face value cards = 10
				jmp userOrDealer
			drawQueen:
				prtStr cardQueen
				mov cardValue,10
				jmp userOrDealer
			drawKing:
				prtStr cardKing
				mov cardValue,10
				jmp userOrDealer
				
			playerDraw:
				cmp cardValue,1			; checks if it is an ace
				je playerDrawAce
				
				mov ax,cardValue		; movs cardValue and adds to playerTotal
				add playerTotal,ax
				
				jmp rngSuite			; jmps to suite part of cardDraw
				
				playerDrawAce:
					prtStr cardAce		; prints proper card name
					add playerAceNum,1	; increments aceNum variable (for later)
					mov cardValue,11	; makes ace normally 11
					jmp playerDraw
					
			dealerDraw:					; dealer is almost identical
				cmp cardValue,1			; checks if it is an ace
				je dealerDrawAce
				
				mov ax,cardValue		; movs cardValue and adds to dealerTotal
				add dealerTotal,ax
				
				jmp rngSuite			; jmps to suite part of cardDraw
				
				dealerDrawAce:
					prtStr cardAce		; prints proper card name
					add dealerAceNum,1	; increments aceNum variable (for later)
					mov cardValue,11	; makes ace normally 11
					jmp dealerDraw
			
			rngSuite:
				prtStr cardA	; prints " of "
			
				genRand4 roll	; gets a number between 1-4

				cmp roll,1		; jumps based on random number
				je pHearts
				cmp roll,2
				je pClubs
				cmp roll,3
				je pSpades
				cmp roll,4
				je pDiamonds
			
			pHearts:
				prtStr suiteHearts	; prints proper cardSuite
				jmp returnProc
			pClubs:
				prtStr suiteClubs
				jmp returnProc
			pSpades:
				prtStr suiteSpades
				jmp returnProc
			pDiamonds:
				prtStr suiteDiamonds
				jmp returnProc
			
			returnProc:		; procedure to jump to at the end. Makes each suite unified incase I want to add something here
				xor bx,bx	; turns out I did
				mov bx,4	; sound only plays on successful cardDraw. More for testing, but still sounds good
				playSound			; Plays a beep. 0=lossing, 2 = win, 4 = draw card
			ret
			
		pickCard endp
		
		;------- end of card draw ----------
		
		start:					; play again would jump to here
			clrScr				; clears screen
			chgColor colorA		; resets color
			resetVar			; reset variables macro
			prtStr promptA
			prtStr promptB
			readChar choice		; waits for user input. Any key continutes the game
		endp
		
		L1:
			prtStr promptC		; prints number of chips the user has
			mov ax,chips
			call outdec
			prtStr promptD
			call indec			; gets user input for their bet
			
			cmp ax, chips		; user put in a bet over their amount
			jg L1
			
			cmp ax, 0			; user has to put up a bet >0
			jle L1
			
			mov bet,ax			; moves user input into bet variable
			
			mov userDraw,0		; 0 = player drawing
			
			prtStr replyA		; draw first card for player
			call pickCard
			
			prtStr promptB		; waits for user input to continue
			readChar choice		; system time change = rng change
			
			prtStr replyB		; draw second card for player
			call pickCard
			
			prtStr promptB		; waits for user input to continue
			readChar choice		; system time change = rng change
			
			mov userDraw,1		; 1 = dealer drawing
			
			prtStr dealerA		; visually showing that the dealer has one face up card and one face down
			call pickCard		; only calculates the face up card for now
			prtStr dealerB
			
			mov userDraw,0		; 0 = player drawing
			
			jmp L2				; jump to main player actions. Also checks for > 21 and ace
		endp
		
		aceProc:
			
			cmp userDraw, 0			; Integrated compare to see whether whos drawing
			je acePlayer			; if player, jump
			
			sub dealerAceNum, 1		; Must be dealer's turn then
			sub dealerTotal, 10
			
			prtStr aceDealer		; Tells player what the dealer did
			
			;jmp L3					; jumping to the start of the dealers turn makes him always draw a new card
			jmp L3b					; this jump to the soft 17 compare to see if the dealer hits or stands
			
			acePlayer:
				sub playerAceNum,1	; remove ace variable and turn it from 11 to a 1
				sub playerTotal,10
			
				prtStr aceA			; informs the player what happened
				prtStr aceB
			
				jmp L2a				; jmp to L2a
		endp
		
		hitProc:
			prtStr replyE		; print player draws a card
			call pickCard		; draws a card
		endp
		
		L2:
			cmp playerTotal,21	; if player score < 21, jump L2a
			je standProc		; stand if player total equals 21
			jl L2a
								; code only continues if player has > 21. So check for ace
			cmp playerAceNum,1	; if player has an ace, jump to aceProc
			jge aceProc
			jl bustProc			; else, jump to bustProc
		L2a:
			pScoreMacro			; prints players total score
		
			prtStr replyD		; print choices for player
			readChar choice
			
			clrScr				; clears screen
			chgColor colorA		; resets color
			
			cmp choice,'h'		; jumps depending on user choice
			je hitProc
			cmp choice,'s'
			je standProc
			cmp choice,'d'
			je doubleProc
			jmp L2a				; if player puts in an invalid choice, jmp back to L2a
		endp
		
		bustProc:
			prtStr promptB		; waits for user input to continue
			readChar choice		; they might not be paying attention... but the user just lost
								; if they are paying attention, it's a cool moment to show they messed up
		
			clrScr				; After the player continues, clear screen
			chgColor colorB		; change color to loss
			
			pScoreMacro				; prints players total score
		
			prtStr replyF			; prints that the player busts
			
			prtStr chipsB			; prints chips lost...
			mov ax,bet
			call outdec
			
			sub chips,ax			; removes chips equal to bet
			
			prtStr chipsC			; ...prints chips lost (cont)
			
			finalChips				; prints total amount of chips
			
			xor bx,bx
			mov bx,0
			playSound			; Plays a beep. 0=lossing, 2 = win, 4 = draw card
			
			cmp chips, 0			; compares chips to 0
			jg replayGame			; if player still has chips they can replay
			
			prtStr outOfChipsMsg	; if not... they can't play and the game exits
			prtStr gameOverMsg
			
			prtStr promptB			; waits for user input to process that they are out of money
			readChar choice
			
			exit
		
		endp
		
		exitProc:					; exit proc used for jumps
			exit					; good place to say the exit macro changes the color back to DOS default
		endp
		
		overBalance:				; if the player attempts to double down
			prtStr overBalanceMsg	; without enough money, explain that they
			shr bet, 1				; cannot. Also restore their original bet
			
			pop ax
			jmp L2a					; jump back to player choices
		endp
		
		doubleProc:				; Double down procedure
			push ax
			
			shl bet,1			; doubles players bet
			
			mov ax, chips		; check if the player has enough chips with the doubled bet
			cmp bet, ax
			jg overBalance		; if not, explain to the player
			
			prtStr replyE		; print player draws a card
			call pickCard		; draws a card
			
			cmp playerTotal,21	; if >21, then bust. Otherwise continue
			jg bustProc
			
			pScoreMacro			; prints players total score
			
			pop ax
		endp
		
		standProc:				; stand procedure when the player stands, gets 21, or doubles down and gets a new card
			; this is where the dealer code would start. The dealer already drew their first card,
			; but now they need to at a minimum draw again and show the hidden card
			; aka dealerC db 0ah,0dh,'The dealers face down card was a $'
			
			; userDraw variable needs to be 1 from now on so all drawn cards are the dealers
			
			; don't worry about setting userDraw back to 0. I do that before the player draws for the first time
			; I have a resetVar macro that resets aceNum and total scores for the player and dealer
			; you shouldn't have to reset any extra variables
			
			; aces are complicated, you can check what I did for the player above. the dealer also has dealerAceNum and dealerTotal
			
			L3:							; Label to start dealer's turn
				mov userDraw, 1	 		; dealer = 1
				
				prtStr dealerC			; Dealer's other card is...
				call pickCard
				
				cmp playerTotal, 21		; Compares if player has 21
				je checkForTie			; Jumps to see if dealer has 21
				jg checkAce				; > 17  then check for ace
				
				dScoreMacro				; prints dealer score
				
				prtStr promptB
				readChar choice
				
				cmp dealerTotal, 17		; Dealer stops at 17, so it's time to compare
				jge cmpScr
			
			L3a:						; The main label controling dealer's AI
				prtStr dealerA
				call pickCard
			L3b:						; used exclusively to jump here after the dealer draws an ace
				dScoreMacro
				prtStr promptB			; System time change = rng change
				readChar choice			
				
				cmp dealerTotal, 17		; < 17, draw another card
				jl L3a					
				
				cmp dealerTotal, 21		; = 21, dealer wins
				;je dealerWins			; if equal, continue incase it is a draw
				jg checkAce				; > 17  then check for ace
				
			cmpScr:						; Compares who has higher score
				prtStr dealerE			; prints that the dealer stands
				
				prtStr promptB			; waits for user input to continue clrScr is called after the jumps,
				readChar choice			; so let the player process the dealer standing, before continuing
			
				mov ax, playerTotal
				
				cmp ax, dealerTotal		; Compares player score to dealers
				jg playerWins
				je draw
				jl dealerWins		
			endp
			
			checkForTie:				; Checks if both players have 21
				cmp dealerTotal, 21		; Already checked player total
				je draw					; so must check dealers
				
				jmp playerWins			; Else player wins
			
			checkAce:					; Checks if dealer has Ace
				mov userDraw, 1
				cmp dealerAceNum, 1
				jge aceProc
				jl dealerBust
			endp
			
			dealerBust:					; If Dealer goes over 21
				clrScr					; clear screen + make it the win color
				chgColor colorC
				
				;xor dx,dx
				;mov dx, 'W'				; Setting dx = W for array
				;call displayWinLoss		; Calling array proc
				
				prtStr dealerD			; Dealer busts
				prtStr resultA			; You win
				
				finalScores				; prints scores
				
				prtStr chipsA			; prints "+ bet"
				mov ax,bet
				call outdec
			
				add chips,ax			; adds chips equal to bet
				
				prtStr chipsC			; prints " chips"
				
				finalChips				; prints final chips
				
				xor bx,bx
				mov bx,2
				playSound			; Plays a beep. 0=lossing, 2 = win, 4 = draw card
				
				jmp replayGame		; ask user if they want to replay
			endp
			
			draw:						; If both player and dealer scores are equal
				clrScr					; clear screen + make sure its the same color as normal
				chgColor colorA
				
				;xor dx,dx
				;mov dx, 'T'			; Setting dx = W for array
				;call displayWinLoss	; Calling array proc
				
				prtStr resultC			; Draw.
				
				finalScores				; print final scores
				
				finalChips				; print final chips
				
				xor bx,bx
				mov bx,4			; plays a neutral sound. Same as card draw
				playSound			; Plays a beep. 0=lossing, 2 = win, 4 = draw card
				
				jmp replayGame			; ask user if they want to replay
			endp
			
			playerWins:
				clrScr					; clear screen + make it the win color
				chgColor colorC
				
				prtStr resultA			; print the player wins
				
				;xor dx,dx
				;mov dx, 'W'				; Setting dx = W for array
				;call displayWinLoss		; Calling array proc
				
				finalScores				; print final scores
				
				prtStr chipsA			; prints "+ bet"
				mov ax,bet
				call outdec
			
				add chips,ax			; adds chips equal to bet
				
				prtStr chipsC			; prints " chips"
			
				finalChips				; print final chips
				
				xor bx,bx
				mov bx,2
				playSound			; Plays a beep. 0=lossing, 2 = win, 4 = draw card
				
				jmp replayGame		; ask user if they want to replay
			endp
			
			dealerWins:				; if the dealerTotal > playerTotal
				clrScr				; clear screen + make it the loss color
				chgColor colorB
				
				xor dx,dx
				
				;mov dx, 'L'				; Setting dx = W for array
				;call displayWinLoss		; Calling array proc
				;prtStr resultB
				
				finalScores
				
				prtStr chipsB			; prints "- bet"
				mov ax,bet
				call outdec
			
				sub chips,ax			; removes chips equal to bet
				
				prtStr chipsC			; prints " chips"
				
				finalChips
				
				xor bx,bx
				mov bx,0
				playSound			; Plays a beep. 0=lossing, 2 = win, 4 = draw card
				
				cmp chips, 0			; Chips are bigger than zero
				jg replayGame			; Plays sound and ask user if they want to replay
				
				prtStr outOfChipsMsg	; If out tell user they are done
				prtStr gameOverMsg
				
				prtStr promptB			; waits for user input to process that they are out of money
				readChar choice
				
				exit
			endp
			
			displayWinLoss:				; displays the win/loss array of the player
				push dx					; We'll pop dx once we need the value to store it
				
				prtStr arrayLabel
				xor ax, ax
				xor bx, bx
				lea bx, winLossArray 	; Load win loss Array
				mov cx, bx
				add cx, 10 				; first address after the end of the array
				
				printArray:
					mov ax, [bx] 		; brackets means indirect index

					je setNewScore
					prtStr ax
					prtStr arraySeperator
					cmp bx, cx
					je printArray
					add bx, 2
					
				setNewScore:
					pop dx
					mov [bx], dx
					prtStr [bx]
					
					readChar choice
					
					pop cx
					pop bx
					pop ax
					ret
			endp
		
		
			replayGame:					; prompts user to play again
				prtStr againPrompt		; prints if player wants to play again
				readChar choice
				cmp choice,'n'			; if yes go back to start. Otherwise exit
				je exitProc				; n and y both have je, so if the user inputs a different character, it jmps back to bustProcA
				cmp choice,'y'
				je start				
				jmp replayGame			; Runs replay prompt
			endp
			
		exit
		
	end main