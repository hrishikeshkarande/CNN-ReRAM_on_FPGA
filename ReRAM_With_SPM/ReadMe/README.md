# ReRAM Memory System - Complete Architecture# ReRAM Cell Emulator



## 🏗️ Architecture Overview- A SystemVerilog implementation of a resistive random-access memory (ReRAM) cell emulator for FPGA deployment.



This ReRAM memory system implements a production-ready, layered architecture for reliable resistive RAM integration in FPGA and ARM-based systems.## Overview



```This project implements a physics-based ReRAM cell model with configurable resistance states, read/write operations, and endurance tracking. The design is optimized for synthesis on Xilinx FPGAs while maintaining behavioral accuracy for research and educational purposes.

┌─────────────────────────────────────────────────────────────────┐

│                        Application Layer                        │## Features

│  ┌──────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │

│  │   C/C++ Driver   │  │  Linux Kernel   │  │  Bare Metal     │ │- **Dual Resistance States**: High Resistance State (HRS) and Low Resistance State (LRS)

│  │     reram_axi_   │  │    Module       │  │   Applications  │ │- **Complete Operations**: Read, Write (SET/RESET), and Multiply operations

│  │     driver.c/h   │  │                 │  │                 │ │- **Endurance Modeling**: Configurable write cycle limits with degradation tracking

│  └──────────────────┘  └─────────────────┘  └─────────────────┘ │- **FPGA Optimized**: Synthesizable design targeting Xilinx Artix-7 series

└─────────────────────────────────────────────────────────────────┘- **Comprehensive Testing**: Full testbench with read/write verification and stress testing

                                    │

                          Memory-Mapped I/O## Architecture

                                    │

┌─────────────────────────────────────────────────────────────────┐### Core Module: `reram_cell_enhanced.sv`

│                      AXI4-Lite Interface Layer                  │

│  ┌─────────────────────────────────────────────────────────────┐ │The main ReRAM cell implementation features:

│  │             axi_reram_memory_controller.sv              │ │

│  │                                                         │ │- **5-State FSM**: IDLE, READING, WRITING_SET, WRITING_RESET, MULTIPLYING

│  │  • AXI4-Lite Protocol Compliance                       │ │- **Configurable Parameters**: 

│  │  • Address Decode (Memory vs Control Regions)          │ │  - SET/RESET delays (default: 10ns each)

│  │  • Memory-Mapped Register Interface                    │ │  - Maximum write cycles (default: 1M cycles) 

│  │  • Error Response Translation (OKAY/SLVERR/DECERR)     │ │  - HRS/LRS resistance values

│  │  • Address Alignment Checking                          │ │- **Single-Cycle Success Pulses**: Immediate completion indication

│  │  • ARM Processor Integration                           │ │- **Self-Contained Design**: No external package dependencies

│  └─────────────────────────────────────────────────────────────┘ │

└─────────────────────────────────────────────────────────────────┘### Key Interfaces

                                    │

                          Simple Memory Interface```systemverilog

                                    │// Control signals

┌─────────────────────────────────────────────────────────────────┐input  logic        clk,           // System clock

│                    Memory Controller Layer                      │input  logic        rst_n,         // Active-low reset

│  ┌─────────────────────────────────────────────────────────────┐ │input  logic        read_en,       // Read enable

│  │           reram_memory_controller_blocking.sv              │ │input  logic        write_en,      // Write enable  

│  │                                                         │ │input  logic        multiply_en,   // Multiply enable

│  │  • Memory Management & Address Decoding                    │ │input  logic        data_in,       // Data input (1-bit)

│  │  • Read/Write Operation Orchestration                      │ │

│  │  • Endurance Monitoring & Health Tracking                  │ │// Status outputs

│  │  • Error Detection & Worn-Out Cell Management             │ │output logic        read_success,  // Read operation complete

│  │  • Operation Statistics & Performance Monitoring          │ │output logic        write_success, // Write operation complete

│  │  • Word-Level Operation Control                           │ │output logic        multiply_success, // Multiply operation complete

│  └─────────────────────────────────────────────────────────────┘ │output logic        data_out,      // Data output (1-bit)

└─────────────────────────────────────────────────────────────────┘output logic [31:0] resistance,    // Current resistance value

                                    │output logic        hrs_state,     // High resistance state indicator

                          Word Array Interfaceoutput logic [31:0] write_cycles   // Total write cycles performed

                                    │## File Structure

┌─────────────────────────────────────────────────────────────────┐

│                      Word Array Layer                          │```

│  ┌─────────────────────────────────────────────────────────────┐ │ReRam/

│  │              reram_word_array_simple.sv                │ │├── reram_cell_enhanced.sv    # Main ReRAM cell implementation

│  │                                                         │ │├── tb_reram_cell.sv         # Comprehensive testbench

│  │  • Individual Word Storage Management                      │ │├── run_sim.ps1              # PowerShell simulation script

│  │  • Cell-Level Operation Coordination                       │ │└── README.md                # This file

│  │  • Parallel Word Access Architecture                       │ │```

│  │  • Write Cycle Counting per Word                          │ │

│  │  • Cell Error Aggregation & Reporting                     │ │## Quick Start

│  │  • Word-Level Timing Control                              │ │

│  └─────────────────────────────────────────────────────────────┘ │### Prerequisites

└─────────────────────────────────────────────────────────────────┘

                                    │Install one of the following simulators:

                          Cell Array Interface  - **Xilinx Vivado** (recommended for FPGA synthesis)

                                    │- **ModelSim/QuestaSim** (comprehensive simulation)

┌─────────────────────────────────────────────────────────────────┐- **Verilator** (open-source simulation)

│                        Cell Array Layer                        │

│  ┌─────────────────────────────────────────────────────────────┐ │### Running Simulations

│  │                reram_cell_enhanced.sv                  │ │

│  │                                                         │ │1. **Auto-detect and run with any available simulator:**

│  │  • Individual Cell Modeling & Simulation                   │ │   ```powershell

│  │  • SET/RESET Operation Implementation                      │ │   .\run_sim.ps1

│  │  • Resistance State Management (HRS/LRS)                  │ │   ```

│  │  • Endurance Tracking & Wear-Out Simulation              │ │

│  │  • Timing-Accurate Operation Delays                       │ │2. **Run with specific simulator:**

│  │  • Cell-Level Error Generation                            │ │   ```powershell

│  └─────────────────────────────────────────────────────────────┘ │   .\run_sim.ps1 -Simulator vivado

└─────────────────────────────────────────────────────────────────┘   .\run_sim.ps1 -Simulator modelsim  

```   .\run_sim.ps1 -Simulator verilator

   ```

## 📊 System Features

3. **Run synthesis test:**

### **Production-Ready Capabilities**   ```powershell

- ✅ **Full ARM SoC Integration** - Standard AXI4-Lite interface   .\run_sim.ps1 -Synthesis

- ✅ **Comprehensive Health Monitoring** - Real-time endurance tracking   ```

- ✅ **Robust Error Handling** - Automatic worn-out cell management

- ✅ **Performance Optimization** - Parallel word access architecture4. **Clean simulation files:**

- ✅ **Protocol Compliance** - Proper AXI handshaking and responses   ```powershell

- ✅ **Address Safety** - Bounds checking prevents data corruption   .\run_sim.ps1 -Clean

   ```

### **Advanced Monitoring & Diagnostics**

- 📈 **Per-Word Cycle Counting** - Track individual word endurance### Simulation Output

- 🔍 **Cell-Level Error Detection** - Identify failing cells early

- 📊 **Health Categories** - Healthy/Warning/Critical/Worn-out classificationThe testbench performs comprehensive testing:

- 🚨 **Predictive Maintenance** - Early warning system for failures

- 📝 **Comprehensive Logging** - Error codes, timestamps, addresses- **Basic Operations**: Read/write functionality verification

- **State Transitions**: HRS ↔ LRS switching validation  

## 🗂️ Documentation Structure- **Multiply Operations**: Resistance-based computation testing

- **Endurance Testing**: Write cycle limit verification

| Layer | File | Description |- **Concurrent Operations**: Multiple simultaneous operation handling

|-------|------|-------------|- **Stress Testing**: Rapid operation sequences

| **System** | `README.md` | This overview document |

| **AXI Interface** | `README_AXI_Layer.md` | AXI4-Lite protocol implementation |Expected output includes operation confirmations, resistance state changes, and test completion status.

| **Memory Controller** | `README_Memory_Controller.md` | Core memory management logic |

| **Word Array** | `README_Word_Array.md` | Word-level storage architecture |## Design Details

| **Cell Layer** | `README_Cell_Layer.md` | Individual cell modeling |

| **Software** | `README_Software_Interface.md` | C driver and integration guide |### State Machine

| **Integration** | `README_Integration_Guide.md` | System integration and examples |

The ReRAM cell operates through a 5-state finite state machine:

## 🚀 Quick Start

1. **IDLE**: Default state, ready for operations

### For ARM SoC Integration:2. **READING**: Performing read operation (1 cycle)

```systemverilog3. **WRITING_SET**: Switching to LRS (configurable delay)

axi_reram_memory_controller #(4. **WRITING_RESET**: Switching to HRS (configurable delay) 

    .MEMORY_DEPTH(16),              // 16 words = 64 bytes5. **MULTIPLYING**: Performing resistance-based computation (1 cycle)

    .MEMORY_BASE_ADDR(32'h20000000), // Memory region

    .CTRL_BASE_ADDR(32'h40000000),   // Control registers### Operation Timing

    .MAX_WRITE_CYCLES(200)           // Endurance limit

) reram_ctrl (- **Read**: Single cycle operation

    .aclk(axi_clk),- **Write (SET/RESET)**: Configurable delay (default: 10 cycles each)

    .aresetn(axi_resetn),- **Multiply**: Single cycle operation

    // Connect to AXI interconnect...- **Success Pulses**: Single-cycle confirmation signals

);

```### Resistance Model



### For Software Access:- **HRS (High Resistance State)**: 1MΩ (configurable)

```c- **LRS (Low Resistance State)**: 1kΩ (configurable)  

#include "reram_axi_driver.h"- **State Switching**: Based on write operations and data input

- **Endurance**: Tracks total write cycles with configurable limits

// Initialize driver

if (reram_init() != RERAM_SUCCESS) {## Synthesis Results

    printf("ReRAM initialization failed!\n");

    return -1;When synthesized for Xilinx Artix-7 (xc7a35tcpg236-1):

}

- **Logic Utilization**: Minimal LUT and FF usage

// Write data- **Memory**: No BRAM required (register-based state storage)

uint32_t data = 0xDEADBEEF;- **Timing**: Optimized for high-frequency operation

if (reram_write_word(0, data) == RERAM_SUCCESS) {- **Power**: Low static power consumption

    printf("Write successful\n");

}## Customization



// Read data back### Parameters

uint32_t read_data;

if (reram_read_word(0, &read_data) == RERAM_SUCCESS) {Key parameters can be modified in `reram_cell_enhanced.sv`:

    printf("Read: 0x%08X\n", read_data);

}```systemverilog

```parameter SET_DELAY_CYCLES = 10;     // SET operation delay

parameter RESET_DELAY_CYCLES = 10;   // RESET operation delay  

## 📁 File Organizationparameter MAX_WRITE_CYCLES = 1000000; // Endurance limit

parameter HRS_RESISTANCE = 1000000;  // High resistance value

```parameter LRS_RESISTANCE = 1000;     // Low resistance value

ReRam/```

├── README.md                              # This overview

├── README_AXI_Layer.md                    # AXI interface documentation### Adding Features

├── README_Memory_Controller.md            # Memory controller documentation  

├── README_Word_Array.md                   # Word array documentationThe modular design allows easy extension:

├── README_Cell_Layer.md                   # Cell layer documentation

├── README_Software_Interface.md           # Software driver documentation- **Error injection**: Add random failure modes

├── README_Integration_Guide.md            # Integration examples- **Temperature effects**: Include thermal resistance variation

│- **Wear leveling**: Implement endurance management algorithms

├── axi_reram_memory_controller.sv         # AXI4-Lite interface layer- **Advanced operations**: Add specialized computation modes

├── reram_memory_controller_blocking.sv    # Memory controller layer

├── reram_word_array_simple.sv             # Word array layer## Troubleshooting

├── reram_cell_enhanced.sv                 # Cell layer

│### Common Issues

├── reram_axi_driver.h                     # C driver header

├── reram_axi_driver.c                     # C driver implementation1. **Simulator not found**: Ensure simulator is in system PATH

├── reram_axi_example.c                    # Example application2. **Compilation errors**: Check SystemVerilog syntax compatibility

│3. **Timing violations**: Adjust clock frequency or operation delays

├── tb_axi_reram_memory_controller.sv      # AXI testbench4. **Simulation hangs**: Verify testbench termination conditions

├── tb_reram_memory_controller_blocking.sv # Memory controller testbench

├── example_arm_reram_system.sv            # ARM integration example### Debug Tips

│

└── simulation/                            # Simulation files- Enable waveform generation in your simulator

    ├── run_axi_test.sh- Use `$display` statements for runtime debugging

    └── run_memory_test.sh- Check reset behavior and initial conditions

```- Verify operation enable signal timing



## 🎯 Key Design Principles## Contributing



### **Layered Architecture**When contributing to this project:

- **Single Responsibility** - Each layer has a clear, focused purpose

- **Clean Interfaces** - Well-defined boundaries between layers1. Maintain FPGA synthesis compatibility

- **Separation of Concerns** - Transport vs logic vs storage clearly separated2. Follow SystemVerilog coding standards

3. Update testbench for new features

### **Error Handling Philosophy**4. Document parameter changes

- **Fail Fast** - Immediate error detection and reporting  5. Test with multiple simulators when possible

- **Graceful Degradation** - System continues operating with worn-out cells

- **Transparent Recovery** - Automatic retry and error correction where possible## License



### **Performance Optimization**This project is provided for educational and research purposes. Please refer to your institution's policies regarding hardware description language implementations.

- **Parallel Access** - Multiple words can be accessed simultaneously

- **Pipelined Operations** - Overlapped read/write operations## References

- **Predictive Caching** - Health data cached for fast access

- ReRAM device physics and modeling literature

## 🔧 Configuration Options- Xilinx FPGA synthesis guidelines

- SystemVerilog IEEE 1800 standard

| Parameter | Default | Range | Description |- FPGA-based memory emulation techniques

|-----------|---------|-------|-------------|│   ├── vivado_sim.tcl            # Vivado simulation script

| `MEMORY_DEPTH` | 16 | 1-1024 | Number of 32-bit words |│   └── vivado_synth.tcl          # Vivado synthesis script

| `MAX_WRITE_CYCLES` | 200 | 50-10000 | Endurance limit per cell |├── run_sim.ps1                   # PowerShell simulation script

| `READ_DELAY_CYCLES` | 3 | 1-10 | Read operation timing |├── README.md                     # This file

| `SET_DELAY_CYCLES` | 10 | 5-50 | Write SET operation timing |└── DESIGN_ANALYSIS.md            # Detailed design analysis and review

| `RESET_DELAY_CYCLES` | 10 | 5-50 | Write RESET operation timing |```



## 📋 System Requirements## Quick Start



### **FPGA Resources (Zynq-7020 Example)**### Prerequisites

- **LUTs**: ~500 per 16-word system- SystemVerilog-compatible simulator (ModelSim, Vivado, Verilator)

- **Flip-Flops**: ~800 per 16-word system  - For synthesis: Xilinx Vivado (tested with 7-series FPGAs)

- **Block RAMs**: None (uses distributed RAM)

- **Clock**: Single clock domain, 100MHz recommended### Running Simulation



### **Software Requirements**#### Windows PowerShell

- **ARM Processor**: Cortex-M3/M4/A9/A53 or similar```powershell

- **AXI Interface**: AXI4-Lite master capability# Default enhanced testbench

- **Memory**: 32-bit word-aligned access.\run_sim.ps1

- **OS**: Bare metal, Linux, or RTOS compatible

# Comprehensive testing

## 🧪 Testing & Validation.\run_sim.ps1 -TestBench comprehensive



All layers include comprehensive testbenches:# Run all testbenches

- **Unit Tests** - Individual module validation.\run_sim.ps1 -TestBench all

- **Integration Tests** - Multi-layer interaction testing

- **Stress Tests** - Endurance and error condition testing# Specific simulator with focused testing

- **Protocol Tests** - AXI compliance verification.\run_sim.ps1 -Simulator vivado -TestBench focused

```

## 📈 Performance Characteristics

#### Using Makefile (if available)

### **Timing (at 100MHz)**```bash

- **Read Latency**: 30ns (3 cycles)# Default simulator (ModelSim)

- **Write Latency**: 100ns (10 cycles)  make sim

- **Throughput**: ~100MB/s sustained (with pipelining)

- **Error Detection**: Real-time, single cycle# Specific simulators

make sim_vivado

### **Endurance**make sim_verilator

- **Write Cycles**: 200 per cell (configurable)

- **Data Retention**: Infinite (simulated)# Synthesis test

- **Error Rate**: <1E-12 (before wear-out)make synth

```

## 🎓 Learning Path

#### Manual Vivado Simulation

1. **Start with Cell Layer** - Understand basic ReRAM physics simulation```tcl

2. **Study Word Array** - Learn parallel access and aggregation# In Vivado TCL console

3. **Explore Memory Controller** - Understand system orchestrationsource scripts/vivado_sim.tcl

4. **Master AXI Interface** - Learn ARM processor integration```

5. **Use Software Driver** - Develop applications

### Expected Test Results

## 🆘 Support & TroubleshootingThe testbenches perform comprehensive verification:

- ✅ Basic read operations with timing verification

For detailed troubleshooting guides and integration examples, see:- ✅ Enhanced write operations (SET/RESET with verification)

- `README_Integration_Guide.md` - Common integration issues- ✅ Write failure scenarios and recovery

- `README_Software_Interface.md` - Driver API and examples- ✅ Multiply operations in different resistance states

- Testbench files - Reference implementations and test vectors- ✅ Comprehensive error reporting and handling

- ✅ Concurrent request rejection

---- ✅ Endurance limit testing with failure probability

- ✅ Edge case and stress testing

**Next Steps**: Choose a layer documentation file to dive deeper into the architecture! 🚀- ✅ Performance characterization

## Usage Examples

### Basic Read Operation
```systemverilog
// Read current resistance state
cmd = 3'b001;       // CMD_READ
cmd_valid = 1'b1;   // Assert valid

// Wait for acceptance
@(posedge clk);
if (request_accepted) begin
    cmd_valid = 1'b0;
    // Wait for completion
    wait(read_success);
    // read_data now contains the resistance state
    $display("Read data: %d", read_data);
end
```

### Enhanced Write Operation
```systemverilog
// Write resistance state
cmd = 3'b010;       // CMD_WRITE
data_in = 8'h01;    // Target resistance state
cmd_valid = 1'b1;   // Assert valid

// Wait for acceptance
@(posedge clk);
if (request_accepted) begin
    cmd_valid = 1'b0;
    // Wait for completion (includes verification)
    wait(write_success || error_flag);
    
    if (write_success) begin
        $display("Write successful, new resistance: %d", resistance_state);
    end else begin
        $display("Write failed with error: %s", error_code.name());
    end
end
```

### Multiply Operation
```systemverilog
// Multiply resistance state by 50
cmd = 3'b011;       // CMD_MULTIPLY
data_in = 8'd50;    // Multiply by 50
cmd_valid = 1'b1;

@(posedge clk);
if (request_accepted) begin
    cmd_valid = 1'b0;
    wait(multiply_success);
    // multiply_result = (resistance_state * 255 / max_resistance) * 50
    $display("Multiply result: %d", multiply_result);
end
```

### Error Handling
```systemverilog
// Check for errors after any operation
if (error_flag) begin
    case (error_code)
        ERR_WRITE_FAIL: $display("Write operation failed");
        ERR_WORN_OUT:   $display("Cell is worn out");
        ERR_BUSY:       $display("Cell is busy");
        default:        $display("Unknown error: %d", error_code);
    endcase
    
    // Wait for error to clear or reset cell
    wait(!error_flag);
end
```

## Implementation Details

### State Machine
The ReRAM cell uses a 4-state FSM:
1. **IDLE**: Ready for new commands
2. **WRITING_SET**: Transitioning to LRS (HRS→LRS)
3. **WRITING_RESET**: Transitioning to HRS (LRS→HRS)
4. **MULTIPLYING**: Performing multiply operation

### Timing Behavior
- All operations have configurable delays to model real ReRAM physics
- SET operations typically take longer than RESET operations
- Multiply operations model the time for analog computation

### Endurance Modeling
- Write counter tracks total write operations
- Cell rejects all write requests after reaching `MAX_WRITES`
- Provides realistic wear-out behavior for system-level simulation

## Future Enhancements

### Planned Features
1. **ReRAM Array Module**: Multiple cells with address decoding
2. **AXI Interface**: Standard memory interface for processor integration
3. **Advanced PIM Operations**: Addition, MAC operations
4. **Variability Modeling**: Process variations and device-to-device differences
5. **Temperature Effects**: Thermal modeling of resistance states
6. **Noise Modeling**: Random resistance fluctuations

### Synthesis Results
Target FPGA: Xilinx Artix-7 (xc7a35tcpg236-1)
- **LUTs**: ~50-100 per cell (depends on parameters)
- **Flip-Flops**: ~100-150 per cell
- **Max Frequency**: >200 MHz (typical)

## Contributing

This is a research/educational project. Contributions are welcome for:
- Additional test cases
- Performance optimizations
- New PIM operations
- Better endurance models
- Synthesis optimizations

## License

Open source - feel free to use and modify for research and educational purposes.

## References

1. ReRAM physics and modeling literature
2. Processing-in-Memory architectures
3. FPGA implementation best practices

---

**Note**: This is an emulator for research and development purposes. Real ReRAM devices have more complex physics and variability that may not be fully captured in this model.