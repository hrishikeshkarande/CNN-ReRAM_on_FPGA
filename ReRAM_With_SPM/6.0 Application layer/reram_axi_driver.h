/*
 * ReRAM AXI4-Lite Driver Header
 * 
 * This header provides comprehensive access to all ReRAM memory controller features
 * through the AXI4-Lite interface. Designed for ARM processors and embedded systems
 * with enhanced reliability and production-ready error handling.
 * 
 * Enhanced Features (Latest Version):
 * - Memory-mapped register access with address validation
 * - Comprehensive endurance monitoring and health tracking
 * - Enhanced error reporting with proper AXI error responses
 * - Per-word cycle counting and cell-level error detection
 * - Fixed protocol compliance for worn-out cell handling
 * - Address bounds checking preventing silent truncation
 * - Production-ready wear leveling support
 * 
 * Architecture Benefits:
 * - Clean separation: AXI handles transport, Memory controller handles ReRAM logic
 * - Memory controller is single source of truth for operational decisions
 * - Enhanced address validation prevents data corruption
 * - Protocol compliance ensures reliable handshaking even with worn-out cells
 */

#ifndef RERAM_AXI_DRIVER_H
#define RERAM_AXI_DRIVER_H

#include <stdint.h>
#include <stdbool.h>

//=============================================================================
// Base Addresses (configurable - matches example ARM system)
//=============================================================================
#ifndef RERAM_MEMORY_BASE
#define RERAM_MEMORY_BASE    0x20000000  // ReRAM memory region (64 bytes)
#endif

#ifndef RERAM_CTRL_BASE
#define RERAM_CTRL_BASE      0x40000000  // Control/status registers (256 bytes)
#endif

//=============================================================================
// System Configuration (matches enhanced ReRAM controller)
//=============================================================================
#define RERAM_MEMORY_WORDS   16          // 16 words = 64 bytes (Z7-20 conservative)
#define RERAM_MEMORY_SIZE    64          // Memory size in bytes
#define RERAM_MAX_CYCLES     200         // Enhanced endurance limit
#define RERAM_ADDR_WIDTH     4           // 4-bit addressing for 16 words

//=============================================================================
// Register Offsets
//=============================================================================

// Basic Control/Status Registers (0x00-0x1F)
#define RERAM_REG_STATUS           0x00  // Status register (RO)
#define RERAM_REG_CONTROL          0x04  // Control register (RW)
#define RERAM_REG_ERROR_COUNT      0x08  // Error counts (RO)
#define RERAM_REG_TOTAL_OPS        0x0C  // Total operations (RO)
#define RERAM_REG_LAST_ERROR_ADDR  0x10  // Last error address (RO)
#define RERAM_REG_LAST_ERROR_CODE  0x14  // Last error code details (RO)
#define RERAM_REG_WORN_CELLS_LOW   0x18  // Worn cells bitmap 0-31 (RO)
#define RERAM_REG_WORN_CELLS_HIGH  0x1C  // Worn cells bitmap 32-63 (RO)

// Configuration Registers (0x20-0x3F)
#define RERAM_REG_CONFIG           0x20  // ReRAM timing config (RO)
#define RERAM_REG_ENDURANCE_LIMITS 0x24  // Endurance settings (RW)

// Per-Word Write Cycles (0x40-0x4F) - Packed format
#define RERAM_REG_CYCLES_0_3       0x40  // Words 0-3 write cycles
#define RERAM_REG_CYCLES_4_7       0x44  // Words 4-7 write cycles  
#define RERAM_REG_CYCLES_8_11      0x48  // Words 8-11 write cycles
#define RERAM_REG_CYCLES_12_15     0x4C  // Words 12-15 write cycles

// Per-Word Cell Error Details (0x80-0xBF)
#define RERAM_REG_CELL_ERRORS_BASE 0x80  // Base for individual word cell errors

// Health Summary (0xC0-0xFF)
#define RERAM_REG_HEALTH_SUMMARY   0xC0  // Overall health statistics

//=============================================================================
// Register Bit Definitions
//=============================================================================

// Status Register (0x00) bit definitions
#define RERAM_STATUS_BUSY          (1 << 0)   // Memory controller busy
#define RERAM_STATUS_ERROR         (1 << 1)   // Global error flag
#define RERAM_STATUS_ENDURANCE_ERR (1 << 2)   // Endurance error
#define RERAM_STATUS_OPERATION_ERR (1 << 3)   // Operation error
#define RERAM_STATUS_PROGRESS_MASK (0xFF << 8) // Operation progress
#define RERAM_STATUS_ACTIVE_WORD_MASK (0xFFFF << 16) // Active word address

// Control Register (0x04) bit definitions
#define RERAM_CTRL_ERROR_CLEAR     (1 << 0)   // Clear all errors
#define RERAM_CTRL_DEBUG_MODE      (1 << 1)   // Enable debug mode
#define RERAM_CTRL_ENDURANCE_MON   (1 << 2)   // Endurance monitoring enable
#define RERAM_CTRL_AUTO_REFRESH    (1 << 3)   // Auto-refresh enable

// Error type codes (for Last Error Code register) - Enhanced
#define RERAM_ERR_NONE             0x00       // No error
#define RERAM_ERR_ENDURANCE        0x01       // Cell worn out
#define RERAM_ERR_OPERATION        0x02       // Operation failed (includes busy/worn-out)
#define RERAM_ERR_ADDRESS          0x03       // Address out of range (AXI bounds check)
#define RERAM_ERR_ALIGNMENT        0x04       // Misaligned access
#define RERAM_ERR_PROTOCOL         0x05       // AXI protocol violation
#define RERAM_ERR_TRUNCATION       0x06       // Address truncation prevented

//=============================================================================
// AXI Response Code Mappings (for software reference)
//=============================================================================
#define AXI_RESP_OKAY              0x00       // Successful operation
#define AXI_RESP_EXOKAY            0x01       // Exclusive access okay
#define AXI_RESP_SLVERR            0x02       // Slave error (address/operation invalid)
#define AXI_RESP_DECERR            0x03       // Decode error (address unmapped)
#define AXI_RESP_SLVERR            0x02       // Slave error (address/operation invalid)
#define AXI_RESP_DECERR            0x03       // Decode error (address unmapped)
#define RERAM_ERR_ADDRESS          0x03       // Address out of range
#define RERAM_ERR_ALIGNMENT        0x04       // Misaligned access

//=============================================================================
// Data Structures
//=============================================================================

typedef struct {
    uint32_t base_addr;          // Base address of ReRAM controller
    uint32_t memory_base;        // Memory region base address  
    uint32_t memory_size;        // Memory size in bytes
    uint16_t memory_words;       // Number of 32-bit words
    uint8_t  max_write_cycles;   // Maximum write cycles per cell
    uint8_t  warning_threshold;  // Warning threshold (% of max cycles)
} reram_config_t;

typedef struct {
    uint8_t healthy_words;       // Number of healthy words
    uint8_t warning_words;       // Words with >50% cycles used
    uint8_t critical_words;      // Words with >80% cycles used  
    uint8_t worn_words;          // Completely worn out words
} reram_health_t;

typedef struct {
    uint16_t operation_errors;   // Total operation errors
    uint16_t endurance_errors;   // Total endurance errors
    uint32_t last_error_addr;    // Address of last error
    uint8_t  last_error_type;    // Type of last error
    uint8_t  last_error_word;    // Word index of last error
    uint16_t last_error_time;    // Timestamp of last error
} reram_error_info_t;

typedef struct {
    uint16_t total_reads;        // Total read operations
    uint16_t total_writes;       // Total write operations
    bool     busy;               // Controller busy status
    uint16_t active_word;        // Currently active word (if busy)
} reram_status_t;

//=============================================================================
// Function Prototypes
//=============================================================================

// Initialization and configuration
bool reram_init(reram_config_t *config, uint32_t ctrl_base_addr);
void reram_get_config(reram_config_t *config);
bool reram_set_warning_threshold(uint8_t threshold_percent);

// Memory operations
uint32_t reram_read_word(uint16_t word_addr);
bool reram_write_word(uint16_t word_addr, uint32_t data);
bool reram_read_burst(uint16_t start_addr, uint32_t *buffer, uint16_t word_count);
bool reram_write_burst(uint16_t start_addr, const uint32_t *buffer, uint16_t word_count);

// Status and health monitoring
void reram_get_status(reram_status_t *status);
void reram_get_health(reram_health_t *health);
void reram_get_error_info(reram_error_info_t *error_info);
bool reram_clear_errors(void);

// Endurance monitoring
uint8_t reram_get_word_cycles(uint16_t word_addr);
bool reram_get_all_word_cycles(uint8_t *cycles_array, uint16_t max_words);
uint32_t reram_get_word_cell_errors(uint16_t word_addr);
bool reram_is_word_worn_out(uint16_t word_addr);

// Diagnostic and utility functions
bool reram_wait_ready(uint32_t timeout_ms);
void reram_print_health_report(void);
void reram_print_error_report(void);
bool reram_run_basic_test(void);

//=============================================================================
// Inline Helper Functions
//=============================================================================

// Register access helpers
static inline uint32_t reram_read_reg(uint32_t offset) {
    volatile uint32_t *reg = (volatile uint32_t *)(RERAM_CTRL_BASE + offset);
    return *reg;
}

static inline void reram_write_reg(uint32_t offset, uint32_t value) {
    volatile uint32_t *reg = (volatile uint32_t *)(RERAM_CTRL_BASE + offset);
    *reg = value;
}

// Quick status checks
static inline bool reram_is_busy(void) {
    return (reram_read_reg(RERAM_REG_STATUS) & RERAM_STATUS_BUSY) != 0;
}

static inline bool reram_has_error(void) {
    return (reram_read_reg(RERAM_REG_STATUS) & RERAM_STATUS_ERROR) != 0;
}

static inline bool reram_has_endurance_error(void) {
    return (reram_read_reg(RERAM_REG_STATUS) & RERAM_STATUS_ENDURANCE_ERR) != 0;
}

// Memory access helpers
static inline uint32_t reram_read_memory_direct(uint16_t word_addr) {
    volatile uint32_t *mem = (volatile uint32_t *)(RERAM_MEMORY_BASE + (word_addr * 4));
    return *mem;
}

static inline void reram_write_memory_direct(uint16_t word_addr, uint32_t data) {
    volatile uint32_t *mem = (volatile uint32_t *)(RERAM_MEMORY_BASE + (word_addr * 4));
    *mem = data;
}

//=============================================================================
// Macros for Common Operations
//=============================================================================

#define RERAM_WAIT_READY() \
    do { while (reram_is_busy()); } while(0)

#define RERAM_CHECK_ERROR() \
    (reram_has_error())

#define RERAM_GET_WORD_CYCLES(addr) \
    ((reram_read_reg(RERAM_REG_CYCLES_0_3 + ((addr >> 2) << 2)) >> ((addr & 3) * 8)) & 0xFF)

#define RERAM_IS_WORD_HEALTHY(addr) \
    (RERAM_GET_WORD_CYCLES(addr) < 100)  // Less than 50% of typical 200 cycle limit

#define RERAM_IS_WORD_CRITICAL(addr) \
    (RERAM_GET_WORD_CYCLES(addr) >= 160) // More than 80% of typical 200 cycle limit

//=============================================================================
// Enhanced Validation Macros (Production Safety)
//=============================================================================

#define RERAM_VALIDATE_ADDR(addr) \
    ((addr) < RERAM_MEMORY_WORDS)

#define RERAM_IS_ADDR_ALIGNED(addr) \
    (((addr) & 0x3) == 0)  // Word-aligned addresses only

#define RERAM_SAFE_WRITE(addr, data) \
    (RERAM_VALIDATE_ADDR(addr) && !reram_is_word_worn_out(addr) && reram_write_word(addr, data))

#define RERAM_SAFE_READ(addr) \
    (RERAM_VALIDATE_ADDR(addr) ? reram_read_word(addr) : 0xDEADBEEF)

#define RERAM_CHECK_HEALTH_CRITICAL() \
    (reram_has_endurance_error() || (reram_read_reg(RERAM_REG_HEALTH_SUMMARY) >> 24) > 0)

#define RERAM_GET_WEAR_LEVEL() \
    ((reram_read_reg(RERAM_REG_HEALTH_SUMMARY) >> 16) & 0xFF)  // Critical word count

#endif // RERAM_AXI_DRIVER_H