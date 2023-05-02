// ADC.c:  Shows how to use the 14-bit ADC.  This program
// measures the voltage from some pins of the EFM8LB1 using the ADC.
//
// (c) 2008-2023, Jesus Calvino-Fraga
//  RUTH TAU  & JASIA AZREEN
//

#include <stdio.h>
#include <stdlib.h>
#include <EFM8LB1.h>
#include <math.h>
#include <string.h>
// ~C51~  

#define SYSCLK 72000000L
#define BAUDRATE 115200L
#define SARCLK 18000000L

//LCD 

#define LCD_RS P2_6
#define LCD_E  P2_5
#define LCD_D4 P2_4
#define LCD_D5 P2_3
#define LCD_D6 P2_2
#define LCD_D7 P2_1
#define CHARS_PER_LINE 16

#define LIGHT_SPEED 300000000.0
unsigned char overflow_count;

char _c51_external_startup (void)
{
	// Disable Watchdog with key sequence
	SFRPAGE = 0x00;
	WDTCN = 0xDE; //First key
	WDTCN = 0xAD; //Second key
  
	VDM0CN=0x80;       // enable VDD monitor
	RSTSRC=0x02|0x04;  // Enable reset on missing clock detector and VDD

	#if (SYSCLK == 48000000L)	
		SFRPAGE = 0x10;
		PFE0CN  = 0x10; // SYSCLK < 50 MHz.
		SFRPAGE = 0x00;
	#elif (SYSCLK == 72000000L)
		SFRPAGE = 0x10;
		PFE0CN  = 0x20; // SYSCLK < 75 MHz.
		SFRPAGE = 0x00;
	#endif
	
	#if (SYSCLK == 12250000L)
		CLKSEL = 0x10;
		CLKSEL = 0x10;
		while ((CLKSEL & 0x80) == 0);
	#elif (SYSCLK == 24500000L)
		CLKSEL = 0x00;
		CLKSEL = 0x00;
		while ((CLKSEL & 0x80) == 0);
	#elif (SYSCLK == 48000000L)	
		// Before setting clock to 48 MHz, must transition to 24.5 MHz first
		CLKSEL = 0x00;
		CLKSEL = 0x00;
		while ((CLKSEL & 0x80) == 0);
		CLKSEL = 0x07;
		CLKSEL = 0x07;
		while ((CLKSEL & 0x80) == 0);
	#elif (SYSCLK == 72000000L)
		// Before setting clock to 72 MHz, must transition to 24.5 MHz first
		CLKSEL = 0x00;
		CLKSEL = 0x00;
		while ((CLKSEL & 0x80) == 0);
		CLKSEL = 0x03;
		CLKSEL = 0x03;
		while ((CLKSEL & 0x80) == 0);
	#else
		#error SYSCLK must be either 12250000L, 24500000L, 48000000L, or 72000000L
	#endif
	
	P0MDOUT |= 0x10; // Enable UART0 TX as push-pull output
	P1MDOUT|=0b_1111_1111;
	XBR0     = 0x01; // Enable UART0 on P0.4(TX) and P0.5(RX)                     
	XBR1     = 0X00;
	XBR2     = 0x40; // Enable crossbar and weak pull-ups

	// Configure Uart 0
	#if (((SYSCLK/BAUDRATE)/(2L*12L))>0xFFL)
		#error Timer 0 reload value is incorrect because (SYSCLK/BAUDRATE)/(2L*12L) > 0xFF
	#endif
	SCON0 = 0x10;
	//extra//
	CKCON0 |= 0b_0000_0000 ; // Timer 1 uses the system clock divided by 12.
	//
	TH1 = 0x100-((SYSCLK/BAUDRATE)/(2L*12L));
	TL1 = TH1;      // Init Timer1
	TMOD &= ~0xf0;  // TMOD: timer 1 in 8-bit auto-reload
	TMOD |=  0x20;                       
	TR1 = 1; // START Timer1
	TI = 1;  // Indicate TX0 ready
  	
	return 0;
}

void InitADC (void)
{
	SFRPAGE = 0x00;
	ADEN=0; // Disable ADC
	
	ADC0CN1=
		(0x2 << 6) | // 0x0: 10-bit, 0x1: 12-bit, 0x2: 14-bit
        (0x0 << 3) | // 0x0: No shift. 0x1: Shift right 1 bit. 0x2: Shift right 2 bits. 0x3: Shift right 3 bits.		
		(0x0 << 0) ; // Accumulate n conversions: 0x0: 1, 0x1:4, 0x2:8, 0x3:16, 0x4:32
	
	ADC0CF0=
	    ((SYSCLK/SARCLK) << 3) | // SAR Clock Divider. Max is 18MHz. Fsarclk = (Fadcclk) / (ADSC + 1)
		(0x0 << 2); // 0:SYSCLK ADCCLK = SYSCLK. 1:HFOSC0 ADCCLK = HFOSC0.
	
	ADC0CF1=
		(0 << 7)   | // 0: Disable low power mode. 1: Enable low power mode.
		(0x1E << 0); // Conversion Tracking Time. Tadtk = ADTK / (Fsarclk)
	
	ADC0CN0 =
		(0x0 << 7) | // ADEN. 0: Disable ADC0. 1: Enable ADC0.
		(0x0 << 6) | // IPOEN. 0: Keep ADC powered on when ADEN is 1. 1: Power down when ADC is idle.
		(0x0 << 5) | // ADINT. Set by hardware upon completion of a data conversion. Must be cleared by firmware.
		(0x0 << 4) | // ADBUSY. Writing 1 to this bit initiates an ADC conversion when ADCM = 000. This bit should not be polled to indicate when a conversion is complete. Instead, the ADINT bit should be used when polling for conversion completion.
		(0x0 << 3) | // ADWINT. Set by hardware when the contents of ADC0H:ADC0L fall within the window specified by ADC0GTH:ADC0GTL and ADC0LTH:ADC0LTL. Can trigger an interrupt. Must be cleared by firmware.
		(0x0 << 2) | // ADGN (Gain Control). 0x0: PGA gain=1. 0x1: PGA gain=0.75. 0x2: PGA gain=0.5. 0x3: PGA gain=0.25.
		(0x0 << 0) ; // TEMPE. 0: Disable the Temperature Sensor. 1: Enable the Temperature Sensor.

	ADC0CF2= 
		(0x0 << 7) | // GNDSL. 0: reference is the GND pin. 1: reference is the AGND pin.
		(0x1 << 5) | // REFSL. 0x0: VREF pin (external or on-chip). 0x1: VDD pin. 0x2: 1.8V. 0x3: internal voltage reference.
		(0x1F << 0); // ADPWR. Power Up Delay Time. Tpwrtime = ((4 * (ADPWR + 1)) + 2) / (Fadcclk)
	
	ADC0CN2 =
		(0x0 << 7) | // PACEN. 0x0: The ADC accumulator is over-written.  0x1: The ADC accumulator adds to results.
		(0x0 << 0) ; // ADCM. 0x0: ADBUSY, 0x1: TIMER0, 0x2: TIMER2, 0x3: TIMER3, 0x4: CNVSTR, 0x5: CEX5, 0x6: TIMER4, 0x7: TIMER5, 0x8: CLU0, 0x9: CLU1, 0xA: CLU2, 0xB: CLU3

	ADEN=1; // Enable ADC
}

// Uses Timer3 to delay <us> micro-seconds. 
void Timer3us(unsigned char us)
{
	unsigned char i;               // usec counter
	
	// The input for Timer 3 is selected as SYSCLK by setting T3ML (bit 6) of CKCON0:
	CKCON0|=0b_0100_0000;
	
	TMR3RL = (-(SYSCLK)/1000000L); // Set Timer3 to overflow in 1us.
	TMR3 = TMR3RL;                 // Initialize Timer3 for first overflow
	
	TMR3CN0 = 0x04;                 // Sart Timer3 and clear overflow flag
	for (i = 0; i < us; i++)       // Count <us> overflows
	{
		while (!(TMR3CN0 & 0x80));  // Wait for overflow
		TMR3CN0 &= ~(0x80);         // Clear overflow indicator
	}
	TMR3CN0 = 0 ;                   // Stop Timer3 and clear overflow flag
}

void waitms (unsigned int ms)
{
	unsigned int j;
	unsigned char k;
	for(j=0; j<ms; j++)
		for (k=0; k<4; k++) Timer3us(250);
}

//LCD

void TIMER0_Init(void)
{
	TMOD&=0b_1111_0000; // Set the bits of Timer/Counter 0 to zero
	TMOD|=0b_0000_0001; // Timer/Counter 0 used as a 16-bit timer
	TR0=0; // Stop Timer/Counter 0
}


void LCD_pulse (void)
{
	LCD_E=1;
	Timer3us(40);
	LCD_E=0;
}

void LCD_byte (unsigned char x)
{
	// The accumulator in the C8051Fxxx is bit addressable!
	ACC=x; //Send high nible
	LCD_D7=ACC_7;
	LCD_D6=ACC_6;
	LCD_D5=ACC_5;
	LCD_D4=ACC_4;
	LCD_pulse();
	Timer3us(40);
	ACC=x; //Send low nible
	LCD_D7=ACC_3;
	LCD_D6=ACC_2;
	LCD_D5=ACC_1;
	LCD_D4=ACC_0;
	LCD_pulse();
}

void WriteData (unsigned char x)
{
	LCD_RS=1;
	LCD_byte(x);
	waitms(2);
}

void WriteCommand (unsigned char x)
{
	LCD_RS=0;
	LCD_byte(x);
	waitms(5);
}

void LCD_4BIT (void)
{
	LCD_E=0; // Resting state of LCD's enable is zero
	// LCD_RW=0; // We are only writing to the LCD in this program
	waitms(20);
	// First make sure the LCD is in 8-bit mode and then change to 4-bit mode
	WriteCommand(0x33);
	WriteCommand(0x33);
	WriteCommand(0x32); // Change to 4-bit mode

	// Configure the LCD
	WriteCommand(0x28);
	WriteCommand(0x0c);
	WriteCommand(0x01); // Clear screen command (takes some time)
	waitms(20); // Wait for clear screen command to finsih.
}

void LCDprint(char * string, unsigned char line, bit clear)
{
	int j;

	WriteCommand(line==2?0xc0:0x80);
	waitms(5);
	for(j=0; string[j]!=0; j++)	WriteData(string[j]);// Write the message
	if(clear) for(; j<CHARS_PER_LINE; j++) WriteData(' '); // Clear the rest of the line
}

int getsn (char * buff, int len)
{
	int j;
	char c;
	
	for(j=0; j<(len-1); j++)
	{
		c=getchar();
		if ( (c=='\n') || (c=='\r') )
		{
			buff[j]=0;
			return j;
		}
		else
		{
			buff[j]=c;
		}
	}
	buff[j]=0;
	return len;
}

unsigned int Get_ADC (void)
{
ADINT = 0;
ADBUSY = 1;
while (!ADINT); // Wait for conversion to complete
return (ADC0);
}

//original
#define VDD 3.299 // The measured value of VDD in volts

void InitPinADC (unsigned char portno, unsigned char pinno)
{
	unsigned char mask;
	
	mask=1<<pinno;

	SFRPAGE = 0x20;
	switch (portno)
	{
		case 0:
			P0MDIN &= (~mask); // Set pin as analog input
			P0SKIP |= mask; // Skip Crossbar decoding for this pin
		break;
		case 1:
			P1MDIN &= (~mask); // Set pin as analog input
			P1SKIP |= mask; // Skip Crossbar decoding for this pin
		break;
		case 2:
			P2MDIN &= (~mask); // Set pin as analog input
			P2SKIP |= mask; // Skip Crossbar decoding for this pin
		break;
		default:
		break;
	}
	SFRPAGE = 0x00;
}

unsigned int ADC_at_Pin(unsigned char pin)
{
	ADC0MX = pin;   // Select input from pin
	ADINT = 0;
	ADBUSY = 1;     // Convert voltage at the pin
	while (!ADINT); // Wait for conversion to complete
	return (ADC0);
}

float Volts_at_Pin(unsigned char pin)
{
	 return ((ADC_at_Pin(pin)*VDD)/0b_0011_1111_1111_1111);
}

//added

void main (void)
{
	
	float v[4];
	float half_period;
	double freq;
	double wave_length;
	float time_diff;
	double rms_signal;
	double peak1 =0.0;
	double peak2 =0.0;
	double peak_ref;
	double peak_sig;
	double phase_shift =0.0;
	double TH0_a;
	double TL0_a;
	double TF0_a;
	int overflow_count_2 =0;
	char bcd_string[7];

	
	P0_7 =0;
	//LCD
    // Configure the LCD
	LCD_4BIT();
	
	TIMER0_Init();
	
    waitms(500); // Give PuTTy a chance to start before sending
	printf("\x1b[2J"); // Clear screen using ANSI escape sequence.
	
	printf ("ADC test program\n"
	        "File: %s\n"
	        "Compiled: %s, %s\n\n",
	        __FILE__, __DATE__, __TIME__);
	
	InitPinADC(1, 4); // Configure P2.2 as analog input
	InitPinADC(1, 6); // Configure P2.4 as analog input
    InitADC();
		
	ADC_at_Pin(QFP32_MUX_P1_4);
	
	// Reset the timer
	TL0=0;
	TH0=0;
	TF0=0;
	overflow_count=0;
		
	while (Get_ADC()!=0); // Wait for the signal to be zero
	while (Get_ADC()==0);  // Wait for the signal to be positive
	TR0=1; // Start the timer 0
	while(Get_ADC()!=0) // Wait for the signal to be zero
		{
			if(TF0==1) // Did the 16-bit timer overflow?
			{
				TF0=0;
				overflow_count++;
			}
		}
	while(Get_ADC()==0) // Wait for the signal to be one
		{
			if(TF0==1) // Did the 16-bit timer overflow?
			{
				TF0=0;
				overflow_count++;
			}
		}

		// Wait for the signal to be zero again
	TR0=0; // Stop timer 0
	
	ADC_at_Pin(QFP32_MUX_P1_6);
	TH0_a = TH0;
	TL0_a = TL0;
	TF0_a = TF0;
	
	half_period=((overflow_count*65536.0+TH0_a*256.0+TL0_a)*(12.0/SYSCLK))/2.0;
	
	
	while(1)
	{

	
	    // Read 14-bit value from the pins configured as analog inputs
	    
		v[0] = Volts_at_Pin(QFP32_MUX_P1_4);
		v[2] = Volts_at_Pin(QFP32_MUX_P1_6);
		
		if ( v[0] >= peak1){
			peak1 = v[0];
		}
		
		if (v[2] >= peak2){
			peak2 = v[2];
		}
	
		
		//reset timer 1 
		TH0 =0;
		TL0 =0;
		TF0=0;
		overflow_count_2=0;
		ADC_at_Pin(QFP32_MUX_P1_4);
		
		while(Get_ADC() !=0);
		TR0 =1;
		
		ADC_at_Pin(QFP32_MUX_P1_6);
		while(Get_ADC() !=0){
				if(TF0==1) // Did the 16-bit timer overflow?
			{
				TF0=0;
				overflow_count_2++;
			}
		
		}
		TR0=0;
		
	
		//measure time diff + convert to rms
		time_diff = ((overflow_count_2*65536.0+TH0*256.0+TL0)*(12.0/SYSCLK));
		phase_shift = (time_diff*1000.0*360.0)/((half_period*2000.0));
		rms_signal = 0.70710678118;
		freq = 1.0/(2.0*half_period);
		
		//P0_6
		//while(Get_ADC() !=0);
		waitms(half_period*0.5*1000.0);
		peak_sig = v[2];
		waitms(half_period*0.5*1000.0);
		peak_ref = v[0];
	
	
		//LCD display
		LCDprint("V1   V2   Phase", 1, 1);
		sprintf(bcd_string,"%3.2f %3.2f %3.1fd",peak1*rms_signal,peak2*rms_signal,phase_shift);
		LCDprint(bcd_string,2,1);
		
	
		//putty
		printf ("T1/2=%4.3f ms Freq=%4.3f Hz Vref_RMS=%5.3fV, Vsig_RMS=%5.3fV Phase=%4.3fdeg\n", half_period*1000.0,freq, peak_ref*rms_signal,peak_sig*rms_signal, phase_shift);

		
		//insurance
		TH0 = TH0_a;
		TL0 = TL0_a;
		
		
		//
		if(phase_shift > 90.0){
			P0_7 =1;
			waitms(300);
			P0_7 =0;
		}
		
		
		
		//buttons
		if(P0_4 ==0){
		sprintf(bcd_string,"   WAVE LENGTH  ");
		LCDprint(bcd_string,1,1);
		sprintf(bcd_string,"****************");
		LCDprint(bcd_string,2,1);
		
		waitms(300);
		
		wave_length = LIGHT_SPEED/freq;
		sprintf(bcd_string,"    %4.2f m  ", wave_length);
		LCDprint(bcd_string,2,1);
		waitms(5000);
		}
		
		if(P0_3 == 0){
		sprintf(bcd_string,"    FREQUENCY   ");
		LCDprint(bcd_string,1,1);
		sprintf(bcd_string,"    %3.2f Hz    ", freq);
		LCDprint(bcd_string,2,1);
		waitms(5000);
		}
		
		if(P0_2 == 0){
		sprintf(bcd_string,"   COLOR SLIDE  ");
		LCDprint(bcd_string,1,1);
		sprintf(bcd_string,"#               ");
		LCDprint(bcd_string,2,1);
		waitms(10);
		sprintf(bcd_string,"##              ");
		LCDprint(bcd_string,2,1);
		waitms(10);
		sprintf(bcd_string,"###             ");
		LCDprint(bcd_string,2,1);
		waitms(10);
		sprintf(bcd_string,"####            ");
		LCDprint(bcd_string,2,1);
		waitms(10);
		sprintf(bcd_string,"#####           ");
		LCDprint(bcd_string,2,1);
		waitms(10);
		sprintf(bcd_string,"######          ");
		LCDprint(bcd_string,2,1);
		waitms(10);
		sprintf(bcd_string,"#######         ");
		LCDprint(bcd_string,2,1);
		waitms(10);
		sprintf(bcd_string,"########        ");
		LCDprint(bcd_string,2,1);
		waitms(10);
		sprintf(bcd_string,"#########       ");
		LCDprint(bcd_string,2,1);
		waitms(10);
		sprintf(bcd_string,"##########      ");
		LCDprint(bcd_string,2,1);
		waitms(10);
		sprintf(bcd_string,"###########     ");
		LCDprint(bcd_string,2,1);
		waitms(10);
		sprintf(bcd_string,"############    ");
		LCDprint(bcd_string,2,1);
		waitms(10);
		sprintf(bcd_string,"#############   ");
		LCDprint(bcd_string,2,1);
		waitms(10);
		sprintf(bcd_string,"##############  ");
		LCDprint(bcd_string,2,1);
		waitms(10);
		sprintf(bcd_string,"############### ");
		LCDprint(bcd_string,2,1);
		waitms(10);
		sprintf(bcd_string,"################");
		LCDprint(bcd_string,2,1);
		waitms(10);
		waitms(2000);
		
		
		
		//info
		sprintf(bcd_string,"       RED      ");
		LCDprint(bcd_string,1,1);
		sprintf(bcd_string,"   620-750 nm   ");
		LCDprint(bcd_string,2,1);
		waitms(1000);
		
		sprintf(bcd_string,"     ORANGE     ");
		LCDprint(bcd_string,1,1);
		sprintf(bcd_string,"   590-620 nm   ");
		LCDprint(bcd_string,2,1);
		waitms(1000);
		
		sprintf(bcd_string,"     YELLOW     ");
		LCDprint(bcd_string,1,1);
		sprintf(bcd_string,"   570-590 nm   ");
		LCDprint(bcd_string,2,1);
		waitms(1000);
		
		sprintf(bcd_string,"      GREEN       ");
		LCDprint(bcd_string,1,1);
		sprintf(bcd_string,"   495-570 nm   ");
		LCDprint(bcd_string,2,1);
		waitms(1000);
		
		sprintf(bcd_string,"      BLUE      ");
		LCDprint(bcd_string,1,1);
		sprintf(bcd_string,"   450-495 nm   ");
		LCDprint(bcd_string,2,1);
		waitms(1000);
		
		sprintf(bcd_string,"     VIOLET     ");
		LCDprint(bcd_string,1,1);
		sprintf(bcd_string,"   380-450 nm   ");
		LCDprint(bcd_string,2,1);
		waitms(1000);
		
		waitms(5000);
		
		}
		
		waitms(500);
		
	 }  
}	

