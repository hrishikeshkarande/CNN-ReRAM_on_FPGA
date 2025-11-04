# Cell Layer Documentation

## 🧬 Overview

The Cell Layer (`reram_cell_simple.sv`) implements individual ReRAM cell modeling with accurate timing, endurance tracking, and physics-based behavior simulation. Each cell represents a single bit of resistive memory with realistic operational characteristics.

```
┌─────────────────────────────────────────────────────────────────┐
│                      Word Array Layer                          │
│                reram_word_array_simple.sv                      │
└─────────────────────────────────────────────────────────────────┘
                                    │
                          Cell Array Interface
                                    │
┌─────────────────────────────────────────────────────────────────┐
│                        Cell Array Layer                        │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                  reram_cell_simple.sv                  │ │
│  │                                                         │ │
│  │  • Binary Resistance State Modeling (HRS/LRS)             │ │
│  │  • Timing-Accurate Operation Delays                       │ │
│  │  • Write Cycle Endurance Tracking                         │ │
│  │  • Command-Based Interface (NOP/READ/WRITE)               │ │
│  │  • Error Detection & Wear-Out Simulation                  │ │
│  │  • Single-Bit Storage with Physics Emulation             │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 🏗️ Architecture

### **Core Responsibilities**
1. **Binary State Modeling** - HRS (High Resistance) / LRS (Low Resistance) states
2. **Timing Simulation** - Realistic read/write operation delays
3. **Endurance Modeling** - Write cycle counting and wear-out simulation
4. **Command Processing** - NOP/READ/WRITE operation handling
5. **Error Generation** - Busy state and wear-out error reporting
6. **Data Storage** - Single-bit persistent memory storage

### **ReRAM Physics Emulation**
The cell models the fundamental physics of resistive RAM:
- **SET Operation**: Transition from HRS → LRS (write '1')
- **RESET Operation**: Transition from LRS → HRS (write '0')
- **READ Operation**: Non-destructive resistance measurement
- **Endurance Limit**: Finite number of write cycles before failure

## 🔄 State Machine

```
                    ┌─────────────┐
                    │    IDLE     │◄──────────────┐
                    │             │               │
                    └─────┬───────┘               │
                          │                       │
              CMD_READ ┌──┘  └──┐ CMD_WRITE       │
                       │        │                 │
                       ▼        ▼                 │
                 ┌───────────┐ ┌──────────────┐   │
                 │  READING  │ │              │   │
                 │           │ │ data_in=1?   │   │
                 └─────┬─────┘ │              │   │
                       │       └─┬──────────┬─┘   │
                       │         │ SET      │     │
                operation_      │ │        │ RESET │operation_
                complete        │ ▼        ▼ │    │complete
                       │         │┌─────────────┐ │   │
                       │         ││WRITING_SET │ │   │
                       │         ││            │ │   │
                       │         │└─────┬───────┘ │   │
                       │         │      │         │   │
                       │         │ operation_     │   │
                       │         │ complete       │   │
                       │         │      │         │   │
                       │         │      ▼         │   │
                       │         │┌─────────────┐ │   │
                       │         ││WRITING_RESET│ │   │
                       │         ││            │ │   │
                       │         │└─────┬───────┘ │   │
                       │         │      │         │   │
                       │         │ operation_     │   │
                       │         │ complete       │   │
                       │         │      │         │   │
                       └─────────┴──────┴─────────┴───┘
```

### **State Descriptions**

| State | Description | Data Operation | Duration |
|-------|-------------|----------------|----------|
| **IDLE** | Waiting for command | None | Until command |
| **READING** | Read operation active | Output current state | 3 cycles (configurable) |
| **WRITING_SET** | SET operation (0→1) | HRS → LRS transition | 10 cycles (configurable) |
| **WRITING_RESET** | RESET operation (1→0) | LRS → HRS transition | 10 cycles (configurable) |

### **State Transition Logic**
```systemverilog
always_comb begin
    case (current_state)
        IDLE: begin
            if (active_read_cmd && !worn_out) 
                next_state = READING;
            else if (active_write_cmd && !worn_out) begin
                if (data_in == 1'b1) 
                    next_state = WRITING_SET;    // SET to LRS
                else 
                    next_state = WRITING_RESET;  // RESET to HRS
            end else 
                next_state = IDLE;
        end
        
        READING, WRITING_SET, WRITING_RESET: begin
            if (operation_complete)
                next_state = IDLE;
            else
                next_state = current_state;
        end
    endcase
end
```

## 🎛️ Interface Definition

### **Module Parameters**
```systemverilog
module reram_cell_simple #(
    parameter int READ_DELAY_CYCLES = 3,     // Read operation timing
    parameter int SET_DELAY_CYCLES = 10,     // SET operation timing (HRS→LRS)
    parameter int RESET_DELAY_CYCLES = 10,   // RESET operation timing (LRS→HRS)
    parameter int MAX_WRITE_CYCLES = 255     // Endurance limit (8-bit counter)
);
```

### **Interface Signals**

#### **Control Interface**
```systemverilog
// Clock and Reset
input  logic        clk,            // System clock
input  logic        rst_n,          // Active-low reset

// Command Interface
input  logic [1:0]  command,        // Command from word array
input  logic        cell_enable,    // Individual cell addressing
input  logic        data_in         // Write data (1-bit)
```

#### **Data Interface**
```systemverilog
// Data and Status Outputs
output logic        read_success,   // Read operation complete (1-cycle pulse)
output logic        write_success,  // Write operation complete (1-cycle pulse)
output logic        data_out,       // Read data output (current cell state)
output logic        cell_state      // Current resistance state (1=LRS, 0=HRS)
```

#### **Monitoring Interface**
```systemverilog
// Endurance and Error Monitoring
output logic [7:0]  write_cycles,   // Total write operations performed
output logic [1:0]  error_code,     // Error type code
output logic        error_flag      // Error condition present
```

## 🎮 Command Protocol

### **Command Encoding**
```systemverilog
localparam [1:0] CMD_NOP   = 2'b00;  // No operation
localparam [1:0] CMD_READ  = 2'b01;  // Read current state
localparam [1:0] CMD_WRITE = 2'b10;  // Write new state
```

### **Command Processing**
```systemverilog
// Command activation (requires cell_enable)
always_comb begin
    active_read_cmd  = cell_enable && (command == CMD_READ);
    active_write_cmd = cell_enable && (command == CMD_WRITE);
end
```

### **Operation Flow**

#### **Read Operation**
```
1. CMD_READ + cell_enable asserted
2. State → READING
3. data_out = current cell_state
4. Wait READ_DELAY_CYCLES
5. read_success pulse generated
6. State → IDLE
```

#### **Write Operation** 
```
1. CMD_WRITE + cell_enable + data_in valid
2. State → WRITING_SET (data_in=1) or WRITING_RESET (data_in=0)
3. Internal resistance state changes
4. Wait SET_DELAY_CYCLES or RESET_DELAY_CYCLES
5. write_success pulse generated
6. write_cycles incremented
7. Check for endurance limit
8. State → IDLE
```

## 🔬 ReRAM Physics Modeling

### **Resistance States**
```
┌─────────────────────────────────────────────────────────┐
│                  ReRAM Cell States                      │
├─────────────────────────────────────────────────────────┤
│  HRS (High Resistance State)                           │
│  • Resistance: ~10^6 Ω                                 │
│  • Logic Value: 0                                      │
│  • Default state after reset                           │
│  • Requires SET operation to change                    │
├─────────────────────────────────────────────────────────┤
│  LRS (Low Resistance State)                            │
│  • Resistance: ~10^3 Ω                                 │
│  • Logic Value: 1                                      │
│  • Requires RESET operation to change                  │
│  • Higher current consumption                          │
└─────────────────────────────────────────────────────────┘
```

### **State Mapping**
```systemverilog
// Physics to logic mapping
always_comb begin
    cell_state = internal_cell_state;  // 1=LRS, 0=HRS
    data_out = internal_cell_state;    // Direct mapping for read
end
```

### **Write Operation Physics**
```systemverilog
// State transitions during write operations
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        internal_cell_state <= 1'b0;   // Reset to HRS
    end else begin
        case (current_state)
            WRITING_SET: begin
                if (operation_complete) begin
                    internal_cell_state <= 1'b1;  // Transition to LRS
                end
            end
            
            WRITING_RESET: begin
                if (operation_complete) begin
                    internal_cell_state <= 1'b0;  // Transition to HRS
                end
            end
        endcase
    end
end
```

## ⏱️ Timing Control

### **Delay Counter Management**
```systemverilog
// Timing control for operations
always_comb begin
    case (current_state)
        READING:      target_delay = READ_DELAY_CYCLES;
        WRITING_SET:  target_delay = SET_DELAY_CYCLES;
        WRITING_RESET: target_delay = RESET_DELAY_CYCLES;
        default:      target_delay = 0;
    endcase
    
    operation_complete = (delay_counter >= target_delay);
end
```

### **Counter Logic**
```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        delay_counter <= 0;
    end else begin
        if (current_state == IDLE) begin
            delay_counter <= 0;
        end else begin
            delay_counter <= delay_counter + 1;
        end
    end
end
```

### **Operation Timing Diagrams**

#### **Read Operation (3 cycles)**
```
Clock     : __|‾|__|‾|__|‾|__|‾|__
command   : __| READ  |_________
cell_enable: ____|‾‾‾‾‾|_________
data_out  : ----<=====>---------
read_success: ________|‾|_______
```

#### **Write Operation (10 cycles)**
```
Clock     : __|‾|__|‾|__|‾|..|‾|__|‾|__
command   : __| WRITE |_______________
cell_enable: ____|‾‾‾‾‾|_______________
data_in   : ----<=D>-----------------
cell_state: ------<====NEW STATE====>
write_success: ______________|‾|_____
```

## 📈 Endurance Modeling

### **Write Cycle Tracking**
```systemverilog
// Write cycle counter (8-bit for simulation efficiency)
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        write_counter <= 8'h00;
    end else begin
        if (write_success_reg && (write_counter < MAX_WRITE_CYCLES)) begin
            write_counter <= write_counter + 1;
        end
    end
end

// Output write cycle count
assign write_cycles = write_counter;
```

### **Wear-Out Detection**
```systemverilog
// Endurance limit checking
logic worn_out;
assign worn_out = (write_counter >= MAX_WRITE_CYCLES);

// Prevent operations on worn-out cells
always_comb begin
    if (worn_out) begin
        current_error_code = ERR_WORN_OUT;
        current_error_flag = 1'b1;
    end else if (current_state != IDLE) begin
        current_error_code = ERR_BUSY;
        current_error_flag = 1'b0;  // Busy is not an error
    end else begin
        current_error_code = ERR_NONE;
        current_error_flag = 1'b0;
    end
end
```

### **Endurance Characteristics**
| Parameter | Typical Value | Range | Description |
|-----------|---------------|-------|-------------|
| **MAX_WRITE_CYCLES** | 200 | 50-1000 | Write endurance limit |
| **Write Degradation** | None | Linear | Uniform wear model |
| **Retention** | Infinite | N/A | No data loss over time |
| **Disturb Immunity** | Perfect | N/A | Reads don't affect data |

## 🚨 Error Handling

### **Error Code Definitions**
```systemverilog
localparam [1:0] ERR_NONE     = 2'b00;  // No error
localparam [1:0] ERR_BUSY     = 2'b01;  // Cell currently busy
localparam [1:0] ERR_WORN_OUT = 2'b10;  // Cell exceeded endurance limit
```

### **Error Conditions**
| Error Type | Detection | Response | Recovery |
|------------|-----------|----------|----------|
| **ERR_NONE** | Normal operation | Continue operation | N/A |
| **ERR_BUSY** | Command during operation | Ignore new command | Wait for completion |
| **ERR_WORN_OUT** | `write_cycles >= MAX_WRITE_CYCLES` | Block all operations | Replace cell |

### **Error Response Logic**
```systemverilog
// Error flag generation
always_comb begin
    error_code = current_error_code;
    error_flag = current_error_flag;
end

// Operation blocking for worn-out cells
always_comb begin
    if (worn_out) begin
        // Block all operations on worn-out cells
        next_state = IDLE;
    end else begin
        // Normal state machine operation
        case (current_state)
            // ... normal state transitions
        endcase
    end
end
```

## 📊 Performance Characteristics

### **Timing Specifications**
| Operation | Default Cycles | Time @ 100MHz | Configurable Range |
|-----------|----------------|---------------|-------------------|
| **Read** | 3 | 30ns | 1-10 cycles |
| **SET (0→1)** | 10 | 100ns | 5-50 cycles |
| **RESET (1→0)** | 10 | 100ns | 5-50 cycles |
| **Command Setup** | 1 | 10ns | Fixed |

### **Resource Usage (per cell)**
| Resource | Usage | Notes |
|----------|-------|-------|
| **LUTs** | ~4 | State machine + counters |
| **Flip-Flops** | ~6 | State + counter registers |
| **Memory** | 0 | Pure logic implementation |

### **Scalability**
- **Linear Scaling**: Resources scale linearly with cell count
- **Parallel Operation**: All cells operate independently
- **Clock Efficiency**: Single clock domain, up to 200MHz

## 🧪 Testing Strategy

### **Unit Test Coverage**
```systemverilog
// Comprehensive cell testing
task test_cell_operations();
    // Test read of initial state (should be HRS=0)
    send_command(CMD_READ);
    wait_for_completion();
    assert(data_out == 1'b0) else $error("Initial state wrong");
    
    // Test SET operation (0→1)
    send_command(CMD_WRITE, 1'b1);
    wait_for_completion();
    assert(cell_state == 1'b1) else $error("SET failed");
    
    // Test RESET operation (1→0)
    send_command(CMD_WRITE, 1'b0);
    wait_for_completion();
    assert(cell_state == 1'b0) else $error("RESET failed");
    
    // Test read after write
    send_command(CMD_READ);
    wait_for_completion();
    assert(data_out == 1'b0) else $error("Read after write failed");
endtask
```

### **Endurance Testing**
```systemverilog
// Test write cycle limit
task test_endurance_limit();
    logic [7:0] initial_cycles = write_cycles;
    
    // Write until limit
    for (int i = 0; i < MAX_WRITE_CYCLES + 10; i++) begin
        send_command(CMD_WRITE, i[0]);
        wait_for_completion();
        
        if (i < MAX_WRITE_CYCLES) begin
            assert(!error_flag) else $error("Premature wear-out");
        end else begin
            assert(error_flag) else $error("Wear-out not detected");
        end
    end
endtask
```

### **Timing Verification**
```systemverilog
// Verify operation timing
task test_operation_timing();
    int start_time, end_time;
    
    start_time = $time;
    send_command(CMD_READ);
    wait_for_completion();
    end_time = $time;
    
    assert((end_time - start_time) == READ_DELAY_CYCLES * CLK_PERIOD) 
        else $error("Read timing incorrect");
endtask
```

## 🔧 Configuration Examples

### **Fast Cell Configuration**
```systemverilog
reram_cell_simple #(
    .READ_DELAY_CYCLES(1),      // Fast read
    .SET_DELAY_CYCLES(3),       // Fast SET
    .RESET_DELAY_CYCLES(3),     // Fast RESET
    .MAX_WRITE_CYCLES(50)       // Lower endurance
) fast_cell (
    // connections...
);
```

### **Reliable Cell Configuration**
```systemverilog
reram_cell_simple #(
    .READ_DELAY_CYCLES(5),      // Conservative read
    .SET_DELAY_CYCLES(20),      // Conservative SET
    .RESET_DELAY_CYCLES(20),    // Conservative RESET
    .MAX_WRITE_CYCLES(1000)     // High endurance
) reliable_cell (
    // connections...
);
```

### **Simulation-Optimized Configuration**
```systemverilog
reram_cell_simple #(
    .READ_DELAY_CYCLES(1),      // Fast simulation
    .SET_DELAY_CYCLES(2),       // Fast simulation
    .RESET_DELAY_CYCLES(2),     // Fast simulation
    .MAX_WRITE_CYCLES(10)       // Quick endurance testing
) sim_cell (
    // connections...
);
```

## 🛠️ Integration Guidelines

### **Word Array Integration**
```systemverilog
// In reram_word_array_simple.sv
genvar i;
generate
    for (i = 0; i < WORD_WIDTH; i++) begin : cell_instances
        reram_cell_simple #(
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
            .cell_state(cell_states[i]),
            .write_cycles(cell_write_cycles[i]),
            .error_code(cell_error_codes[i]),
            .error_flag(cell_error_flag[i])
        );
    end
endgenerate
```

### **Timing Considerations**
- **Clock Domain**: Single clock, up to 200MHz
- **Reset**: Hold `rst_n` low for minimum 2 clock cycles
- **Command Stability**: Commands must be stable during entire operation
- **Enable Timing**: `cell_enable` should be stable with command

## 🔍 Debug Features

### **State Visibility**
```systemverilog
// Debug outputs (add for debugging)
output logic [1:0] debug_state,
output logic [31:0] debug_delay_counter,
output logic debug_operation_complete
```

### **Common Debug Scenarios**
| Issue | Symptoms | Investigation |
|-------|----------|---------------|
| **Cell doesn't respond** | No success pulses | Check `cell_enable` and `command` |
| **Wrong read data** | `data_out` incorrect | Check `cell_state` and recent writes |
| **Timing issues** | Operations too fast/slow | Check `debug_delay_counter` |
| **Endurance errors** | Premature wear-out | Check `write_cycles` progression |

### **Debug Waveform Analysis**
```
Key signals to monitor:
- command[1:0]
- cell_enable  
- current_state[1:0]
- delay_counter[31:0]
- operation_complete
- read_success/write_success
- error_flag
```

---

**Next**: See `README_Software_Interface.md` for the C driver and software integration details.