# Memory Controller Layer Documentation

## 🎯 Overview

The Memory Controller Layer (`reram_memory_controller_blocking.sv`) is the core orchestration engine of the ReRAM system. It manages memory operations, coordinates with word arrays, tracks endurance, and provides comprehensive health monitoring.

```
┌─────────────────────────────────────────────────────────────────┐
│                    AXI4-Lite Interface Layer                    │
│                axi_reram_memory_controller.sv                   │
└─────────────────────────────────────────────────────────────────┘
                                    │
                          Simple Memory Interface
                                    │
┌─────────────────────────────────────────────────────────────────┐
│                    Memory Controller Layer                      │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │            reram_memory_controller_blocking.sv             │ │
│  │                                                         │ │
│  │  • Address Decoding & Validation                           │ │
│  │  • Operation State Machine Management                      │ │
│  │  • Word Array Coordination                                 │ │
│  │  • Endurance Monitoring & Health Tracking                  │ │
│  │  • Error Detection & Management                            │ │
│  │  • Performance Statistics Collection                       │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                    │
                          Word Array Interface
                                    │
┌─────────────────────────────────────────────────────────────────┐
│                      Word Array Layer                          │
│                reram_word_array_simple.sv                      │
└─────────────────────────────────────────────────────────────────┘
```

## 🏗️ Architecture

### **Core Responsibilities**
1. **Memory Operation Management** - Read/write operation orchestration
2. **Address Space Management** - Address validation and word selection
3. **Endurance Monitoring** - Per-word write cycle tracking
4. **Health Assessment** - Cell error aggregation and health categorization
5. **Error Handling** - Worn-out cell detection and graceful degradation
6. **Performance Monitoring** - Operation counting and statistics

### **Interface Boundaries**
- **Upward**: Simple blocking interface to AXI layer
- **Downward**: Word array command interface to storage layer

## 🔄 State Machine

```
                    ┌─────────────┐
                    │    IDLE     │◄──────────────┐
                    │             │               │
                    └─────┬───────┘               │
                          │                       │
                  read_i OR write_i               │
                          │                       │
                          ▼                       │
                    ┌─────────────┐               │
          ┌────────►│   READING   │               │
          │         │             │               │
          │         └─────┬───────┘               │
          │               │                       │
          │        word_operation_complete        │
          │               │                       │
    read_i│               ▼                       │done_o
          │         ┌─────────────┐               │
          │    ┌───►│   WRITING   │               │
          │    │    │             │               │
          │    │    └─────┬───────┘               │
          │    │          │                       │
          │    │   word_operation_complete        │
          │    │          │                       │
          │    │          ▼                       │
          │    │    ┌─────────────┐               │
          │    │    │ ERROR_STATE │───────────────┘
          │    │    │             │
          │    │    └─────────────┘
          │    │
          │    write_i
          │    │
          └────┘
```

### **State Descriptions**

| State | Description | Duration | Next State |
|-------|-------------|----------|------------|
| **IDLE** | Waiting for operation request | Until request | READING/WRITING |
| **READING** | Read operation in progress | 3 cycles (configurable) | IDLE |
| **WRITING** | Write operation in progress | 10 cycles (configurable) | IDLE |
| **ERROR_STATE** | Invalid command combination | 1 cycle | IDLE |

### **State Transition Logic**
```systemverilog
always_comb begin
    case (state)
        IDLE: begin
            if (read_i && !write_i) 
                next_state = READING;
            else if (write_i && !read_i) 
                next_state = WRITING;
            else if (read_i && write_i) 
                next_state = ERROR_STATE;  // Invalid
            else 
                next_state = IDLE;
        end
        
        READING, WRITING: begin
            if (current_word_complete)
                next_state = IDLE;
            else
                next_state = state;
        end
        
        ERROR_STATE: 
            next_state = IDLE;
    endcase
end
```

## 🎛️ Interface Definition

### **Module Parameters**
```systemverilog
module reram_memory_controller_blocking #(
    parameter int MEMORY_DEPTH = 16,                // Number of words
    parameter int DATA_WIDTH = 32,                  // Data width in bits
    parameter int ADDR_WIDTH = $clog2(MEMORY_DEPTH), // Auto-calculated
    parameter int READ_DELAY_CYCLES = 3,            // Read timing
    parameter int SET_DELAY_CYCLES = 10,            // Write SET timing
    parameter int RESET_DELAY_CYCLES = 10,          // Write RESET timing
    parameter int MAX_WRITE_CYCLES = 200            // Endurance limit
);
```

### **Interface Signals**

#### **Memory Interface (Upward to AXI)**
```systemverilog
// Clock and Reset
input  logic                    clk,            // System clock
input  logic                    rst_n,          // Active-low reset

// Simple Memory Interface
input  logic [ADDR_WIDTH-1:0]  addr_i,         // Word address
input  logic [DATA_WIDTH-1:0]  data_i,         // Write data
output logic [DATA_WIDTH-1:0]  data_o,         // Read data
input  logic                   read_i,         // Start read operation
input  logic                   write_i,        // Start write operation
output logic                   done_o,         // Operation complete
output logic                   error_o,        // Error occurred
output logic                   busy_o          // Controller busy
```

#### **Monitoring Interface**
```systemverilog
// Performance Statistics
output logic [31:0]            total_reads,    // Total reads performed
output logic [31:0]            total_writes,   // Total writes performed
output logic [MEMORY_DEPTH-1:0] word_errors,   // Per-word error flags

// Enhanced Endurance Monitoring
output logic [7:0]             word_write_cycles [MEMORY_DEPTH-1:0],
output logic [MEMORY_DEPTH-1:0] word_cell_errors_any,
output logic [DATA_WIDTH-1:0]  word_cell_errors [MEMORY_DEPTH-1:0]
```

#### **Word Array Interface (Downward)**
```systemverilog
// Word Array Control
logic [MEMORY_DEPTH-1:0]        word_enables;           // Word selection
logic [1:0]                     word_command_reg;       // Command to words
logic [DATA_WIDTH-1:0]          word_write_data;        // Data to words

// Word Array Status  
logic [DATA_WIDTH-1:0]          word_read_data [MEMORY_DEPTH-1:0];
logic [MEMORY_DEPTH-1:0]        word_operation_complete;
logic [MEMORY_DEPTH-1:0]        word_busy;
logic [MEMORY_DEPTH-1:0]        word_error;
```

## 📊 Address Management

### **Address Decoding**
```systemverilog
// Address validation
always_comb begin
    valid_address = (current_addr < MEMORY_DEPTH);
    
    // Word selection (one-hot encoding)
    for (int i = 0; i < MEMORY_DEPTH; i++) begin
        word_enables[i] = valid_address && (current_addr == i) && 
                         (state == READING || state == WRITING);
    end
end
```

### **Address Space**
| Address | Word | Byte Offset | Description |
|---------|------|-------------|-------------|
| 0x0 | 0 | 0x00-0x03 | First word |
| 0x1 | 1 | 0x04-0x07 | Second word |
| ... | ... | ... | ... |
| 0xF | 15 | 0x3C-0x3F | Last word (for 16-word config) |

### **Address Validation**
- **Range Check**: `addr_i < MEMORY_DEPTH`
- **Error Response**: `error_o = 1` for invalid addresses
- **Data Output**: `data_o = 0` for invalid reads

## 🔧 Operation Management

### **Command Encoding**
```systemverilog
localparam [1:0] CMD_NOP   = 2'b00;  // No operation
localparam [1:0] CMD_READ  = 2'b01;  // Read command
localparam [1:0] CMD_WRITE = 2'b10;  // Write command
```

### **Read Operation Flow**
```
1. addr_i valid, read_i asserted
2. State → READING
3. Address decoded, word selected
4. CMD_READ sent to target word
5. Wait for word_operation_complete
6. Data captured from word_read_data
7. done_o asserted, data_o valid
8. State → IDLE
```

### **Write Operation Flow**
```
1. addr_i valid, data_i valid, write_i asserted  
2. State → WRITING
3. Address decoded, word selected
4. CMD_WRITE sent to target word
5. data_i copied to word_write_data
6. Wait for word_operation_complete
7. done_o asserted
8. Write cycle counters updated
9. State → IDLE
```

### **Timing Diagrams**

#### **Read Operation**
```
Clock    : __|‾|__|‾|__|‾|__|‾|__|‾|__
read_i   : ______|‾‾‾‾‾|_____________
addr_i   : ------< ADDR >-----------
busy_o   : ________|‾‾‾‾‾‾‾|________
done_o   : ________________|‾|______
data_o   : ----------------< DATA >-
```

#### **Write Operation**  
```
Clock    : __|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__|‾|__
write_i  : ______|‾‾‾‾‾|_________________________________________
addr_i   : ------< ADDR >---------------------------------------
data_i   : ------< DATA >---------------------------------------
busy_o   : ________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|________
done_o   : ____________________________________________|‾|______
```

## 📈 Endurance Monitoring

### **Write Cycle Tracking**
```systemverilog
// Per-word write cycle extraction
for (int i = 0; i < MEMORY_DEPTH; i++) begin
    word_write_cycles[i] = word_total_write_cycles[i][7:0];  // 8-bit counter
end
```

### **Health Assessment**
```systemverilog
// Cell error aggregation  
for (int w = 0; w < MEMORY_DEPTH; w++) begin
    word_cell_errors_any[w] = (word_cell_error_flags[w] != '0);
end
```

### **Health Categories**
| Category | Write Cycles | Description |
|----------|-------------|-------------|
| **Healthy** | 0-99 (0-49%) | Normal operation, no concerns |
| **Warning** | 100-159 (50-79%) | Monitor closely, plan replacement |
| **Critical** | 160-199 (80-99%) | Immediate attention required |
| **Worn-out** | 200+ (100%+) | Exceeded limit, marked as failed |

### **Endurance Data Flow**
```
Word Array → Memory Controller → AXI Interface → Software
    ↓              ↓                  ↓            ↓
Raw Counters → Aggregation → Reg Interface → Health Reports
```

## 🚨 Error Handling

### **Error Detection Sources**
1. **Address Errors**: Invalid addresses (>= MEMORY_DEPTH)
2. **Word Array Errors**: Individual word failures
3. **Command Errors**: Invalid command combinations
4. **Endurance Errors**: Cells exceeding write cycle limits

### **Error Response Strategy**
```systemverilog
always_comb begin
    // Error aggregation
    if (!valid_address) begin
        error_o = 1'b1;           // Address error
        data_o = '0;
    end else if (|word_error) begin
        error_o = 1'b1;           // Word array error
        data_o = current_word_data;  // May be partial data
    end else begin
        error_o = 1'b0;           // No error
        data_o = current_word_data;
    end
end
```

### **Error Recovery**
- **Worn-out Cells**: Marked in `word_errors` bitmap
- **Temporary Errors**: Retry automatically handled by word arrays
- **Permanent Errors**: Flagged for software handling
- **Address Errors**: Immediate response, no retry

## 📊 Performance Monitoring

### **Operation Counters**
```systemverilog
// Counter updates
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        read_counter <= '0;
        write_counter <= '0;
    end else begin
        if (done_o && !error_o) begin
            if (state == READING) 
                read_counter <= read_counter + 1;
            else if (state == WRITING) 
                write_counter <= write_counter + 1;
        end
    end
end
```

### **Statistics Outputs**
- **total_reads**: Successful read operations
- **total_writes**: Successful write operations  
- **word_errors**: Bitmap of failed words
- **word_write_cycles**: Per-word endurance usage

### **Performance Metrics**
| Metric | Typical Value | Description |
|--------|---------------|-------------|
| **Read Latency** | 3 cycles | Time from read_i to done_o |
| **Write Latency** | 10 cycles | Time from write_i to done_o |
| **Throughput** | 33M reads/sec | At 100MHz clock |
| **Error Rate** | <1E-9 | Before endurance limits |

## 🧪 Testing Strategy

### **Test Phases in Testbench**
1. **Basic Operations** - Simple read/write verification
2. **Address Testing** - Boundary and invalid address testing
3. **Error Injection** - Simulate word array failures
4. **Multi-Address Testing** - Parallel word access validation
5. **Statistics Monitoring** - Counter verification
6. **Endurance Testing** - Write cycle tracking
7. **Stress Testing** - High-frequency operation testing

### **Key Test Scenarios**
```systemverilog
// Example test: Address boundary checking
task test_address_bounds();
    // Valid address
    write_memory(4'h0, 32'hDEADBEEF);
    read_memory(4'h0, read_data);
    assert(read_data == 32'hDEADBEEF);
    
    // Invalid address  
    write_memory(4'hF + 1, 32'h12345678);  // Out of bounds
    assert(error_o == 1'b1);
endtask
```

## 🔧 Configuration Guidelines

### **Memory Sizing**
```systemverilog
// Small systems (IoT, sensors)
parameter MEMORY_DEPTH = 16;     // 64 bytes

// Medium systems (embedded controllers)  
parameter MEMORY_DEPTH = 64;     // 256 bytes

// Large systems (data logging)
parameter MEMORY_DEPTH = 256;    // 1 KB
```

### **Timing Optimization**
```systemverilog
// Fast operation (may reduce reliability)
parameter READ_DELAY_CYCLES = 1;
parameter SET_DELAY_CYCLES = 5;
parameter RESET_DELAY_CYCLES = 5;

// Balanced operation (recommended)
parameter READ_DELAY_CYCLES = 3;
parameter SET_DELAY_CYCLES = 10;  
parameter RESET_DELAY_CYCLES = 10;

// Conservative operation (maximum reliability)
parameter READ_DELAY_CYCLES = 5;
parameter SET_DELAY_CYCLES = 20;
parameter RESET_DELAY_CYCLES = 20;
```

### **Endurance Configuration**
```systemverilog
// Development/simulation
parameter MAX_WRITE_CYCLES = 100;

// Production systems
parameter MAX_WRITE_CYCLES = 500;

// Long-term deployment
parameter MAX_WRITE_CYCLES = 1000;
```

## 🛠️ Integration Patterns

### **Direct Integration (No AXI)**
```systemverilog
reram_memory_controller_blocking #(
    .MEMORY_DEPTH(32),
    .DATA_WIDTH(32)
) memory_ctrl (
    .clk(clk),
    .rst_n(rst_n),
    
    // Direct CPU interface
    .addr_i(cpu_addr[6:2]),       // Word address from CPU
    .data_i(cpu_wdata),           // CPU write data
    .data_o(cpu_rdata),           // CPU read data
    .read_i(cpu_read & cpu_select), // CPU read enable
    .write_i(cpu_write & cpu_select), // CPU write enable
    .done_o(memory_ready),        // Memory operation complete
    .error_o(memory_error),       // Memory error flag
    .busy_o(memory_busy)          // Memory busy flag
);
```

### **With AXI Integration**
```systemverilog
// Already integrated in axi_reram_memory_controller.sv
// See README_AXI_Layer.md for details
```

## 🔍 Debug Features

### **Internal State Visibility**
- **Current State**: Available through state machine
- **Address Decode**: valid_address flag
- **Word Selection**: word_enables bitmap
- **Operation Progress**: word_operation_complete flags

### **Debug Recommendations**
1. **Monitor busy_o**: Indicates controller activity
2. **Track error_o**: Immediate error detection
3. **Watch word_errors**: Persistent error tracking
4. **Check counters**: Operation statistics validation

### **Common Debug Scenarios**
| Symptom | Likely Cause | Investigation |
|---------|--------------|---------------|
| **done_o never asserts** | Word array hung | Check word_operation_complete |
| **error_o always high** | Address out of bounds | Verify addr_i < MEMORY_DEPTH |
| **Wrong read data** | Write operation failed | Check write cycle limits |
| **Performance degradation** | Multiple words worn out | Check word_errors bitmap |

---

**Next**: See `README_Word_Array.md` for the word storage architecture details.