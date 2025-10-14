#include "xil_io.h"
#include "xparameters.h"
#include "xil_printf.h"

#define RERAM_BASEADDR   XPAR_RERAM_AXI_IP_0_S00_AXI_BASEADDR

#define REG_CONTROL      0x00
#define REG_ADDR         0x04
#define REG_DATA_IN      0x08
#define REG_STATUS       0x0C
#define REG_DATA_OUT     0x10
#define REG_READSTATE    0x14
#define REG_VERSION      0x18

int main()
{
    xil_printf("ReRAM AXI IP Test Start\r\n");

    // Read version (quick connectivity test)
    u32 version = Xil_In32(RERAM_BASEADDR + REG_VERSION);
    xil_printf("ReRAM IP Version = 0x%08X\r\n", version);

    // Select cell address 0
    Xil_Out32(RERAM_BASEADDR + REG_ADDR, 0x0);

    // Set data to '1' and write LRS state
    Xil_Out32(RERAM_BASEADDR + REG_DATA_IN, 0x1);
    Xil_Out32(RERAM_BASEADDR + REG_CONTROL, 0x1);  // start command, target_state=0=LRS

    // Wait for busy=0
    u32 status;
    do {
        status = Xil_In32(RERAM_BASEADDR + REG_STATUS);
    } while (status & 0x1);
    xil_printf("Write done (STATUS=0x%08X)\r\n", status);

    // Read data back
    u32 data_out = Xil_In32(RERAM_BASEADDR + REG_DATA_OUT);
    u32 read_state = Xil_In32(RERAM_BASEADDR + REG_READSTATE);
    xil_printf("DATA_OUT=%d, READ_STATE=%d\r\n", data_out & 1, read_state & 1);

    // Try resetting same cell to HRS
    Xil_Out32(RERAM_BASEADDR + REG_CONTROL, 0x3); // bit1=1 (target=HRS), bit0=1 (start)
    do {
        status = Xil_In32(RERAM_BASEADDR + REG_STATUS);
    } while (status & 0x1);

    read_state = Xil_In32(RERAM_BASEADDR + REG_READSTATE);
    xil_printf("After RESET, READ_STATE=%d\r\n", read_state & 1);

    xil_printf("ReRAM AXI IP Test Complete\r\n");
    return 0;
}
