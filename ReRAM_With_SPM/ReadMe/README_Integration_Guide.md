# Integration Guide Documentation

## 🎯 Overview

This comprehensive integration guide provides step-by-step instructions for integrating the ReRAM memory system into various hardware and software environments, from bare metal embedded systems to complex ARM SoC designs.

```
┌─────────────────────────────────────────────────────────────────┐
│                   Integration Scenarios                        │
├─────────────────────────────────────────────────────────────────┤
│  ARM SoC    │  Microcontroller  │  FPGA Only  │  Linux System  │
│  (Zynq)     │  (Cortex-M)       │  (Pure HDL) │  (Full Stack)  │
├─────────────────────────────────────────────────────────────────┤
│             ReRAM Integration Architecture                      │
│  Hardware Layer → Software Layer → Application Layer          │
└─────────────────────────────────────────────────────────────────┘
```

## 🏗️ Integration Options

### **Integration Levels**
1. **Hardware-Only**: Direct HDL integration without AXI
2. **AXI Integration**: Standard ARM processor integration
3. **Software Stack**: Complete driver and application integration
4. **System Integration**: Full SoC with OS support

### **Target Platforms**
| Platform | Complexity | Use Cases | Documentation Section |
|----------|------------|-----------|----------------------|
| **FPGA Development Board** | Low | Prototyping, Education | [FPGA Integration](#fpga-integration) |
| **ARM Cortex-M System** | Medium | Embedded, IoT | [Microcontroller Integration](#microcontroller-integration) |
| **Zynq SoC** | High | High-performance systems | [ARM SoC Integration](#arm-soc-integration) |
| **Linux System** | Very High | Enterprise, Research | [Linux Integration](#linux-integration) |

## 🔧 FPGA Integration

### **Basic FPGA Setup (No Processor)**

For pure FPGA implementations without ARM processors:

```systemverilog
// Top-level FPGA design
module fpga_reram_system (
    input  logic        clk_100mhz,     // Board clock
    input  logic        reset_n,        // Board reset
    
    // External interfaces
    input  logic [7:0]  switches,       // Board switches
    output logic [7:0]  leds,           // Board LEDs
    
    // UART for debugging
    input  logic        uart_rx,
    output logic        uart_tx
);

    // Clock and reset management
    logic sys_clk, sys_reset_n;
    logic pll_locked;
    
    // System PLL for stable clock
    clk_wiz_0 system_pll (
        .clk_in1(clk_100mhz),
        .clk_out1(sys_clk),      // 100MHz system clock
        .locked(pll_locked),
        .resetn(reset_n)
    );
    
    // Reset synchronizer
    reset_sync reset_sync_inst (
        .clk(sys_clk),
        .async_reset_n(reset_n && pll_locked),
        .sync_reset_n(sys_reset_n)
    );
    
    // Simple controller for testing ReRAM
    simple_reram_controller controller (
        .clk(sys_clk),
        .rst_n(sys_reset_n),
        
        // User interface
        .switches(switches),
        .leds(leds),
        
        // UART debug
        .uart_rx(uart_rx),
        .uart_tx(uart_tx)
    );

endmodule
```

#### **Simple Test Controller**
```systemverilog
module simple_reram_controller (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [7:0]  switches,
    output logic [7:0]  leds,
    input  logic        uart_rx,
    output logic        uart_tx
);

    // ReRAM controller interface
    logic [3:0]  mem_addr;
    logic [31:0] mem_data_in;
    logic [31:0] mem_data_out;
    logic        mem_read;
    logic        mem_write;
    logic        mem_done;
    logic        mem_error;
    logic        mem_busy;
    
    // Test state machine
    typedef enum logic [2:0] {
        TEST_IDLE,
        TEST_WRITE,
        TEST_READ,
        TEST_VERIFY,
        TEST_DONE
    } test_state_t;
    
    test_state_t test_state;
    logic [31:0] test_data;
    logic [31:0] read_result;
    
    // ReRAM memory controller instance
    reram_memory_controller_blocking #(
        .MEMORY_DEPTH(16),
        .DATA_WIDTH(32),
        .READ_DELAY_CYCLES(3),
        .SET_DELAY_CYCLES(10),
        .RESET_DELAY_CYCLES(10),
        .MAX_WRITE_CYCLES(200)
    ) reram_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .addr_i(mem_addr),
        .data_i(mem_data_in),
        .data_o(mem_data_out),
        .read_i(mem_read),
        .write_i(mem_write),
        .done_o(mem_done),
        .error_o(mem_error),
        .busy_o(mem_busy),
        // ... other connections
    );
    
    // Simple test sequence
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            test_state <= TEST_IDLE;
            mem_addr <= 4'h0;
            mem_data_in <= 32'h0;
            mem_read <= 1'b0;
            mem_write <= 1'b0;
            test_data <= 32'hA5A5A5A5;
            leds <= 8'h00;
        end else begin
            case (test_state)
                TEST_IDLE: begin
                    if (switches[0]) begin  // Start test with switch 0
                        test_state <= TEST_WRITE;
                        mem_data_in <= test_data;
                        mem_write <= 1'b1;
                        leds[0] <= 1'b1;  // Indicate test started
                    end
                end
                
                TEST_WRITE: begin
                    if (mem_done) begin
                        mem_write <= 1'b0;
                        if (!mem_error) begin
                            test_state <= TEST_READ;
                            mem_read <= 1'b1;
                            leds[1] <= 1'b1;  // Write success
                        end else begin
                            leds[7] <= 1'b1;  // Error indicator
                            test_state <= TEST_IDLE;
                        end
                    end
                end
                
                TEST_READ: begin
                    if (mem_done) begin
                        mem_read <= 1'b0;
                        read_result <= mem_data_out;
                        test_state <= TEST_VERIFY;
                    end
                end
                
                TEST_VERIFY: begin
                    if (read_result == test_data) begin
                        leds[2] <= 1'b1;  // Verify success
                        test_state <= TEST_DONE;
                    end else begin
                        leds[6] <= 1'b1;  // Verify failed
                        test_state <= TEST_IDLE;
                    end
                end
                
                TEST_DONE: begin
                    leds[3:0] <= 4'b1111;  // All tests passed
                    if (!switches[0]) begin
                        test_state <= TEST_IDLE;
                        leds <= 8'h00;
                    end
                end
            endcase
        end
    end

endmodule
```

### **FPGA Resource Requirements**

| FPGA Device | Memory Size | LUTs | Flip-Flops | BRAMs | Max Clock |
|-------------|-------------|------|------------|-------|-----------|
| **Artix-7 (XC7A35T)** | 16 words | ~600 | ~800 | 0 | 150MHz |
| **Zynq-7020** | 64 words | ~2000 | ~2500 | 0 | 200MHz |
| **Kintex-7** | 256 words | ~7000 | ~9000 | 0 | 250MHz |

### **FPGA Build Script**
```tcl
# Vivado TCL script for ReRAM system
create_project reram_fpga ./reram_fpga -part xc7z020clg484-1

# Add source files
add_files -norecurse {
    reram_cell_simple.sv
    reram_word_array_simple.sv
    reram_memory_controller_blocking.sv
    simple_reram_controller.sv
    fpga_reram_system.sv
}

# Add constraints
add_files -fileset constrs_1 -norecurse fpga_constraints.xdc

# Set top module
set_property top fpga_reram_system [current_fileset]

# Run synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Run implementation
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# Generate bitstream
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

puts "Build completed successfully!"
```

## 🔌 Microcontroller Integration

### **ARM Cortex-M with Memory-Mapped Interface**

For microcontrollers without AXI support:

```systemverilog
// Cortex-M memory-mapped ReRAM interface
module cortex_m_reram_interface #(
    parameter int MEMORY_DEPTH = 16,
    parameter int MEMORY_BASE_ADDR = 32'h20000000,  // SRAM region
    parameter int CTRL_BASE_ADDR = 32'h40000000     // Peripheral region
) (
    input  logic        hclk,           // AHB clock
    input  logic        hresetn,        // AHB reset
    
    // AHB Lite interface (from Cortex-M)
    input  logic [31:0] haddr,          // Address
    input  logic [2:0]  hsize,          // Transfer size
    input  logic [1:0]  htrans,         // Transfer type
    input  logic        hwrite,         // Write enable
    input  logic [31:0] hwdata,         // Write data
    output logic [31:0] hrdata,         // Read data
    output logic        hready,         // Transfer ready
    output logic        hresp           // Transfer response
);

    // AHB transaction decode
    logic addr_sel, ctrl_sel;
    logic trans_valid;
    logic [3:0] word_addr;
    
    assign trans_valid = (htrans != 2'b00);  // IDLE or BUSY
    assign addr_sel = (haddr >= MEMORY_BASE_ADDR) && 
                     (haddr < MEMORY_BASE_ADDR + (MEMORY_DEPTH * 4));
    assign ctrl_sel = (haddr >= CTRL_BASE_ADDR) && 
                     (haddr < CTRL_BASE_ADDR + 32'h100);
    assign word_addr = (haddr - MEMORY_BASE_ADDR) >> 2;
    
    // ReRAM controller interface
    logic [3:0]  mem_addr;
    logic [31:0] mem_data_in;
    logic [31:0] mem_data_out;
    logic        mem_read;
    logic        mem_write;
    logic        mem_done;
    logic        mem_error;
    logic        mem_busy;
    
    // ReRAM controller instance
    reram_memory_controller_blocking #(
        .MEMORY_DEPTH(MEMORY_DEPTH),
        .DATA_WIDTH(32),
        .READ_DELAY_CYCLES(3),
        .SET_DELAY_CYCLES(10),
        .RESET_DELAY_CYCLES(10),
        .MAX_WRITE_CYCLES(200)
    ) reram_ctrl (
        .clk(hclk),
        .rst_n(hresetn),
        .addr_i(mem_addr),
        .data_i(mem_data_in),
        .data_o(mem_data_out),
        .read_i(mem_read),
        .write_i(mem_write),
        .done_o(mem_done),
        .error_o(mem_error),
        .busy_o(mem_busy),
        // ... monitoring outputs
    );
    
    // AHB state machine
    typedef enum logic [1:0] {
        AHB_IDLE,
        AHB_ACCESS,
        AHB_WAIT
    } ahb_state_t;
    
    ahb_state_t ahb_state;
    logic [31:0] addr_reg;
    logic        write_reg;
    
    always_ff @(posedge hclk or negedge hresetn) begin
        if (!hresetn) begin
            ahb_state <= AHB_IDLE;
            addr_reg <= 32'h0;
            write_reg <= 1'b0;
            mem_read <= 1'b0;
            mem_write <= 1'b0;
        end else begin
            case (ahb_state)
                AHB_IDLE: begin
                    if (trans_valid && (addr_sel || ctrl_sel)) begin
                        addr_reg <= haddr;
                        write_reg <= hwrite;
                        ahb_state <= AHB_ACCESS;
                        
                        if (addr_sel) begin
                            mem_addr <= word_addr;
                            if (hwrite) begin
                                mem_data_in <= hwdata;
                                mem_write <= 1'b1;
                            end else begin
                                mem_read <= 1'b1;
                            end
                        end
                    end
                end
                
                AHB_ACCESS: begin
                    if (addr_sel) begin
                        if (mem_done) begin
                            mem_read <= 1'b0;
                            mem_write <= 1'b0;
                            ahb_state <= AHB_IDLE;
                        end else begin
                            ahb_state <= AHB_WAIT;
                        end
                    end else begin
                        // Control register access (single cycle)
                        ahb_state <= AHB_IDLE;
                    end
                end
                
                AHB_WAIT: begin
                    if (mem_done) begin
                        mem_read <= 1'b0;
                        mem_write <= 1'b0;
                        ahb_state <= AHB_IDLE;
                    end
                end
            endcase
        end
    end
    
    // AHB response generation
    always_comb begin
        hready = (ahb_state == AHB_IDLE) || 
                ((ahb_state == AHB_ACCESS) && (ctrl_sel || mem_done));
        hresp = mem_error;  // Error response
        
        if (addr_sel && !write_reg) begin
            hrdata = mem_data_out;
        end else if (ctrl_sel) begin
            // Control register read
            case (addr_reg[7:0])
                8'h00: hrdata = {mem_busy, 31'h0};  // Status
                8'h04: hrdata = 32'h0;              // Control
                default: hrdata = 32'h0;
            endcase
        end else begin
            hrdata = 32'h0;
        end
    end

endmodule
```

### **Cortex-M Software Integration**
```c
// Cortex-M bare metal driver
#include <stdint.h>
#include <stdbool.h>

// Memory-mapped register addresses
#define RERAM_MEMORY_BASE   0x20000000
#define RERAM_CTRL_BASE     0x40000000
#define RERAM_STATUS_REG    (RERAM_CTRL_BASE + 0x00)
#define RERAM_CONTROL_REG   (RERAM_CTRL_BASE + 0x04)

// Memory access macros
#define RERAM_WRITE_WORD(addr, data) (*(volatile uint32_t*)(RERAM_MEMORY_BASE + ((addr) * 4)) = (data))
#define RERAM_READ_WORD(addr) (*(volatile uint32_t*)(RERAM_MEMORY_BASE + ((addr) * 4)))
#define RERAM_READ_STATUS() (*(volatile uint32_t*)RERAM_STATUS_REG)

// Simple ReRAM driver for Cortex-M
bool reram_cortex_m_write(uint8_t word_addr, uint32_t data) {
    if (word_addr >= 16) return false;  // Address bounds check
    
    // Check if controller is busy
    if (RERAM_READ_STATUS() & 0x1) {
        return false;  // Busy
    }
    
    // Perform write
    RERAM_WRITE_WORD(word_addr, data);
    
    // Wait for completion (with timeout)
    int timeout = 1000;
    while ((RERAM_READ_STATUS() & 0x1) && (timeout-- > 0)) {
        __NOP();  // Wait
    }
    
    return (timeout > 0);  // Success if not timeout
}

uint32_t reram_cortex_m_read(uint8_t word_addr) {
    if (word_addr >= 16) return 0;  // Address bounds check
    
    // Read operation (blocking)
    return RERAM_READ_WORD(word_addr);
}

// Example application
int main(void) {
    // System initialization
    SystemInit();
    
    // Test ReRAM
    if (reram_cortex_m_write(0, 0xDEADBEEF)) {
        uint32_t read_data = reram_cortex_m_read(0);
        if (read_data == 0xDEADBEEF) {
            // Success - use green LED
            GPIOA->ODR |= (1 << 5);
        }
    }
    
    while (1) {
        // Main application loop
        __WFI();  // Wait for interrupt
    }
}
```

## 🚀 ARM SoC Integration

### **Zynq-7000 Complete System**

For full ARM SoC integration with Zynq:

```systemverilog
// Complete Zynq system with ReRAM
module zynq_reram_system (
    // Zynq processing system connections
    input  logic        ps_clk,
    input  logic        ps_resetn,
    
    // External interfaces
    input  logic        uart_rx,
    output logic        uart_tx,
    output logic [7:0]  gpio_out,
    input  logic [7:0]  gpio_in
);

    // Clock and reset from Zynq PS
    logic axi_clk;
    logic axi_resetn;
    
    // AXI interconnect signals
    logic [31:0] m_axi_awaddr;
    logic        m_axi_awvalid;
    logic        m_axi_awready;
    logic [31:0] m_axi_wdata;
    logic [3:0]  m_axi_wstrb;
    logic        m_axi_wvalid;
    logic        m_axi_wready;
    logic [1:0]  m_axi_bresp;
    logic        m_axi_bvalid;
    logic        m_axi_bready;
    logic [31:0] m_axi_araddr;
    logic        m_axi_arvalid;
    logic        m_axi_arready;
    logic [31:0] m_axi_rdata;
    logic [1:0]  m_axi_rresp;
    logic        m_axi_rvalid;
    logic        m_axi_rready;
    
    // Zynq Processing System
    zynq_ps_wrapper zynq_ps (
        .ps_clk(ps_clk),
        .ps_resetn(ps_resetn),
        
        // AXI master interface
        .m_axi_aclk(axi_clk),
        .m_axi_aresetn(axi_resetn),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready),
        
        // External interfaces
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .gpio_out(gpio_out),
        .gpio_in(gpio_in)
    );
    
    // ReRAM AXI Controller
    axi_reram_memory_controller #(
        .AXI_ADDR_WIDTH(32),
        .AXI_DATA_WIDTH(32),
        .MEMORY_DEPTH(64),                    // 256 bytes
        .MEMORY_BASE_ADDR(32'h2000_0000),     // ARM memory region
        .CTRL_BASE_ADDR(32'h4000_0000),       // ARM peripheral region
        .READ_DELAY_CYCLES(3),
        .SET_DELAY_CYCLES(10),
        .RESET_DELAY_CYCLES(10),
        .MAX_WRITE_CYCLES(500)
    ) reram_axi (
        .aclk(axi_clk),
        .aresetn(axi_resetn),
        
        // AXI slave interface
        .s_axi_awaddr(m_axi_awaddr),
        .s_axi_awvalid(m_axi_awvalid),
        .s_axi_awready(m_axi_awready),
        .s_axi_awprot(3'b000),
        .s_axi_wdata(m_axi_wdata),
        .s_axi_wstrb(m_axi_wstrb),
        .s_axi_wvalid(m_axi_wvalid),
        .s_axi_wready(m_axi_wready),
        .s_axi_bresp(m_axi_bresp),
        .s_axi_bvalid(m_axi_bvalid),
        .s_axi_bready(m_axi_bready),
        .s_axi_araddr(m_axi_araddr),
        .s_axi_arvalid(m_axi_arvalid),
        .s_axi_arready(m_axi_arready),
        .s_axi_arprot(3'b000),
        .s_axi_rdata(m_axi_rdata),
        .s_axi_rresp(m_axi_rresp),
        .s_axi_rvalid(m_axi_rvalid),
        .s_axi_rready(m_axi_rready)
    );

endmodule
```

### **Zynq Vivado Block Design**
```tcl
# Create block design for Zynq + ReRAM
create_bd_design "zynq_reram_design"

# Add Zynq processing system
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0

# Configure Zynq PS
set_property -dict [list \\
    CONFIG.PCW_USE_S_AXI_HP0 {1} \\
    CONFIG.PCW_S_AXI_HP0_DATA_WIDTH {32} \\
    CONFIG.PCW_UART1_PERIPHERAL_ENABLE {1} \\
    CONFIG.PCW_GPIO_MIO_GPIO_ENABLE {1} \\
] [get_bd_cells processing_system7_0]

# Add ReRAM AXI controller
create_bd_cell -type module -reference axi_reram_memory_controller reram_ctrl_0

# Connect clocks and resets
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \\
               [get_bd_pins reram_ctrl_0/aclk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] \\
               [get_bd_pins reram_ctrl_0/aresetn]

# Connect AXI interface
connect_bd_intf_net [get_bd_intf_pins processing_system7_0/M_AXI_GP0] \\
                    [get_bd_intf_pins reram_ctrl_0/s_axi]

# Create address segments
create_bd_addr_seg -range 0x100 -offset 0x20000000 \\
    [get_bd_addr_spaces processing_system7_0/Data] \\
    [get_bd_addr_segs reram_ctrl_0/s_axi/memory_region] \\
    SEG_reram_memory

create_bd_addr_seg -range 0x100 -offset 0x40000000 \\
    [get_bd_addr_spaces processing_system7_0/Data] \\
    [get_bd_addr_segs reram_ctrl_0/s_axi/ctrl_region] \\
    SEG_reram_ctrl

# Generate HDL wrapper
make_wrapper -files [get_files zynq_reram_design.bd] -top
add_files -norecurse ./zynq_reram_design_wrapper.v

# Set as top
set_property top zynq_reram_design_wrapper [current_fileset]
```

## 🐧 Linux Integration

### **Device Tree Configuration**
```dts
// Device tree entry for ReRAM controller
/ {
    amba {
        reram_ctrl: reram@40000000 {
            compatible = "xlnx,reram-controller-1.0";
            reg = <0x40000000 0x100>,      // Control registers
                  <0x20000000 0x100>;      // Memory region
            reg-names = "ctrl", "memory";
            xlnx,memory-depth = <64>;
            xlnx,max-write-cycles = <500>;
            status = "okay";
        };
    };
};
```

### **Linux Kernel Driver**
```c
// Linux kernel driver for ReRAM controller
#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/of.h>
#include <linux/io.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/uaccess.h>

struct reram_device {
    void __iomem *ctrl_base;
    void __iomem *memory_base;
    dev_t dev_num;
    struct cdev cdev;
    struct class *class;
    struct device *device;
    int memory_depth;
    int max_write_cycles;
};

static struct reram_device *reram_dev;

// Character device operations
static int reram_open(struct inode *inode, struct file *file) {
    file->private_data = reram_dev;
    return 0;
}

static ssize_t reram_read(struct file *file, char __user *buffer,
                         size_t count, loff_t *pos) {
    struct reram_device *dev = file->private_data;
    uint32_t data;
    int word_addr = *pos / 4;
    
    if (word_addr >= dev->memory_depth) {
        return -EINVAL;
    }
    
    if (count < sizeof(uint32_t)) {
        return -EINVAL;
    }
    
    data = ioread32(dev->memory_base + word_addr * 4);
    
    if (copy_to_user(buffer, &data, sizeof(data))) {
        return -EFAULT;
    }
    
    *pos += sizeof(data);
    return sizeof(data);
}

static ssize_t reram_write(struct file *file, const char __user *buffer,
                          size_t count, loff_t *pos) {
    struct reram_device *dev = file->private_data;
    uint32_t data;
    int word_addr = *pos / 4;
    
    if (word_addr >= dev->memory_depth) {
        return -EINVAL;
    }
    
    if (count < sizeof(uint32_t)) {
        return -EINVAL;
    }
    
    if (copy_from_user(&data, buffer, sizeof(data))) {
        return -EFAULT;
    }
    
    iowrite32(data, dev->memory_base + word_addr * 4);
    
    *pos += sizeof(data);
    return sizeof(data);
}

// Health monitoring through sysfs
static ssize_t health_status_show(struct device *device,
                                 struct device_attribute *attr,
                                 char *buf) {
    struct reram_device *dev = dev_get_drvdata(device);
    uint32_t health = ioread32(dev->ctrl_base + 0xC0);  // Health summary register
    
    return sprintf(buf, "healthy:%d warning:%d critical:%d worn_out:%d\\n",
                   health & 0xFF,
                   (health >> 8) & 0xFF,
                   (health >> 16) & 0xFF,
                   (health >> 24) & 0xFF);
}

static DEVICE_ATTR_RO(health_status);

static struct attribute *reram_attrs[] = {
    &dev_attr_health_status.attr,
    NULL,
};

static const struct attribute_group reram_attr_group = {
    .attrs = reram_attrs,
};

static const struct file_operations reram_fops = {
    .owner = THIS_MODULE,
    .open = reram_open,
    .read = reram_read,
    .write = reram_write,
    .llseek = default_llseek,
};

static int reram_probe(struct platform_device *pdev) {
    struct resource *res;
    int ret;
    
    reram_dev = devm_kzalloc(&pdev->dev, sizeof(*reram_dev), GFP_KERNEL);
    if (!reram_dev) {
        return -ENOMEM;
    }
    
    // Map control registers
    res = platform_get_resource_byname(pdev, IORESOURCE_MEM, "ctrl");
    reram_dev->ctrl_base = devm_ioremap_resource(&pdev->dev, res);
    if (IS_ERR(reram_dev->ctrl_base)) {
        return PTR_ERR(reram_dev->ctrl_base);
    }
    
    // Map memory region
    res = platform_get_resource_byname(pdev, IORESOURCE_MEM, "memory");
    reram_dev->memory_base = devm_ioremap_resource(&pdev->dev, res);
    if (IS_ERR(reram_dev->memory_base)) {
        return PTR_ERR(reram_dev->memory_base);
    }
    
    // Get device tree properties
    of_property_read_u32(pdev->dev.of_node, "xlnx,memory-depth",
                        &reram_dev->memory_depth);
    of_property_read_u32(pdev->dev.of_node, "xlnx,max-write-cycles",
                        &reram_dev->max_write_cycles);
    
    // Create character device
    ret = alloc_chrdev_region(&reram_dev->dev_num, 0, 1, "reram");
    if (ret < 0) {
        return ret;
    }
    
    cdev_init(&reram_dev->cdev, &reram_fops);
    ret = cdev_add(&reram_dev->cdev, reram_dev->dev_num, 1);
    if (ret < 0) {
        goto unregister_chrdev;
    }
    
    // Create device class
    reram_dev->class = class_create(THIS_MODULE, "reram");
    if (IS_ERR(reram_dev->class)) {
        ret = PTR_ERR(reram_dev->class);
        goto delete_cdev;
    }
    
    // Create device
    reram_dev->device = device_create(reram_dev->class, &pdev->dev,
                                     reram_dev->dev_num, reram_dev,
                                     "reram%d", 0);
    if (IS_ERR(reram_dev->device)) {
        ret = PTR_ERR(reram_dev->device);
        goto destroy_class;
    }
    
    // Create sysfs attributes
    ret = sysfs_create_group(&reram_dev->device->kobj, &reram_attr_group);
    if (ret) {
        goto destroy_device;
    }
    
    platform_set_drvdata(pdev, reram_dev);
    
    dev_info(&pdev->dev, "ReRAM controller initialized: %d words, %d max cycles\\n",
             reram_dev->memory_depth, reram_dev->max_write_cycles);
    
    return 0;
    
destroy_device:
    device_destroy(reram_dev->class, reram_dev->dev_num);
destroy_class:
    class_destroy(reram_dev->class);
delete_cdev:
    cdev_del(&reram_dev->cdev);
unregister_chrdev:
    unregister_chrdev_region(reram_dev->dev_num, 1);
    return ret;
}

static int reram_remove(struct platform_device *pdev) {
    struct reram_device *dev = platform_get_drvdata(pdev);
    
    sysfs_remove_group(&dev->device->kobj, &reram_attr_group);
    device_destroy(dev->class, dev->dev_num);
    class_destroy(dev->class);
    cdev_del(&dev->cdev);
    unregister_chrdev_region(dev->dev_num, 1);
    
    return 0;
}

static const struct of_device_id reram_of_match[] = {
    { .compatible = "xlnx,reram-controller-1.0" },
    { /* end of list */ }
};
MODULE_DEVICE_TABLE(of, reram_of_match);

static struct platform_driver reram_driver = {
    .probe = reram_probe,
    .remove = reram_remove,
    .driver = {
        .name = "reram-controller",
        .of_match_table = reram_of_match,
    },
};

module_platform_driver(reram_driver);

MODULE_AUTHOR("ReRAM Development Team");
MODULE_DESCRIPTION("ReRAM Memory Controller Driver");
MODULE_LICENSE("GPL v2");
```

### **User Space Application**
```c
// User space application for Linux
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>
#include <string.h>

int main(int argc, char *argv[]) {
    int fd;
    uint32_t data;
    ssize_t ret;
    
    // Open ReRAM device
    fd = open("/dev/reram0", O_RDWR);
    if (fd < 0) {
        perror("Failed to open ReRAM device");
        return -1;
    }
    
    if (argc > 1 && strcmp(argv[1], "write") == 0) {
        // Write test data
        printf("Writing test pattern...\\n");
        for (int i = 0; i < 16; i++) {
            data = 0x12345678 + i;
            lseek(fd, i * 4, SEEK_SET);
            ret = write(fd, &data, sizeof(data));
            if (ret != sizeof(data)) {
                printf("Write failed at word %d\\n", i);
                break;
            }
        }
        printf("Write completed\\n");
    } else {
        // Read and display data
        printf("Reading ReRAM contents:\\n");
        for (int i = 0; i < 16; i++) {
            lseek(fd, i * 4, SEEK_SET);
            ret = read(fd, &data, sizeof(data));
            if (ret == sizeof(data)) {
                printf("Word %2d: 0x%08X\\n", i, data);
            } else {
                printf("Read failed at word %d\\n", i);
                break;
            }
        }
    }
    
    close(fd);
    
    // Check health status
    FILE *health_file = fopen("/sys/class/reram/reram0/health_status", "r");
    if (health_file) {
        char health_str[256];
        if (fgets(health_str, sizeof(health_str), health_file)) {
            printf("\\nHealth Status: %s", health_str);
        }
        fclose(health_file);
    }
    
    return 0;
}
```

## 🛠️ Build and Deployment

### **Vivado Build Scripts**
```bash
#!/bin/bash
# build_reram_system.sh

PROJECT_NAME="reram_system"
PART="xc7z020clg484-1"

echo "Building ReRAM system for $PART..."

# Create project
vivado -mode batch -source <<EOF
create_project $PROJECT_NAME ./$PROJECT_NAME -part $PART

# Add HDL sources
add_files -norecurse {
    reram_cell_simple.sv
    reram_word_array_simple.sv
    reram_memory_controller_blocking.sv
    axi_reram_memory_controller.sv
    zynq_reram_system.sv
}

# Add IP repository (if using custom IP)
set_property ip_repo_paths ./ip_repo [current_project]
update_ip_catalog

# Create block design
source ./create_bd.tcl

# Generate HDL wrapper
make_wrapper -files [get_files zynq_reram_design.bd] -top
add_files -norecurse ./zynq_reram_design_wrapper.v
set_property top zynq_reram_design_wrapper [current_fileset]

# Add constraints
add_files -fileset constrs_1 -norecurse constraints.xdc

# Run synthesis
launch_runs synth_1 -jobs 8
wait_on_run synth_1

# Check synthesis results
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed"
    exit 1
}

# Run implementation
launch_runs impl_1 -jobs 8
wait_on_run impl_1

# Check implementation results
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed"  
    exit 1
}

# Generate bitstream
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

puts "Build completed successfully!"
puts "Bitstream: ./$PROJECT_NAME/$PROJECT_NAME.runs/impl_1/zynq_reram_design_wrapper.bit"

exit
EOF

echo "Build completed!"
```

### **Software Build (CMake)**
```cmake
# CMakeLists.txt for ReRAM software
cmake_minimum_required(VERSION 3.10)
project(ReRAMSoftware)

set(CMAKE_C_STANDARD 99)

# Include directories
include_directories(include)

# ReRAM driver library
add_library(reram_driver
    src/reram_axi_driver.c
)

# Example applications
add_executable(reram_example
    src/reram_axi_example.c
)

target_link_libraries(reram_example reram_driver)

# Test applications
add_executable(reram_test
    tests/reram_unit_tests.c
)

target_link_libraries(reram_test reram_driver)

# Installation
install(TARGETS reram_driver reram_example reram_test
        DESTINATION bin)

install(FILES include/reram_axi_driver.h
        DESTINATION include)
```

### **Deployment Script**
```bash
#!/bin/bash
# deploy_reram.sh

BITSTREAM="reram_system.bit"
DEVICE_TREE="reram_devicetree.dtb"
KERNEL_MODULE="reram_driver.ko"
APP_BINARY="reram_example"

echo "Deploying ReRAM system..."

# Program FPGA
echo "Programming FPGA..."
fpga_program $BITSTREAM

# Load device tree overlay
echo "Loading device tree..."
dtc -O dtb -o $DEVICE_TREE reram_overlay.dts
mkdir -p /sys/kernel/config/device-tree/overlays/reram
cat $DEVICE_TREE > /sys/kernel/config/device-tree/overlays/reram/dtbo

# Load kernel module
echo "Loading kernel module..."
insmod $KERNEL_MODULE

# Test installation
echo "Testing ReRAM access..."
./$APP_BINARY

echo "Deployment completed successfully!"
```

## 🧪 Testing and Validation

### **Hardware-in-the-Loop Testing**
```python
# Python test script for ReRAM system validation
import time
import random
import subprocess

def run_test_pattern(pattern_name, test_data):
    """Run a specific test pattern"""
    print(f"Running {pattern_name} test...")
    
    # Write test data
    for addr, data in enumerate(test_data):
        cmd = f"./reram_example write {addr} 0x{data:08X}"
        result = subprocess.run(cmd.split(), capture_output=True, text=True)
        if result.returncode != 0:
            print(f"  FAIL: Write to address {addr}")
            return False
    
    # Read back and verify
    for addr, expected in enumerate(test_data):
        cmd = f"./reram_example read {addr}"
        result = subprocess.run(cmd.split(), capture_output=True, text=True)
        if result.returncode != 0:
            print(f"  FAIL: Read from address {addr}")
            return False
        
        actual = int(result.stdout.strip(), 16)
        if actual != expected:
            print(f"  FAIL: Data mismatch at {addr}: expected 0x{expected:08X}, got 0x{actual:08X}")
            return False
    
    print(f"  PASS: {pattern_name} test successful")
    return True

def comprehensive_test_suite():
    """Run comprehensive test suite"""
    test_patterns = {
        "All Zeros": [0x00000000] * 16,
        "All Ones": [0xFFFFFFFF] * 16,
        "Alternating": [0xAAAAAAAA if i % 2 == 0 else 0x55555555 for i in range(16)],
        "Walking Ones": [1 << i for i in range(16)],
        "Random": [random.randint(0, 0xFFFFFFFF) for _ in range(16)]
    }
    
    passed = 0
    total = len(test_patterns)
    
    for pattern_name, test_data in test_patterns.items():
        if run_test_pattern(pattern_name, test_data):
            passed += 1
    
    print(f"\\nTest Results: {passed}/{total} patterns passed")
    return passed == total

if __name__ == "__main__":
    print("ReRAM System Validation Suite")
    print("=" * 40)
    
    if comprehensive_test_suite():
        print("\\n✓ ALL TESTS PASSED - System is ready for deployment")
        exit(0)
    else:
        print("\\n✗ SOME TESTS FAILED - Please check system configuration")
        exit(1)
```

## 📚 Integration Checklist

### **Pre-Integration Checklist**
- [ ] Hardware platform requirements verified
- [ ] Clock and reset strategy defined
- [ ] Address map planned and documented
- [ ] Memory requirements calculated
- [ ] Power consumption analyzed
- [ ] Timing constraints identified

### **Hardware Integration Checklist**
- [ ] ReRAM controller modules added to project
- [ ] Clock domains properly connected
- [ ] Reset sequences implemented correctly
- [ ] AXI interface connected (if applicable)
- [ ] Address decoding verified
- [ ] Timing constraints applied
- [ ] Simulation completed successfully
- [ ] Synthesis passes without errors
- [ ] Implementation meets timing

### **Software Integration Checklist**
- [ ] Driver header files included
- [ ] Base addresses configured correctly
- [ ] Initialization sequence implemented
- [ ] Error handling implemented
- [ ] Memory access functions tested
- [ ] Health monitoring integrated
- [ ] Performance monitoring added
- [ ] Documentation updated

### **Validation Checklist**
- [ ] Basic read/write operations verified
- [ ] Address bounds checking confirmed
- [ ] Error conditions tested
- [ ] Performance benchmarks met
- [ ] Endurance monitoring validated
- [ ] Health reporting functional
- [ ] Power consumption measured
- [ ] Temperature testing completed

## 🆘 Troubleshooting Guide

### **Common Integration Issues**

| Issue | Symptoms | Solution |
|-------|----------|----------|
| **Clock domain crossing** | Data corruption, timing violations | Use proper clock domain crossing techniques |
| **Reset synchronization** | Erratic behavior on startup | Implement proper reset synchronizers |
| **Address map conflicts** | Access failures, wrong data | Review and fix address assignments |
| **AXI protocol violations** | Hangs, protocol errors | Verify AXI handshaking sequences |
| **Timing closure** | Synthesis/implementation failures | Adjust clock constraints, pipeline logic |
| **Resource usage** | Build failures | Optimize design or use larger device |

### **Debug Strategies**
1. **Start Simple**: Begin with basic functionality before adding complexity
2. **Use Simulation**: Validate design in simulation before hardware
3. **Incremental Integration**: Add one component at a time
4. **Monitor Key Signals**: Use ILA/ChipScope for hardware debug
5. **Check Power**: Ensure adequate power delivery
6. **Verify Clocks**: Confirm all clocks are stable and correct frequency

---

This completes the comprehensive ReRAM system documentation! The integration guide provides everything needed to successfully deploy the ReRAM memory system in various hardware and software environments. 🚀