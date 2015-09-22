'This version is for PIC 16C715 only!!!!!!!!!!!!!!!!!!
'NOTES - This version uses the multiplexed buttons. The  buttons (on RB0) change function
'depending on the mode that unit is in at the time. 
'This version re initializes the LCD modes are changed (stopped, running, settings). 
'This version now lets settings be changed while driving, hold 'up' and 'down' buttons for two seconds. 

'Turbo timer program Ver 
'PIC 16C715 port pin alocations
'RA0 = turbo temp
'RA1 = boost pressure
'RA2 = engine oil temp
'RA3 = battery volts
'RA4 = LCD E (enable), read the port (10K pullup is required)
'RB0 = LCD data4 (LSB)  + Stop/Prog button
'RB1 = LCD data5        + Up button
'RB2 = LCD data6        + Down button
'RB3 = LCD data7
'RB4 = LCD RS (register select), command or data
'RB5 = Alarm LED output
'RB6 = Ignition hold
'RB7 = Ignition sense
'           
'registers used B0,B1(bit vars), B2, B3, B4 and B5(W2),, B10, B11, B12, B13,B15, B16, B17, B18
'B0 is used by LCD routines because bit manipulation is required (bit vars 0 to 15)
'B1 likewise but for allowing the alarm LED and Hold Pin to be used on Port B simultaneously with LCD data
'B2 is used for storage of the character/command to be displayed/sent next
'B3,B6 and B7 is used by for-next loops
'B4 and B5 taken by W2 which is used for holding scaling results

Symbol  LCD = B2                        'Variable to store next character to be sent to LCD
Symbol  Loop_VAR1 = B3                  'Varable for timing for/next loop
	'W2 uses B4 and B5
Symbol  Loop_VAR2 = B6                  'Varable for timing for/next loop
Symbol  Loop_Var3 = B7                  'Varaible for a third for/next loop 
Symbol  ADC_SET = B8                    'location of the hex value of the ADC channel set command
Symbol  ADC_CONVERT = B9                'location of the hex value of the ADC channel set command
Symbol  ADC_VALU = B10                  'location of the A/D value                      'Varaible for second timing for/next loop
Symbol  ALARMSET = B11                  'Variable to keep track of each analog inputs alarms status
Symbol  Timerset = W6                   'Variable (16 Bit) to keep track of the turbo timer timing (B12 and B13 = W6)
Symbol  peakTt = B16                    'Variable for location of peak reading, turbo temp
Symbol  peakTb = B17                    'Variable for location of peak reading, turbo boost
Symbol  peakOt = B18                    'Variable for location of peak reading, oil temp
Symbol  peakBv = B19                    'Variable for location of peak reading, batt volt
Symbol  Store1 = W10                    'Variable (16 Bit) for location of a temporary variable,B20 and B21
Symbol  Time_off = W11                  'Variable to store the maximum turbo timer duration (value = off time in seconds)
Symbol  Temp_off = B24                  'Variable to store 'turbo timer off' temperature (as step value)        
Symbol  Alarm_TT = B25                  'Variable to store turbo temp alarm point (as step value)
Symbol  Alarm_TB = B26                  'Variable to store turbo boost alarm point (as step value)
Symbol  Alarm_OT = B27                  'Variable to store oil temp alarm point (as step value)
Symbol  Alarm_BV = B28                  'Variable to store battery volts alarm point (as step value)
Symbol  ButtonNum = B29                 'Variable to store the number of the button pushed
Symbol  Mode = B30                      'Variable to store the current setting mode
Symbol  Time_Out = B31                  'Variable to hold number of button checks for time out if none pressed
Symbol  Store2 = B32                    'Variable loctaion of 8 bit general temporary variable
Symbol  ADCON0 = $1F                    'A/D Configuration Register 0
Symbol  ADRES = $1E                     'A/D Result
Symbol  ADCON1 = $9F                    'A/D Configuration Register 1
Symbol  PortB = 6                       'PortB is PIC register 6
Symbol  TrisB = $86                     'PortB data direction is PIC register hexadecimal 86
Symbol  PortA = 5                       'PortA register address
Symbol  TrisA = $85                     'PortA data direction register address

Symbol  Buttons_on = %10000111          '1=input, 0=output, byte for port B pins 0,1,2 and 7 as inputs, 3,4,5,6 as outputs
Symbol  Buttons_off = %10000000         'byte for portB pins 0,1,2,3,4,5,6 as outputs, pin 7 as input 



'Default timer and temperature alarm values
	TIME_OFF = 300                  'default maximum turbo timer duration (value = 0.5 of time in seconds)
	TEMP_OFF = 103                  'default 'turbo timer off' temperature (as step value)  
	ALARM_TT = 128                  'default turbo temp alarm point (as step value)
	ALARM_TB = 121                  'default turbo boost alarm point (as step value)
	ALARM_OT = 51                   'default oil temp alarm point (as step value)
	ALARM_BV = 150                  'default battery volts alarm point (as step value)      

'initialization routine
	poke trisA, $f                  'pins RA0-3 as inputs, RA4 as output (digital i/o mode)
	poke portA, 0                   'set E line low (all porta low)
	poke TrisB, $80                 'set PortB lines 0 to 6 to output, 7 to input
	Poke PortB, 0                   'start with all LCD lines low
	gosub lcdinit                   'go and initialise the LCD to be in 4 bit mode etc.
	gosub lcdclr                    'Clear and home the LCD after initialization    
	gosub paws1                     '1ms delay via subroutine, to wait for LCD to finish initializing     
	for loop_var3 = 0 to 15         'for/next loop that sends a character string to the LCD via 'lookup'
	lookup loop_var3,("Default settings"),LCD
	gosub lcddata                   'send 'data' byte to the LCD    
	next loop_var3                  'next increment of for/next loop        
	LCD = $c0                       'Set variable LCD to the command value $c0 that will shift LCD cursor to lower line
	gosub lcdcom                    'Send the command via subroutine 'lcdcom'
	for loop_var3 = 0 to 15         'for/next loop that sends a character string to the LCD on line 2, via 'lookup'
	lookup loop_var3,("loaded in to RAM"),LCD
	gosub lcddata                   'send 'data' byte to the LCD
	next loop_var3                  'next increment of for/next loop

	poke portb, $20                 'lamp test, turn on warning LED and dash lamp, $20 is 100000 in binary (pin RB6)
	gosub paws1000                  '1000ms delay via subroutine, repeats 4 times to get 4 seconds
	gosub paws1000                  
	gosub paws1000
	gosub paws1000
	gosub lcdclr                    'clear lcd
	poke portb, 0                   'turn off warning LED and lamp
	goto stopped                    'goto the engine off routine

'main loop with engine off---------------------------------------------------------------------
stopped:  ADC_SET = $81                 'The A/D channel and cofiguration byte for AD1  
	ADC_CONVERT = $45               'The 'start conversion' command byte for AD1
	gosub getadc                    'get and store the ADC value
	gosub disptt                    'display the turbo temp, via subroutine
	
	gosub dispco                    'Display 'eng off' text message

	gosub setadc                    'set the ADC port for AD2 (toggles to next A/D)
	gosub setadc                    'set the ADC port for AD3 (skiped AD2, no boost with engine off)
	gosub getadc                    'get and store the ADC value
	gosub dispot                    'display the oil temp, via subroutine
	
	gosub setadc                    'set the ADC port for AD3
	gosub getadc                    'get and store the ADC value
	gosub dispbv                    'display the battery volts via subroutine

	if pin7 = 1 then started        'pin7 = ignit i/p. goto 'started' , tests for engine start.

	gosub buttons                   'check to see one of the buttons is being pressed
	if ButtonNum = %00000001 then stop      'if select button is pressed display peaks via 'stop'
	if ButtonNum = %00000110 then settings  'if the up and down buttons are both pressed then jump to 'settings' subroutine

	goto stopped                    'loop around again

started: gosub lcdinit                  'reboot the LCD in case it has crashed
	PEAKTT = 0 : PEAKTB = 0         'clear peaks, then fall through to 'running
	PEAKOT = 0 : PEAKBV = 0
	
'Engine Running mode loop-------------------------------------------------------------
running: alarmset = 0
	
	gosub Button_fast               'check to see if a button is pressed, via the faster button routine. Not debounced.
	if ButtonNum = %00000001 then stop      'goto 'display peaks' via 'stop'
	if ButtonNum = %00000110 then settings  'enter settings mode while driving if required

	ADC_SET = $81                   'the A/D channel and cofiguration portA byte for AD1 
	ADC_CONVERT = $45               'The 'start conversion' portA command byte for AD1
	gosub average                   'get and store the ADC value, via subroutine
	gosub disptt                    'display the turbo temp, via subroutine
	gosub ignit                     'as two above, checks are made often as possible to reduce relay switch delay time. 
	gosub alarmTT                   'test turbo temp value against a set point, via subroutine
	if ADC_VALU < PEAKTT then boost 'if temp is not higher than the stored peak skip next line.
	PEAKTT = ADC_VALU               'update the stored peak temp with the new peak value.
	

boost:  gosub ignit                     'checks ignition line to detect engine being switched off.
	gosub setadc                    'set the ADC port for AD2,toggels through all 4 A/D's
	gosub average                   'get and store the ADC value, does 10 reading and takes average, via subroutine
	gosub disptb                    'display the turbo boost, via subroutine
	gosub ignit                     'checks ignition line to detect engine being switched off.
	gosub alarmTB                   'test turbo boost value against a set point, via subroutine
	if ADC_VALU < PEAKTB then oil_temp      'if boost is not higher than the stored peak, skip next line.
	PEAKTB = ADC_VALU

oil_temp: gosub ignit                   'checks ignition line to detect engine being switched off.
	gosub setadc                    'set the ADC port for AD3       
	gosub average                   'get and store the ADC value
	gosub dispot                    'display the oil temp, via subroutine
	gosub ignit                     'checks ignition line to detect engine being switched off.
	gosub alarmOT                   'test oil temp value against a set point, via subroutine
	if ADC_VALU < PEAKOT then Volts         'if temp is not higher than the stored peak, skip next line.
	PEAKOT = ADC_VALU

Volts:  gosub ignit                     'checks ignition line to detect engine being switched off.
	gosub setadc                    'set the ADC port for AD4       
	gosub average                   'get and store the ADC value, does 10 reading and takes average
	gosub dispbv                    'display the battery volts, via subroutine
	gosub ignit                     'checks ignition line to detect engine being switched off.
	gosub alarmBV                   'test battery volts value against a set point, via subroutine
	if ADC_VALU < PEAKBV then skip2         'if volts is not higher than the stored peak, skip next line.
	PEAKBV = ADC_VALU
skip2:  gosub ignit                     'checks ignition line to detect engine being switched off.
	if ALARMSET = 1 then on         'check alarm status variable, if 1 then turn on the LED and lamp,skip next line 
	gosub led_off                   'turn LED and lamp off
	goto running                    'loop around and do it all again

on:     gosub led_on                    'turn on LED/lamp via subroutine
	goto running                    'loop around and do it all again

'Button routines---------------------------------------------------------------
'This routine checks to see if one of the three buttons is pressed, and debounces. Stores value in ButtonNum
Buttons: ButtonNum = 0                  'Reset variable to zero
	poke trisb, Buttons_on          'change portB pins 0,1 and 2 to inputs
	gosub paws1                     'wait 1ms for port to stabilize
	peek portb, Store2              'read portB and poke value to variable 'store2'
	pause 10                        'wait 10ms (button debounce period)
	peek portb, ButtonNum           'read portB and poke value to variable 'ButtonNum'
	if ButtonNum = Store2 then done 'check to see if the 'same' button is still pressed
	goto Buttons
'        ButtonNum = 0                   'if not then reset the variable
Done:   poke trisb, Buttons_off         'change portB pins 0,1 and 2 to outputs
	gosub paws1                     'wait 1ms for port to stabilize
	ButtonNum = ButtonNum & %00000111       'mask off any bits higher than 111
	return

'The same as the above routine BUT with no debounce, to speed it up.
Button_fast: ButtonNum = 0              'Reset variable to zero
	poke trisb, Buttons_on          'change portB pins 0,1 and 2 to inputs
	gosub paws1                     'wait 1ms for port to stabilize
	peek portb, ButtonNum           'read portB and poke value to variable 'ButtonNum'
	gosub Done
	return

'This routine waits for the button to be released before continueing
Wait:   gosub buttons                   '
	if ButtonNum > 0 then Wait      'if any button is still held down, wait some more
	return

settings: gosub lcdinit                 're-initialize the LCD, LCD crash recovery      
'       gosub lcdclr    
	gosub paws1                     'wait 1ms for lcd to reset
	for loop_var3 = 0 to 15         'for/next loop that sends a character string to the LCD via 'lookup'
	lookup loop_var3,(" Hold to enter  "),LCD
	gosub lcddata                   'send 'data' byte to the LCD 
	next loop_var3                  'next increment of for/next loop
	LCD = $c0                       'Set variable LCD to the command value $c0 that will shift LCD cursor to lower line
	gosub lcdcom                    'Send the command via subroutine 'lcdcom'
	for loop_var3 = 0 to 15         'for/next loop that sends a character string to the LCD on line 2, via 'lookup'
	lookup loop_var3,("  settings mode "),LCD
	gosub lcddata                   'send 'data' byte to the LCD 
	next loop_var3                  'next increment of for/next loop
	gosub paws1000                  'pause 2 seconds to show the message
	gosub paws1000
	gosub buttons                   'check buttons again
'        if ButtonNum = %00000001 then mode1     'if button 1 is still down then enter the 'settings' mode screens
	if ButtonNum =%00000110 then mode1      'if both up and down buttons are pressed enter 'settings' mode screens
 
exiting: gosub lcdclr                   'clear the LCD and home the cursor
	gosub paws1                     'wait 1ms for clear to complete
	for loop_var3 = 0 to 15         'for/next loop that sends a character string to the LCD via 'lookup'    
	lookup loop_var3,("    Exiting     "),LCD
	gosub lcddata                   'send 'data' byte to the LCD 
	next loop_var3                  'next increment of for/next loop
	gosub paws1000                  'wait 1 second (to display the message)
	goto stopped                    'finished, go back to the engine off mode

'These are routines to allow the user to set the timer and alarm point values, each value is set in a 'mode'
mode1:  'MODE = 1                       'store the value of the mode that is being used 
	gosub lcdclr                    'clear LCD
	gosub paws1                     'wait for LCD to finish
	for loop_var3 = 0 to 15         'see above for comments on text loops
	lookup loop_var3,(" TEMP for timer "),LCD
	gosub lcddata
	next loop_var3
	LCD = $c0
	gosub lcdcom
	for loop_var3 = 0 to 15
	lookup loop_var3,(" off? < --- degC"),LCD
	gosub lcddata
	next loop_var3

	gosub Wait                      'wait for button to be released before proceeding. So mode is not skipped.

mode11: LCD = $c8                       'set LCD cursor location to character 8 on line 2
	gosub lcdcom
	W2 = TEMP_OFF * 39               'W2 holds ttemp * 39 then divided by 10 = * 3.9
	W2 = W2 / 10                    'divide W2 by 10 to arrive at W2/3.9
	gosub send3num                  'send the temperature values to the LCD, to display the user value
	gosub buttons                   'check the buttons
	
	if ButtonNum = %00000001 then Mode2     'if button 1 is pushed jump to Mode2
	if ButtonNum = %00000010 then Up1       'if button 2 is pushed increment value
	if ButtonNum = %00000100 then Down1     'if button 3 is pushed decrement value  
	goto mode11                             'keep going until button 1 is pushed
	

Up1:    TEMP_OFF = TEMP_OFF + 1 Max 193         'increment TEMP_OFF by 1 (adc step value) to a maximum value of 193
	gosub paws200                           'wait for 200ms, this sets the increment repeat speed (about 5 per sec)
	goto mode11                             'go back and display the change in value

Down1:  TEMP_OFF = TEMP_OFF - 1 Min 25          'decrement TEMP_OFF by 1 (adc step value) to a minimum value of 25      
	gosub paws200                           'wait for 200ms, this sets the increment repeat speed (about 5 per sec)
	goto mode11                             'go back and display the change in value
	
Mode2:  'MODE = 2                               'same as above but for the 'maximum' timer time out period
	gosub lcdclr                            'all the same stuff as above, just the variables have changed
	gosub paws1
	for loop_var3 = 0 to 15
	lookup loop_var3,(" TIME for timer "),LCD
	gosub lcddata
	next loop_var3
	LCD = $c0
	gosub lcdcom
	for loop_var3 = 0 to 15
	lookup loop_var3,("off MAX --- Sec "),LCD
	gosub lcddata
	next loop_var3
	gosub Wait

mode21: LCD = $c8
	gosub lcdcom
	W2 = TIME_OFF                   'no scaleing is required as the value is in 1 second units
	gosub send3num                  'send the temp values
	gosub buttons
	
	if ButtonNum = %00000001 then Mode3
	if ButtonNum = %00000010 then Up2
	if ButtonNum = %00000100 then Down2
	goto mode21

Up2:    TIME_OFF = TIME_OFF + 10 Max 600        'increment by 10, up to max of 600 seconds (10 minutes)
	gosub paws100
	goto mode21

Down2:  TIME_OFF = TIME_OFF - 10 Min 30         'decrement by 10, down to min of 30 seconds (0.5 minutes)
	gosub paws100
	goto mode21

Mode3:  'MODE = 3
	gosub text1

	LCD = $c0
	gosub lcdcom
	gosub text2
'        for loop_var3 = 0 to 15
'        lookup loop_var3,(" TEMP > --- degC"),LCD
'        gosub lcddata
'        next loop_var3
	gosub Wait

mode31: LCD = $c8
	gosub lcdcom
	W2 = ALARM_TT * 39               'W2 holds ttemp * 39 then divided by 10 = * 3.9
	W2 = W2 / 10
	gosub send3num                  'send the temp values
	gosub buttons
	
	if ButtonNum = %00000001 then Mode4
	if ButtonNum = %00000010 then Up3
	if ButtonNum = %00000100 then Down3
	goto mode31

Up3:    ALARM_TT = ALARM_TT + 1 Max 231
	gosub paws200
	goto mode31

Down3:  ALARM_TT = ALARM_TT - 1 Min 13
	gosub paws200
'        pause 200
	goto mode31

Mode4:  'MODE = 4

	gosub text1             'uses a subroutine to send line 1 text, to save space, also used again below

	LCD = $c0
	gosub lcdcom
	for loop_var3 = 0 to 15
	lookup loop_var3,("BOOST > -.-- Bar"),LCD
	gosub lcddata
	next loop_var3
	gosub Wait

mode41: LCD = $c8
	gosub lcdcom
	
	W2 = ALARM_TB - 12                'W2 to hold tboost - offset in steps
	W2 = W2 * 92                    'W2 by multipier value X 100
	gosub DivW2by100                'W2 divided by 100 to get back to multiplier, via subroutine(to save space)
	gosub sendbar                   'send the value as x.xx formate, via subroutine

	gosub buttons
	if ButtonNum = %00000001 then Mode5
	if ButtonNum = %00000010 then Up4
	if ButtonNum = %00000100 then Down4
	goto mode41

Up4:    ALARM_TB = ALARM_TB + 1 Max 230
	gosub paws100
	goto mode41

Down4:  ALARM_TB = ALARM_TB - 1 Min 23
	gosub paws100
	goto mode41

Mode5:  'MODE = 3
	gosub lcdclr
	gosub paws1
	for loop_var3 = 0 to 15
	lookup loop_var3,(" Oil warning at "),LCD
	gosub lcddata
	next loop_var3
	LCD = $c0
	gosub lcdcom
	gosub text2
'        for loop_var3 = 0 to 15
'        lookup loop_var3,(" TEMP > --- degC"),LCD
'        gosub lcddata
'        next loop_var3
	gosub Wait

mode51: LCD = $c8
	gosub lcdcom
	W2 = ALARM_OT * 196             'W2 hold Otemp * 196 then divided by 100 = * 1.96
	gosub DivW2by100                'W2 divided by 100 to get back to multiplier, via subroutine
	gosub send3num                  'send the temp values
	
	gosub buttons
	if ButtonNum = %00000001 then exiting
	if ButtonNum = %00000010 then Up5
	if ButtonNum = %00000100 then Down5
	goto mode51

Up5:    ALARM_OT = ALARM_OT + 1 Max 103
	gosub paws200
	goto mode51

Down5:  ALARM_OT = ALARM_OT - 1 Min 26
	gosub paws200
'        pause 200
	goto mode51


text1:  gosub lcdclr
	gosub paws1
	for loop_var3 = 0 to 15
	lookup loop_var3,("Turbo warning at"),LCD
	gosub lcddata
	next loop_var3  
	return

text2:  for loop_var3 = 0 to 15
	lookup loop_var3,(" TEMP > --- degC"),LCD
	gosub lcddata
	next loop_var3
	return



'Utility subroutines-----------------------------------------------------------

ignit:  if pin7 = 0 then timer          'if ignition drops in running mode start the turbo timer
	return 

SetADC: ADC_SET = ADC_SET + 8           'toggle the A/D address and conversion values (switch A/D's)
	ADC_CONVERT = ADC_CONVERT + 8
	return

'routine to get an averaged A/D result and place the result in ADC_VALU variable.                                        
average: store1 = 0                     ' clear the temp variables      
	
	for Loop_Var3 = 0 to 9          'averaging routine, sample 10 times then divide by 10
	gosub getadc                    'go get A/D result 
	store1 = store1 + ADC_VALU      'Add (sum) the result to the previous results
	gosub ignit                     'check for engine turning off, via subroutine
	next Loop_Var3                  'back to loop
	ADC_VALU = store1 / 10          'divide by 10 (average) and place result back to ADC_VALU etc.
	return

'this routine may now be redundant (since ver21a), please check MCS.********************
'this average subroutine does not check ignition during averageing, used in timer loop
average2: store1 = 0                     ' clear the temp variables      
	
	for Loop_Var3 = 0 to 9          'averaging routine, sample 10 times then divide by 10
	gosub getadc                    'go get A/D result 
	store1 = store1 + ADC_VALU      'Add (sum) the result to the previous results
	next Loop_Var3                  'back to loop
	ADC_VALU = store1 / 10          'divide by 10 (average) and place result back to ADC_VALU etc.
	return

'alarm point reached routines, from A/D results after averageing routine.

alarm:  alarmset = 1                    'if an alarm set point is reached  from below, set varaible 'alarmset' to 1
	return
				
alarmTT: if ADC_VALU > ALARM_TT then alarm      'test against preset alarm point
	return
alarmTB: if ADC_VALU > ALARM_TB then alarm     'test against preset alarm point ( add offset steps !)
	return
alarmOT: if ADC_VALU > ALARM_OT then alarm       'test against preset alarm point
	return
alarmBV: if ADC_VALU > ALARM_BV then alarm      'test against preset alarm point
	return

'turn on the alarm LED routine, sets 8th bit in B0 and is poked to the port by lcddata and lcdcom routines
led_on:  Bit8 = 1                  'set variable to be used by lcddata and lcdcom
	return

led_off: bit8 = 0
	return


paws1000: pause 1000
	return

paws100: pause 100
	return

paws200: pause 200
	return

paws1:  pause 1
	return                  

DivW2by100: W2 = W2 / 100                   'W2 divided by 100 to get back to multiplier
	return

'start of timer routine--------------------------------------------------------
 
timer:  Poke PortB, $40                 'send direct to portb to set hold pin on quickly
	bit9 = 1                        'set bit9 so hold stays on during LCD operation
	
	TIMERSET = TIME_OFF             'load user seconds for maximum time out period
	
timing: if TIMERSET = 0 then stop
	gosub led_on                    'flash the alarm led on, set bit
	gosub dispto                    'display timer on message
	ADC_SET = $81                   'set up the A/D port for sampling on AD1 (pin RA0)
	ADC_CONVERT = $45               'sets up the conversion for port AD1
	gosub average2                  'get A/D result (without going to ignit subroutine like 'average'does)
	if ADC_VALU < TEMP_OFF then skip     'if turbo is less than temp_off value abort loop ( number  = temp/3.9 )
	gosub disptt                    'display turbo temp     
	gosub paws200                   'pause for 200ms while LED is on(above)
	gosub buttons                   'check for a button pressed
	if ButtonNum = %00000001 then stop      'if button 1 is pressed abort the timer routine
	gosub led_off                   'alarm led flash bit to off, done by next OT display.
	gosub setadc                    'set to AD2 (skiped )
	gosub setadc                    'set to AD3
	gosub average2                  '
	gosub dispot                    'display oil temp
	pause 675                       'trim the pause time to make loop 1 second long
	TIMERSET = TIMERSET - 1         'subtract 1 from the countdown
	goto timing     

skip:   gosub paws1000                  '3 second delay after ingnition is turned off
	gosub paws1000                  'to let driver know system is working.
	gosub paws1000  
stop:   bit9 = 0                        'hold-pin bit off
	gosub led_on                    'set the alarm led on, set LED bit
	Poke PortB, 0                   'send something to set hold pin off, bit9
'START OF PEAK DISPLAY AFTER TIMER
	gosub lcdinit                   'reboot LCD in case it crashed while driving
	gosub lcdclr                    'clear lcd
	ADC_VALU  = PEAKTT              'load peaks to working variable locations
	gosub disptt                    'display the recorded peaks
	ADC_VALU = PEAKTB                 
	gosub disptb                    'ditto, so to display peak values
	ADC_VALU = PEAKOT
	gosub dispot                    'ditto, after timer stops.
	ADC_VALU = PEAKBV                 
	gosub dispbv                    'ditto
	
	for Loop_Var1 = 0 to 15         'display arrows X times
	gosub arrows
	next Loop_Var1
'        PEAKTT = 0 : PEAKTB = 0         'clear peaks
'        PEAKOT = 0 : PEAKBV = 0
	gosub led_off
	goto stopped


'------------------------------------------------------------------------------
'get A/D values routine, for Ttemp, Tboost, Otemp, Bvolt as set by value of ADC_SET

Getadc: poke ADCON1, 0                  ' Set PortA 0-3 to analog inputs

	poke ADCON0, ADC_SET            ' Set A/D to Fosc/32, Channel 0, On (ACDX hold channel variable, B7)
	gosub paws1                     'wait for A/D to stabilize
	poke ADCON0, ADC_CONVERT        ' Start Conversion (ADC_CONVERT hold then coversion variable, B8)
	gosub paws1                     ' Wait 1ms for conversion
	peek ADRES, ADC_VALU              ' Get Result to variable ADVALU
	return  


'------------------------------------------------------------------------------
'scale A/D temp registers and use W2 as temp register in ENGINE RUNNING mode only

''display the turbo temp, multiply step value by 3.9 to give 0-999C full scale
'TURBO TEMP                
disptt: b2 = $2 : gosub lcdcom         'home cursor and display (if shifted) 
	b2 = $80 : gosub lcdcom         'register location for start of 'turbo temp'
	gosub space                     'print space

	W2 = ADC_VALU * 39               'W2 holds ttemp * 39 then divided by 10 = * 3.9
	W2 = W2 / 10
	gosub send3num                  'send the temp values
	
	b2 = $df : gosub lcddata        'print deg symbol
	b2 = $43 : gosub lcddata        'print Uppercase C
	gosub space                     'print space
	gosub space                     'print space
	return
'BOOST  
disptb: b2 = $88 : gosub lcdcom         'register value for first tboost character location
	b2 = $20 : gosub lcddata        'print space
	if ADC_VALU > 12 then cont        'detect values less than the offset step value
	 ADC_VALU = 12                     'change value to zero point, offset value
cont:   W2 = ADC_VALU - 12                'W2 to hold tboost - offset in steps
	W2 = W2 * 92                    'W2 by multipier value X 100
	gosub DivW2by100                'W2 divided by 100 to get back to multiplier, via subroutine
	gosub sendbar
	b2 = $62 : gosub lcddata        'print Uppercase b
	b2 = $61 : gosub lcddata        'print Uppercase a
	b2 = $72 : gosub lcddata        'print Uppercase r
	return
'OIL    
dispot: b2 = $c0 : gosub lcdcom         'register value for first oil temp character location
	b2 = $20 : gosub lcddata        'print space    
	W2 = ADC_VALU * 196                'W2 hold Otemp * 196 then divided by 100 = * 1.96
	gosub DivW2by100                'W2 divided by 100 to get back to multiplier, via subroutine
	gosub send3num
	b2 = $df : gosub lcddata        'print deg symbol
	b2 = $43 : gosub lcddata        'print Uppercase C
	gosub space                     'print space
space:  b2 = $20 : gosub lcddata        'print space
	return
'VOLTS  no multiplier required because trim is done by pot before A/D
dispbv: b2 = $c8 : gosub lcdcom         'register value for first battery volt character location
	gosub space                     'print space
	W2 = ADC_VALU
	gosub sendvolt
	b2 = $56 : gosub lcddata        'print V
	gosub space                     'print space
	gosub space                     'print space
	return
'CAR OFF
dispco: b2 = $88 : gosub lcdcom         'register value for first battery volt character location
	b2 = $45 : gosub lcddata        'print E
	b2 = $4E : gosub lcddata        'print N
	b2 = $47 : gosub lcddata        'print G
	gosub space                     'print space
	b2 = $4f : gosub lcddata        'print O
	b2 = $46 : gosub lcddata        'print F
	b2 = $46 : gosub lcddata        'print F
	gosub space                     'print space
	return

'TIMER TEXT
dispto: b2 = $88 : gosub lcdcom         'register value for first TIMER ON character location
	gosub space                     'print space
	b2 = $54 : gosub lcddata        'print T
	b2 = $49 : gosub lcddata        'print I              
	b2 = $4d : gosub lcddata        'print M
	b2 = $45 : gosub lcddata        'print E
	b2 = $52 : gosub lcddata        'print R
	gosub space                     'print space                   
	gosub space                     'print space
	b2 = $c8 : gosub lcdcom         'register value
	gosub space                     'print space
	gosub space                     'print space
	gosub space                     'print space
	b2 = $4f : gosub lcddata        'print O
	b2 = $4e : gosub lcddata        'print N 
	gosub space                     'print space
	gosub space                     'print space        
	gosub space                     'print space
	return
'------------------------------------------------------------------------------
'PEAK HOLD ARROWS with scrolling
arrows: b2 = $c7 : gosub lcdcom         'line 2 middle character
	b2 = $5e : gosub lcddata        'print ^
	gosub paws200
	b2 = $87 : gosub lcdcom         'line 1 middle character
	b2 = $5e : gosub lcddata        'print ^        
	gosub paws200
	b2 = $c7 : gosub lcdcom         'line 2 middle character
	b2 = $20 : gosub lcddata        'blank the ^
	gosub paws200
	b2 = $87 : gosub lcdcom         'line 1 middle character
	b2 = $20 : gosub lcddata        'blank the ^  
	gosub paws200
	return

'------------------------------------------------------------------------------
'hex to Ascii conversion and blank checking, send to LCD

send3num: gosub hundreds        'b2 hold the 100's digit, W2 is the number to convert, 48 corrects to ascii template    
	gosub zeroblank         'test for '0' and blank it
	gosub lcddata           'send the character
	gosub ten_units         'W2 temporarily holds only the 10's and units via subroutine 
	gosub tens
	gosub zeroblank         'test for '0' and blank it
	gosub lcddata
	gosub units             'b2 holds just the units and is ascii converted via subroutine
	gosub lcddata
	bit10 = 0                 'reset flag for blank test, in "zeroblank"
	return

send2num: gosub ten_units       'W2 temporarily holds only the 10's and units via subroutine 
	gosub tens              'b2 hold just the 10's and is acsii converted
	gosub zeroblank         'test for '0' and blank it
	gosub lcddata
	gosub units             'b2 holds just the units and is ascii converted via subroutine
	gosub lcddata
	bit10 = 0                 'reset flag for blank test, in "zeroblank"
	return

sendbar: gosub hundreds         'b2 hold the 100's digit, W2 is the number to convert, 48 corrects to ascii template 
	gosub lcddata           'send the character
	b2 = $2e                'load . character
	gosub lcddata           'send the character
	gosub ten_units         'W2 temporarily holds only the 10's and units via subroutine 
	gosub tens              'b2 hold just the 10's and is acsii converted
	gosub lcddata
	gosub units             'b2 holds just the units and is ascii converted via subroutine
	gosub lcddata
	return

sendvolt: gosub hundreds        'b2 hold the 100's digit, W2 is the number to convert, 48 corrects to ascii template 
	gosub zeroblank         'test for '0' and blank it
	gosub lcddata           'send the character
	gosub ten_units         'W2 temporarily holds only the 10's and units via subroutine 
	gosub tens              'b2 hold just the 10's and is acsii converted
	gosub lcddata
	b2 = $2e                'load . character
	gosub lcddata           'send the character
	gosub units             'b2 holds just the units and is ascii converted via subroutine
	gosub lcddata
	bit10 = 0                 'reset flag for blank test, in "zeroblank"
	return

hundreds:  B2 = W2 / 100 + 48     'b2 hold the 100's digit, W2 is the number to convert, 48 corrects to ascii template
	return

ten_units: W2 = W2 // 100       'W2 temporarily holds only the 10's and units
	return

tens:   b2 = W2 / 10 + 48       'b2 hold just the 10's and acsii converted
	return

units:  b2 = W2 // 10 + 48      'b2 holds just the units and is ascii converted
	return

zeroblank: if B2 = $30 then check 'is value in b2 the 0 character 
	bit10 = 1
	return

check:  if bit10 = 1 then noblank 'was previous number not a 0
	B2 = $20                'blank character   
noblank: return                 'dont blank, number is valid eg. 203

'------------------------------------------------------------------------------
'LCD handling routines - this is adapted from the PicBasic sample to work on portB instead of portA
' AND allow bit manipulation of the spare pins

'Variable B0 is used as buffer between var B2 and LCD because B0 (and B1) allows bit manipulation in PBC.
' subroutine to initialize the lcd - uses B0 directly
lcdinit: Pause 15                       'wait at least 15ms

	B0 = 3                          'use var B0 to hold data to send to LCD as command              
	gosub pokeportb                 'initialize the lcd via B0
	Gosub lcdtog                    'toggle the lcd enable line, uses bit 5 of B0
	Pause 5                         'wait at least 4.1ms
	Gosub lcdtog                    'toggle the lcd enable line
	gosub paws1                     'wait at least 100us
	Gosub lcdtog                    'toggle the lcd enable line
	gosub paws1                     'wait once more for good luck
	B0 = 2 
	gosub pokeportb                 'put lcd into 4 bit mode via portB and B0
	Gosub lcdtog                    'toggle the lcd enable line

'from here on use var B2 as data/command ( via B0 in lcdcom: or lcddata: )
	B2 = $28                        '4 bit mode, 2 lines, 5x7 font
	Gosub lcdcom                    'send B2 to lcd

	B2 = $0c                        'lcd display on, no cursor, no blink
	Gosub lcdcom                    'send B2 to lcd

	B2 = $06                        'lcd entry mode set, increment, no shift
	Goto lcdcom                     'exit through send lcd command

' subroutine to clear the lcd screen - uses B2 and B0
lcdclr: B2 = 1                          'set B2 to clear command and fall through to lcdcom

' subroutine to send a command to the lcd - uses B2 and B0
lcdcom: B0 = B2 / 16                    'shift top 4 bits down to bottom 4 bits
	bit5 = bit8                     'add in the alarm status bit
	bit6 = bit9                     'add in the ignition hold status bit
	gosub pokeportb                 'send upper 4 bits (of B2) to lcd
	Gosub lcdtog                    'toggle the lcd enable line

	B0 = B2 & 15                    'isolate bottom 4 bits
	bit5 = bit8                     'add in the alarm status bit
	bit6 = bit9                     'add in the ignition hold status bit
	gosub pokeportb                 'send lower 4 bits (of B2) to lcd
	Gosub lcdtog                    'toggle the lcd enable line
'       gosub paws1                     'wait 1ms for write to complete, sometimes needed for slow LCD's
	Return

' subroutine to send data to the lcd - uses B2 and B0
lcddata: B0 = B2 / 16 + 16              'shift top 4 bits down to bottom 4 bits and set 'data' bit
	bit5 = bit8                     'add in the alarm status bit
	bit6 = bit9                     'add in the ignition hold status bit
	gosub pokeportb                 'send upper 4 bits (of B2) to lcd
	Gosub lcdtog                     'toggle the lcd enable line

	B0 = B2 & 15 + 16               'isolate bottom 4 bits and add 16 to set 'data' bit
	bit5 = bit8                     'add in the alarm status bit
	bit6 = bit9                     'add in the ignition hold status bit
	gosub pokeportb                 'send lower 4 bits (of B2) to lcd
	Gosub lcdtog                    'toggle the lcd enable line
'       gosub paws1                     'wait 1ms for write to complete, sometimes needed for slow LCD's 
	Return

pokeportB:  Poke PortB,B0               'send  4 bits from B0 to lcd
	return

' subroutine to toggle the lcd enable line useing PortA RA4, does not affect A/D's

lcdtog: poke portA, $10                 'portA pin4 high ( LCD E pin), $10 = 00010000
'        pause 1                        'wait 1ms for write to complete, sometimes needed for slow LCD's 
	poke portA, 0                   'portA pin4 low
	return

end
