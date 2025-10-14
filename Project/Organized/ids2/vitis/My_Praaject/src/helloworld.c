#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xtime_l.h"

// -----------------------------
// ReRAM register map
// -----------------------------
#define RERAM_BASE     XPAR_BRAM_0_BASEADDR
#define REG_CONTROL    (RERAM_BASE + 0x00)  // control signals
#define REG_ADDR       (RERAM_BASE + 0x04)  // cell address
#define REG_DATA_IN    (RERAM_BASE + 0x08)  // input data
#define REG_STATUS     (RERAM_BASE + 0x0C)  // busy/failed
#define REG_DATA_OUT   (RERAM_BASE + 0x10)  // read data

// -----------------------------
// Delay function (ns resolution)
// -----------------------------
void delay_ns(u64 ns) {
    XTime t1, t2;
    u64 cycles = (COUNTS_PER_SECOND * ns) / 1000000000ULL;  // ns  cycles
    XTime_GetTime(&t1);
    do {
        XTime_GetTime(&t2);
    } while ((t2 - t1) < cycles);
}

int main() {
    xil_printf("=== ReRAM Test Start ===\n\r");
    xil_printf("=== Myself Hrishikesh ===\n\r");

    while (1) {
        // Example: write '1' to address 0
        xil_printf("\n\rWriting value '1' to address 0...\n\r");
        Xil_Out32(RERAM_BASE, 1);       // select cell address
//        Xil_Out32(REG_DATA_IN, 1);    // data to store
//        Xil_Out32(REG_CONTROL, 1);    // trigger write (SET = LRS)
        xil_printf("\n\rWriting value '1' to address 0...\n\r");
        // Wait until write finishes
//        while (Xil_In32(REG_STATUS) & 0x1);

        // Ensure ReRAM has enough SET pulse time (example: 1 ms)
        delay_ns(1000000ULL);  // 1 ms = 1,000,000 ns

        // Read back result
        int val = Xil_In32(RERAM_BASE);
        xil_printf("Read value at addr 0: %d\n\r", val+1);

        xil_printf("=== ReRAM cycle complete ===\n\r");

        // Add a gap before next cycle (example: 100 ms)
        delay_ns(100000000ULL);  // 100 ms
    }

    return 0;
}
