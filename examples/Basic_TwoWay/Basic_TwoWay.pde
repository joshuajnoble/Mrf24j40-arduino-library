/**
 * Example code for using a microchip mrf24j40 module to send and receive
 * packets using plain 802.15.4
 * Requirements: 3 pins for spi, 3 pins for reset, chip select and interrupt
 * notifications
 * This example file is considered to be in the public domain
 * Originally written by Karl Palsson, karlp@tweak.net.au, March 2011
 */
#include <SPI.h>
#include <mrf24j.h>

const int pin_reset = 6;
const int pin_cs = 7;
const int pin_interrupt = 5;

Mrf24j mrf(pin_reset, pin_cs, pin_interrupt);

long last_time;
long tx_interval = 1000;

void setup() {
  Serial.begin(9600);

  mrf.set_pan(0xcafe);
  // This is _our_ address
  mrf.address16_write(0x6001); 

  // uncomment if you want to receive any packet on this channel
  // mrf.set_promiscuous(true);

  attachInterrupt(0, interrupt_routine, CHANGE);   
  last_time = millis();
}

volatile uint8_t gotrx;
volatile uint8_t txok;

void interrupt_routine() {
    // read and clear from the radio
    byte last_interrupt = mrf.read_short(MRF_INTSTAT);
    if (last_interrupt & MRF_I_RXIF) {
        gotrx = 1;
    }
    if (last_interrupt & MRF_I_TXNIF) {
        txok = 1;
    }
}

void loop() {
    int tmp;
    interrupts();
    unsigned long current_time = millis();
    if (current_time - last_time > tx_interval) {
        last_time = current_time;
        Serial.println("txxxing...");
        mrf.send16(0x4202, 4, "abcd");
    }
    if (txok) {
        txok = 0;
        Serial.print("tx went ok:");
        tmp = mrf.read_short(MRF_TXSTAT);
        Serial.print(tmp);
        if (!(tmp & ~(1<<TXNSTAT))) {  // 1 = failed
            Serial.print("...And we got an ACK");
        } else {
            Serial.print("retried ");
            Serial.print(tmp >> 6, HEX);
        }
        Serial.println();
    }
    if (gotrx) {
        gotrx = 0;
        noInterrupts();
        mrf.rx_disable();

        byte frame_length = mrf.read_long(0x300);  // read start of rxfifo
        Serial.print("received a packet ");Serial.print(frame_length, DEC);Serial.println(" bytes long");
        Serial.println("Packet data:");
        for (int i = 1; i <= frame_length; i++) {
            tmp = mrf.read_long(0x300 + i);
            Serial.print(tmp, HEX);
        }
        Serial.print("\r\nLQI/RSSI=");
        byte lqi = mrf.read_long(0x300 + frame_length + 1);
        byte rssi = mrf.read_long(0x300 + frame_length + 2);
        Serial.print(lqi, HEX);
        Serial.println(rssi, HEX);

        mrf.rx_enable();
        interrupts();

    }
  
}
