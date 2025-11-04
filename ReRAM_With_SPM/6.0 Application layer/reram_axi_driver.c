/*
 * ReRAM AXI4-Lite Driver Implementation
 * 
 * Complete implementation of enhanced ReRAM memory controller driver for AXI4-Lite interface.
 * Provides high-level functions for memory access, health monitoring, and diagnostics with
 * production-ready error handling and address validation.
 * 
 * Enhanced Features:
 * - Address bounds checking preventing silent truncation
 * - Protocol compliance for worn-out cell handling
 * - Comprehensive endurance monitoring with health scoring
 * - Robust error detection and recovery
 * - Production-ready wear leveling support
 * 
 * Architecture: Clean separation between AXI transport and ReRAM-specific logic
 */

#include "reram_axi_driver.h"
#include <stdio.h>
#include <string.h>

//=============================================================================
// Global Variables
//=============================================================================
static reram_config_t g_reram_config = {0};
static bool g_reram_initialized = false;

//=============================================================================
// Initialization and Configuration
//=============================================================================

bool reram_init(reram_config_t *config, uint32_t ctrl_base_addr) {
    if (!config) return false;
    
    // Store configuration
    g_reram_config = *config;
    g_reram_config.base_addr = ctrl_base_addr;
    
    // Read hardware configuration
    uint32_t hw_config = reram_read_reg(RERAM_REG_CONFIG);
    uint32_t endurance_config = reram_read_reg(RERAM_REG_ENDURANCE_LIMITS);
    
    g_reram_config.max_write_cycles = endurance_config & 0xFF;
    g_reram_config.warning_threshold = (endurance_config >> 8) & 0xFF;
    
    // Clear any existing errors
    reram_clear_errors();
    
    g_reram_initialized = true;
    
    printf("Enhanced ReRAM Controller Initialized:\n");
    printf("  Memory: %d words (%d bytes) with address validation\n", 
           g_reram_config.memory_words, g_reram_config.memory_size);
    printf("  Max Write Cycles: %d (enhanced endurance limit)\n", g_reram_config.max_write_cycles);
    printf("  Warning Threshold: %d%% (configurable health monitoring)\n", g_reram_config.warning_threshold);
    printf("  Enhanced Features: Address bounds checking, protocol compliance, wear leveling\n");
    printf("  Architecture: Clean separation - Memory controller handles all ReRAM-specific logic\n");
    
    return true;
}

void reram_get_config(reram_config_t *config) {
    if (config && g_reram_initialized) {
        *config = g_reram_config;
    }
}

bool reram_set_warning_threshold(uint8_t threshold_percent) {
    if (!g_reram_initialized || threshold_percent > 100) return false;
    
    uint32_t current = reram_read_reg(RERAM_REG_ENDURANCE_LIMITS);
    uint32_t new_val = (current & 0xFFFF00FF) | ((uint32_t)threshold_percent << 8);
    
    reram_write_reg(RERAM_REG_ENDURANCE_LIMITS, new_val);
    g_reram_config.warning_threshold = threshold_percent;
    
    return true;
}

//=============================================================================
// Memory Operations
//=============================================================================

uint32_t reram_read_word(uint16_t word_addr) {
    if (!g_reram_initialized) {
        printf("ERROR: ReRAM not initialized\n");
        return 0xDEADBEEF;  // Error indicator
    }
    
    // Enhanced address validation (prevents silent truncation)
    if (!RERAM_VALIDATE_ADDR(word_addr)) {
        printf("ERROR: Address %d out of bounds (max: %d) - AXI bounds checking active\n", 
               word_addr, g_reram_config.memory_words - 1);
        return 0xDEADBEEF;  // Error indicator
    }
    
    RERAM_WAIT_READY();
    uint32_t data = reram_read_memory_direct(word_addr);
    
    if (RERAM_CHECK_ERROR()) {
        printf("ERROR: Read failed at word %d (memory controller rejected operation)\n", word_addr);
        return 0xERR0R000;  // Different error indicator for operation failure
    }
    
    return data;
}

bool reram_write_word(uint16_t word_addr, uint32_t data) {
    if (!g_reram_initialized) {
        printf("ERROR: ReRAM not initialized\n");
        return false;
    }
    
    // Enhanced address validation (prevents silent truncation)
    if (!RERAM_VALIDATE_ADDR(word_addr)) {
        printf("ERROR: Address %d out of bounds (max: %d) - AXI bounds checking active\n", 
               word_addr, g_reram_config.memory_words - 1);
        return false;
    }
    
    // Check if word is worn out before attempting write
    if (reram_is_word_worn_out(word_addr)) {
        printf("WARNING: Word %d is worn out - memory controller will reject operation\n", word_addr);
        // Continue anyway to let memory controller handle rejection properly
    }
    
    RERAM_WAIT_READY();
    reram_write_memory_direct(word_addr, data);
    RERAM_WAIT_READY();
    
    if (RERAM_CHECK_ERROR()) {
        printf("ERROR: Write failed at word %d (memory controller rejected: busy/worn-out/failure)\n", word_addr);
        return false;
    }
    
    return true;
}

bool reram_read_burst(uint16_t start_addr, uint32_t *buffer, uint16_t word_count) {
    if (!g_reram_initialized || !buffer || 
        start_addr + word_count > g_reram_config.memory_words) {
        return false;
    }
    
    for (uint16_t i = 0; i < word_count; i++) {
        buffer[i] = reram_read_word(start_addr + i);
        if (RERAM_CHECK_ERROR()) {
            printf("ERROR: Burst read failed at word %d\n", start_addr + i);
            return false;
        }
    }
    
    return true;
}

bool reram_write_burst(uint16_t start_addr, const uint32_t *buffer, uint16_t word_count) {
    if (!g_reram_initialized || !buffer || 
        start_addr + word_count > g_reram_config.memory_words) {
        return false;
    }
    
    for (uint16_t i = 0; i < word_count; i++) {
        if (!reram_write_word(start_addr + i, buffer[i])) {
            printf("ERROR: Burst write failed at word %d\n", start_addr + i);
            return false;
        }
    }
    
    return true;
}

//=============================================================================
// Status and Health Monitoring
//=============================================================================

void reram_get_status(reram_status_t *status) {
    if (!status || !g_reram_initialized) return;
    
    uint32_t status_reg = reram_read_reg(RERAM_REG_STATUS);
    uint32_t ops_reg = reram_read_reg(RERAM_REG_TOTAL_OPS);
    
    status->busy = (status_reg & RERAM_STATUS_BUSY) != 0;
    status->total_reads = ops_reg & 0xFFFF;
    status->total_writes = (ops_reg >> 16) & 0xFFFF;
    status->active_word = (status_reg >> 16) & 0xFFFF;
}

void reram_get_health(reram_health_t *health) {
    if (!health || !g_reram_initialized) return;
    
    uint32_t health_reg = reram_read_reg(RERAM_REG_HEALTH_SUMMARY);
    
    health->healthy_words = health_reg & 0xFF;
    health->warning_words = (health_reg >> 8) & 0xFF;
    health->critical_words = (health_reg >> 16) & 0xFF;
    health->worn_words = (health_reg >> 24) & 0xFF;
}

void reram_get_error_info(reram_error_info_t *error_info) {
    if (!error_info || !g_reram_initialized) return;
    
    uint32_t error_count = reram_read_reg(RERAM_REG_ERROR_COUNT);
    uint32_t last_addr = reram_read_reg(RERAM_REG_LAST_ERROR_ADDR);
    uint32_t last_code = reram_read_reg(RERAM_REG_LAST_ERROR_CODE);
    
    error_info->operation_errors = error_count & 0xFFFF;
    error_info->endurance_errors = (error_count >> 16) & 0xFFFF;
    error_info->last_error_addr = last_addr;
    error_info->last_error_type = last_code & 0xFF;
    error_info->last_error_word = (last_code >> 8) & 0xFF;
    error_info->last_error_time = (last_code >> 16) & 0xFFFF;
}

bool reram_clear_errors(void) {
    if (!g_reram_initialized) return false;
    
    reram_write_reg(RERAM_REG_CONTROL, RERAM_CTRL_ERROR_CLEAR);
    
    // Wait a bit for clearing to complete
    for (volatile int i = 0; i < 1000; i++);
    
    // Clear the control bit
    reram_write_reg(RERAM_REG_CONTROL, 0);
    
    return true;
}

//=============================================================================
// Endurance Monitoring
//=============================================================================

uint8_t reram_get_word_cycles(uint16_t word_addr) {
    if (!g_reram_initialized || word_addr >= g_reram_config.memory_words) {
        return 0xFF;  // Error indicator
    }
    
    return RERAM_GET_WORD_CYCLES(word_addr);
}

bool reram_get_all_word_cycles(uint8_t *cycles_array, uint16_t max_words) {
    if (!g_reram_initialized || !cycles_array) return false;
    
    uint16_t words_to_read = (max_words < g_reram_config.memory_words) ? 
                            max_words : g_reram_config.memory_words;
    
    // Read packed cycle data from registers
    for (int reg = 0; reg < 4; reg++) {  // 4 registers for 16 words
        uint32_t packed_cycles = reram_read_reg(RERAM_REG_CYCLES_0_3 + (reg * 4));
        
        for (int word = 0; word < 4; word++) {
            uint16_t word_addr = reg * 4 + word;
            if (word_addr >= words_to_read) break;
            
            cycles_array[word_addr] = (packed_cycles >> (word * 8)) & 0xFF;
        }
    }
    
    return true;
}

uint32_t reram_get_word_cell_errors(uint16_t word_addr) {
    if (!g_reram_initialized || word_addr >= g_reram_config.memory_words) {
        return 0xFFFFFFFF;  // Error indicator
    }
    
    uint32_t offset = RERAM_REG_CELL_ERRORS_BASE + (word_addr * 4);
    return reram_read_reg(offset);
}

bool reram_is_word_worn_out(uint16_t word_addr) {
    if (!g_reram_initialized || word_addr >= g_reram_config.memory_words) {
        return false;
    }
    
    // Check worn cells bitmap
    if (word_addr < 32) {
        uint32_t bitmap = reram_read_reg(RERAM_REG_WORN_CELLS_LOW);
        return (bitmap & (1 << word_addr)) != 0;
    } else if (word_addr < 64) {
        uint32_t bitmap = reram_read_reg(RERAM_REG_WORN_CELLS_HIGH);
        return (bitmap & (1 << (word_addr - 32))) != 0;
    }
    
    return false;
}

//=============================================================================
// Diagnostic and Utility Functions
//=============================================================================

bool reram_wait_ready(uint32_t timeout_ms) {
    if (!g_reram_initialized) return false;
    
    uint32_t count = 0;
    uint32_t max_count = timeout_ms * 1000;  // Assume 1MHz loop rate
    
    while (reram_is_busy() && count < max_count) {
        count++;
    }
    
    return !reram_is_busy();
}

void reram_print_health_report(void) {
    if (!g_reram_initialized) {
        printf("ERROR: ReRAM not initialized\n");
        return;
    }
    
    reram_health_t health;
    reram_status_t status;
    reram_error_info_t errors;
    
    reram_get_health(&health);
    reram_get_status(&status);
    reram_get_error_info(&errors);
    
    printf("\\n=== ReRAM Health Report ===\\n");
    printf("Memory Status: %s\\n", status.busy ? "BUSY" : "READY");
    printf("Total Operations: %d reads, %d writes\\n", 
           status.total_reads, status.total_writes);
    
    printf("\\nWord Health Summary:\\n");
    printf("  Healthy words:  %d/%d\\n", health.healthy_words, g_reram_config.memory_words);
    printf("  Warning words:  %d (>50%% cycles)\\n", health.warning_words);
    printf("  Critical words: %d (>80%% cycles)\\n", health.critical_words);
    printf("  Worn-out words: %d\\n", health.worn_words);
    
    printf("\\nError Summary:\\n");
    printf("  Operation errors: %d\\n", errors.operation_errors);
    printf("  Endurance errors: %d\\n", errors.endurance_errors);
    
    if (errors.operation_errors > 0 || errors.endurance_errors > 0) {
        printf("  Last error: Type %d at address 0x%08X\\n", 
               errors.last_error_type, errors.last_error_addr);
    }
    
    // Show individual word cycles for critical/worn words
    printf("\\nDetailed Word Status:\\n");
    for (uint16_t i = 0; i < g_reram_config.memory_words; i++) {
        uint8_t cycles = reram_get_word_cycles(i);
        bool worn = reram_is_word_worn_out(i);
        
        if (worn || cycles >= 100) {  // Show problematic words
            printf("  Word %2d: %3d cycles", i, cycles);
            if (worn) {
                printf(" [WORN OUT]");
            } else if (cycles >= 160) {
                printf(" [CRITICAL]");
            } else if (cycles >= 100) {
                printf(" [WARNING]");
            }
            printf("\\n");
        }
    }
    
    printf("=========================\\n\\n");
}

void reram_print_error_report(void) {
    if (!g_reram_initialized) {
        printf("ERROR: ReRAM not initialized\\n");
        return;
    }
    
    reram_error_info_t errors;
    reram_get_error_info(&errors);
    
    printf("\\n=== ReRAM Error Report ===\\n");
    printf("Total operation errors: %d\\n", errors.operation_errors);
    printf("Total endurance errors: %d\\n", errors.endurance_errors);
    
    if (errors.operation_errors > 0 || errors.endurance_errors > 0) {
        printf("\\nLast Error Details:\\n");
        printf("  Address: 0x%08X (Word %d)\\n", 
               errors.last_error_addr, errors.last_error_word);
        printf("  Type: ");
        switch (errors.last_error_type) {
            case RERAM_ERR_ENDURANCE: printf("Endurance (cell worn out)"); break;
            case RERAM_ERR_OPERATION: printf("Operation failed (busy/worn-out/failure)"); break;
            case RERAM_ERR_ADDRESS:   printf("Address out of range"); break;
            case RERAM_ERR_ALIGNMENT: printf("Misaligned access"); break;
            default:                  printf("Unknown (%d)", errors.last_error_type); break;
        }
        printf("\\n");
        printf("  Timestamp: %d\\n", errors.last_error_time);
    } else {
        printf("No errors recorded.\\n");
    }
    
    printf("=========================\\n\\n");
}

bool reram_run_basic_test(void) {
    if (!g_reram_initialized) {
        printf("ERROR: ReRAM not initialized\\n");
        return false;
    }
    
    printf("Running ReRAM Basic Test...\\n");
    
    // Test patterns
    uint32_t test_patterns[] = {
        0x00000000, 0xFFFFFFFF, 0xAAAAAAAA, 0x55555555,
        0x12345678, 0x87654321, 0xDEADBEEF, 0xCAFEBABE
    };
    int num_patterns = sizeof(test_patterns) / sizeof(test_patterns[0]);
    
    bool all_passed = true;
    int tests_run = 0;
    int tests_passed = 0;
    
    // Test each available word with each pattern
    for (uint16_t word = 0; word < g_reram_config.memory_words; word++) {
        // Skip worn-out words
        if (reram_is_word_worn_out(word)) {
            printf("  Word %d: SKIPPED (worn out)\\n", word);
            continue;
        }
        
        for (int p = 0; p < num_patterns; p++) {
            tests_run++;
            
            // Write pattern
            if (!reram_write_word(word, test_patterns[p])) {
                printf("  Word %d Pattern 0x%08X: WRITE FAILED\\n", word, test_patterns[p]);
                all_passed = false;
                continue;
            }
            
            // Read back and verify
            uint32_t read_data = reram_read_word(word);
            if (read_data == test_patterns[p]) {
                tests_passed++;
            } else {
                printf("  Word %d Pattern 0x%08X: VERIFY FAILED (got 0x%08X)\\n", 
                       word, test_patterns[p], read_data);
                all_passed = false;
            }
        }
    }
    
    printf("Basic Test Complete: %d/%d tests passed\\n", tests_passed, tests_run);
    
    if (all_passed) {
        printf("*** ALL BASIC TESTS PASSED! ***\\n");
    } else {
        printf("*** SOME TESTS FAILED ***\\n");
        reram_print_error_report();
    }
    
    return all_passed;
}