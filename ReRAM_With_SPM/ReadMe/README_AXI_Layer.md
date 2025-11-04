# AXI4-Lite Interface Layer Documentation

## 🚀 Overview

The AXI4-Lite interface layer (`axi_reram_memory_controller.sv`) provides a standard ARM AMBA interface for the ReRAM memory system. This layer handles all AXI protocol details, allowing seamless integration with ARM processors and AXI interconnects.

```
┌─────────────────────────────────────────────────────────────────┐
│                    AXI4-Lite Interface Layer                    │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                                                         │ │
│  │    ARM Processor  ←→  AXI Interconnect  ←→  ReRAM AXI     │ │
│  │                                                Controller   │ │
│  │                                                         │ │
│  │  • Protocol Compliance     • Memory-Mapped Registers      │ │
│  │  • Address Decoding        • Error Response Translation   │ │
│  │  • Alignment Checking      • Status/Control Interface     │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                    │
                          Simple Memory Interface
                                    │
┌─────────────────────────────────────────────────────────────────┐
│                    Memory Controller Layer                      │
│                reram_memory_controller_blocking.sv              │
└─────────────────────────────────────────────────────────────────┘
```

## 🏗️ Architecture

### **Key Responsibilities**
1. **AXI Protocol Management** - Handles all AXI4-Lite handshaking
2. **Address Space Management** - Decodes memory vs control regions  
3. **Error Response Translation** - Maps internal errors to AXI responses
4. **Register Interface** - Provides memory-mapped control/status access
5. **Data Path Management** - Coordinates read/write data flow

### **Interface Boundaries**
- **Upward**: Standard AXI4-Lite slave interface to ARM processors
- **Downward**: Simple memory interface to ReRAM controller

## 🗺️ Memory Map

```
┌─────────────────────────────────────────────────────────────┐
│                      Memory Address Space                   │
├─────────────────────────────────────────────────────────────┤
│ 0x0000_0000 │                                              │
│      ↓      │           ReRAM Memory Region                │
│ 0x0000_003F │      (16 words × 4 bytes = 64 bytes)        │
├─────────────────────────────────────────────────────────────┤
│ 0x0004_0000 │                                              │
│      ↓      │         Control/Status Registers             │
│ 0x0004_00FF │            (256 bytes)                       │
└─────────────────────────────────────────────────────────────┘
```

### **Memory Region (0x0000_0000 - 0x0000_003F)**
- **Access Type**: Read/Write
- **Word Size**: 32-bit aligned access only
- **Behavior**: Direct access to ReRAM memory array
- **Error Responses**: 
  - `DECERR` for out-of-bounds addresses
  - `SLVERR` for alignment errors or ReRAM controller errors

### **Control Region (0x0004_0000 - 0x0004_00FF)**
- **Access Type**: Mixed (see register descriptions)
- **Word Size**: 32-bit aligned access only
- **Behavior**: Memory-mapped register interface

## 📋 Register Map

### **Basic Control/Status Registers (0x00-0x1F)**

| Offset | Name | Access | Description |
|--------|------|---------|-------------|
| 0x0000 | Status Register | RO | System status and busy flags |
| 0x0004 | Control Register | RW | System control and error clearing |
| 0x0008 | Error Count Register | RO | Operation and endurance error counts |
| 0x000C | Total Operations | RO | Read and write operation counters |
| 0x0010 | Last Error Address | RO | Address of most recent error |
| 0x0014 | Last Error Code | RO | Detailed error information |
| 0x0018 | Worn Cells Low | RO | Worn-out cell bitmap (words 0-31) |
| 0x001C | Worn Cells High | RO | Worn-out cell bitmap (words 32-63) |

### **Configuration Registers (0x20-0x3F)**

| Offset | Name | Access | Description |
|--------|------|---------|-------------|
| 0x0020 | ReRAM Configuration | RO | Timing parameters (read-only) |
| 0x0024 | Endurance Limits | RW | Warning thresholds and limits |

### **Monitoring Registers (0x40-0x7F)**

| Offset | Name | Access | Description |
|--------|------|---------|-------------|
| 0x0040 | Word Cycles 0-3 | RO | Write cycles for words 0-3 (packed) |
| 0x0044 | Word Cycles 4-7 | RO | Write cycles for words 4-7 (packed) |
| 0x0048 | Word Cycles 8-11 | RO | Write cycles for words 8-11 (packed) |
| 0x004C | Word Cycles 12-15 | RO | Write cycles for words 12-15 (packed) |

### **Detailed Monitoring (0x80-0xBF)**

| Offset | Name | Access | Description |
|--------|------|---------|-------------|
| 0x0080 | Word 0 Cell Errors | RO | Detailed cell error flags for word 0 |
| 0x0084 | Word 1 Cell Errors | RO | Detailed cell error flags for word 1 |
| ... | ... | ... | ... |
| 0x00BC | Word 15 Cell Errors | RO | Detailed cell error flags for word 15 |

### **Health Summary (0xC0-0xFF)**

| Offset | Name | Access | Description |
|--------|------|---------|-------------|
| 0x00C0 | Health Summary | RO | Health category counts |

## 🔍 Register Details

### **Status Register (0x0000) - Read Only**
```
31        16|15     8|7   4|3|2|1|0
┌───────────┼────────┼─────┼─┼─┼─┼─┐
│  Address  │Progress│ Rsvd│M│E│G│B│
│ (Active)  │        │     │O│E│E│U│
│           │        │     │P│R│R│S│
│           │        │     │ │R│R│Y│
└───────────┴────────┴─────┴─┴─┴─┴─┘
```

- **[0] BUSY**: Memory controller busy flag
- **[1] GERR**: Global error flag (any error occurred)
- **[2] EERR**: Endurance error flag (worn-out cells detected)
- **[3] MOPERR**: Memory operation error flag
- **[7:4] Reserved**: Must read as 0
- **[15:8] Progress**: Operation progress (0xFF when busy)
- **[31:16] Address**: Currently active word address during operation

### **Control Register (0x0004) - Read/Write**
```
31           4|3|2|1|0
┌─────────────┼─┼─┼─┼─┐
│  Reserved   │A│E│D│E│
│             │R│M│B│C│
│             │E│O│G│L│
│             │F│N│ │R│
└─────────────┴─┴─┴─┴─┘
```

- **[0] ECLR**: Error clear (write 1 to clear all error flags)
- **[1] DBG**: Debug mode enable  
- **[2] EMON**: Endurance monitoring enable
- **[3] AREF**: Auto-refresh enable
- **[31:4] Reserved**: Must write as 0

### **Error Count Register (0x0008) - Read Only**
```
31           16|15           0
┌──────────────┼──────────────┐
│   Endurance  │  Operation   │
│    Errors    │    Errors    │
└──────────────┴──────────────┘
```

- **[15:0]**: Total operation errors (busy/worn-out/failed operations)
- **[31:16]**: Total endurance errors (cells exceeding write limits)

### **Health Summary Register (0x00C0) - Read Only**
```
31        24|23       16|15        8|7         0
┌───────────┼───────────┼───────────┼──────────┐
│  Worn-out │ Critical  │  Warning  │ Healthy  │
│   Count   │   Count   │   Count   │  Count   │
└───────────┴───────────┴───────────┴──────────┘
```

- **[7:0] Healthy**: Words with <50% of max write cycles
- **[15:8] Warning**: Words with 50-80% of max write cycles  
- **[23:16] Critical**: Words with 80-100% of max write cycles
- **[31:24] Worn-out**: Words exceeding max write cycles

## 🔄 AXI State Machines

### **Write State Machine**
```
     IDLE ──────┐
       │        │
       ▼        │
   ┌─ADDR    DATA─┐
   │   │      │   │
   ▼   ▼      ▼   ▼
   │   └─ MEM ─┘   │
   │       │       │
   └─── RESP ──────┘
        │
        ▼
      IDLE
```

**States:**
- **IDLE**: Waiting for transaction
- **ADDR**: Address phase captured
- **DATA**: Data phase captured  
- **MEM**: Memory operation in progress
- **RESP**: Response phase

### **Read State Machine**
```
     IDLE
       │
       ▼
     ADDR
       │
       ▼
   ┌─ MEM ─┐
   │       │
   ▼       ▼
   └─ DATA ┘
       │
       ▼
     IDLE
```

**States:**
- **IDLE**: Waiting for transaction
- **ADDR**: Address captured, decode in progress
- **MEM**: Memory operation in progress (for memory region)
- **DATA**: Data/response phase

## 🚨 Error Handling

### **AXI Response Codes**

| Response | Code | Description | When Generated |
|----------|------|-------------|----------------|
| **OKAY** | 0x00 | Success | Normal operation completion |
| **SLVERR** | 0x10 | Slave error | Alignment error, memory controller busy/worn-out |
| **DECERR** | 0x11 | Decode error | Address out of bounds |

### **Error Response Matrix**

| Condition | Memory Access | Control Access |
|-----------|--------------|----------------|
| **Valid address, aligned** | OKAY/SLVERR* | OKAY |
| **Valid address, misaligned** | SLVERR | SLVERR |
| **Out of bounds** | DECERR | DECERR |
| **Memory controller error** | SLVERR | N/A |

*SLVERR if memory controller reports busy/worn-out/operation failure

### **Error Data Patterns**

| Error Type | Read Data Pattern |
|------------|------------------|
| **DECERR (out of bounds)** | 0xDEADBEEF |
| **DECERR (invalid ctrl reg)** | 0xBAD0BAAD |
| **SLVERR (alignment)** | 0xBAD00BAD |
| **SLVERR (mem controller)** | 0xDEAD0000 |

## ⚙️ Configuration Parameters

```systemverilog
module axi_reram_memory_controller #(
    parameter int AXI_ADDR_WIDTH = 32,           // AXI address bus width
    parameter int AXI_DATA_WIDTH = 32,           // AXI data bus width  
    parameter int MEMORY_DEPTH = 16,             // ReRAM words (16 = 64B)
    parameter int MEMORY_BASE_ADDR = 32'h0000_0000,  // Memory base
    parameter int CTRL_BASE_ADDR = 32'h0004_0000,    // Control base
    parameter int READ_DELAY_CYCLES = 3,         // Read timing
    parameter int SET_DELAY_CYCLES = 10,         // Write SET timing
    parameter int RESET_DELAY_CYCLES = 10,       // Write RESET timing
    parameter int MAX_WRITE_CYCLES = 200         // Endurance limit
);
```

### **Parameter Guidelines**

| Parameter | Recommended Range | Notes |
|-----------|------------------|-------|
| `MEMORY_DEPTH` | 16-256 | Larger sizes require more FPGA resources |
| `MEMORY_BASE_ADDR` | Any 4KB aligned | Should not overlap with other memories |
| `CTRL_BASE_ADDR` | Any 4KB aligned | Should be different from memory base |
| `MAX_WRITE_CYCLES` | 100-1000 | Higher values = longer simulation time |

## 🔌 Interface Signals

### **AXI4-Lite Slave Interface**

```systemverilog
// Clock and Reset
input  logic                        aclk,        // AXI clock
input  logic                        aresetn,     // AXI reset (active low)

// Write Address Channel
input  logic [AXI_ADDR_WIDTH-1:0]  s_axi_awaddr,   // Write address
input  logic                        s_axi_awvalid,  // Write address valid
output logic                        s_axi_awready,  // Write address ready
input  logic [2:0]                  s_axi_awprot,   // Protection (ignored)

// Write Data Channel
input  logic [AXI_DATA_WIDTH-1:0]  s_axi_wdata,    // Write data
input  logic [3:0]                  s_axi_wstrb,    // Write strobes
input  logic                        s_axi_wvalid,   // Write data valid
output logic                        s_axi_wready,   // Write data ready

// Write Response Channel  
output logic [1:0]                  s_axi_bresp,    // Write response
output logic                        s_axi_bvalid,   // Write response valid
input  logic                        s_axi_bready,   // Write response ready

// Read Address Channel
input  logic [AXI_ADDR_WIDTH-1:0]  s_axi_araddr,   // Read address
input  logic                        s_axi_arvalid,  // Read address valid
output logic                        s_axi_arready,  // Read address ready
input  logic [2:0]                  s_axi_arprot,   // Protection (ignored)

// Read Data Channel
output logic [AXI_DATA_WIDTH-1:0]  s_axi_rdata,    // Read data
output logic [1:0]                  s_axi_rresp,    // Read response
output logic                        s_axi_rvalid,   // Read data valid
input  logic                        s_axi_rready    // Read data ready
```

### **Memory Controller Interface**

```systemverilog
// Memory controller connections (internal)
logic [MEMORY_ADDR_WIDTH-1:0] mem_addr;        // Word address
logic [AXI_DATA_WIDTH-1:0]    mem_data_in;     // Write data
logic [AXI_DATA_WIDTH-1:0]    mem_data_out;    // Read data  
logic                         mem_read;        // Read request
logic                         mem_write;       // Write request
logic                         mem_done;        // Operation complete
logic                         mem_error;       // Error occurred
logic                         mem_busy;        // Controller busy
```

## 🧪 Testing

### **Testbench Overview**
The AXI testbench (`tb_axi_reram_memory_controller.sv`) provides comprehensive testing:

```systemverilog
// 8-phase comprehensive test
Phase 1: Basic Memory Read/Write Operations  
Phase 2: Control Register Access
Phase 3: Address Validation  
Phase 4: Sequential Memory Test
Phase 5: Endurance Monitoring
Phase 6: Error Handling
Phase 7: Health Monitoring
Phase 8: Final Status Check
```

### **Key Test Features**
- **AXI Protocol Compliance** - Proper handshaking verification
- **Address Boundary Testing** - Out-of-bounds detection
- **Error Response Validation** - OKAY/SLVERR/DECERR verification  
- **Register Access Testing** - All control/status registers
- **Endurance Monitoring** - Write cycle tracking validation

### **Running Tests**
```bash
# Compile and run AXI testbench
iverilog -g2012 -o axi_test tb_axi_reram_memory_controller.sv \
         axi_reram_memory_controller.sv \
         reram_memory_controller_blocking.sv \
         reram_word_array_simple.sv \
         reram_cell_enhanced.sv
         
./axi_test
```

## 🔧 Integration Example

### **ARM SoC Integration**
```systemverilog
// In your ARM SoC design
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
    .aclk(axi_aclk),
    .aresetn(axi_aresetn),
    
    // Connect to AXI interconnect
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    // ... all other AXI signals
);
```

## 📊 Performance Characteristics

### **Latency (at 100MHz)**
- **Register Read**: 1 AXI cycle (10ns)
- **Register Write**: 1 AXI cycle (10ns)  
- **Memory Read**: 4 AXI cycles (40ns) - includes ReRAM timing
- **Memory Write**: 11 AXI cycles (110ns) - includes ReRAM timing

### **Throughput**
- **Sequential Reads**: 25 Million operations/sec
- **Sequential Writes**: 9 Million operations/sec
- **Mixed Operations**: 15 Million operations/sec

### **Resource Usage (Zynq-7020)**
- **LUTs**: ~300 (for 16-word configuration)
- **Flip-Flops**: ~500 (for 16-word configuration)
- **BRAMs**: 0 (uses distributed memory)

## 🛠️ Design Guidelines

### **Address Space Planning**
- **Memory Base**: Align to memory size boundary (e.g., 4KB for <4KB memory)
- **Control Base**: Should be in different 4KB page from memory
- **Separation**: Keep at least 4KB between memory and control regions

### **Timing Considerations**
- **AXI Clock**: 50-200MHz recommended
- **Reset**: Hold aresetn low for at least 10 clock cycles
- **Back-pressure**: AXI interface handles back-pressure from memory controller

### **Error Handling Best Practices**
- **Check Response**: Always check AXI response codes in software
- **Error Recovery**: Use control register to clear error flags
- **Monitoring**: Poll health summary register periodically

## 🔍 Debug Features

### **Status Visibility**
- **Real-time busy status** via status register
- **Operation progress** during long operations
- **Error logging** with timestamps and addresses

### **Debug Registers**
- **Control[1]**: Debug mode for enhanced logging
- **Last Error Address**: Shows address of most recent error
- **Last Error Code**: Detailed error information with timestamp

---

**Next**: See `README_Memory_Controller.md` for the underlying memory controller architecture.