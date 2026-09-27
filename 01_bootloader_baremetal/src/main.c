#include <stdint.h>

/* STM32F103RB register definitions, RM0008. No HAL, LL or CMSIS. */
#define REG32(address) (*(volatile uint32_t *)(address))
#define RCC_CR       REG32(0x40021000u)
#define RCC_CFGR     REG32(0x40021004u)
#define RCC_APB1RSTR REG32(0x40021010u)
#define RCC_APB2ENR  REG32(0x40021018u)
#define RCC_APB1ENR  REG32(0x4002101Cu)
#define GPIOA_CRL    REG32(0x40010800u)
#define GPIOA_BSRR   REG32(0x40010810u)
#define USART2_SR    REG32(0x40004400u)
#define USART2_DR    REG32(0x40004404u)
#define USART2_BRR   REG32(0x40004408u)
#define USART2_CR1   REG32(0x4000440Cu)
#define USART2_CR2   REG32(0x40004410u)
#define USART2_CR3   REG32(0x40004414u)
#define USART_SR_RXNE (1u << 5)
#define USART_SR_TXE  (1u << 7)
#define USART_SR_ERRORS 0x0Fu /* ORE, NE, FE, PE */
#define POLL_LIMIT 1000000u

/* Volatile forces runtime reads so startup initialization is actually checked. */
static volatile uint32_t data_probe = 0x12345678u;
static volatile uint32_t bss_probe;
volatile uint32_t uart_rx_errors;
volatile uint32_t fault_code;

static void stop(uint32_t code)
{
    fault_code = code; /* Inspect with optional SWD if no UART output is possible. */
    for (;;) {
        __asm volatile ("nop");
    }
}

static void clock_init(void)
{
    uint32_t remaining = POLL_LIMIT;
    RCC_CR |= 1u; /* HSION; retain factory HSI trim. */
    while ((RCC_CR & (1u << 1)) == 0u) {
        if (--remaining == 0u) { stop(1u); }
    }
    RCC_CFGR &= ~3u; /* SW = HSI */
    remaining = POLL_LIMIT;
    while ((RCC_CFGR & (3u << 2)) != 0u) {
        if (--remaining == 0u) { stop(2u); }
    }
    /* HPRE, PPRE1, PPRE2 = /1. SYSCLK/HCLK/PCLK1/PCLK2 = nominal 8 MHz. */
    RCC_CFGR &= ~((15u << 4) | (7u << 8) | (7u << 11));
}

static void uart_init(void)
{
    RCC_APB2ENR |= (1u << 2); /* GPIOA clock */
    RCC_APB1ENR |= (1u << 17); /* USART2 clock */
    (void)RCC_APB2ENR;
    (void)RCC_APB1ENR;
    RCC_APB1RSTR |= (1u << 17);
    RCC_APB1RSTR &= ~(1u << 17);

    /* Reset default mapping: PA2 TX, PA3 RX.
       PA2: alternate-function push-pull, 2 MHz (0xA).
       PA3: input with pull-up (0x8), idle UART level is high. */
    GPIOA_BSRR = (1u << 3);
    GPIOA_CRL = (GPIOA_CRL & ~0x0000FF00u) | 0x00008A00u;
    USART2_CR1 = 0u;
    USART2_CR2 = 0u; /* One stop bit */
    USART2_CR3 = 0u; /* No hardware flow control */
    /* Round PCLK1/baud: 8,000,000/115,200 -> 69 = 0x45.
       Nominal actual baud is 115,942 (+0.64%), plus HSI tolerance. */
    USART2_BRR = 0x45u;
    USART2_CR1 = (1u << 13) | (1u << 3) | (1u << 2); /* UE, TE, RE; 8N1 */
}

static void uart_putc(uint8_t byte)
{
    uint32_t remaining = POLL_LIMIT;
    while ((USART2_SR & USART_SR_TXE) == 0u) {
        if (--remaining == 0u) { stop(3u); }
    }
    USART2_DR = byte;
}

static void uart_puts(const char *text)
{
    while (*text != '\0') { uart_putc((uint8_t)*text++); }
}

int main(void)
{
    const uint32_t startup_ok =
        (data_probe == 0x12345678u) && (bss_probe == 0u);
    clock_init();
    uart_init();
    uart_puts("\r\nbootloader\r\n");
    if (!startup_ok) {
        uart_puts("startup: FAIL (.data/.bss)\r\n");
        stop(4u);
    }
    uart_puts("startup: OK (.data/.bss)\r\n"
              "USART2 PA2/PA3 | 115200 8N1 | HSI 8 MHz\r\n"
              "echo ready\r\n");

    for (;;) {
        const uint32_t status = USART2_SR;
        if ((status & (USART_SR_RXNE | USART_SR_ERRORS)) != 0u) {
            /* SR read followed by DR read also clears receive error flags. */
            const uint8_t byte = (uint8_t)USART2_DR;
            if ((status & USART_SR_ERRORS) != 0u) {
                ++uart_rx_errors;
            } else if ((status & USART_SR_RXNE) != 0u) {
                uart_putc(byte); /* Exact byte echo, including CR/LF and UTF-8. */
            }
        }
        /* Waiting for user input is intentionally unbounded; no transaction
           is in progress. Continuous bulk traffic is outside this demo. */
    }
}

