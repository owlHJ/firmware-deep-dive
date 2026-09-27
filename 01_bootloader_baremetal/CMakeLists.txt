cmake_minimum_required(VERSION 3.20)
project(startup_uart2 LANGUAGES C ASM)

add_executable(startup_uart2 startup/startup_stm32f103rb.S src/main.c)
set_target_properties(startup_uart2 PROPERTIES SUFFIX ".elf" C_STANDARD 11 C_EXTENSIONS OFF)
target_compile_options(startup_uart2 PRIVATE
    -mcpu=cortex-m3 -mthumb -g3 -Og
    -ffreestanding -fno-builtin -ffunction-sections -fdata-sections
    -Wall -Wextra -Werror -Wa,--noexecstack)
set(LINKER_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/linker/stm32f103rb.ld")
target_link_options(startup_uart2 PRIVATE
    -mcpu=cortex-m3 -mthumb -nostdlib
    "-T${LINKER_SCRIPT}" -Wl,--gc-sections -Wl,--build-id=none
    "-Wl,-Map=${CMAKE_CURRENT_BINARY_DIR}/startup_uart2.map")
set_property(TARGET startup_uart2 APPEND PROPERTY LINK_DEPENDS "${LINKER_SCRIPT}")
add_custom_command(TARGET startup_uart2 POST_BUILD
    COMMAND "${ARM_OBJCOPY}" -O binary "$<TARGET_FILE:startup_uart2>" "${CMAKE_CURRENT_BINARY_DIR}/startup_uart2.bin"
    COMMAND "${ARM_OBJCOPY}" -O ihex "$<TARGET_FILE:startup_uart2>" "${CMAKE_CURRENT_BINARY_DIR}/startup_uart2.hex"
    COMMAND "${ARM_SIZE}" "$<TARGET_FILE:startup_uart2>"
    BYPRODUCTS "${CMAKE_CURRENT_BINARY_DIR}/startup_uart2.bin" "${CMAKE_CURRENT_BINARY_DIR}/startup_uart2.hex"
    VERBATIM)
