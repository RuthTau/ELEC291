
// CODE IM SUPPOSED TO WORK ON STARTS HERE

#include "../Common/Include/stm32l051xx.h"
#include <stdio.h>
#include <stdlib.h>
#include "../Common/Include/serial.h"
#include "adc.h"
#include "lcd.h"

#define F_CPU 32000000L
#define DEF_F 100000L // 10us tick



volatile int PWM_Counter = 0;
volatile unsigned char ISR_pwm1 = 100, ISR_pwm2 = 100;



void wait_1ms(void)
{
    // For SysTick info check the STM32l0xxx Cortex-M0 programming manual.
    SysTick->LOAD = (F_CPU / 1000L) - 1;  // set reload register, counter rolls over from zero, hence -1
    SysTick->VAL = 0; // load the SysTick counter
    SysTick->CTRL = SysTick_CTRL_CLKSOURCE_Msk | SysTick_CTRL_ENABLE_Msk; // Enable SysTick IRQ and SysTick Timer */
    while ((SysTick->CTRL & BIT16) == 0); // Bit 16 is the COUNTFLAG.  True when counter rolls over from zero.
    SysTick->CTRL = 0x00; // Disable Systick counter
}

// Interrupt service routines are the same as normal
// subroutines (or C funtions) in Cortex-M microcontrollers.
// The following should happen at a rate of 1kHz. (1ms period)
// The following function is associated with the TIM2 interrupt 
// via the interrupt vector table defined in startup.c
void TIM2_Handler(void)
{
    TIM2->SR &= ~BIT0; // clear update interrupt flag
    PWM_Counter++;

    if (ISR_pwm1 > PWM_Counter)
    {
        GPIOA->ODR |= BIT11;
    }
    else
    {
        GPIOA->ODR &= ~BIT11;
    }

    if (ISR_pwm2 > PWM_Counter)
    {
        GPIOA->ODR |= BIT12;
    }
    else
    {
        GPIOA->ODR &= ~BIT12;
    }

    if (PWM_Counter > 2000) // THe period is 20ms
    {
        PWM_Counter = 0;
        GPIOA->ODR |= (BIT11 | BIT12);
    }
}




void Configure_Pins(void)
{
    RCC->IOPENR |= BIT0; // peripheral clock enable for port A

    // Make pins PA0 to PA5 outputs (page 200 of RM0451, two bits used to configure: bit0=1, bit1=0)
    GPIOA->MODER = (GPIOA->MODER & ~(BIT0 | BIT1)) | BIT0; // PA0
    GPIOA->OTYPER &= ~BIT0; // Push-pull

    GPIOA->MODER = (GPIOA->MODER & ~(BIT2 | BIT3)) | BIT2; // PA1
    GPIOA->OTYPER &= ~BIT1; // Push-pull

    GPIOA->MODER = (GPIOA->MODER & ~(BIT4 | BIT5)) | BIT4; // PA2
    GPIOA->OTYPER &= ~BIT2; // Push-pull

    GPIOA->MODER = (GPIOA->MODER & ~(BIT6 | BIT7)) | BIT6; // PA3
    GPIOA->OTYPER &= ~BIT3; // Push-pull

    GPIOA->MODER = (GPIOA->MODER & ~(BIT8 | BIT9)) | BIT8; // PA4
    GPIOA->OTYPER &= ~BIT4; // Push-pull

    GPIOA->MODER = (GPIOA->MODER & ~(BIT10 | BIT11)) | BIT10; // PA5
    GPIOA->OTYPER &= ~BIT5; // Push-pull
}



void Hardware_Init(void)
{
    RCC->IOPENR |= (BIT1 | BIT0);         // peripheral clock enable for ports A and B

    // Configure the pin used for analog input: PB0 and PB1 (pins 14 and 15)
    GPIOB->MODER |= (BIT0 | BIT1);  // Select analog mode for PB0 (pin 14 of LQFP32 package)
    GPIOB->MODER |= (BIT2 | BIT3);  // Select analog mode for PB1 (pin 15 of LQFP32 package)

    initADC();

    // Configure the pin used to measure period
    GPIOA->MODER &= ~(BIT16 | BIT17); // Make pin PA8 input
    // Activate pull up for pin PA8:
    GPIOA->PUPDR |= BIT16;
    GPIOA->PUPDR &= ~(BIT17);

    GPIOA->MODER &= ~(BIT26 | BIT27); // Make pin PA13 input
// Activate pull up for pin PA13:
    GPIOA->PUPDR &= ~(BIT26);
    GPIOA->PUPDR &= ~(BIT27);


    GPIOA->MODER &= ~(BIT24 | BIT25); // Make pin PA12 input
    // Activate pull down for pin PA12:
    GPIOA->PUPDR &= ~(BIT24);
    GPIOA->PUPDR &= ~(BIT25);


    // Configure the pin connected to the pushbutton as input
    GPIOA->MODER &= ~(BIT28 | BIT29); // Make pin PA14 input
    // Activate pull up for pin PA8:
    //GPIOA->PUPDR |= BIT28; 
    //GPIOA->PUPDR &= ~(BIT29);

    GPIOA->PUPDR &= ~(BIT28);
    GPIOA->PUPDR |= (BIT29);

    // Configure some pins as outputs:
    // Make pins PB3 to PB7 outputs (page 200 of RM0451, two bits used to configure: bit0=1, bit1=0)
    GPIOB->MODER = (GPIOB->MODER & ~(BIT6 | BIT7)) | BIT6;    // PB3
    GPIOB->OTYPER &= ~BIT3; // Push-pull
    GPIOB->MODER = (GPIOB->MODER & ~(BIT8 | BIT9)) | BIT8;    // PB4
    GPIOB->OTYPER &= ~BIT4; // Push-pull
    GPIOB->MODER = (GPIOB->MODER & ~(BIT10 | BIT11)) | BIT10; // PB5
    GPIOB->OTYPER &= ~BIT5; // Push-pull
    GPIOB->MODER = (GPIOB->MODER & ~(BIT12 | BIT13)) | BIT12; // PB6
    GPIOB->OTYPER &= ~BIT6; // Push-pull
    GPIOB->MODER = (GPIOB->MODER & ~(BIT14 | BIT15)) | BIT14;  // PB7
    GPIOB->OTYPER &= ~BIT7; // Push-pull

    // Set up timer
    RCC->APB1ENR |= BIT0;  // turn on clock for timer2 (UM: page 177)
    TIM2->ARR = F_CPU / DEF_F - 1;
    NVIC->ISER[0] |= BIT15; // enable timer 2 interrupts in the NVIC
    TIM2->CR1 |= BIT4;      // Downcounting    
    TIM2->CR1 |= BIT7;      // ARPE enable    
    TIM2->DIER |= BIT0;     // enable update event (reload event) interrupt 
    TIM2->CR1 |= BIT0;      // enable counting    

    __enable_irq();
}

// A define to easily read PA8 (PA8 must be configured as input first)
#define PA8 (GPIOA->IDR & BIT8)


void PrintNumber(long int val, int Base, int digits)
{
    char HexDigit[] = "0123456789ABCDEF";
    int j;
#define NBITS 32
    char buff[NBITS + 1];
    buff[NBITS] = 0;

    j = NBITS - 1;
    while ((val > 0) | (digits > 0))
    {
        buff[j--] = HexDigit[val % Base];
        val /= Base;
        if (digits != 0) digits--;
    }
    eputs(&buff[j + 1]);
}


#define PB3_0 (GPIOB->ODR &= ~BIT3)
#define PB3_1 (GPIOB->ODR |=  BIT3)
#define PB4_0 (GPIOB->ODR &= ~BIT4)
#define PB4_1 (GPIOB->ODR |=  BIT4)
#define PB5_0 (GPIOB->ODR &= ~BIT5)
#define PB5_1 (GPIOB->ODR |=  BIT5)
#define PB6_0 (GPIOB->ODR &= ~BIT6)
#define PB6_1 (GPIOB->ODR |=  BIT6)
#define PB7_0 (GPIOB->ODR &= ~BIT7)
#define PB7_1 (GPIOB->ODR |=  BIT7)

#define PA14 (GPIOA->IDR & BIT14)

// note to myself: add pin to to protect inductor


// will want to check voltage constantly
// but we only want to do this in tracking mode


int tracking_mode = 0;
int command_mode = 1;
int init_mode_03m = 2;
int init_mode_05m = 3;

int tracking_time = 76;
int forward_time = 12;
int backward_time = 28;
int left_time = 44;
int right_time = 60;
int command_time = 92;
int extra_feature = 108;
float time_tolerance = 8; // in ms
int command;
int forward_com = 0;
int backward_com = 1;
int left_com = 2;
int right_com = 3;
int voltage_tolerance_right = 0;
int voltage_tolerance_left = 0;


// extra features for backwards left and right
int backward_right_time = 124;
int backward_left_time = 140;


// need to make sure we configure the correct pins to output and input



#define PIN_PERIOD1 (GPIOA->IDR&BIT12)
#define PIN_PERIOD2 (GPIOA->IDR&BIT13)

long int OffTime_one(void)
{
    int i;
    unsigned int saved_TCNT1a, saved_TCNT1b;

    //**the 1st 2 lines RESET the timer
    SysTick->LOAD = 0xffffff;  // 24-bit counter set to check for signal present
    SysTick->VAL = 0xffffff; // load the SysTick counter
    SysTick->CTRL = SysTick_CTRL_CLKSOURCE_Msk | SysTick_CTRL_ENABLE_Msk; // Enable SysTick IRQ and SysTick Timer */
    while (PIN_PERIOD1 != 0) // Wait for square wave to be 0
    {
        if (SysTick->CTRL & BIT16) return 0;
    }
    //**the following lines STOPS the timer
    SysTick->CTRL = 0x00; // Disable Systick counter

    SysTick->LOAD = 0xffffff;  // 24-bit counter set to check for signal present
    SysTick->VAL = 0xffffff; // load the SysTick counter
    SysTick->CTRL = SysTick_CTRL_CLKSOURCE_Msk | SysTick_CTRL_ENABLE_Msk; // Enable SysTick IRQ and SysTick Timer */
    // not to self: might need to make this a comparison and not an equals
    while (PIN_PERIOD1 == 0) // Wait for square wave to be 1
    {
        if (SysTick->CTRL & BIT16) return 0;
    }
    SysTick->CTRL = 0x00; // Disable Systick counter

    SysTick->LOAD = 0xffffff;  // 24-bit counter reset
    SysTick->VAL = 0xffffff; // load the SysTick counter to initial value
    SysTick->CTRL = SysTick_CTRL_CLKSOURCE_Msk | SysTick_CTRL_ENABLE_Msk; // Enable SysTick IRQ and SysTick Timer */

    while (PIN_PERIOD1 != 0) // Wait for square wave to be 0
    {
        if (SysTick->CTRL & BIT16) return 0;
        if (((0xffffff - SysTick->VAL) * 1000) / (F_CPU) > (command_time * 2)) return 1000;
        // making sure to return 0 if we're waiting longer than longest command
    }
    SysTick->CTRL = 0x00; // Disable Systick counter

    SysTick->LOAD = 0xffffff;  // 24-bit counter reset
    SysTick->VAL = 0xffffff; // load the SysTick counter to initial value
    SysTick->CTRL = SysTick_CTRL_CLKSOURCE_Msk | SysTick_CTRL_ENABLE_Msk;

    while (PIN_PERIOD1 == 0) // Wait for square wave to be 1
    {
        if (SysTick->CTRL & BIT16) return 0;
        // we don't need the thing here bc we're never in a state where we're always sending a 0 signal
    }

    SysTick->CTRL = 0x00; // Disable Systick counter

    return 0xffffff - SysTick->VAL;
}



int main() {
    // note to self: need to test 
    long int count2;
    int T, f;
    int j, v;
    int off_time;
    int signal[] = {};
    int right_inductor, left_inductor;
    int right_ind_05_val;
    int left_ind_03_val;
    int right_ind_03_val;
    int left_ind_05_val;
    int distance;
    long int count, count1;
    char line1[17];
    char line2[17];
    int mode = 0;
    T = 1; //not accurate!!! it's actually basically 0 milliseconds
    // also it's a float but im giving it an integer value


    Hardware_Init();
    Configure_Pins();
    waitms(500); // Wait for putty to start.

    LCD_4BIT();

    // automatically in tracking mode
    mode = 0;

    PB3_0;
    PB4_0;
    PB5_0;
    PB6_0;
    PB7_0;

    eputs("initialization");
    sprintf(line1, "initializing");
    waitms(2000);


    LCDprint(line1, 1, 1);

    mode = init_mode_05m;

    while (mode == init_mode_05m) {
        j = readADC(ADC_CHSELR_CHSEL8);
        left_ind_05_val = (j * 33000) / 0xfff;

        j = readADC(ADC_CHSELR_CHSEL9);
        right_ind_05_val = (j * 33000) / 0xfff;

        // pin is pulled high unless button pulls it low i believe
        if (PA14) {
            waitms(300);
            if (PA14) {
                mode = init_mode_03m; // will default to tracking mode unless otherwise specified
                waitms(1000); //allow for slow human
            }

        }

    }
    
    sprintf(line2, "past first button");
    LCDprint(line2, 2, 1);
    mode = command_mode;
    
    while (mode == init_mode_03m) {
        // = readADC(ADC_CHSELR_CHSEL8);
        //left_ind_03_val = (j * 33000) / 0xfff;

        j = readADC(ADC_CHSELR_CHSEL9);
        right_ind_03_val = (j * 33000) / 0xfff;

        // pin is pulled high unless button pulls it low i believe
        if (PA14) {
            waitms(300);
            if (PA14) {
                mode = command_mode; // will default to tracking mode unless otherwise specified
                waitms(1000); //allow for slow human
            }

        }

    }

	int d_scale = (5000000-3000000)/(right_ind_03_val);


    sprintf(line2, "past second button");
    LCDprint(line2, 2, 1);
    mode = command_mode;

    while (1)
    {
        off_time = (OffTime_one() * 1000) / (F_CPU); // should be in this loop until we press the button
        // the first button should indicate if we're in command or tracking mode

        if ((off_time < (command_time + time_tolerance)) && (off_time > (command_time - time_tolerance))) {
            mode = command_mode;
        }
        else if ((off_time < (tracking_time + time_tolerance)) && (off_time > (tracking_time - time_tolerance))) {
            mode = tracking_mode;
        }
        else if (off_time == 0) {
            if (mode == command_mode) {
                // make sure motors aren't spinning
                PB4_0;
                PB3_0;

                // left wheel counterclockwise: left_right off and left_left on
                PB5_0;
                PB6_0;
            }
            else if (mode == tracking_mode) {
                // do nothing?
            }
        }

        if (mode == tracking_mode) {

            while (PIN_PERIOD1 != 0) {
                // while in tracking mode, the signal always stays high unless something is pressed, and we're gonna stay here
                j = readADC(ADC_CHSELR_CHSEL8);
                left_inductor = (j * 33000) / 0xfff;

                j = readADC(ADC_CHSELR_CHSEL9);
                right_inductor = (j * 33000) / 0xfff;
                
                distance = right_inductor*d_scale;

                //waitms(200);

                //sprintf(line1, "right: %d.%dV", right_inductor/10000, right_inductor%10000);
                //LCDprint(line1, 1, 1);

                //sprintf(line2, "left: %d.%dV", left_inductor/10000, left_inductor%10000);
                //LCDprint(line2, 2, 1);
                // for now won't put directions, but ideally the car would be constantly adjusting

                // if our voltage is GREATER than 0.5, move forward (ie away from receiver)
                // if our voltage is smaller than at 0.6, move BACKWARD (ie towards receiver)
                // if our left inductor is smaller than 0.5, turn RIGHT
                // if our right inductor is smaller than 0.5, turn LEFT


                if (right_inductor > right_ind_05_val + voltage_tolerance_right && left_inductor > left_ind_05_val + voltage_tolerance_left) {
                    // move forward
                    PB4_1;
                    PB3_0;

                    PB5_0;
                    PB6_1;

                }
                else if (right_inductor < right_ind_05_val - voltage_tolerance_right && left_inductor < left_ind_05_val - voltage_tolerance_left) {
                    // move backward

                    PB4_0;
                    PB3_1;

                    PB5_1;
                    PB6_0;

                }
                else if ((right_inductor > right_ind_05_val + voltage_tolerance_right) && (left_inductor < left_ind_05_val - voltage_tolerance_left)) {
                    // turn left
                    PB4_1;
                    PB3_0;

                    PB5_0;
                    PB6_0;

                }
                else if ((left_inductor > left_ind_05_val + voltage_tolerance_left)  && (right_inductor < right_ind_05_val - voltage_tolerance_right)) {
                    // turn right
                    PB4_0;
                    PB3_0;

                    PB5_0;
                    PB6_1;
                }
                // extra features - backwards left and right for tracking mode
                else if ((right_inductor < right_ind_05_val - voltage_tolerance_right)  && (left_inductor > left_ind_05_val + voltage_tolerance_left)) {
                    // backwards left
                    PB5_0;
                    PB6_0;

                    PB4_0;
                    PB3_1;
                }
                else if ((left_inductor < left_ind_05_val - voltage_tolerance_left) && (right_inductor > right_ind_05_val + voltage_tolerance_right)) {
                    // backwards right
                    PB4_0;
                    PB3_0;

                    PB5_1;
                    PB6_0;
                }

            }
            // pin_period has gone low, going to be receiving new command (or potentially being told we're still in tracking mode)
            // so while we're waiting to determine, want to turn wheels off 
        }
        else if (mode == command_mode)
        {
            //eputs("Initialization");
            //count1=GetPeriod(100);
            count2 = OffTime_one();
            //sprintf(line2, "command_mode");
            //LCDprint(line2, 1,1);
            if (count2 > 0)
            {
                off_time = (count2 * 1000) / (F_CPU);
                if (off_time > T) {
                    //dont change anything
                    //sprintf(line1, "offt= %d", off_time);
                    //LCDprint(line1, 1, 1);
                    //waitms(200);


                    if ((off_time < forward_time + time_tolerance) && (off_time > forward_time - time_tolerance)) {
                        //sprintf(line2, "forward");
                        //LCDprint(line2, 2, 1);

                        PB4_1;
                        PB3_0;

                        PB5_0;
                        PB6_1;
                    }
                    else if ((off_time < backward_time + time_tolerance) && (off_time > backward_time - time_tolerance)) {
                        //sprintf(line2, "backward");
                        //LCDprint(line2, 2, 1);
                        // right wheel counter clockwise: right_right off, right_left on
                        PB4_0;
                        PB3_1;

                        // left wheel clockwise: left_right on, left_left off
                        PB5_1;
                        PB6_0;

                    }
                    else if ((off_time < left_time + time_tolerance) && (off_time > left_time - time_tolerance)) {
                        // right wheel clockwise and left wheel off
                        PB4_1;
                        PB3_0;

                        PB5_0;
                        PB6_0;

                        //sprintf(line2, "left");
                        //LCDprint(line2, 2, 1);


                    }
                    else if ((off_time < right_time + time_tolerance) && (right_time > right_time - time_tolerance)) {
                        // right wheel off, left wheel counter clockwise
                        PB4_0;
                        PB3_0;

                        PB5_0;
                        PB6_1;

                        //sprintf(line2, "right");
                        //LCDprint(line2, 2, 1);
                    }
                    else if ((off_time < tracking_time + time_tolerance) && (off_time > tracking_time - time_tolerance)) {
                        // right wheel off, left wheel counter clockwise
                        PB4_0;
                        PB3_0;

                        PB5_0;
                        PB6_0;

                        //sprintf(line2, "tracking");
                        //LCDprint(line2, 2, 1);
                    }
                    else if ((off_time < command_time + time_tolerance) && (off_time > command_time - time_tolerance)) {
                        // right wheel off, left wheel counter clockwise
                        PB4_0;
                        PB3_0;

                        PB5_0;
                        PB6_0;

                        //sprintf(line2, "command");
                        //LCDprint(line2, 2, 1);
                    }
                    else if ((off_time < backward_right_time + time_tolerance) && (off_time > backward_right_time - time_tolerance)) {


                        PB4_0;
                        PB3_0;

                        PB5_1;
                        PB6_0;

                    }
                    else if ((off_time < backward_left_time + time_tolerance) && (off_time > backward_left_time - time_tolerance)){
                    // backwards left  - PB5_0 , PB6_0, PB4_0; PB3_1;

                    PB5_0;
                    PB6_0;

                    PB4_0;
                    PB3_1;
                }
                    
                    
                    else {
                        // do nothing
                        //sprintf(line2, "nothing");
                        //LCDprint(line2, 2, 1);
                    }
                }

            }
          }
            
            else
            {
                //sprintf(line2, "error");
                //LCDprint(line2, 2, 1);
            }
            //fflush(stdout); // GCC printf wants a \n in order to send something.  If \n is not present, we fflush(stdout)
            //waitms(200);
        }

    }
