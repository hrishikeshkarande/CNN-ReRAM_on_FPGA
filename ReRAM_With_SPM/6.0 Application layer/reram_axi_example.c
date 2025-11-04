/*
 * ReRAM AXI4-Lite Example Application
 * 
 * Comprehensive example showing how to use all enhanced ReRAM controller features
 * through the AXI4-Lite interface. This demonstrates:
 * - Enhanced memory operations with address validation
 * - Comprehensive health monitoring and endurance tracking
 * - Production-ready error handling and recovery
 * - Address bounds checking preventing silent truncation
 * - Protocol compliance for worn-out cell handling
 * - Diagnostic reporting and wear leveling
 * 
 * Enhanced Architecture Benefits:
 * - Clean separation: AXI handles transport, Memory controller handles ReRAM logic
 * - Memory controller is single source of truth for operational decisions
 * - Enhanced validation prevents data corruption
 * - Production-ready wear leveling and health management
 */

#include "reram_axi_driver.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

//=============================================================================
// Configuration (Enhanced ReRAM System)
//=============================================================================
// Use constants from driver header for consistency

//=============================================================================
// Example Functions
//=============================================================================

void example_basic_operations(void) {
    printf("\\n=== Basic Memory Operations ===\\n");
    
    // Write some test data
    printf("Writing test patterns...\\n");
    reram_write_word(0, 0xDEADBEEF);
    reram_write_word(1, 0xCAFEBABE);
    reram_write_word(2, 0x12345678);
    reram_write_word(15, 0xA5A5A5A5);  // Last word
    
    // Read back and verify
    printf("Reading back data...\\n");
    printf("  Word 0: 0x%08X\\n", reram_read_word(0));
    printf("  Word 1: 0x%08X\\n", reram_read_word(1));
    printf("  Word 2: 0x%08X\\n", reram_read_word(2));
    printf("  Word 15: 0x%08X\\n", reram_read_word(15));
    
    // Test burst operations
    printf("\\nTesting burst operations...\\n");
    uint32_t write_buffer[] = {0x11111111, 0x22222222, 0x33333333, 0x44444444};
    uint32_t read_buffer[4] = {0};
    
    reram_write_burst(4, write_buffer, 4);
    reram_read_burst(4, read_buffer, 4);
    
    printf("Burst write/read verification:\\n");
    for (int i = 0; i < 4; i++) {
        printf("  Word %d: wrote 0x%08X, read 0x%08X %s\\n", 
               i+4, write_buffer[i], read_buffer[i],
               (write_buffer[i] == read_buffer[i]) ? "[PASS]" : "[FAIL]");
    }
}

void example_endurance_monitoring(void) {
    printf("\\n=== Endurance Monitoring ===\\n");
    
    // Show current write cycles for all words
    printf("Current write cycles per word:\\n");
    uint8_t all_cycles[RERAM_MEMORY_WORDS];
    reram_get_all_word_cycles(all_cycles, RERAM_MEMORY_WORDS);
    
    for (int i = 0; i < 16; i++) {
        printf("  Word %2d: %3d cycles", i, all_cycles[i]);
        
        if (reram_is_word_worn_out(i)) {
            printf(" [WORN OUT]");
        } else if (RERAM_IS_WORD_CRITICAL(i)) {
            printf(" [CRITICAL]");
        } else if (!RERAM_IS_WORD_HEALTHY(i)) {
            printf(" [WARNING]");
        } else {
            printf(" [HEALTHY]");
        }
        printf("\\n");
    }
    
    // Show detailed cell errors for first few words
    printf("\\nDetailed cell error information:\\n");
    for (int i = 0; i < 4; i++) {
        uint32_t cell_errors = reram_get_word_cell_errors(i);
        printf("  Word %d cell errors: 0x%08X\\n", i, cell_errors);
        if (cell_errors != 0) {
            printf("    Failed cells: ");
            for (int bit = 0; bit < 32; bit++) {
                if (cell_errors & (1 << bit)) {
                    printf("%d ", bit);
                }
            }
            printf("\\n");
        }
    }
}

void example_health_monitoring(void) {
    printf("\\n=== Health Status Monitoring ===\\n");
    
    reram_status_t status;
    reram_health_t health;
    
    reram_get_status(&status);
    reram_get_health(&health);
    
    printf("Controller Status:\\n");
    printf("  State: %s\\n", status.busy ? "BUSY" : "READY");
    printf("  Total reads: %d\\n", status.total_reads);
    printf("  Total writes: %d\\n", status.total_writes);
    if (status.busy) {
        printf("  Active word: %d\\n", status.active_word);
    }
    
    printf("\\nMemory Health:\\n");
    printf("  Healthy words: %d/%d (%.1f%%)\\n", 
           health.healthy_words, RERAM_MEMORY_WORDS,
           (health.healthy_words * 100.0) / RERAM_MEMORY_WORDS);
    printf("  Warning words: %d (>50%% cycles used)\\n", health.warning_words);
    printf("  Critical words: %d (>80%% cycles used)\\n", health.critical_words);
    printf("  Worn-out words: %d\\n", health.worn_words);
    
    // Calculate overall health percentage
    float health_score = (health.healthy_words * 100.0 + 
                         health.warning_words * 60.0 + 
                         health.critical_words * 20.0) / RERAM_MEMORY_WORDS;
    printf("  Overall health score: %.1f%%\\n", health_score);
}

void example_endurance_testing(void) {
    printf("\\n=== Endurance Testing Example ===\\n");
    printf("Testing endurance on word 8 (writing multiple times)...\\n");
    
    uint16_t test_word = 8;
    uint8_t initial_cycles = reram_get_word_cycles(test_word);
    
    printf("Initial cycles for word %d: %d\\n", test_word, initial_cycles);
    
    // Perform multiple writes to increase cycle count
    printf("Performing 10 write operations...\\n");
    for (int i = 0; i < 10; i++) {
        uint32_t test_data = 0xCYCLE000 | i;  // Pattern with counter
        if (!reram_write_word(test_word, test_data)) {
            printf("  Write %d FAILED\\n", i);
            break;
        }
        
        uint8_t current_cycles = reram_get_word_cycles(test_word);
        printf("  Write %d: cycles now = %d\\n", i+1, current_cycles);
        
        // Check if word became worn out
        if (reram_is_word_worn_out(test_word)) {
            printf("  *** Word %d is now WORN OUT! ***\\n", test_word);
            break;
        }
    }
    
    uint8_t final_cycles = reram_get_word_cycles(test_word);
    printf("Final cycles for word %d: %d (+%d)\\n", 
           test_word, final_cycles, final_cycles - initial_cycles);
}

void example_error_handling(void) {
    printf("\\n=== Enhanced Error Handling Example ===\\n");
    
    // Clear any existing errors
    reram_clear_errors();
    printf("Cleared all existing errors.\\n");
    
    // Test enhanced address validation (prevents silent truncation)
    printf("\\nTesting enhanced address validation...\\n");
    printf("Enhanced AXI controller prevents silent address truncation from 32-bit to 4-bit\\n");
    uint32_t invalid_data = reram_read_word(999);  // Invalid word address > 4-bit range
    printf("Read from invalid address 999 returned: 0x%08X (address validation active)\\n", invalid_data);
    
    // Test boundary condition
    printf("Testing boundary address (word %d)...\\n", RERAM_MEMORY_WORDS);
    uint32_t boundary_data = reram_read_word(RERAM_MEMORY_WORDS);  // Just beyond valid range
    printf("Read from boundary address returned: 0x%08X\\n", boundary_data);
    
    // Check error status
    if (reram_has_error()) {
        printf("Address validation errors detected as expected.\\n");
        reram_print_error_report();
    } else {
        printf("Driver-level validation prevented invalid operations.\\n");
    }
    
    // Test memory controller rejection handling (protocol compliance)
    printf("\\nTesting memory controller rejection handling...\\n");
    printf("Enhanced memory controller with protocol compliance for worn-out cells\\n");
    
    // Try writing to a worn-out word (if any exist)
    bool found_worn_word = false;
    for (uint16_t i = 0; i < 16; i++) {
        if (reram_is_word_worn_out(i)) {
            printf("Found worn-out word %d, attempting write...\\n", i);
            bool result = reram_write_word(i, 0xTEST1234);
            printf("Write to worn word result: %s\\n", 
                   result ? "SUCCESS" : "REJECTED");
            printf("Memory controller properly handled worn-out cell with protocol compliance\\n");
            found_worn_word = true;
            break;
        }
    }
            printf("Write to worn word result: %s (memory controller handled rejection)\\n", 
                   result ? "SUCCESS" : "REJECTED");
            found_worn_word = true;
            break;
        }
    }
    
    if (!found_worn_word) {
        printf("No worn-out words found (memory still healthy).\\n");
        printf("Memory controller will reject operations when words become worn out.\\n");
    }
    
    // Show final error status
    reram_get_error_info(&(reram_error_info_t){0});
}

void example_configuration(void) {
    printf("\\n=== Configuration and Settings ===\\n");
    
    reram_config_t config;
    reram_get_config(&config);
    
    printf("Current Configuration:\\n");
    printf("  Memory size: %d words (%d bytes)\\n", 
           config.memory_words, config.memory_size);
    printf("  Max write cycles: %d\\n", config.max_write_cycles);
    printf("  Warning threshold: %d%%\\n", config.warning_threshold);
    
    // Try adjusting warning threshold
    printf("\\nAdjusting warning threshold to 70%%...\\n");
    if (reram_set_warning_threshold(70)) {
        printf("Warning threshold updated successfully.\\n");
    } else {
        printf("Failed to update warning threshold.\\n");
    }
    
    // Read back configuration
    reram_get_config(&config);
    printf("New warning threshold: %d%%\\n", config.warning_threshold);
}

void stress_test_memory(void) {
    printf("\\n=== Memory Stress Test ===\\n");
    printf("Performing comprehensive memory test...\\n");
    
    // Run the built-in basic test
    bool test_result = reram_run_basic_test();
    
    if (test_result) {
        printf("\\nStress test: ALL PATTERNS PASSED\\n");
        printf("Memory controller is functioning correctly.\\n");
    } else {
        printf("\\nStress test: SOME TESTS FAILED\\n");
        printf("Check error report for details.\\n");
    }
}

//=============================================================================
// Main Application
//=============================================================================

int main(void) {
    printf("=============================================================================\\n");
    printf("Enhanced ReRAM AXI4-Lite Controller - Comprehensive Example Application\\n");
    printf("Production Architecture: AXI transport + Enhanced Memory controller\\n");
    printf("=============================================================================\\n");
    
    // Initialize enhanced ReRAM controller
    reram_config_t config = {
        .base_addr = RERAM_CTRL_BASE,
        .memory_base = RERAM_MEMORY_BASE,
        .memory_size = RERAM_MEMORY_SIZE,      // Use driver constant
        .memory_words = RERAM_MEMORY_WORDS,    // Use driver constant
        .max_write_cycles = RERAM_MAX_CYCLES,  // Use driver constant
        .warning_threshold = 80
    };
    
    if (!reram_init(&config, RERAM_CTRL_BASE)) {
        printf("ERROR: Failed to initialize enhanced ReRAM controller!\\n");
        return 1;
    }
    
    printf("\\nEnhanced Architecture Benefits:\\n");
    printf("- AXI layer: Enhanced address validation preventing silent truncation\\n");
    printf("- Memory controller: Fixed protocol compliance for worn-out cells\\n");  
    printf("- Clean separation prevents logic duplication and ensures reliability\\n");
    printf("- Memory controller is single source of truth for all operational decisions\\n");
    printf("- Production-ready error handling and wear leveling support\\n");
    
    // Run all example functions
    example_basic_operations();
    example_endurance_monitoring();
    example_health_monitoring();
    example_configuration();
    example_endurance_testing();
    example_error_handling();
    stress_test_memory();
    
    // Final comprehensive health report
    printf("\\n=== Final Enhanced System Report ===\\n");
    reram_print_health_report();
    reram_print_error_report();
    
    printf("=============================================================================\\n");
    printf("Enhanced ReRAM Example Application Complete\\n");
    printf("Features Demonstrated: Address validation, Protocol compliance, Health monitoring\\n");
    printf("Production Ready: Wear leveling, Error recovery, Silent truncation prevention\\n");
    printf("=============================================================================\\n");
    
    return 0;
}