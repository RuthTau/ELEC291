#include <XC.h>
#include <sys/attribs.h>
#include <stdio.h>
#include <stdlib.h>
 
// Configuration Bits (somehow XC32 takes care of this)
#pragma config FNOSC = FRCPLL       // Internal Fast RC oscillator (8 MHz) w/ PLL
#pragma config FPLLIDIV = DIV_2     // Divide FRC before PLL (now 4 MHz)
#pragma config FPLLMUL = MUL_20     // PLL Multiply (now 80 MHz)
#pragma config FPLLODIV = DIV_2     // Divide After PLL (now 40 MHz)
 
#pragma config FWDTEN = OFF         // Watchdog Timer Disabled
#pragma config FPBDIV = DIV_1       // PBCLK = SYCLK

// Defines
#define SYSCLK 40000000L
#define DEF_FREQ 15500L
#define Baud2BRG(desired_baud)( (SYSCLK / (16*desired_baud))-1)
 
volatile int pw = 0;
volatile int count = 0;
volatile int joy_x;
volatile int joy_y;
volatile char but1;
volatile char but2;

//ADC
volatile int adcval;
volatile float voltage;
volatile float measure;
volatile float temp;
volatile int flag =0;

void UART2Configure(int baud_rate)
{
    // Peripheral Pin Select
    U2RXRbits.U2RXR = 4;    //SET RX to RB8
    RPB9Rbits.RPB9R = 2;    //SET RB9 to TX

    U2MODE = 0;         // disable autobaud, TX and RX enabled only, 8N1, idle=HIGH
    U2STA = 0x1400;     // enable TX and RX
    U2BRG = Baud2BRG(baud_rate); // U2BRG = (FPb / (16*baud)) - 1
    
    U2MODESET = 0x8000;     // enable UART2
}

//ADC
void ADCConf(void)
{
    AD1CON1CLR = 0x8000;    // disable ADC before configuration
    AD1CON1 = 0x00E0;       // internal counter ends sampling and starts conversion (auto-convert), manual sample
    AD1CON2 = 0;            // AD1CON2<15:13> set voltage reference to pins AVSS/AVDD
    AD1CON3 = 0x0f01;       // TAD = 4*TPB, acquisition time = 15*TAD 
    AD1CON1SET=0x8000;      // Enable ADC
}

int ADCRead(char analogPIN)
{
    AD1CHS = analogPIN << 16;    // AD1CHS<16:19> controls which analog pin goes to the ADC
 
    AD1CON1bits.SAMP = 1;        // Begin sampling
    while(AD1CON1bits.SAMP);     // wait until acquisition is done
    while(!AD1CON1bits.DONE);    // wait until conversion done
 
    return ADC1BUF0;             // result stored in ADC1BUF0
}


//END ADC


// Needed to by scanf() and gets()o
int _mon_getc(int canblock)
{
	char c;
	
    if (canblock)
    {
	    while( !U2STAbits.URXDA); // wait (block) until data available in RX buffer
	    c=U2RXREG;
        while( U2STAbits.UTXBF);    // wait while TX buffer full
        U2TXREG = c;          // echo
	    if(c=='\r') c='\n'; // When using PUTTY, pressing <Enter> sends '\r'.  Ctrl-J sends '\n'
		return (int)c;
    }
    else
    {
        if (U2STAbits.URXDA) // if data available in RX buffer
        {
		    c=U2RXREG;
		    if(c=='\r') c='\n';
			return (int)c;
        }
        else
        {
            return -1; // no characters to return
        }
    }
}

void wait_1ms(void)
{
    unsigned int ui;
    _CP0_SET_COUNT(0); // resets the core timer count

    // get the core timer count
    while ( _CP0_GET_COUNT() < (SYSCLK/(2*1000)) );
}

void delayms(int len)
{
	while(len--) wait_1ms();
}


void __ISR(_TIMER_1_VECTOR, IPL5SOFT) Timer1_Handler(void)
{
	//ADC
		//ADC temp
		adcval = ADCRead(9); // note that we call pin AN4 (RB2) by it's analog number
    	measure=adcval*3.316/1023.0;
    	voltage = (measure - 2.73)*100.0;
    	
    	if(voltage > 20.0)
    	{
    		temp = voltage;
    	} 
    	if(temp >= 60.0)
    	{
    		flag = 1;
    	}
    	else if(temp < 60.0)
    	{
    		flag = 0;
    	}
    	
    //ADC_END
	
	LATBbits.LATB6 = !LATBbits.LATB6;
	LATBbits.LATB0 = !LATBbits.LATB0;
	
	if(count <= 0)
	{
	//first button - move forward
	if ((joy_y > 55) && (but1 == 1) && (but2 == 1) && (joy_x < 3) &&(joy_x > -3)){
		pw = 12;
			if(pw > 0)
		    {
		       	LATBbits.LATB6 = 0;
				LATBbits.LATB0 = 1;
				LATBbits.LATB14=1; 
				delayms(pw);
				LATBbits.LATB14=0;
				count = 4000;
				
			}
	    }
	//second button - move backward
		if ((joy_y < -55) && (but1 == 1) && (but2 == 1) && (joy_x < 3) &&(joy_x > -3)){
		pw = 28;
			if(pw > 0)
		    {
		       	LATBbits.LATB6 = 0;
				LATBbits.LATB0 = 1;
				LATBbits.LATB13=1; 
				delayms(pw);
				LATBbits.LATB13=0;
				count = 4000;
			}
	    }
	    
	//third button - move left
		if ((joy_x < -55) && (but1 == 1) && (but2 == 1) && (joy_y < 3) &&(joy_y -3)){
		pw = 44;
			if(pw > 0)
		    {
		       	LATBbits.LATB6 = 0;
				LATBbits.LATB0 = 1;
				LATBbits.LATB12=1; 
				delayms(pw);
				LATBbits.LATB12=0;
				count = 4000;
			}
	    }  
	    
	//fourth button - move right
		if (joy_x > 55 && (but1 == 1) && (but2 == 1) && (joy_y < 3) &&(joy_y -3)){
		pw = 60;
			if(pw > 0)
		    {
		       	LATBbits.LATB6 = 0;
				LATBbits.LATB0 = 1;
				LATBbits.LATB10=1; 
				delayms(pw);
				LATBbits.LATB10=0;
				count = 4000;
			}
	    }  

	//fifth button - tracking mode - z button
		if (((but1) == 0) && (joy_y == 0) &&(but2 == 1)){
		pw = 76;
			if(pw > 0)
		    {
		       	LATBbits.LATB6 = 0;
				LATBbits.LATB0 = 1;
				LATBbits.LATB14=1; 
				LATBbits.LATB10=1; 
				delayms(pw);
				LATBbits.LATB14=0;
				LATBbits.LATB10=0;
				count = 4000;
			}
	    } 

	//sixth button - command mode - c button
		if ((but2 == 0) && (but1 == 1) && (joy_y == 0)){
		pw = 92;
			if(pw > 0)
		    {
		       	LATBbits.LATB6 = 0;
				LATBbits.LATB0 = 1;
				LATBbits.LATB13=1; 
				LATBbits.LATB12=1; 
				delayms(pw);
				LATBbits.LATB13=0;
				LATBbits.LATB12=0;
				count = 4000;
			}
		}	

		//seventh button RB9 - extra feature 1 - u-turn i think
		if ((but1 == 0) && (joy_y > 55)){
			pw = 124;
			if(pw > 0)
			{
				LATBbits.LATB6 = 0;
				LATBbits.LATB0 = 1;
				//blink w
				LATAbits.LATA2=1; // One pin set to one
				delayms(pw);
				LATAbits.LATA2=0;
				count = 4000;
			}
		}

	//eighth button - extra feature 2 - stop i think
		if ((but2 == 0) && (but1 == 0)){
			pw = 140;
			if(pw > 0)
			{
				LATBbits.LATB6 = 0;
				LATBbits.LATB0 = 1;
				LATBbits.LATB14=1; 
				LATBbits.LATB13=1; 
				LATBbits.LATB12=1; 
				LATBbits.LATB10=1; 
				LATAbits.LATA2=1; 
				delayms(pw);
				LATBbits.LATB14=0; 
				LATBbits.LATB13=0; 
				LATBbits.LATB12=0; 
				LATBbits.LATB10=0; 
				LATAbits.LATA2=0;
				count = 4000;
			}
		}


	}
	
	count--;
	
	IFS0CLR=_IFS0_T1IF_MASK; // Clear timer 1 interrupt flag, bit 4 of IFS0
	
	
}

void SetupTimer1 (void)
{
	// Explanation here:
	// https://www.youtube.com/watch?v=bu6TTZHnMPY
	__builtin_disable_interrupts();
	PR1 =(SYSCLK/(DEF_FREQ*2L))-1; // since SYSCLK/FREQ = PS*(PR1+1)
	TMR1 = 0;
	T1CONbits.TCKPS = 0; // Pre-scaler: 1
	T1CONbits.TCS = 0; // Clock source
	T1CONbits.ON = 1;
	IPC1bits.T1IP = 5;
	IPC1bits.T1IS = 0;
	IFS0bits.T1IF = 0;
	IEC0bits.T1IE = 1;
	
	INTCONbits.MVEC = 1; //Int multi-vector
	__builtin_enable_interrupts();
}


/* Pinout for DIP28 PIC32MX130:
                                          --------
                                   MCLR -|1     28|- AVDD 
  VREF+/CVREF+/AN0/C3INC/RPA0/CTED1/RA0 -|2     27|- AVSS 
        VREF-/CVREF-/AN1/RPA1/CTED2/RA1 -|3     26|- AN9/C3INA/RPB15/SCK2/CTED6/PMCS1/RB15
   PGED1/AN2/C1IND/C2INB/C3IND/RPB0/RB0 -|4     25|- CVREFOUT/AN10/C3INB/RPB14/SCK1/CTED5/PMWR/RB14
  PGEC1/AN3/C1INC/C2INA/RPB1/CTED12/RB1 -|5     24|- AN11/RPB13/CTPLS/PMRD/RB13
   AN4/C1INB/C2IND/RPB2/SDA2/CTED13/RB2 -|6     23|- AN12/PMD0/RB12
     AN5/C1INA/C2INC/RTCC/RPB3/SCL2/RB3 -|7     22|- PGEC2/TMS/RPB11/PMD1/RB11
                                    VSS -|8     21|- PGED2/RPB10/CTED11/PMD2/RB10
                     OSC1/CLKI/RPA2/RA2 -|9     20|- VCAP
                OSC2/CLKO/RPA3/PMA0/RA3 -|10    19|- VSS
                         SOSCI/RPB4/RB4 -|11    18|- TDO/RPB9/SDA1/CTED4/PMD3/RB9
         SOSCO/RPA4/T1CK/CTED9/PMA1/RA4 -|12    17|- TCK/RPB8/SCL1/CTED10/PMD4/RB8
                                    VDD -|13    16|- TDI/RPB7/CTED3/PMD5/INT0/RB7
                    PGED3/RPB5/PMD7/RB5 -|14    15|- PGEC3/RPB6/PMD6/RB6
                                          --------
*/

// Use the core timer to wait for 1 ms.
void Init_I2C2(void)
{
	// Configure pin RB2, used for SDA2 (pin 6 of DIP28) as digital I/O
    ANSELB &= ~(1<<2); // Set RB2 as a digital I/O
    TRISB |= (1<<2);   // configure pin RB2 as input
    CNPUB |= (1<<2);   // Enable pull-up resistor for RB2
	// Configure pin RB3, used for SCL2 (pin 7 of DIP28) as digital I/O
    ANSELB &= ~(1<<3); // Set RB3 as a digital I/O
    TRISB |= (1<<3);   // configure pin RB3 as input
    CNPUB |= (1<<3);   // Enable pull-up resistor for RB3

	I2C2BRG = 0x0C6;   // SCL2 = 100kHz with SYSCLK = 40MHz (See table 24-1 in page 24-32, 830 in pdf)
	I2C2CONbits.ON=1;  // turn on I2C
}
 
int I2C_byte_write(unsigned char saddr, unsigned char maddr, unsigned char data)
{
	I2C2CONbits.SEN = 1;
	while(I2C2CONbits.SEN); //Wait till Start sequence is completed

	I2C2TRN = (saddr << 1);
	while(I2C2STATbits.TRSTAT); // Check Tx complete

	I2C2TRN = maddr;
	while(I2C2STATbits.TRSTAT); // Check Tx complete

	I2C2TRN = data;
	while(I2C2STATbits.TRSTAT); // Check Tx complete

	I2C2CONbits.PEN = 1; // Terminate communication with stop signal
	while(I2C2CONbits.PEN); // Wait till stop sequence is completed

	return 0;
}

int I2C_burst_write(unsigned char saddr, unsigned char maddr, int byteCount, unsigned char* data)
{
	I2C2CONbits.SEN = 1;
	while(I2C2CONbits.SEN); //Wait till Start sequence is completed

	I2C2TRN = (saddr << 1);
	while(I2C2STATbits.TRSTAT); // Check Tx complete

	I2C2TRN = maddr;
	while(I2C2STATbits.TRSTAT); // Check Tx complete

    for (; byteCount > 0; byteCount--)
    {
		I2C2TRN = *data++; // send data
		while(I2C2STATbits.TRSTAT); // Check Tx complete
	}

	I2C2CONbits.PEN = 1; // Terminate communication with stop signal
	while(I2C2CONbits.PEN); // Wait till stop sequence is completed

	return 0;
}

int I2C_burstRead(char saddr, char maddr, int byteCount, unsigned char* data)
{
	// First we send the address we want to read from:
	I2C2CONbits.SEN = 1;
	while(I2C2CONbits.SEN); //Wait till Start sequence is completed

	I2C2TRN = (saddr << 1);
	while(I2C2STATbits.TRSTAT); // Check Tx complete

	I2C2TRN = maddr;
	while(I2C2STATbits.TRSTAT); // Check Tx complete

	I2C2CONbits.PEN = 1; // Terminate communication with stop signal
	while(I2C2CONbits.PEN); // Wait till stop sequence is completed
	
	// Second: we gatter the data sent by the slave device
	I2C2CONbits.SEN = 1;
	while(I2C2CONbits.SEN); //Wait till Start sequence is completed
	
	I2C2TRN = ((saddr << 1) | 1); // The receive address has the least significant bit set to 1
	while(I2C2STATbits.TRSTAT); // Check Tx complete
  
    for (; byteCount > 0; byteCount--)
    {
    	I2C2CONbits.RCEN=1;
		while(I2C2CONbits.RCEN); // Wait for a byte to arrive
		*data++=I2C2RCV;
		if(byteCount==0) // We are done, send NACK
		{
			I2C2CONbits.ACKDT=1; // Selects NACK
			I2C2CONbits.ACKEN = 1;
			while(I2C2CONbits.ACKEN); // Wait till NACK sequence is completed
		}
		else // Not done yet, send an ACK 
		{
			I2C2CONbits.ACKDT=0; // Selects ACK
			I2C2CONbits.ACKEN = 1;
			while(I2C2CONbits.ACKEN); // Wait till ACK sequence is completed
		}
	}
	
	I2C2CONbits.PEN = 1; // Terminate communication with stop signal
	while(I2C2CONbits.PEN); // Wait till stop sequence is completed

	return 0;
}

void nunchuck_init(int print_extension_type)
{
	unsigned char buf[6];
	
	I2C_byte_write(0x52, 0xF0, 0x55);
	I2C_byte_write(0x52, 0xFB, 0x00);
		 
	// Read the extension type from the register block.
	// For the original Nunchuk it should be: 00 00 a4 20 00 00.
	I2C_burstRead(0x52, 0xFA, 6, buf);
	delayms(10);
	if(print_extension_type)
	{
		printf("Extension type: %02x  %02x  %02x  %02x  %02x  %02x\r\n", 
			buf[0],  buf[1], buf[2], buf[3], buf[4], buf[5]);
	}

	// Send the crypto key (zeros), in 3 blocks of 6, 6 & 4.
	buf[0]=0; buf[1]=0; buf[2]=0; buf[3]=0; buf[4]=0; buf[5]=0;
	
	I2C_byte_write(0x52, 0xF0, 0xAA);
	I2C_burst_write(0x52, 0x40, 6, buf);
	I2C_burst_write(0x52, 0x40, 6, buf);
	I2C_burst_write(0x52, 0x40, 4, buf);
}

void nunchuck_getdata(unsigned char * s)
{
	unsigned char i;

	// Start measurement
	I2C_burstRead(0x52, 0x00, 6, s);
	delayms(10);

	// Decrypt received data
	for(i=0; i<6; i++)
	{
		s[i]=(s[i]^0x17)+0x17;
	}
}

void main(void)
{
    char buf[32];
    int newPw, reload;
    unsigned char rbuf[6];
 	int off_x, off_y, acc_x, acc_y, acc_z;
	int count = 0;
	int flag2 = 0;
	CFGCON = 0;
	Init_I2C2(); // Configure I2C2
	
	// Configure RB15 as temp
    ANSELBbits.ANSB15 = 1; 
    TRISBbits.TRISB15 = 1; 
	
	ADCConf(); // Configure ADC
    delayms(200);
    //int pw = 0;

	DDPCON = 0;
	CFGCON = 0;
	TRISBbits.TRISB0 = 0;
	LATBbits.LATB0 = 0;	
	TRISBbits.TRISB6 = 0;
	LATBbits.LATB6 = 0;	
	INTCONbits.MVEC = 1;
	
	LATBbits.LATB0=1; // One pin set to one
	LATBbits.LATB6=0; // The other pin set to zero
	
	//initialize led W
	TRISAbits.TRISA2 = 0;
	LATAbits.LATA2 =0;
	
	//LED G
	TRISBbits.TRISB14= 0;
	LATBbits.LATB14 =0;
	
	//LED Y
	TRISBbits.TRISB13= 0;
	LATBbits.LATB13 =0;
	
	//LED R
	TRISBbits.TRISB12 = 0;
	LATBbits.LATB12 =0;
	
	//LED B
	TRISBbits.TRISB10= 0;
	LATBbits.LATB10 =0;
	
	SetupTimer1();
  
    UART2Configure(115200);  // Configure UART2 for a baud rate of 115200
 
	delayms(500); // Give putty time to start before we send stuff.
    printf("Frequency generator for the PIC32MX130F064B.  Output is in RB5 and RB6 (pins 14 and 15)\r\n");
    printf("By Jesus Calvino-Fraga (c) 2018.\r\n\r\n");

	nunchuck_init(1);
	delayms(100);
	nunchuck_getdata(rbuf);

	off_x=(int)rbuf[0]-128;
	off_y=(int)rbuf[1]-128;
	printf("Offset_X:%4d Offset_Y:%4d\r\n", off_x, off_y);
	
	while (1)
	{	
		count--;
		if(flag == 1) //blinking W LED
    	{
    		LATAbits.LATA2 =!LATAbits.LATA2;
    		T1CONbits.ON = 0;
    	    count = 150;
    	    flag2 = 1;
    	    flag = 0;

    	}
    	if(flag2 == 1)
    	{
    		T1CONbits.ON = 0;	
    	}
		if (count <= 0)
		{
			T1CONbits.ON = 1;
			flag2 = 0;
			LATAbits.LATA2 = 0;
		}
		nunchuck_getdata(rbuf);

		joy_x=(int)rbuf[0]-128-off_x;
		joy_y=(int)rbuf[1]-128-off_y;
		but1=(rbuf[5] & 0x01)?1:0;
		but2=(rbuf[5] & 0x02)?1:0;
		
    	printf("\rCurrent Temperature: %7.4fC %3.4f\r", temp, measure);
       // printf("\rButtons(Z:%c, C:%c) Joystick(%4d, %4d) Accelerometer(%3d, %3d, %3d)\x1b[0J\r",
	//		   but1?'1':'0', but2?'1':'0', joy_x, joy_y, acc_x, acc_y, acc_z);
		fflush(stdout);
		delayms(100);
      
	}
}