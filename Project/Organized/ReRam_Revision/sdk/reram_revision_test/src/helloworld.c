#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "sleep.h"

// Replace with your IP base address from Address Editor
#define RERAM_BASEADDR   XPAR_AXI_RERAM_0_S00_AXI_BASEADDR

// Register offsets (word-aligned)
#define REG_CONTROL   0x00   // [0]=start, [1]=target_state, [2]=data_in
#define REG_ADDR      0x04   // address of cell
#define REG_STATUS    0x08   // [0]=busy,[1]=failed,[2]=read,[3]=data_out

int main(void)
{
    xil_printf("=== Simple ReRAM AXI Register Test ===\r\n");

    // 1. Write address 0
    Xil_Out32(RERAM_BASEADDR + REG_ADDR, 0b00000101);
    xil_printf("ADDR to five write written: 0x%08X\r\n", Xil_In32(RERAM_BASEADDR + REG_ADDR));

    // 2. Start SET (target=LRS=0, data_in=1)
    // bits: [2]=data_in(1), [1]=target_state(0=LRS), [0]=start(1)
    Xil_Out32(RERAM_BASEADDR + REG_CONTROL, 0b00000101);
    xil_printf("CONTROL written: 0x%08X\r\n", Xil_In32(RERAM_BASEADDR + REG_CONTROL));

    // 3. Poll STATUS until busy=0
    u32 status;
    do {
        status = Xil_In32(RERAM_BASEADDR + REG_STATUS);
    } while (status & 0x1);
    xil_printf("STATUS after SET = 0x%08X\r\n", status);

    // 4. Read back STATUS bits (observe in Memory window too)
    xil_printf("ReadData(bit2)=%d, DataOut(bit3)=%d\r\n",
               (status >> 2) & 1, (status >> 3) & 1);

    // 5. Now issue RESET (target=HRS=1)
    Xil_Out32(RERAM_BASEADDR + REG_CONTROL, 0b00000011);
    do {
        status = Xil_In32(RERAM_BASEADDR + REG_STATUS);
    } while (status & 0x1);
    xil_printf("STATUS after RESET = 0x%08X\r\n", status);

    xil_printf("=== Done ===\r\n");

    while (1) ; // Keep running so memory window stays valid
    return 0;
}
