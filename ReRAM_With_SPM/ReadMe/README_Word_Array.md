# Word Array Layer Documentation

## 🎯 Overview

The Word Array Layer (`reram_word_array_simple.sv`) manages a single word of ReRAM memory by coordinating multiple ReRAM cells in parallel. It provides word-level operations while handling cell-level timing, error aggregation, and endurance monitoring.

```
┌─────────────────────────────────────────────────────────────────┐
│                    Memory Controller Layer                      │
│                reram_memory_controller_blocking.sv              │
└─────────────────────────────────────────────────────────────────┘
                                    │
                          Word Array Interface
                                    │
┌─────────────────────────────────────────────────────────────────┐
│                      Word Array Layer                          │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │               reram_word_array_simple.sv               │ │
│  │                                                         │ │
│  │  • Parallel Cell Coordination (32 cells per word)          │ │
│  │  • Word-Level Operation State Machine                      │ │
│  │  • Cell Error Aggregation & Reporting                     │ │
│  │  • Write Cycle Tracking & Maximum Detection               │ │
│  │  • Synchronized Cell Command Distribution                  │ │
│  │  • Data Path Management (32-bit parallel)                 │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                    │
                          Cell Array Interface
                                    │
┌─────────────────────────────────────────────────────────────────┐
│                        Cell Array Layer                        │
│               32× reram_cell_enhanced.sv                       │
└─────────────────────────────────────────────────────────────────┘
```

## 🏗️ Architecture

### **Core Responsibilities**
1. **Parallel Cell Management** - Coordinate 32 ReRAM cells simultaneously
2. **Word-Level Operations** - Execute read/write operations on entire words
3. **Error Aggregation** - Collect and summarize cell-level errors
4. **Timing Synchronization** - Ensure all cells complete operations together
5. **Endurance Tracking** - Monitor maximum write cycles across all cells
6. **Data Path Control** - Manage 32-bit parallel data flow

### **Design Philosophy**
- **Simplified Interface** - Clean word-level memory operations only
- **Parallel Architecture** - All cells operate simultaneously
- **Error Transparency** - Cell errors are aggregated and reported upward
- **Timing Accuracy** - Realistic ReRAM operation delays preserved

## 🔄 State Machine

```
                    ┌─────────────┐
                    │ WORD_IDLE   │◄──────────────┐
                    │             │               │
                    └─────┬───────┘               │
                          │                       │
                  CMD_READ OR CMD_WRITE           │
                          │                       │
                          ▼                       │
                    ┌─────────────┐               │
          ┌────────►│WORD_READING │               │
          │         │             │               │
          │         └─────┬───────┘               │
          │               │                       │
          │        all_read_complete              │
          │               │                       │
    CMD_READ              ▼                       │operation_complete
          │         ┌─────────────┐               │
          │    ┌───►│WORD_WRITING │               │
          │    │    │             │               │
          │    │    └─────┬───────┘               │
          │    │          │                       │
          │    │   all_write_complete             │
          │    │          │                       │
          │    │          └───────────────────────┘
          │    │
          │    CMD_WRITE
          │    │
          └────┘
```

### **State Descriptions**

| State | Description | Active Signals | Duration |
|-------|-------------|----------------|----------|
| **WORD_IDLE** | Waiting for command | `operation_complete = 0` | Until command |
| **WORD_READING** | Read operation active | `word_busy = 1` | 3 cycles (configurable) |
| **WORD_WRITING** | Write operation active | `word_busy = 1` | 10 cycles (configurable) |

## 🎛️ Interface Definition

### **Module Parameters**
```systemverilog
module reram_word_array_simple #(
    parameter int WORD_WIDTH = 32,           // Bits per word (32-bit system)
    parameter int READ_DELAY_CYCLES = 3,     // Read operation timing
    parameter int SET_DELAY_CYCLES = 10,     // Write SET operation timing
    parameter int RESET_DELAY_CYCLES = 10,   // Write RESET operation timing
    parameter int MAX_WRITE_CYCLES = 200     // Endurance limit per cell
);
```

### **Command Interface**
```systemverilog
// Clock and Reset
input  logic        clk,                    // System clock
input  logic        rst_n,                  // Active-low reset

// Command Interface
input  logic [1:0]              command,    // Command from memory controller
input  logic                    word_enable, // Word selection enable
input  logic [WORD_WIDTH-1:0]  write_data, // Write data input
output logic [WORD_WIDTH-1:0]  read_data,  // Read data output
output logic                    operation_complete // Operation done flag
```

### **Status Interface**
```systemverilog
// Status and Monitoring
output logic                    word_busy,      // Word operation in progress
output logic [WORD_WIDTH-1:0]  cell_error_flags, // Per-cell error status
output logic                    word_error,     // Any cell has error
output logic [7:0]              total_write_cycles // Maximum write cycles
```

## 🎮 Command Protocol

### **Command Encoding**
```systemverilog
localparam [1:0] CMD_NOP   = 2'b00;  // No operation
localparam [1:0] CMD_READ  = 2'b01;  // Read word from cells
localparam [1:0] CMD_WRITE = 2'b10;  // Write word to cells
```

### **Command Processing**
```systemverilog
always_comb begin
    // Command routing to cells
    if (word_enable && (command != CMD_NOP)) begin
        cell_command = command;
        cell_enables = {WORD_WIDTH{1'b1}};  // Enable all cells
    end else begin
        cell_command = CMD_NOP;
        cell_enables = '0;
    end
    
    // Data routing
    cell_data_in = write_data;  // Parallel write data to all cells
end
```

## 🔧 Cell Coordination

### **Cell Array Instantiation**
```systemverilog
genvar i;
generate
    for (i = 0; i < WORD_WIDTH; i++) begin : cell_instances
        reram_cell_enhanced #(
            .READ_DELAY_CYCLES(READ_DELAY_CYCLES),
            .SET_DELAY_CYCLES(SET_DELAY_CYCLES),
            .RESET_DELAY_CYCLES(RESET_DELAY_CYCLES),
            .MAX_WRITE_CYCLES(MAX_WRITE_CYCLES)
        ) cell_inst (
            .clk(clk),
            .rst_n(rst_n),
            
            // Command interface
            .command(cell_command_reg),
            .cell_enable(cell_enables_reg[i]),
            .data_in(cell_data_in[i]),
            
            // Status outputs
            .read_success(cell_read_success[i]),
            .write_success(cell_write_success[i]),
            .data_out(cell_data_out[i]),
            .error_flag(cell_error_flag[i]),
            .current_state(cell_states[i]),
            .write_cycles(cell_write_cycles[i]),
            .error_code(cell_error_codes[i])
        );
    end
endgenerate
```

### **Parallel Operation Logic**
```systemverilog
// Status aggregation
always_comb begin
    // Busy if any cell is busy
    any_cell_busy = |cell_states;  // Any cell not in IDLE state
    
    // Read complete when all cells complete read
    all_read_complete = &cell_read_success;
    
    // Write complete when all cells complete write  
    all_write_complete = &cell_write_success;
    
    // Error aggregation
    word_error = |cell_error_flag;
    cell_error_flags = cell_error_flag;
end
```

## 📊 Data Path Management

### **Read Data Path**
```
Cell[31] ─────┐
Cell[30] ─────┤
     ...      ├──► read_data[31:0]
Cell[1]  ─────┤
Cell[0]  ─────┘
```

```systemverilog
// Read data aggregation
always_comb begin
    for (int i = 0; i < WORD_WIDTH; i++) begin
        read_data[i] = cell_data_out[i];
    end
end
```

### **Write Data Path**
```
write_data[31:0] ──┬──► Cell[31]
                   ├──► Cell[30]
                   │     ...
                   ├──► Cell[1]
                   └──► Cell[0]
```

```systemverilog
// Write data distribution
always_comb begin
    for (int i = 0; i < WORD_WIDTH; i++) begin
        cell_data_in[i] = write_data[i];
    end
end
```

## 📈 Endurance Monitoring

### **Write Cycle Tracking**
```systemverilog
// Find maximum write cycles across all cells
always_comb begin
    logic [7:0] max_cycles;
    max_cycles = '0;
    
    for (int i = 0; i < WORD_WIDTH; i++) begin
        if (cell_write_cycles[i] > max_cycles) begin
            max_cycles = cell_write_cycles[i];
        end
    end
    
    total_write_cycles = max_cycles;
end
```

### **Error Flag Aggregation**
```systemverilog
// Aggregate cell error flags
always_comb begin
    cell_error_flags = cell_error_flag;  // Direct mapping
    word_error = |cell_error_flag;       // OR reduction
end
```

### **Health Assessment**
The word array reports the **worst-case** health across all cells:
- **Healthy Word**: All cells < 50% of max cycles
- **Warning Word**: Any cell 50-80% of max cycles
- **Critical Word**: Any cell 80-100% of max cycles
- **Worn-out Word**: Any cell > max cycles

## ⏱️ Timing Control

### **Operation Timing**

#### **Read Operation Timing**
```
Clock     : __|‾|__|‾|__|‾|__|‾|__
command   : __| READ  |_________
word_enable: ____|‾‾‾‾‾|_________
word_busy : ______|‾‾‾‾‾‾‾|_____
operation_complete: ________|‾|_
read_data : ----------------<=>-
```

#### **Write Operation Timing**
```
Clock     : __|‾|__|‾|__|‾|..|‾|__|‾|__
command   : __| WRITE |_________________
word_enable: ____|‾‾‾‾‾|_________________
write_data: ----<=====DATA=====>--------
word_busy : ______|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|___
operation_complete: ________________|‾|_
```

### **Synchronization Logic**
```systemverilog
// State machine timing
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_word_state <= WORD_IDLE;
        cell_command_reg <= CMD_NOP;
        cell_enables_reg <= '0;
    end else begin
        current_word_state <= next_word_state;
        
        // Register command and enables for proper timing
        cell_command_reg <= cell_command;
        cell_enables_reg <= cell_enables;
    end
end
```

## 🚨 Error Management

### **Error Detection Hierarchy**
1. **Cell-Level Errors**: Individual cell failures (wear-out, operation failure)
2. **Word-Level Aggregation**: Any cell error causes word error
3. **Error Propagation**: Word errors reported to memory controller

### **Error Types**
| Error Source | Detection | Response |
|-------------|-----------|----------|
| **Cell Wear-out** | `cell_write_cycles > MAX_WRITE_CYCLES` | Mark cell as failed |
| **Operation Timeout** | Cell state machine timeout | Mark cell as failed |
| **Data Corruption** | Cell verification failure | Mark cell as failed |
| **Command Error** | Invalid command sequence | Report to controller |

### **Error Recovery**
```systemverilog
// Error handling in state machine
always_comb begin
    case (current_word_state)
        WORD_READING: begin
            if (all_read_complete || word_error) begin
                next_word_state = WORD_IDLE;
                operation_complete = 1'b1;
            end else begin
                next_word_state = WORD_READING;
                operation_complete = 1'b0;
            end
        end
        
        WORD_WRITING: begin
            if (all_write_complete || word_error) begin
                next_word_state = WORD_IDLE;
                operation_complete = 1'b1;
            end else begin
                next_word_state = WORD_WRITING;
                operation_complete = 1'b0;
            end
        end
    endcase
end
```

## 📊 Performance Characteristics

### **Latency (32-bit word)**
| Operation | Cycles | Time @ 100MHz | Description |
|-----------|--------|---------------|-------------|
| **Read** | 3 | 30ns | All cells read in parallel |
| **Write** | 10 | 100ns | All cells write in parallel |
| **Command Setup** | 1 | 10ns | Command registration delay |

### **Throughput**
| Metric | Value | Notes |
|--------|-------|-------|
| **Read Bandwidth** | 1.07 GB/s | 32 bits @ 33.3M ops/sec |
| **Write Bandwidth** | 0.32 GB/s | 32 bits @ 10M ops/sec |
| **Mixed Operations** | 0.64 GB/s | 50/50 read/write mix |

### **Resource Usage (per word)**
| Resource | Usage | Scaling |
|----------|-------|---------|
| **LUTs** | ~150 | Linear with WORD_WIDTH |
| **Flip-Flops** | ~200 | Linear with WORD_WIDTH |
| **Logic Levels** | 5 | Constant (parallel architecture) |

## 🧪 Testing Strategy

### **Unit Testing**
```systemverilog
// Test individual word operations
task test_word_read_write();
    logic [31:0] test_data = 32'hA5A5A5A5;
    logic [31:0] read_result;
    
    // Write test pattern
    send_command(CMD_WRITE, test_data);
    wait_for_completion();
    
    // Read back and verify
    send_command(CMD_READ, 32'h0);
    wait_for_completion();
    read_result = read_data;
    
    assert(read_result == test_data) else
        $error("Word read/write failed: expected %h, got %h", 
               test_data, read_result);
endtask
```

### **Error Injection Testing**
```systemverilog
// Test error handling
task test_error_handling();
    // Force cell error condition
    force cell_instances[0].cell_inst.error_flag = 1'b1;
    
    // Attempt operation
    send_command(CMD_READ, 32'h0);
    wait_for_completion();
    
    // Verify error propagation
    assert(word_error == 1'b1) else
        $error("Word error not detected");
        
    // Release error
    release cell_instances[0].cell_inst.error_flag;
endtask
```

### **Endurance Testing**
```systemverilog
// Test write cycle tracking
task test_endurance_tracking();
    logic [7:0] initial_cycles, final_cycles;
    
    initial_cycles = total_write_cycles;
    
    // Perform write operations
    for (int i = 0; i < 10; i++) begin
        send_command(CMD_WRITE, $random);
        wait_for_completion();
    end
    
    final_cycles = total_write_cycles;
    
    assert(final_cycles >= initial_cycles) else
        $error("Write cycle counting failed");
endtask
```

## 🔧 Configuration Examples

### **High-Speed Configuration**
```systemverilog
reram_word_array_simple #(
    .WORD_WIDTH(32),
    .READ_DELAY_CYCLES(1),    // Fast read
    .SET_DELAY_CYCLES(5),     // Fast write
    .RESET_DELAY_CYCLES(5),   // Fast write
    .MAX_WRITE_CYCLES(100)    // Lower endurance
) fast_word_array (
    // connections...
);
```

### **High-Reliability Configuration**
```systemverilog
reram_word_array_simple #(
    .WORD_WIDTH(32),
    .READ_DELAY_CYCLES(5),    // Conservative read
    .SET_DELAY_CYCLES(20),    // Conservative write
    .RESET_DELAY_CYCLES(20),  // Conservative write
    .MAX_WRITE_CYCLES(1000)   // High endurance
) reliable_word_array (
    // connections...
);
```

### **Custom Width Configuration**
```systemverilog
reram_word_array_simple #(
    .WORD_WIDTH(64),          // 64-bit words
    .READ_DELAY_CYCLES(3),
    .SET_DELAY_CYCLES(10),
    .RESET_DELAY_CYCLES(10),
    .MAX_WRITE_CYCLES(200)
) wide_word_array (
    // connections...
);
```

## 🛠️ Integration Guidelines

### **Memory Controller Integration**
```systemverilog
// In reram_memory_controller_blocking.sv
genvar w;
generate
    for (w = 0; w < MEMORY_DEPTH; w++) begin : word_array_instances
        reram_word_array_simple #(
            .WORD_WIDTH(DATA_WIDTH),
            .READ_DELAY_CYCLES(READ_DELAY_CYCLES),
            .SET_DELAY_CYCLES(SET_DELAY_CYCLES),
            .RESET_DELAY_CYCLES(RESET_DELAY_CYCLES),
            .MAX_WRITE_CYCLES(MAX_WRITE_CYCLES)
        ) word_array_inst (
            .clk(clk),
            .rst_n(rst_n),
            
            // Command interface
            .command(word_command_reg),
            .word_enable(word_enables[w]),
            .write_data(word_write_data),
            .read_data(word_read_data[w]),
            .operation_complete(word_operation_complete[w]),
            
            // Status
            .word_busy(word_busy[w]),
            .word_error(word_error[w]),
            .cell_error_flags(word_cell_error_flags[w]),
            .total_write_cycles(word_total_write_cycles[w])
        );
    end
endgenerate
```

### **Timing Considerations**
- **Clock Requirements**: Single clock domain, up to 200MHz
- **Reset**: Hold `rst_n` low for minimum 5 clock cycles
- **Command Timing**: Commands registered for proper cell coordination
- **Data Stability**: Write data must be stable during entire write operation

## 🔍 Debug Features

### **Observability Signals**
```systemverilog
// Debug outputs (add to module for debugging)
output logic [1:0] debug_current_state,
output logic [WORD_WIDTH-1:0] debug_cell_states,
output logic debug_all_read_complete,
output logic debug_all_write_complete
```

### **Debug Assignments**
```systemverilog
assign debug_current_state = current_word_state;
assign debug_cell_states = cell_states;
assign debug_all_read_complete = all_read_complete;
assign debug_all_write_complete = all_write_complete;
```

### **Common Debug Scenarios**
| Issue | Symptoms | Investigation |
|-------|----------|---------------|
| **Operation hangs** | `operation_complete` never asserts | Check `debug_cell_states` for stuck cells |
| **Data corruption** | Wrong read data | Check individual `cell_data_out` values |
| **Performance degradation** | Operations take too long | Check `total_write_cycles` for wear-out |
| **Error escalation** | Frequent `word_error` | Check `cell_error_flags` for failing cells |

---

**Next**: See `README_Cell_Layer.md` for the individual ReRAM cell modeling details.