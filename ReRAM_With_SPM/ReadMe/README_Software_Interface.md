# Software Interface Documentation

## 💻 Overview

The Software Interface provides a comprehensive C driver for accessing the ReRAM memory system through the AXI4-Lite interface. It offers high-level APIs for memory operations, health monitoring, and system diagnostics while handling all low-level hardware details.

```
┌─────────────────────────────────────────────────────────────────┐
│                     Application Layer                          │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                User Applications                        │ │
│  │  • File Systems    • Data Logging    • IoT Sensors        │ │
│  │  • Embedded Apps   • Real-time Systems                    │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                    │
                          C Driver API
                                    │
┌─────────────────────────────────────────────────────────────────┐
│                    Software Driver Layer                       │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │              reram_axi_driver.c/.h                     │ │
│  │                                                         │ │
│  │  • High-Level Memory Operations                            │ │
│  │  • Comprehensive Health Monitoring                        │ │
│  │  • Error Handling & Recovery                              │ │
│  │  • Address Validation & Safety                            │ │
│  │  • Performance Statistics                                 │ │
│  │  • Diagnostic & Debug Functions                           │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                    │
                          Memory-Mapped I/O
                                    │
┌─────────────────────────────────────────────────────────────────┐
│                      AXI4-Lite Interface                       │
│                axi_reram_memory_controller.sv                  │
└─────────────────────────────────────────────────────────────────┘
```

## 🏗️ Architecture

### **Driver Components**
1. **Core Memory API** - High-level read/write operations
2. **Health Monitoring** - Endurance tracking and health assessment
3. **Error Management** - Comprehensive error detection and recovery
4. **Performance Monitoring** - Operation statistics and timing
5. **Diagnostic Tools** - Debug and system analysis functions
6. **Configuration Management** - Runtime configuration and tuning

### **Design Principles**
- **Safety First** - Address validation prevents data corruption
- **Error Transparency** - All hardware errors properly reported
- **Performance Optimization** - Efficient register access patterns
- **Portable Design** - Works on bare metal, RTOS, and Linux

## 📚 API Reference

### **Core Data Types**

#### **Configuration Structure**
```c
typedef struct {
    uint32_t base_addr;              // Control register base address
    uint32_t memory_base;            // Memory region base address
    uint8_t  max_write_cycles;       // Maximum write cycles per cell
    uint8_t  warning_threshold;      // Warning threshold (% of max cycles)
    bool     enable_health_monitoring; // Enable background health checks
    bool     enable_auto_refresh;    // Enable automatic refresh
} reram_config_t;
```

#### **Health Status Structure**
```c
typedef struct {
    uint8_t healthy_words;           // Number of healthy words
    uint8_t warning_words;           // Number of warning words  
    uint8_t critical_words;          // Number of critical words
    uint8_t worn_out_words;          // Number of worn-out words
    uint8_t overall_health_score;    // Overall health (0-100)
} reram_health_status_t;
```

#### **Error Information Structure**
```c
typedef struct {
    uint32_t last_error_addr;        // Address of last error
    uint32_t last_error_code;        // Detailed error code
    uint16_t operation_errors;       // Total operation errors
    uint16_t endurance_errors;       // Total endurance errors
    uint32_t total_operations;       // Total operations performed
} reram_error_info_t;
```

### **Return Codes**
```c
typedef enum {
    RERAM_SUCCESS = 0,               // Operation successful
    RERAM_ERROR_INVALID_ADDR = -1,   // Address out of bounds
    RERAM_ERROR_HARDWARE = -2,       // Hardware error occurred
    RERAM_ERROR_WORN_OUT = -3,       // Memory location worn out
    RERAM_ERROR_BUSY = -4,           // Controller busy
    RERAM_ERROR_NOT_INITIALIZED = -5, // Driver not initialized
    RERAM_ERROR_INVALID_PARAM = -6   // Invalid parameter
} reram_result_t;
```

## 🚀 Core Memory Operations

### **Initialization**
```c
// Initialize ReRAM driver
reram_result_t reram_init(reram_config_t *config, uint32_t ctrl_base_addr);

// Example usage
reram_config_t config = {
    .base_addr = 0x40000000,         // Control register base
    .memory_base = 0x20000000,       // Memory region base
    .max_write_cycles = 200,         // Conservative endurance
    .warning_threshold = 160,        // 80% warning threshold
    .enable_health_monitoring = true,
    .enable_auto_refresh = false
};

if (reram_init(&config, 0x40000000) != RERAM_SUCCESS) {
    printf("ReRAM initialization failed!\\n");
    return -1;
}
```

### **Basic Memory Access**
```c
// Read single word (32-bit)
reram_result_t reram_read_word(uint8_t word_addr, uint32_t *data);

// Write single word (32-bit)
reram_result_t reram_write_word(uint8_t word_addr, uint32_t data);

// Example usage
uint32_t data;
if (reram_read_word(0, &data) == RERAM_SUCCESS) {
    printf("Read: 0x%08X\\n", data);
} else {
    printf("Read failed\\n");
}

if (reram_write_word(1, 0xDEADBEEF) == RERAM_SUCCESS) {
    printf("Write successful\\n");
} else {
    printf("Write failed\\n");
}
```

### **Bulk Memory Operations**
```c
// Read multiple words
reram_result_t reram_read_bulk(uint8_t start_addr, uint8_t word_count, uint32_t *data);

// Write multiple words
reram_result_t reram_write_bulk(uint8_t start_addr, uint8_t word_count, const uint32_t *data);

// Example: Read entire memory
uint32_t memory_dump[RERAM_MEMORY_WORDS];
if (reram_read_bulk(0, RERAM_MEMORY_WORDS, memory_dump) == RERAM_SUCCESS) {
    printf("Memory dump successful\\n");
    for (int i = 0; i < RERAM_MEMORY_WORDS; i++) {
        printf("Word %d: 0x%08X\\n", i, memory_dump[i]);
    }
}
```

## 📊 Health Monitoring

### **Health Status Functions**
```c
// Get overall health summary
reram_result_t reram_get_health_status(reram_health_status_t *health);

// Get per-word write cycle count
uint8_t reram_get_word_cycles(uint8_t word_addr);

// Get detailed cell error information
uint32_t reram_get_word_cell_errors(uint8_t word_addr);

// Check if specific word is worn out
bool reram_is_word_worn_out(uint8_t word_addr);

// Example health monitoring
reram_health_status_t health;
if (reram_get_health_status(&health) == RERAM_SUCCESS) {
    printf("Health Summary:\\n");
    printf("  Healthy: %d words\\n", health.healthy_words);
    printf("  Warning: %d words\\n", health.warning_words);
    printf("  Critical: %d words\\n", health.critical_words);
    printf("  Worn-out: %d words\\n", health.worn_out_words);
    printf("  Overall Score: %d/100\\n", health.overall_health_score);
}
```

### **Detailed Word Analysis**
```c
// Analyze individual word health
void analyze_word_health(uint8_t word_addr) {
    uint8_t cycles = reram_get_word_cycles(word_addr);
    uint32_t cell_errors = reram_get_word_cell_errors(word_addr);
    bool worn_out = reram_is_word_worn_out(word_addr);
    
    printf("Word %d Analysis:\\n", word_addr);
    printf("  Write Cycles: %d/%d\\n", cycles, RERAM_MAX_CYCLES);
    printf("  Cell Errors: 0x%08X\\n", cell_errors);
    printf("  Status: %s\\n", worn_out ? "WORN OUT" : "OK");
    
    // Calculate health percentage
    uint8_t health_percent = (cycles * 100) / RERAM_MAX_CYCLES;
    if (health_percent < 50) {
        printf("  Health: HEALTHY (%d%%)\\n", health_percent);
    } else if (health_percent < 80) {
        printf("  Health: WARNING (%d%%)\\n", health_percent);
    } else {
        printf("  Health: CRITICAL (%d%%)\\n", health_percent);
    }
}
```

## 🚨 Error Handling

### **Error Detection and Recovery**
```c
// Check for any errors
bool reram_has_error(void);

// Get detailed error information
reram_result_t reram_get_error_info(reram_error_info_t *error_info);

// Clear all error flags
reram_result_t reram_clear_errors(void);

// Example error handling
if (reram_has_error()) {
    reram_error_info_t error_info;
    if (reram_get_error_info(&error_info) == RERAM_SUCCESS) {
        printf("Error detected:\\n");
        printf("  Last Error Address: 0x%08X\\n", error_info.last_error_addr);
        printf("  Error Code: 0x%08X\\n", error_info.last_error_code);
        printf("  Operation Errors: %d\\n", error_info.operation_errors);
        printf("  Endurance Errors: %d\\n", error_info.endurance_errors);
    }
    
    // Clear errors after handling
    reram_clear_errors();
}
```

### **Robust Memory Operations**
```c
// Safe write with retry and error handling
reram_result_t safe_write_word(uint8_t word_addr, uint32_t data) {
    reram_result_t result;
    int retry_count = 0;
    const int max_retries = 3;
    
    do {
        result = reram_write_word(word_addr, data);
        
        if (result == RERAM_SUCCESS) {
            // Verify write by reading back
            uint32_t read_data;
            if (reram_read_word(word_addr, &read_data) == RERAM_SUCCESS) {
                if (read_data == data) {
                    return RERAM_SUCCESS;  // Write and verify successful
                } else {
                    result = RERAM_ERROR_HARDWARE;  // Data mismatch
                }
            }
        }
        
        if (result == RERAM_ERROR_WORN_OUT) {
            printf("Word %d is worn out, marking as bad\\n", word_addr);
            return result;  // Don't retry worn-out locations
        }
        
        retry_count++;
        if (retry_count < max_retries) {
            printf("Write failed, retrying... (attempt %d/%d)\\n", 
                   retry_count + 1, max_retries);
            usleep(1000);  // Brief delay before retry
        }
        
    } while (retry_count < max_retries);
    
    printf("Write failed after %d attempts\\n", max_retries);
    return result;
}
```

## 📈 Performance Monitoring

### **Performance Statistics**
```c
// Get operation statistics
reram_result_t reram_get_performance_stats(reram_perf_stats_t *stats);

// Performance statistics structure
typedef struct {
    uint32_t total_reads;            // Total read operations
    uint32_t total_writes;           // Total write operations
    uint32_t error_count;            // Total errors encountered
    uint32_t avg_read_time_us;       // Average read time (microseconds)
    uint32_t avg_write_time_us;      // Average write time (microseconds)
} reram_perf_stats_t;

// Example performance monitoring
void monitor_performance(void) {
    reram_perf_stats_t stats;
    
    if (reram_get_performance_stats(&stats) == RERAM_SUCCESS) {
        printf("Performance Statistics:\\n");
        printf("  Total Reads: %u\\n", stats.total_reads);
        printf("  Total Writes: %u\\n", stats.total_writes);
        printf("  Error Count: %u\\n", stats.error_count);
        printf("  Avg Read Time: %u µs\\n", stats.avg_read_time_us);
        printf("  Avg Write Time: %u µs\\n", stats.avg_write_time_us);
        
        // Calculate error rate
        uint32_t total_ops = stats.total_reads + stats.total_writes;
        if (total_ops > 0) {
            float error_rate = (float)stats.error_count / total_ops * 100.0;
            printf("  Error Rate: %.2f%%\\n", error_rate);
        }
    }
}
```

## 🔧 Diagnostic Functions

### **System Diagnostics**
```c
// Run comprehensive system test
reram_result_t reram_run_basic_test(void);

// Print comprehensive health report
void reram_print_health_report(void);

// Print error report
void reram_print_error_report(void);

// Example diagnostic routine
void run_comprehensive_diagnostics(void) {
    printf("\\n=== ReRAM System Diagnostics ===\\n");
    
    // Run basic functionality test
    printf("Running basic test...\\n");
    if (reram_run_basic_test() == RERAM_SUCCESS) {
        printf("  ✓ Basic test PASSED\\n");
    } else {
        printf("  ✗ Basic test FAILED\\n");
    }
    
    // Print health report
    printf("\\nHealth Report:\\n");
    reram_print_health_report();
    
    // Check for errors
    if (reram_has_error()) {
        printf("\\nError Report:\\n");
        reram_print_error_report();
    } else {
        printf("\\n  ✓ No errors detected\\n");
    }
    
    // Performance analysis
    printf("\\nPerformance Analysis:\\n");
    monitor_performance();
}
```

### **Advanced Diagnostics**
```c
// Test specific memory patterns
reram_result_t test_memory_patterns(void) {
    uint32_t patterns[] = {
        0x00000000, 0xFFFFFFFF, 0xAAAAAAAA, 0x55555555,
        0x12345678, 0x87654321, 0xDEADBEEF, 0xCAFEBABE
    };
    
    printf("Testing memory patterns...\\n");
    
    for (int pattern_idx = 0; pattern_idx < 8; pattern_idx++) {
        uint32_t pattern = patterns[pattern_idx];
        printf("  Testing pattern 0x%08X...\\n", pattern);
        
        // Write pattern to all words
        for (int word = 0; word < RERAM_MEMORY_WORDS; word++) {
            if (reram_write_word(word, pattern) != RERAM_SUCCESS) {
                printf("    ✗ Write failed at word %d\\n", word);
                return RERAM_ERROR_HARDWARE;
            }
        }
        
        // Read back and verify
        for (int word = 0; word < RERAM_MEMORY_WORDS; word++) {
            uint32_t read_data;
            if (reram_read_word(word, &read_data) != RERAM_SUCCESS) {
                printf("    ✗ Read failed at word %d\\n", word);
                return RERAM_ERROR_HARDWARE;
            }
            
            if (read_data != pattern) {
                printf("    ✗ Data mismatch at word %d: expected 0x%08X, got 0x%08X\\n",
                       word, pattern, read_data);
                return RERAM_ERROR_HARDWARE;
            }
        }
        
        printf("    ✓ Pattern test passed\\n");
    }
    
    return RERAM_SUCCESS;
}
```

## 🛠️ Integration Examples

### **Bare Metal Integration**
```c
// Simple bare metal example
#include "reram_axi_driver.h"

int main(void) {
    // Initialize system
    reram_config_t config = {
        .base_addr = 0x40000000,
        .memory_base = 0x20000000,
        .max_write_cycles = 200,
        .warning_threshold = 160,
        .enable_health_monitoring = true,
        .enable_auto_refresh = false
    };
    
    if (reram_init(&config, 0x40000000) != RERAM_SUCCESS) {
        return -1;
    }
    
    // Use ReRAM as storage
    uint32_t sensor_data = read_sensor();
    reram_write_word(0, sensor_data);
    
    // Periodic health monitoring
    while (1) {
        // Check health every 1000 operations
        static int op_count = 0;
        if (++op_count >= 1000) {
            reram_health_status_t health;
            reram_get_health_status(&health);
            
            if (health.overall_health_score < 50) {
                printf("WARNING: ReRAM health degraded to %d%%\\n", 
                       health.overall_health_score);
            }
            
            op_count = 0;
        }
        
        // Application logic...
        delay_ms(100);
    }
}
```

### **Linux Driver Integration**
```c
// Linux character device driver integration
#include <linux/module.h>
#include <linux/fs.h>
#include <linux/uaccess.h>
#include "reram_axi_driver.h"

static int reram_open(struct inode *inode, struct file *file) {
    // Initialize ReRAM when device is opened
    reram_config_t config = {
        .base_addr = 0x40000000,
        .memory_base = 0x20000000,
        .max_write_cycles = 200,
        .warning_threshold = 160,
        .enable_health_monitoring = true,
        .enable_auto_refresh = true
    };
    
    return (reram_init(&config, 0x40000000) == RERAM_SUCCESS) ? 0 : -EIO;
}

static ssize_t reram_read(struct file *file, char __user *buffer, 
                         size_t count, loff_t *pos) {
    uint32_t data;
    uint8_t word_addr = *pos / 4;  // Convert byte offset to word address
    
    if (word_addr >= RERAM_MEMORY_WORDS) {
        return -EINVAL;
    }
    
    if (reram_read_word(word_addr, &data) != RERAM_SUCCESS) {
        return -EIO;
    }
    
    if (copy_to_user(buffer, &data, sizeof(data))) {
        return -EFAULT;
    }
    
    *pos += sizeof(data);
    return sizeof(data);
}

static ssize_t reram_write(struct file *file, const char __user *buffer,
                          size_t count, loff_t *pos) {
    uint32_t data;
    uint8_t word_addr = *pos / 4;  // Convert byte offset to word address
    
    if (word_addr >= RERAM_MEMORY_WORDS || count < sizeof(data)) {
        return -EINVAL;
    }
    
    if (copy_from_user(&data, buffer, sizeof(data))) {
        return -EFAULT;
    }
    
    if (reram_write_word(word_addr, data) != RERAM_SUCCESS) {
        return -EIO;
    }
    
    *pos += sizeof(data);
    return sizeof(data);
}

static const struct file_operations reram_fops = {
    .owner = THIS_MODULE,
    .open = reram_open,
    .read = reram_read,
    .write = reram_write,
    .llseek = default_llseek,
};
```

## 🧪 Testing and Validation

### **Unit Test Example**
```c
// Comprehensive unit test suite
void run_unit_tests(void) {
    printf("\\n=== ReRAM Unit Tests ===\\n");
    
    // Test 1: Basic read/write
    printf("Test 1: Basic read/write...\\n");
    uint32_t test_data = 0x12345678;
    assert(reram_write_word(0, test_data) == RERAM_SUCCESS);
    
    uint32_t read_data;
    assert(reram_read_word(0, &read_data) == RERAM_SUCCESS);
    assert(read_data == test_data);
    printf("  ✓ PASSED\\n");
    
    // Test 2: Address bounds checking
    printf("Test 2: Address bounds checking...\\n");
    assert(reram_write_word(RERAM_MEMORY_WORDS, 0) == RERAM_ERROR_INVALID_ADDR);
    assert(reram_read_word(RERAM_MEMORY_WORDS, &read_data) == RERAM_ERROR_INVALID_ADDR);
    printf("  ✓ PASSED\\n");
    
    // Test 3: Bulk operations
    printf("Test 3: Bulk operations...\\n");
    uint32_t bulk_data[4] = {0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC, 0xDDDDDDDD};
    uint32_t bulk_read[4];
    
    assert(reram_write_bulk(0, 4, bulk_data) == RERAM_SUCCESS);
    assert(reram_read_bulk(0, 4, bulk_read) == RERAM_SUCCESS);
    
    for (int i = 0; i < 4; i++) {
        assert(bulk_read[i] == bulk_data[i]);
    }
    printf("  ✓ PASSED\\n");
    
    // Test 4: Health monitoring
    printf("Test 4: Health monitoring...\\n");
    reram_health_status_t health;
    assert(reram_get_health_status(&health) == RERAM_SUCCESS);
    assert(health.healthy_words <= RERAM_MEMORY_WORDS);
    printf("  ✓ PASSED\\n");
    
    printf("All unit tests passed! ✓\\n");
}
```

## 🔍 Debug and Troubleshooting

### **Debug Functions**
```c
// Enable debug output
void reram_enable_debug(bool enable);

// Print register dump
void reram_debug_print_registers(void);

// Print memory dump
void reram_debug_print_memory(void);

// Example debug session
void debug_reram_issue(void) {
    printf("\\n=== Debug Session ===\\n");
    
    // Enable verbose debug output
    reram_enable_debug(true);
    
    // Print current register state
    printf("Register dump:\\n");
    reram_debug_print_registers();
    
    // Print memory contents
    printf("\\nMemory dump:\\n");
    reram_debug_print_memory();
    
    // Check for hardware errors
    if (reram_has_error()) {
        printf("\\nHardware errors detected:\\n");
        reram_print_error_report();
    }
    
    // Analyze health status
    printf("\\nHealth analysis:\\n");
    for (int word = 0; word < RERAM_MEMORY_WORDS; word++) {
        if (reram_is_word_worn_out(word)) {
            printf("  Word %d: WORN OUT\\n", word);
        } else {
            uint8_t cycles = reram_get_word_cycles(word);
            printf("  Word %d: %d cycles\\n", word, cycles);
        }
    }
}
```

### **Common Issues and Solutions**

| Issue | Symptoms | Investigation | Solution |
|-------|----------|---------------|----------|
| **Initialization failure** | `reram_init()` returns error | Check base addresses | Verify hardware connections |
| **Read/write failures** | Operations return errors | Check address validity | Use address bounds checking |
| **Performance degradation** | Slow operations | Check health status | Replace worn-out words |
| **Data corruption** | Wrong read data | Check error flags | Run memory pattern tests |
| **Health warnings** | High write cycle counts | Monitor specific words | Implement wear leveling |

---

**Next**: See `README_Integration_Guide.md` for complete system integration examples and best practices.