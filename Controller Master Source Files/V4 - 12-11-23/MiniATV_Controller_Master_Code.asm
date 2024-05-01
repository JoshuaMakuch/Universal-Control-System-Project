;******************************************************************************
;                                                                             *
;    Filename:	    MiniATV_Controller_Master_Code.asm			      *
;    Date:	    November 9, 2023                                         *
;    File Version:  3                                                         *
;    Author:        Joshua Makuch                                             *
;    Company:       Idaho State University                                    *
;    Description:   Firmware for runing the Master PIC for the MiniATV	      *
;		    Controller						      *
;		                                                              *
;******************************************************************************
;******************************************************************************
;                                                                             *
;    Revision History:                                                        *
;	1: Basic setup for the PIC16LF1789. Test program for the dev board    *
;	   increments portb to indicate that the 1789 was soldered correctly  *
;	2: This version will now have 3 joysticks, 7 buttons, 2 triggers,     *
;          a mode select switch, robot address dip switch package, and	      *
;	   several LED indicators.				              *
;	3: UART transmission and reception function. Mode 1 utilizes nearly   *
;	   all controls to function. Mode 2 is a button test display. Only    *
;	   drive works ATM however.					      *
;									      *
;	    STARTED NOV 17 2023 - Nov 30 2023				      *
;                                                                             *
;******************************************************************************
	

	LIST	    p=16LF1789
	INCLUDE	    P16LF1789.INC
	INCLUDE	    1789_SETUP.INC
	
	; CONFIG1
; __config 0xEFE4
 __CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_OFF & _CLKOUTEN_OFF & _IESO_OFF & _FCMEN_OFF
; CONFIG2
; __config 0xFFFF
 __CONFIG _CONFIG2, _WRT_OFF  & _PLLEN_OFF & _STVREN_ON & _BORV_LO & _LPBOR_OFF & _LVP_ON

    ;suppress "not in bank 0" message,  Found label after column 1,
    errorlevel -302,-207,-305,-206,-203			
							
;******************************************		
;ORIGIN VECTORS & SETUP
;******************************************
		ORG 	H'000'					
 		GOTO 	SETUP				;RESET CONDITION GOTO SETUP
		ORG	H'004'
		GOTO	INTERUPT
SETUP
		CALL	INITIALIZE			;CALLS THE SETUP FILE 1788_SETUP.INC
		GOTO	MAIN
;******************************************
;INTERUPT SERVICE ROUTINE 
;******************************************
INTERUPT
		BANKSEL W_SAVE
		MOVWF		W_SAVE			;SAVE WORKING REGISTER CONTENTS
		BANKSEL	STATUS
		MOVFW		STATUS
		MOVWF		STATUS_SAVE		;SAVES STATUS REGISTER CONTENTS
		
		BANKSEL PIR1
		BTFSC  PIR1, RCIF			;TESTS THE RECEIVE INTERRUPT FLAG, IF SET CALL RECEIVED_BYTE
		CALL REC_BYTE
		
		BANKSEL PIR1
		BTFSC	PIR1, TMR2IF			;IF TIMER2 INTERRUPT FLAG, THEN HANDLE TIMER COUNT
		CALL HANDLE_T2_INT
		
		BANKSEL PIR1
		BCF	PIR1, SSP1IF
		
		BANKSEL STATUS_SAVE			;RECALL STATUS REGISTER CONTENTS
		MOVFW		STATUS_SAVE
		MOVWF		STATUS			;RESTORE STATUS REGISTER CONTENTS
		BANKSEL W_SAVE				
		MOVFW		W_SAVE			;RESTORE WORKING REGISTER CONTENTS
		
		RETFIE					;RETURN AND RESET INTERRUPT ENABLE BITS
;******************************************
;  SUBROUTINES
;******************************************
;*** RECEIVED_BYTE *************************************
REC_BYTE
		BANKSEL RCREG				;STORE RCREG INTO NEWEST_BYTE
		MOVFW		RCREG
		BANKSEL NEWEST_BYTE
		MOVWF		NEWEST_BYTE
		
		BANKSEL RX_INFO_REG			;IF (HANDLING DATA) THEN:
		BTFSC		RX_INFO_REG, 6		    ;RETURN
		RETURN					
		
		BANKSEL RX_INFO_REG
		BTFSC		RX_INFO_REG, 7		;IF (CURRENTLY STORING DATA) THEN:
		GOTO $ + D'11'				    ;GOTO $ + 11	    					    
		MOVLW		H'024'			;ELSE
		XORWF		NEWEST_BYTE, 0		    ;IF (NEWEST_BYTE = $) THEN:
		BANKSEL STATUS					;SET RX_INFO_REG COUNT TO 1
		BTFSS		STATUS, Z			;INDICATE CURRENTLY STORING DATA
		RETURN					    ;ELSE:	
		BANKSEL RX_INFO_REG				;RETURN	
		MOVLW		B'11111000'
		ANDWF		RX_INFO_REG, 1
		INCF		RX_INFO_REG, 1
		BSF		RX_INFO_REG, 7
		
							;SELECT CASE (RX_INFO_REG_COUNT):
		BANKSEL RX_INFO_REG
		MOVLW		B'00000111'		    ;CASE 1
		ANDWF		RX_INFO_REG, 0			;STORE NEWEST_BYTE INTO RX_HS
		MOVWF		SHRT_TRM_REG_INT
		MOVLW		B'00000001'
		XORWF		SHRT_TRM_REG_INT, 0
		BANKSEL STATUS
		BTFSS		STATUS, Z
		GOTO $ + 4
		BANKSEL NEWEST_BYTE
		MOVFW		NEWEST_BYTE
		MOVWF		RX_HS
		
		BANKSEL RX_INFO_REG
		MOVLW		B'00000111'		    ;CASE 2
		ANDWF		RX_INFO_REG, 0			;STORE NEWEST_BYTE INTO RX_CHAR1
		MOVWF		SHRT_TRM_REG_INT
		MOVLW		B'00000010'
		XORWF		SHRT_TRM_REG_INT, 0
		BANKSEL STATUS
		BTFSS		STATUS, Z
		GOTO $ + 4
		BANKSEL NEWEST_BYTE
		MOVFW		NEWEST_BYTE
		MOVWF		RX_CHAR1
		
		BANKSEL RX_INFO_REG
		MOVLW		B'00000111'		    ;CASE 3
		ANDWF		RX_INFO_REG, 0			;STORE NEWEST_BYTE INTO RX_CHAR2
		MOVWF		SHRT_TRM_REG_INT
		MOVLW		B'00000011'
		XORWF		SHRT_TRM_REG_INT, 0
		BANKSEL STATUS
		BTFSS		STATUS, Z
		GOTO $ + 4
		BANKSEL NEWEST_BYTE
		MOVFW		NEWEST_BYTE
		MOVWF		RX_CHAR2
		
		BANKSEL RX_INFO_REG
		MOVLW		B'00000111'		    ;CASE 4
		ANDWF		RX_INFO_REG, 0			;STORE NEWEST_BYTE INTO RX_VAR1
		MOVWF		SHRT_TRM_REG_INT
		MOVLW		B'00000100'
		XORWF		SHRT_TRM_REG_INT, 0
		BANKSEL STATUS
		BTFSS		STATUS, Z
		GOTO $ + 4
		BANKSEL NEWEST_BYTE
		MOVFW		NEWEST_BYTE
		MOVWF		RX_VAR1
		
		BANKSEL RX_INFO_REG
		MOVLW		B'00000111'		    ;CASE 5
		ANDWF		RX_INFO_REG, 0			;STORE NEWEST_BYTE INTO RX_VAR2
		MOVWF		SHRT_TRM_REG_INT
		MOVLW		B'00000101'
		XORWF		SHRT_TRM_REG_INT, 0
		BANKSEL STATUS
		BTFSS		STATUS, Z
		GOTO $ + 4
		BANKSEL NEWEST_BYTE
		MOVFW		NEWEST_BYTE
		MOVWF		RX_VAR2
		
				BANKSEL RX_INFO_REG
		MOVLW		B'00000111'		    ;CASE 6
		ANDWF		RX_INFO_REG, 0			;STORE NEWEST_BYTE INTO RX_VAR3
		MOVWF		SHRT_TRM_REG_INT
		MOVLW		B'00000110'
		XORWF		SHRT_TRM_REG_INT, 0
		BANKSEL STATUS
		BTFSS		STATUS, Z
		GOTO $ + 4
		BANKSEL NEWEST_BYTE
		MOVFW		NEWEST_BYTE
		MOVWF		RX_VAR2
		
							;END CASE 
		
		BANKSEL RX_INFO_REG			;INCREMENT RX_INFO_REG COUNT
		INCF		RX_INFO_REG		    
		
		BANKSEL RX_INFO_REG
		MOVLW		B'00000111'		    ;IF (RX_INFO_REG COUNT = 7) THEN:
		ANDWF		RX_INFO_REG, 0			;SET HANDLING DATA INDICATOR
		MOVWF		SHRT_TRM_REG_INT		;CLEAR STORING DATA INDICATOR
		MOVLW		B'00000111'
		XORWF		SHRT_TRM_REG_INT, 0
		BANKSEL STATUS
		BTFSC		STATUS, Z
		BSF		RX_INFO_REG, 6
		BTFSC		STATUS, Z
		BCF		RX_INFO_REG, 7
		
		BANKSEL PIR1				;CLEAR RECEIVED BYTE FLAG
		BCF		PIR1, RCIF
		
		RETURN
;*** HANDLE T2_INT *************************************
HANDLE_T2_INT
		
		BANKSEL PIR1				;PG.36
		BCF		PIR1, TMR2IF		;TMR2 INTERRUPT FLAG RESET
		
		BANKSEL TMR_CNT
		DECFSZ	TMR_CNT				;IF ? COUNTS OF TMR_CNT HAS OCCURED, RESET THE COUNT
		RETURN
		
		BANKSEL TMR_CNT
		MOVLW		D'010'
		MOVWF		TMR_CNT
		BANKSEL INFO_REG
		BSF		INFO_REG, 3
		
		RETURN
;*** SEND_DATA_PACKET **********************************
SEND_DATA_PACKET
		BANKSEL PIR1				
		BCF		PIR1, TMR2IF		;TMR2 INTERRUPT FLAG RESET
		BANKSEL PIE1				
		BSF		PIE1, TMR2IE		;ENABLE TMR2 INTERRUPT
		
		BANKSEL INFO_REG
		BTFSS		INFO_REG, 3
		GOTO $ - 2
		
		BANKSEL		TXSTA
		BTFSS		TXSTA, TRMT		;TEST IF THE TRANMIT SHIFT REGISTER IS EMPTY, IF IT IS, DON'T RETURN	
		GOTO $ - 2
		;HANDSHAKE TX
		BANKSEL TXREG
		MOVLW		H'024'			;MOVE A '$' TO WORKING
		MOVWF		TXREG			;MOVE WORKING TO TRANSMIT REGISTER	
		BANKSEL TXSTA
		BTFSS		TXSTA, TRMT		;TEST IF THE TRANSMIT SHIFT REGISTER IS EMPTY, IF IT IS, LOOP BACK
		GOTO $ - 2
		;ROBOT ADDRESS TX
		BANKSEL RBT_ADR
		MOVFW		RBT_ADR			;MOVE THE ROBOT ADDRESS TO WORKING
		BANKSEL TXREG				;MOVE WORKING TO TRANSMIT REGISTER
		MOVWF		TXREG
		BANKSEL TXSTA
		BTFSS		TXSTA, TRMT		;TEST IF THE TRANSMIT SHIFT REGISTER IS EMPTY, IF IT IS, LOOP BACK
		GOTO $ - 2
		;CHARACTER TX
		BANKSEL TX_CHAR
		MOVFW		TX_CHAR			;MOVE THE COMMAND CHARACTER TO WORKING
		BANKSEL TXREG				;MOVE WORKING TO TRANSMIT REGISTER
		MOVWF		TXREG
		BANKSEL TXSTA
		BTFSS		TXSTA, TRMT		;TEST IF THE TRANSMIT SHIFT REGISTER IS EMPTY, IF IT IS, LOOP BACK
		GOTO $ - 2
		;VARIABLE 1 TX
		BANKSEL TX_VAR1
		MOVFW		TX_VAR1			;MOVE THE VARIABLE 1 TO WORKING
		BANKSEL TXREG				;MOVE WORKING TO TRANSMIT REGISTER
		MOVWF		TXREG
		BANKSEL TXSTA
		BTFSS		TXSTA, TRMT		;TEST IF THE TRANSMIT SHIFT REGISTER IS EMPTY, IF IT IS, LOOP BACK
		GOTO $ - 2
		;VARIABLE 2 TX
		BANKSEL TX_VAR2
		MOVFW		TX_VAR2			;MOVE THE VARIABLE 2 TO WORKING
		BANKSEL TXREG				;MOVE WORKING TO TRANSMIT REGISTER
		MOVWF		TXREG
		BANKSEL TXSTA
		BTFSS		TXSTA, TRMT		;TEST IF THE TRANSMIT SHIFT REGISTER IS EMPTY, IF IT IS, LOOP BACK
		GOTO $ - 2
		;VARIABLE 3 TX
		BANKSEL TX_VAR3
		MOVFW		TX_VAR3			;MOVE THE VARIABLE 3 TO WORKING
		BANKSEL TXREG				;MOVE WORKING TO TRANSMIT REGISTER
		MOVWF		TXREG
		BANKSEL TXSTA
		BTFSS		TXSTA, TRMT		;TEST IF THE TRANSMIT SHIFT REGISTER IS EMPTY, IF IT IS, LOOP BACK
		GOTO $ - 2
		
		BANKSEL INFO_REG
		BCF		INFO_REG, 3
		
		BANKSEL PIR1				
		BCF		PIR1, TMR2IF		;TMR2 INTERRUPT FLAG RESET
		BANKSEL PIE1				
		BCF		PIE1, TMR2IE		;DISABLE TMR2 INTERRUPT
		
		RETURN
;*** CONVERSION_DONE ***********************************
CONVERSION_DONE
		
		BANKSEL ADCON0				;TEMPORARILY STORES ADCON0 FOR USE IN ANALOG READING
		MOVFW		ADCON0
		BANKSEL SHRT_TRM_REG
		MOVWF		SHRT_TRM_REG
		
		MOVLW		B'00000100'		;INCREMENT ADCON0 ANALOG CHANNEL SELECT
		BANKSEL		ADCON0			
		ADDWF		ADCON0		
		
		
		MOVLW		B'10011001'		;IF (ANALOG SELECT CHANNEL = AN6) THEN:
		BANKSEL ADCON0				    ;RESET ANALOG SELECT CHANNEL TO AN0
		XORWF		ADCON0, 0	    
		BANKSEL STATUS
		BTFSS		STATUS, Z				 
		GOTO $ + 7
		BANKSEL ADCON0				
		BCF		ADCON0, CHS4
		BCF		ADCON0, CHS3
		BCF		ADCON0, CHS2
		BCF		ADCON0, CHS1
		BCF		ADCON0, CHS0
		
		BANKSEL ADRESH				;STORES THE UPPER 8-BIT ADC CONVERSTION RESULT INTO ADC_RESULT
		MOVFW		ADRESH	
		BANKSEL		ADC_RESULT
		MOVWF		ADC_RESULT
		
		
							;SELECT CASE (ANALOG SELECT CHANNEL (ANX)):
		
		MOVLW		B'10000001'		    ;CASE 0
		BANKSEL		SHRT_TRM_REG		    ;STORE ADC_RESULT INTO JOY1UD
		XORWF		SHRT_TRM_REG, 0
		BANKSEL STATUS
		BTFSS		STATUS, Z
		GOTO $ + 4
		BANKSEL ADC_RESULT
		MOVFW		ADC_RESULT
		MOVWF		JOY1UD
		
		MOVLW		B'10000101'		    ;CASE 1
		BANKSEL		SHRT_TRM_REG		    ;STORE ADC_RESULT INTO JOY1LR
		XORWF		SHRT_TRM_REG, 0
		BANKSEL STATUS
		BTFSS		STATUS, Z
		GOTO $ + 4
		BANKSEL ADC_RESULT
		MOVFW		ADC_RESULT
		MOVWF		JOY1LR
		
		MOVLW		B'10001001'		    ;CASE 2
		BANKSEL		SHRT_TRM_REG		    ;STORE ADC_RESULT INTO JOY2UD
		XORWF		SHRT_TRM_REG, 0
		BANKSEL STATUS
		BTFSS		STATUS, Z
		GOTO $ + 4
		BANKSEL ADC_RESULT
		MOVFW		ADC_RESULT
		MOVWF		JOY2UD
		
		MOVLW		B'10001101'		    ;CASE 3
		BANKSEL		SHRT_TRM_REG		    ;STORE ADC_RESULT INTO JOY2LR
		XORWF		SHRT_TRM_REG, 0
		BANKSEL STATUS
		BTFSS		STATUS, Z
		GOTO $ + 4
		BANKSEL ADC_RESULT
		MOVFW		ADC_RESULT
		MOVWF		JOY2LR
		
		MOVLW		B'10010001'		    ;CASE 4
		BANKSEL		SHRT_TRM_REG		    ;STORE ADC_RESULT INTO JOY3UD
		XORWF		SHRT_TRM_REG, 0
		BANKSEL STATUS
		BTFSS		STATUS, Z
		GOTO $ + 4
		BANKSEL ADC_RESULT
		MOVFW		ADC_RESULT
		MOVWF		JOY3UD
		
		MOVLW		B'10010101'		    ;CASE 5
		BANKSEL		SHRT_TRM_REG		    ;STORE ADC_RESULT INTO JOY3LR
		XORWF		SHRT_TRM_REG, 0
		BANKSEL STATUS
		BTFSS		STATUS, Z
		GOTO $ + 4
		BANKSEL ADC_RESULT
		MOVFW		ADC_RESULT
		MOVWF		JOY3LR
							;END CASE
				
		BANKSEL ADCON0
		BSF		ADCON0, 1		;BEGIN A NEW CONVERSION
		
		RETURN
;*** HANDLE_RX_DATA ***********************
HANDLE_RX_DATA

		
		BANKSEL RX_INFO_REG			;CLEAR HANDLING DATA INDICATOR
		BCF		RX_INFO_REG, 6
		
		BANKSEL RX_HS
		CLRF		RX_HS			;CLEAR ALL RX VARIABLES
		CLRF		RX_CHAR1
		CLRF		RX_CHAR2
		CLRF		RX_VAR1
		CLRF		RX_VAR2

		
		RETURN
;*** RETRIEVE_PERIPHERAL_DATA *************
RETRIEVE_PERIPHERAL_DATA
		CALL		I2CIDLE			;ENSURE I2C MODULE IS IDLE
		BANKSEL	SSPCON2
		BSF		SSPCON2,SEN		;GENERATE A START CONDITION
		BANKSEL SSPCON2
		BTFSC		SSPCON2,SEN		;WAIT UNTIL START CONDITION IS COMPLETED
		GOTO 		$ - 2	
		MOVLW		B'00010101'		;SEND OUT PERIPHERAL ADDRESS BYTE (10-READ)
		BANKSEL	SSPBUF
		MOVWF	SSPBUF				
		BANKSEL	SSPSTAT
		BTFSC		SSPSTAT,BF		;WAIT UNTIL 8 BITS HAVE BEEN SHIFTED OUT
		GOTO		$ - 2
		CALL		I2CIDLE			;ENSURE IC2 MODULE IS IDLE
		
		BANKSEL	SSPCON2
		BTFSC		SSPCON2,ACKSTAT	    	;CHECK ACK BIT
		CALL 		BAD1			;RECEIVE NACK
		BTFSC		SSPCON2,ACKSTAT	    	;CHECK ACK BIT
		RETURN					;RECEIVE NACK

		BANKSEL		SSPCON2
		BSF		SSPCON2, RCEN		;RECEIVE ENABLE
		BANKSEL		SSPSTAT
		BTFSS		SSPSTAT, BF		;WAIT UNTIL 8 BITS HAVE BEEN SHIFTED IN	
		GOTO		$ - 2 
		BANKSEL SSPBUF				;STORE THE FIRST BYTE
		MOVFW		SSPBUF
		BANKSEL RX_I2C_BTN_REG
		MOVWF		RX_I2C_BTN_REG
		
		
		BANKSEL SSPCON2
		BCF		SSPCON2, RCEN
		BCF		SSPCON2, ACKSTAT
		BSF		SSPCON2, ACKDT		;INDICATES TO FINISH COMMUNICATION AND DISABLES RECEIEVE
		BSF		SSPCON2, ACKEN
		BSF		SSPCON2, PEN
		BCF		SSPCON2, SEN
		CALL I2CIDLE
		BANKSEL SSPCON1				;THIS RESETS THE SERIAL PORT AND ENSURES RELEASE OF CLOCK
		BCF		SSPCON1, SSPEN
		NOP
		BSF		SSPCON1, SSPEN
		NOP

		


		RETURN
		
	I2CIDLE	
		MOVLW 	0X1F				; Load Bus Test Value (00011111)
		BANKSEL	SSPCON2		
		ANDWF 	SSPCON2, 0			; Compare 1F to check for 5 busy conditions
		BANKSEL	STATUS
		BTFSS		STATUS,Z		;Test Zero Bit
		GOTO 		I2CIDLE			;Z=0  Bus is still busy -repeat
	CHECKR_W					;Z=1 Not Busy
		BANKSEL	SSPSTAT
		BTFSC 		SSPSTAT, R_NOT_W	; see if SSP is transmitting data
		GOTO 		CHECKR_W		;R_W = 1 - Still transmitting data
		RETURN					;R_W = 0 - Transmit done
		
	BAD1	
		MOVLW	0XFF		;SET RETURN CODE TO -1
		BANKSEL	SSPCON2
		BSF		SSPCON2,PEN		;GENERATE A STOP CONDITION
	LOOP5	
		BTFSC		SSPCON2,PEN		;IS STOP CONDITION DONE
		GOTO		LOOP5	
	    RETURN
	
;*** TOGGLE_SPEED *************************
TOGGLE_SPEED
		
		BANKSEL BTN_REG_1			;CLEAR JOYBTN1 INDICATOR
		BCF		BTN_REG_1, 6		
		BANKSEL INFO_REG			;FLIP THE TOGGLE SPEED STATE
		MOVLW		B'00010000'
		XORWF		INFO_REG, 1
		
		RETURN
;*** SEND_LOCK_BRAKES *********************
SEND_LOCK_BRAKES
		
		BANKSEL INFO_REG			;FLIP THE LOCK BRAKES STATE
		MOVLW		B'00100000'
		XORWF		INFO_REG, 1
		MOVLW		0X4C			;HEX "L"
		MOVWF		TX_CHAR			
		MOVLW		0X00			;IF (LOCK BRAKES STATE) THEN:
		BTFSC		INFO_REG, 5		    ;SET TX_VAR1 TO LOCK BRAKES
		MOVLW		0X01			;ELSE
		MOVWF		TX_VAR1			    ;SET TX_VAR1 TO RELEASE BRAKES
		CLRF		TX_VAR2
		CLRF		TX_VAR3
		CALL SEND_DATA_PACKET
		
		BANKSEL BTN_REG_1			;CLEAR BUTTON 2 INDICATOR
		BCF		BTN_REG_1, 3		;CLEAR COAST AND HARD STOP INDICATORS
		BANKSEL INFO_REG
		BCF		INFO_REG, 7
		BCF		INFO_REG, 6
		
		CALL RETRIEVE_PERIPHERAL_DATA
		
		RETURN
;*** SEND_HARD_STOP ***********************
SEND_HARD_STOP
		BANKSEL TX_CHAR
		MOVLW		0X48			;HEX "H"
		MOVWF		TX_CHAR
		CLRF		TX_VAR1
		CLRF		TX_VAR2
		CLRF		TX_VAR3
		CALL SEND_DATA_PACKET
		
		BANKSEL INFO_REG
		BCF		INFO_REG, 7		;CLEAR COAST INDICATOR (INFO_REG, 7)
		
		RETURN
;*** SEND_COAST ***************************
SEND_COAST
		BANKSEL TX_CHAR
		MOVLW		0X53			;HEX "S"
		MOVWF		TX_CHAR
		CLRF		TX_VAR1
		CLRF		TX_VAR2
		CLRF		TX_VAR3
		CALL SEND_DATA_PACKET			;SEND COAST COMMAND
		
		BANKSEL INFO_REG
		BCF		INFO_REG, 7		;CLEAR COAST INDICATOR (INFO_REG, 7)
		
		RETURN
;*** SET_FWD_VAR **************************
SET_FWD_VAR
		BANKSEL JOY1UD				;SET TX_VAR1 TO 2 * (JOY1UD - 128)
		MOVFW		JOY1UD
		BANKSEL TX_VAR1
		MOVWF		TX_VAR1
		MOVLW		D'128'
		SUBWF		TX_VAR1, 1
		LSLF		TX_VAR1, 1					
					
		BANKSEL INFO_REG
		BTFSC		INFO_REG, 4		;IF (TOGGLED SPEED) THEN:
		LSRF		TX_VAR1, 1		;TX_VAR1 = TX_VAR1 / 4
		BTFSC		INFO_REG, 4
		LSRF		TX_VAR1, 1
		
		BANKSEL TX_CHAR
		MOVLW		0X46			;SET TX_CHAR TO 'F'
		MOVWF		TX_CHAR
		CLRF		TX_VAR2			;CLEAR TX_VAR2
		CLRF		TX_VAR3			;CLEAR TX_VAR3
		CALL SEND_DATA_PACKET			;SEND DATA PACKET FOR FORWARD
		
		BANKSEL INFO_REG
		BCF		INFO_REG, 7		;CLEAR COAST INDICATOR (INFO_REG, 7)
		
		RETURN
;*** SET_REV_VAR **************************
SET_REV_VAR
		BANKSEL JOY1UD				;SET TX_VAR1 TO 255 - (JOY1UD * 2)
		MOVFW		JOY1UD
		BANKSEL TX_VAR1
		MOVWF		TX_VAR1
		LSLF		TX_VAR1, 1
		MOVFW		TX_VAR1
		SUBLW		D'255'
		MOVWF		TX_VAR1
		
		BANKSEL INFO_REG
		BTFSC		INFO_REG, 4		;IF (TOGGLED SPEED) THEN:
		LSRF		TX_VAR1, 1		;TX_VAR1 = TX_VAR1 / 4
		BANKSEL INFO_REG
		BTFSC		INFO_REG, 4
		LSRF		TX_VAR1, 1

		BANKSEL TX_CHAR
		MOVLW		0X42			;SET TX_CHAR TO 'B'
		MOVWF		TX_CHAR
		CLRF		TX_VAR2			;CLEAR TX_VAR2
		CLRF		TX_VAR3			;CLEAR TX_VAR3
		CALL SEND_DATA_PACKET			;SEND DATA PACKET FOR BACKWARD
		
		BANKSEL INFO_REG
		BCF		INFO_REG, 7		;CLEAR COAST INDICATOR (INFO_REG, 7)
		
		RETURN
;******************************************
MODE_1_MAIN
;******************************************
		
		BANKSEL PORTE				;IF (BUTTON 2) THEN:
		BTFSC		PORTE, 1		    ;SET BUTTON2_INDICATOR
		BSF		BTN_REG_1, 3		
		
		BANKSEL PORTC				;IF (JOYBTN1) THEN
		BTFSC		PORTC, 1		    ;SET JOYBTN1_INDICATOR
		BSF		BTN_REG_1, 6

		BANKSEL RX_INFO_REG			;IF (HANDLE DATA INDICATOR) THEN:
		BTFSC		RX_INFO_REG, 6		    ;CALL HANDLE DATA
		CALL HANDLE_RX_DATA
		
		MOVLW		D'140'
		BANKSEL JOY1UD
		SUBWF		JOY1UD, 0
		BANKSEL STATUS
		BTFSC		STATUS, C
		BSF		PORTD, 0
		BTFSS		STATUS, C
		BCF		PORTD, 0
		
		
		MOVLW		D'140'
		BANKSEL JOY1LR
		SUBWF		JOY1LR, 0
		BANKSEL STATUS
		BTFSC		STATUS, C
		BSF		PORTD, 1
		BTFSS		STATUS, C
		BCF		PORTD, 1
		
		
		MOVLW		D'140'
		BANKSEL JOY2UD
		SUBWF		JOY2UD, 0
		BANKSEL STATUS
		BTFSC		STATUS, C
		BSF		PORTD, 2
		BTFSS		STATUS, C
		BCF		PORTD, 2

		
		MOVLW		D'140'
		BANKSEL JOY2LR
		SUBWF		JOY2LR, 0
		BANKSEL STATUS
		BTFSC		STATUS, C
		BSF		PORTD, 3
		BTFSS		STATUS, C
		BCF		PORTD, 3

		
		MOVLW		D'140'
		BANKSEL JOY3UD
		SUBWF		JOY3UD, 0
		BANKSEL STATUS
		BTFSC		STATUS, C
		BSF		PORTD, 4
		BTFSS		STATUS, C
		BCF		PORTD, 4

		
		MOVLW		D'140'
		BANKSEL JOY3LR
		SUBWF		JOY3LR, 0
		BANKSEL STATUS
		BTFSC		STATUS, C
		BSF		PORTD, 5
		BTFSS		STATUS, C
		BCF		PORTD, 5
		
		BANKSEL BTN_REG_1			;IF (JOYBTN1 & !PORTC_1) THEN:
		BTFSS		BTN_REG_1, 6		    ;CALL TOGGLE_SPEED
		GOTO $ + 4				    ;SET TX_VAR1 = TX_VAR1 / 4
		BTFSC		PORTC, 1		    ;CLEAR JOYBTN1 INDICATOR
		GOTO $ + 2
		CALL TOGGLE_SPEED		  		

		
		BANKSEL INFO_REG
		BSF		INFO_REG, 7		;SET COAST INDICATOR (INFO_REG, 7)
		
		MOVLW		D'140'			;IF (JOY1UD > 140) THEN:	
		BANKSEL JOY1UD				    ;CALL SET_FWD_VAR 
		SUBWF		JOY1UD, 0		    ;CLEAR COAST INDICATOR (INFO_REG, 7)	
		BANKSEL STATUS				      
		BTFSC		STATUS, C		    
		CALL SET_FWD_VAR
		
		MOVLW		D'113'			;IF (JOY1UD < 113) THEN:	
		BANKSEL JOY1UD			    ;CALL SET_REV_VAR
		SUBWF		JOY1UD	, 0		    ;CLEAR COAST INDICATOR (INFO_REG, 7)
		BANKSEL STATUS				    
		BTFSS		STATUS, C		    
		CALL SET_REV_VAR		
		
		BANKSEL BTN_REG_1			;IF (BTN2_IND & !PORTE_1) THEN:
		BTFSS		BTN_REG_1, 3		    ;CALL SEND_LOCK_BRAKES
		GOTO $ + 4				    ;CLEAR COAST INDICATOR
		BTFSC		PORTE, 1		    ;CLEAR HARD STOP INDICATOR
		GOTO $ + 2
		CALL SEND_LOCK_BRAKES
		
		BANKSEL BTN_REG_1			;IF (BUTTON 1 PRESSED) THEN:
		BTFSC		BTN_REG_1, 2		    ;CALL SEND_HARD_STOP
		CALL SEND_HARD_STOP			    ;CLEAR COAST INDICATOR
		
		BANKSEL INFO_REG			;IF (COAST INDICATOR) THEN:
		BTFSC		INFO_REG, 7		    ;CALL SEND_COAST
		CALL SEND_COAST				    ;CLEAR COAST INDICATOR
							
		
		BANKSEL TX_CHAR				;TRANSMIT TURN ROTATION COMMAND ('t')
		MOVLW		0X74			;TRANSMITS JOY1LR
		MOVWF		TX_CHAR
		MOVFW		JOY1LR			
		MOVWF		TX_VAR1
		CLRF		TX_VAR2
		CLRF		TX_VAR3
		CALL SEND_DATA_PACKET

		
		GOTO MAIN
;******************************************
MODE_2_MAIN
;******************************************
		
		BANKSEL PORTE				;IF (NOT BUTTON 2) THEN:
		BTFSC		PORTE, 1		    ;CLEAR BUTTON2_INDICATOR (BTN_REG_1 BIT3)
		BSF		BTN_REG_1, 3		;ELSEIF (BUTTON 2) THEN:
		BTFSS		PORTE, 1		    ;SET BUTTON2_INDICATOR (BTN_REG_1 BIT3)
		BCF		BTN_REG_1, 3
		
		BANKSEL PORTC				;IF (NOT JOYBTN 1) THEN:
		BTFSC		PORTC, 1		    ;CLEAR JOYBTN1_INDICATOR (BTN_REG_1 BIT6)
		BSF		BTN_REG_1, 6		;ELSEIF (JOYBTN 1) THEN:
		BTFSS		PORTC, 1		    ;SET JOYBTN1_INDICATOR (BTN_REG_1 BIT6)
		BCF		BTN_REG_1, 6
		
		BANKSEL PORTD
		BTFSC		BTN_REG_1, 0
		BSF		PORTD, 7
		BTFSS		BTN_REG_1, 0
		BCF		PORTD, 7
		
		BANKSEL PORTD
		BTFSC		BTN_REG_1, 1
		BSF		PORTD, 6
		BTFSS		BTN_REG_1, 1
		BCF		PORTD, 6
		
		BANKSEL PORTD
		BTFSC		BTN_REG_1, 2
		BSF		PORTD, 5
		BTFSS		BTN_REG_1, 2
		BCF		PORTD, 5
		
		BANKSEL PORTD
		BTFSC		BTN_REG_1, 3
		BSF		PORTD, 4
		BTFSS		BTN_REG_1, 3
		BCF		PORTD, 4
		
		BANKSEL PORTD
		BTFSC		BTN_REG_1, 4
		BSF		PORTD, 3
		BTFSS		BTN_REG_1, 4
		BCF		PORTD, 3
		
		BANKSEL PORTD
		BTFSC		BTN_REG_1, 5
		BSF		PORTD, 2
		BTFSS		BTN_REG_1, 5
		BCF		PORTD, 2
		
		BANKSEL PORTD
		BCF		PORTD, 1
		BTFSC		BTN_REG_1, 6
		BSF		PORTD, 1
		BTFSC		BTN_REG_1, 7
		BSF		PORTD, 1
		BTFSC		BTN_REG_2, 0
		BSF		PORTD, 1
		BCF		PORTD, 0
		
		GOTO MAIN
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
EMERGENCY_MODE
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
;		BANKSEL INTCON
;		CLRF		INTCON		    ;DISABLE ALL INTERRUPTS
		BANKSEL TX_CHAR
		MOVLW		0X45		    ;TRANSMIT EMERGENCY STOP CONSTANTLY
		MOVWF		TX_CHAR
		CLRF		TX_VAR1
		CLRF		TX_VAR2
		CLRF		TX_VAR3
		CALL SEND_DATA_PACKET
		BANKSEL PORTD			    ;SET ALL LED INDICATORS HIGH
		MOVLW		0XFF
		MOVWF		PORTD
		GOTO EMERGENCY_MODE
;******************************************
MAIN
;******************************************
		BANKSEL PORTB				;STORE PORTB INTO ROBOT ADDRESS
		MOVFW		PORTB			;CLEAR BIT 7 AS THIS IS A 7-BIT ADDRESS
		MOVWF		RBT_ADR
		BCF		RBT_ADR, 7
		
		BANKSEL PORTA				;IF (NOT TRIGGER1) THEN:
		BTFSC		PORTA, 6		    ;CLEAR TRIGGER1_INDICATOR (BTN_REG_1 BIT0)
		BSF		BTN_REG_1, 0		;ELSEIF (TRIGGER1) THEN:
		BTFSS		PORTA, 6		    ;SET TRIGGER1_INDICATOR (BTN_REG_1 BIT0)
		BCF		BTN_REG_1, 0
			
		BANKSEL PORTA				;IF (NOT TRIGGER2) THEN:
		BTFSC		PORTA, 7		    ;CLEAR TRIGGER2_INDICATOR (BTN_REG_1 BIT1)
		BSF		BTN_REG_1, 1		;ELSEIF (TRIGGER1) THEN:
		BTFSS		PORTA, 7		    ;SET TRIGGER2_INDICATOR (BTN_REG_1 BIT1)
		BCF		BTN_REG_1, 1
		
		BANKSEL PORTA				;IF (NOT BUTTON 1) THEN:
		BTFSC		PORTA, 4		    ;CLEAR BUTTON1_INDICATOR (BTN_REG_1 BIT2)
		BSF		BTN_REG_1, 2		;ELSEIF (BUTTON 1) THEN:
		BTFSS		PORTA, 4		    ;SET BUTTON1_INDICATOR (BTN_REG_1 BIT2)
		BCF		BTN_REG_1, 2
		
		BANKSEL PORTE				;IF (NOT BUTTON 3) THEN:
		BTFSC		PORTE, 2		    ;CLEAR BUTTON3_INDICATOR (BTN_REG_1 BIT4)
		BSF		BTN_REG_1, 4		;ELSEIF (BUTTON 3) THEN:
		BTFSS		PORTE, 2		    ;SET BUTTON3_INDICATOR (BTN_REG_1 BIT4)
		BCF		BTN_REG_1, 4
		
		BANKSEL PORTC				;IF (NOT BUTTON 4) THEN:
		BTFSC		PORTC, 0		    ;CLEAR BUTTON4_INDICATOR (BTN_REG_1 BIT5)
		BSF		BTN_REG_1, 5		;ELSEIF (BUTTON 4) THEN:
		BTFSS		PORTC, 0		    ;SET BUTTON4_INDICATOR (BTN_REG_1 BIT5)
		BCF		BTN_REG_1, 5
		
		BANKSEL PORTC				;IF (NOT JOYBTN 2) THEN:
		BTFSC		PORTC, 2		    ;CLEAR JOYBTN2_INDICATOR (BTN_REG_1 BIT7)
		BSF		BTN_REG_1, 7		;ELSEIF (JOYBTN 2) THEN:
		BTFSS		PORTC, 2		    ;SET JOYBTN2_INDICATOR (BTN_REG_1 BIT7)
		BCF		BTN_REG_1, 7
		
		BANKSEL PORTC				;IF (NOT JOYBTN 3) THEN:
		BTFSC		PORTC, 5		    ;CLEAR JOYBTN3_INDICATOR (BTN_REG_2 BIT0)
		BSF		BTN_REG_2, 0		;ELSEIF (JOYBTN 3) THEN:
		BTFSS		PORTC, 5		    ;SET JOYBTN3_INDICATOR (BTN_REG_2 BIT0)
		BCF		BTN_REG_2, 0
		
		BANKSEL ADCON0				;IF (ADC DONE) THEN:
		BTFSS		ADCON0, 1		    ;CALL CONVERSION_DONE
		CALL CONVERSION_DONE
		
		BANKSEL BTN_REG_1
		BTFSC		BTN_REG_1, 5		;IF (EMERGENCY BUTTON) THEN:
		GOTO EMERGENCY_MODE			    ;GOTO EMERGENCY MODE
							    
		BANKSEL PORTB				;IF (!MODE SELECT) THEN:
		BTFSS		PORTB, 7		    ;GOTO MODE_1_MAIN
		GOTO MODE_1_MAIN			;ELSEIF (MODE SELECT) THEN:
		BANKSEL PORTB				    ;GOTO MODE_2_MAIN
		BTFSC		PORTB, 7
		GOTO MODE_2_MAIN

		GOTO	MAIN				;LOOP BACK
		END
;********************END PROGRAM DIRECTIVE ***********************************
;*****************************************************************************
