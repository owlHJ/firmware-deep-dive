# STM32F103RB startup + USART2 echo

CubeIDE/CubeMX 생성 코드, HAL/LL/CMSIS 없이 작성한 첫 bare-metal 이미지입니다. 부팅 시 `bootloader`와 런타임 초기화 검사 결과를 출력하고 수신한 바이트를 USART2로 그대로 반환합니다. 현재는 startup 검증 단계이며 앱 검사·점프·업데이트 기능은 아직 없습니다.

**NUCLEO-F103RB의 기본 연결이라면:** 보드 USB의 ST-LINK 가상 COM 포트가 기본적으로 USART2(PA2/PA3)에 연결됩니다. USB 케이블을 유지하고 별도 UART 배선을 옮길 필요가 없습니다. STM32CubeProgrammer에서 **ST-LINK/SWD**로 Flash했다면 BOOT0도 건드릴 필요가 없습니다. 아래 BOOT0 전환과 USART1 배선은 **외장 USB-UART로 내장 ROM 부트로더를 통해 Flash한 경우에만** 해당합니다. [NUCLEO-64 보드 매뉴얼 UM1724](https://www.st.com/resource/en/user_manual/um1724-.pdf)

## 구성

- `startup/startup_stm32f103rb.S`: 초기 MSP, 59개 벡터 슬롯, VTOR 설정, `.data` 복사, `.bss` 초기화, `main` 호출.
- `linker/stm32f103rb.ld`: Flash 128 KiB / SRAM 20 KiB, 초기 MSP `0x20005000`, 스택 2 KiB 예산 검사.
- `src/main.c`: HSI 8 MHz, APB1 /1, PA2/PA3의 USART2 폴링 송수신. HAL 및 표준 라이브러리 링크 없음.
- 미사용 예외는 `Default_Handler`에서 정지합니다. 인터럽트 기반 수신과 대량 데이터 버퍼링은 구현하지 않았습니다.

## 빌드

Windows PowerShell에서는 저장소 루트에서 아래 **한 줄**을 실행하면 됩니다. `build.cmd`가 PowerShell 실행 정책의 영향을 받지 않는 빌드 스크립트를 호출합니다. 스크립트는 CMake/Ninja를 찾고, Arm GNU Toolchain이 PATH에 없으면 `C:\ST` 아래 설치된 CubeIDE의 컴파일러를 찾아 빌드합니다. CubeIDE의 생성 코드나 IDE 프로젝트는 사용하지 않습니다.

```powershell
.\01_bootloader_baremetal\build.cmd
```

툴체인이 다른 위치에 있다면 `-ToolchainBin`으로 `arm-none-eabi-gcc.exe`가 있는 폴더를 지정합니다. 어느 폴더에서 실행해도 스크립트 자신이 있는 프로젝트를 빌드합니다.

```powershell
.\01_bootloader_baremetal\build.cmd -ToolchainBin 'C:\path\to\arm-gnu-toolchain\bin'
```

`build.ps1`을 직접 실행할 때만 PowerShell 실행 정책의 영향을 받을 수 있습니다. 이때는 아래처럼 해당 프로세스에 한해 허용할 수 있습니다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\01_bootloader_baremetal\build.ps1
```

성공하면 스크립트가 Flash에 기록할 `.bin`의 절대 경로와 시작 주소 `0x08000000`을 출력합니다. 기존 빌드 디렉터리가 다른 컴파일러를 사용한다면 실수로 섞이지 않도록 중단합니다. 이때는 `01_bootloader_baremetal/build/`만 삭제한 뒤 다시 실행합니다.

### CMake를 직접 실행하는 방법

CMake, Ninja, Arm GNU Toolchain이 필요합니다. **아래 명령은 저장소 루트의 PowerShell**에서 실행합니다. 먼저 `cmake --version`, `ninja --version`, `arm-none-eabi-gcc --version`으로 설치를 확인합니다. GNU 도구들이 PATH에 있으면 다음 두 명령으로 빌드합니다.

```powershell
cmake -S 01_bootloader_baremetal -B 01_bootloader_baremetal/build -G Ninja '-DCMAKE_TOOLCHAIN_FILE=cmake/arm-none-eabi.cmake'
cmake --build 01_bootloader_baremetal/build
```

툴체인이 PATH에 없다면 첫 명령에 `'-DARM_TOOLCHAIN_BIN=C:/path/to/toolchain/bin'`을 추가합니다. 여기에는 `arm-none-eabi-gcc.exe`, `arm-none-eabi-objcopy.exe`, `arm-none-eabi-size.exe`가 있어야 합니다. CubeIDE에 포함된 GNU 도구 실행 파일도 단독으로 사용할 수 있으며 IDE 프로젝트나 생성 코드는 필요하지 않습니다. Ninja가 PATH에 없다면 `'-DCMAKE_MAKE_PROGRAM=C:/path/to/ninja.exe'`도 추가합니다. PowerShell에서는 경로가 포함된 `-D...` 인자를 예시처럼 따옴표로 묶습니다.

첫 명령은 `-S`의 소스에서 `CMakeLists.txt`를 읽고 `-B`에 Ninja 빌드 파일을 생성합니다. `cmake/arm-none-eabi.cmake`는 PC용 컴파일러 대신 Arm GNU 컴파일러를 지정하며, 실행 파일을 PC에서 시험 컴파일하려 하지 않도록 구성합니다. 두 번째 명령은 C와 ASM을 컴파일하고 링커 스크립트로 ELF를 만든 다음 BIN, HEX를 추출합니다. 수정 후에는 두 번째 명령만 다시 실행하면 됩니다. 컴파일러나 툴체인 경로를 바꾼 경우에는 **해당 모듈의 `build/`만** 지우고 처음부터 설정합니다.

산출물은 `build/startup_uart2.bin`, `.hex`, `.elf`, `.map`입니다. `build/`는 Git 추적에서 제외합니다. 이 작업 환경에서는 GNU Arm 13.3.1과 CMake/Ninja로 빌드를 확인했습니다. 실제 보드 동작은 아직 검증하지 않았습니다.

| 파일 | 용도 |
| --- | --- |
| `startup_uart2.elf` | 심볼과 디버그 정보를 포함한 실행 파일. SWD 분석과 디스어셈블리에 사용 |
| `startup_uart2.map` | 각 섹션·심볼의 실제 주소와 크기 확인 |
| `startup_uart2.bin` | 주소 정보가 없는 Flash 데이터. STM32CubeProgrammer에서 **시작 주소 `0x08000000`**을 별도로 지정 |
| `startup_uart2.hex` | 각 레코드에 주소가 포함된 Intel HEX. 도구가 주소를 읽어 표시하는지 확인 |

빌드가 끝나면 `arm-none-eabi-size 01_bootloader_baremetal/build/startup_uart2.elf`로 크기를 보고, `arm-none-eabi-objdump -h 01_bootloader_baremetal/build/startup_uart2.elf`로 `.isr_vector`가 `0x08000000`, `.data`가 SRAM에 배치되었는지 확인합니다. BIN의 첫 8바이트는 little-endian으로 초기 MSP `0x20005000`과 Reset 진입 값(Thumb 비트가 1인 `Reset_Handler` 주소)이어야 합니다. **빌드 성공은 보드에서 실행된다는 증거가 아니므로** Flash Verify와 리셋 후 UART 관찰을 따로 수행합니다.

## 설계 근거: startup 코드

리셋 시 Cortex-M3는 부트 설정으로 선택된 메모리의 벡터 테이블에서 첫 워드를 MSP로, 다음 워드를 실행 주소로 읽습니다. 초기 스택 포인터는 하드웨어가 로드하므로 `Reset_Handler` 안에서 다시 `mov sp, ...`를 하지 않습니다. 이 프로젝트에서 Flash 시작점에 놓인 `g_vectors`의 첫 워드는 `_estack=0x20005000`, 두 번째 워드는 Thumb 진입 주소 `Reset_Handler`입니다. 벡터 자체의 순서와 리셋 동작은 [PM0056](https://www.st.com/resource/en/programming_manual/cd00228163.pdf), 외부 IRQ 번호는 [RM0008](https://www.st.com/resource/en/reference_manual/cd00171190-stm32f101-103-105-107-stm32f100-series-armbased-32bit-mcus-stmicroelectronics.pdf)을 기준으로 합니다.

| 코드 | 작성 이유 |
| --- | --- |
| `.syntax unified`, `.cpu cortex-m3`, `.thumb` | Arm GNU 어셈블러에 문법·CPU·Thumb 명령어 집합 지정 |
| `.isr_vector,"a",%progbits`와 `.word` | Flash에 실재하는 32비트 벡터 값 생성. `"a"`는 로드 가능한 섹션 표시 |
| 16개 코어 슬롯 + 43개 외부 IRQ 슬롯 | STM32F103RB medium-density의 벡터 크기 확보. 코어의 예약 슬롯은 0, 현재 사용하지 않는 예외·IRQ는 `Default_Handler`로 연결 |
| `.thumb_func` | 핸들러 심볼이 Thumb 코드임을 어셈블러/링커에 알려 벡터의 진입 비트가 맞도록 함 |
| VTOR에 `g_vectors` 기록 후 `dsb`·`isb` | 예외 벡터의 기준을 현재 Flash 이미지로 명시하고, 이후 예외 처리 전에 변경이 반영되도록 함. 첫 리셋 벡터 선택 자체는 BOOT 핀이 결정 |
| `_sidata` → `_sdata.._edata` 복사 | 초기값이 있는 전역 변수의 **Flash 보관값**을 **SRAM 실행 주소**로 옮김 |
| `_sbss.._ebss`를 0으로 초기화 | 초기값이 없는 전역·정적 변수의 C 언어 초기 상태를 구현 |
| `bl main` 및 반환 시 무한 루프 | 직접 작성한 런타임 초기화 후 C 코드 진입. 임베디드 `main`이 반환하면 갈 호출자가 없으므로 멈춤 |
| `Default_Handler` 무한 루프 | 예상하지 못한 예외가 난 위치에서 SWD 디버거로 멈춤. 예외 원인은 이 핸들러만으로 판별되지 않음 |

벡터의 첫 16개 슬롯은 초기 MSP와 코어 예외용이고 그 뒤 43개는 WWDG부터 USBWakeUp까지의 외부 IRQ용입니다. 현재 코드는 폴링 UART만 사용하므로 외부 IRQ 핸들러를 개별 구현하지 않았습니다. 인터럽트를 활성화하는 기능을 추가할 때는 각 IRQ 번호에 맞게 교체해야 합니다.

코드의 `.data`와 `.bss` 루프는 **4바이트 단위**로 읽고 씁니다. 그래서 링커가 시작·끝 심볼을 4바이트 경계에 놓도록 구성했습니다. `startup_ok` 검사는 실제로 `.data`의 `0x12345678`과 `.bss`의 0을 읽어 이 경로를 확인합니다. VTOR 설정은 현재 이미지에 적절하지만, 나중에 앱으로 점프하면 앱 벡터 주소로 다시 설정해야 합니다.

## 설계 근거: 링크 스크립트

GNU ld는 코드를 어디에 놓을지 C 소스만으로 알 수 없습니다. `stm32f103rb.ld`는 STM32F103RB의 128 KiB Flash와 20 KiB SRAM에 각 섹션의 **실행 주소(VMA)**와 **초기 데이터의 저장 주소(LMA)**를 정합니다. 현재 이미지는 Flash 시작점에서 직접 부팅하며, 앱 분리 전에 사용하는 단일 이미지 배치입니다.

| 항목 | 의미와 선택 이유 |
| --- | --- |
| `ENTRY(Reset_Handler)` | ELF 헤더의 엔트리 심볼 지정. 하드웨어 리셋은 이 값이 아니라 Flash의 벡터 두 번째 워드를 사용 |
| `MEMORY`의 `FLASH (rx)` | 명령어·상수·벡터를 `0x08000000..0x0801FFFF`에 배치. BIN의 다운로드 주소와 같아야 함 |
| `MEMORY`의 `RAM (rwx)` | `.data`, `.bss`, 스택을 `0x20000000..0x20004FFF`에 배치 |
| `_estack=ORIGIN(RAM)+LENGTH(RAM)` | 스택이 아래 주소로 자라므로 초기 MSP는 SRAM **마지막 바이트 다음**인 `0x20005000` |
| `_stack_size=2K` | 이 데모의 최소 스택 예산. 스택 섹션을 2 KiB만큼 채우는 명령은 아니며 실행 중 최대 사용량도 검증하지 않음 |
| `.isr_vector` + `KEEP()` | 벡터를 Flash의 첫 섹션으로 놓고 `--gc-sections`가 참조가 없어 보인다는 이유로 제거하지 못하게 함 |
| `.text`와 `.rodata` | 실행 코드와 배너 문자열 같은 읽기 전용 상수를 Flash에 놓아 SRAM을 절약 |
| `.ARM.extab`, `.ARM.exidx` | Arm 도구가 예외 해제 정보를 생성하는 경우 Flash에 수용. 이 C 전용 데모는 해제 동작에 의존하지 않음 |
| `.data > RAM AT > FLASH` | 실행 중 변수는 SRAM에 두되 초기 바이트는 Flash에 보관. `_sidata=LOADADDR(.data)`가 복사 원본 |
| `.bss (NOLOAD) > RAM` | 0으로 초기화할 SRAM 공간만 예약. BIN에는 0 바이트를 넣지 않고 startup이 지움 |
| `/DISCARD/` | 런타임에 필요 없는 어셈블러 메타데이터와 컴파일러 주석을 출력 이미지에서 제거 |
| `ASSERT` 두 개 | 전역 데이터가 예약한 스택 예산을 침범하거나 벡터 슬롯 수가 달라지면 링크 실패 |

**왜 `ALIGN(4)`인가?** ARM의 벡터 항목과 여기서 다루는 레지스터·복사 워드가 32비트이므로 섹션 경계를 4바이트에 맞춥니다. `.data` 복사와 `.bss` 지우기 루프가 `ldr`/`str`로 **4바이트씩** 진행하므로 시작과 끝이 모두 4의 배수여야 뒤의 데이터를 덮지 않습니다. `.text` 끝 정렬은 다음 Flash 로드 섹션의 시작도 워드 경계에 놓습니다. `ALIGN(4)`는 **스택의 8바이트 ABI 정렬**이나 **VTOR 재배치 시 요구되는 벡터 테이블 정렬**과 다른 개념입니다. 현재 `_estack=0x20005000`은 8바이트 경계이고 벡터는 Flash 시작점에 있습니다. 이후 앱을 다른 Flash 주소로 옮길 때는 해당 벡터 크기와 VTOR 정렬 제약을 별도로 확인해야 합니다.

`ASSERT(_ebss <= _estack - _stack_size)`는 정적 데이터와 예약한 스택 영역의 **배치 충돌**만 잡습니다. 스택 오버플로를 런타임에 감지하지는 못합니다. 또한 링커는 명시하지 않은 새 섹션을 자동 배치할 수 있으므로, 소스를 확장할 때 `.map`과 `objdump -h`를 재확인해야 합니다.

## 설계 근거: main.c

소형 레지스터 데모라서 `REG32()`가 매뉴얼의 절대 주소를 `volatile uint32_t` 접근으로 바꿉니다. `volatile`은 컴파일러가 상태 플래그 반복 읽기를 생략하지 못하게 하지만, 잘못된 주소를 보호하거나 하드웨어 상태 전이를 보장하지는 않습니다. 주소·비트 정의는 [RM0008](https://www.st.com/resource/en/reference_manual/cd00171190-stm32f101-103-105-107-stm32f100-series-armbased-32bit-mcus-stmicroelectronics.pdf)의 RCC, GPIO, USART 레지스터 배치에 대응합니다.

| 코드 | 작성 이유 |
| --- | --- |
| `data_probe`, `bss_probe` | 최적화가 검사를 상수로 치환하지 않도록 `volatile`로 두고 startup의 RAM 초기화 결과를 관찰 |
| `clock_init()` | HSI 준비를 확인하고 SYSCLK를 공칭 8 MHz HSI로 선택. AHB/APB 분주를 /1로 설정해 USART2가 속한 APB1의 PCLK1을 공칭 8 MHz로 만듦. 외부 수정·PLL이 없어 첫 bring-up 범위를 줄임 |
| GPIOA·USART2 클록 활성화와 USART2 리셋 | 클록 게이트가 닫혀 있으면 레지스터 설정이 동작하지 않음. USART2는 ROM 부트로더와의 상태 분리를 위해 초기화 |
| `GPIOA_CRL`의 `0x00008A00` | PA2의 4비트 설정 `0xA`는 alternate push-pull, 2 MHz 출력. PA3의 `0x8`은 입력 풀업/풀다운이며 PA3의 ODR 비트를 BSRR로 1로 만들어 풀업 선택. 상위 핀 설정은 유지 |
| `USART2_BRR=0x45` | PCLK1 8 MHz를 115200 baud로 분주할 때 가장 가까운 정수 분주값 69. 공칭 실제 속도는 약 115942 baud로 +0.64%; HSI 자체 오차는 별도 |
| `CR1=UE|TE|RE`, `CR2=CR3=0` | USART 켜기, 송·수신 사용, 데이터 8비트, 패리티 없음, 스톱 1비트, 흐름 제어 없음 |
| `uart_putc`의 TXE 대기 | 송신 데이터 레지스터가 비기를 기다린 뒤 다음 바이트를 씀. 데이터 전송이 완전히 끝나는 TC와는 다르지만 연속 송신에는 TXE가 적절 |
| `uart_puts`와 CRLF | 최소한의 널 종료 문자열 출력. 터미널에서 줄이 정상적으로 표시되도록 `\r\n` 사용 |
| 수신 루프의 SR 읽기 → DR 읽기 | RXNE와 오류 상태를 먼저 확보하고 DR을 읽어 바이트를 소비. 이 순서는 F1 USART 수신 오류 플래그 해제에도 필요 |
| 오류 바이트 버림, 정상 바이트 에코 | 패리티·프레이밍·노이즈·오버런 오류가 있으면 잘못된 문자를 전송하지 않고 카운터만 증가 |
| `stop()`과 `fault_code` | 준비/송신 대기 실패 시 위치를 기록. 무한 입력 대기는 에코 프로그램의 정상 대기 상태 |

이 구현은 **문자 단위 폴링 데모**입니다. 긴 문자열을 한꺼번에 보내면 에코 송신 동안 다음 수신 바이트가 쌓여 오버런이 날 수 있습니다. `fault_code`는 SWD로 관찰하는 용도이며, 코드 1·2에서는 UART 설정 전이라 메시지로 보이지 않습니다. 통신이 안정되지 않으면 로직 아나라이저로 PA2의 시작 비트 폭을 측정하고 실제 보드의 HSI 편차를 확인합니다.

## Flash 실패와 복구 가능성

**이 이미지를 Flash에 쓴다는 이유만으로 일반적으로 보드가 영구적으로 벽돌이 되지는 않습니다.** 사용자 Flash 코드가 망가져도 BOOT0=1, BOOT1=0에서 시작하는 **ST 내장 System Memory 부트로더**는 별도 영역에 있으므로, 정상 전원·배선·부트 핀·옵션 바이트 조건이라면 USART1으로 다시 접속해 지우고 재기록할 수 있습니다. 다만 보드의 BOOT0 접근이 막혀 있거나 PA9/PA10이 다른 회로에 묶여 있으면 UART 복구가 어려울 수 있습니다. 복구 경로는 [AN2606](https://www.st.com/resource/en/application_note/cd00167594.pdf)을 기준으로 보드 회로도와 함께 확인합니다.

이 이미지는 `0x08000000`부터 기존 **사용자 Flash 내용을 덮어씁니다**. 기존 펌웨어가 필요하면 먼저 백업합니다. STM32CubeProgrammer에서 **Option Bytes, readout protection(RDP), write protection, mass erase** 설정은 임의로 바꾸지 마세요. 특히 보호 설정을 건드리면 재프로그래밍 조건이 달라질 수 있습니다. 지우기·기록 대상 주소와 크기를 확인하고 Verify가 끝난 뒤 BOOT0=0으로 되돌려 리셋합니다.

Flash가 실패하거나 실행이 안 되면 먼저 전원을 끄고 결선을 확인합니다. BOOT0=1/BOOT1=0으로 리셋하고, 어댑터 TX→PA10, RX→PA9, 공통 GND로 **STM32CubeProgrammer의 UART 연결부터 재확인**합니다. 인식되면 `0x08000000`에 다시 기록·Verify 후 BOOT0=0으로 실행합니다. 인식되지 않으면 전압·핀 충돌·COM 점유·부트 핀 상태를 확인하고, 사용 가능한 SWD 프로브가 있으면 그 경로로 칩 상태를 점검합니다. **지금은 실제 보드에서 복구 절차를 검증하지 않았으므로 무조건 복구된다고 보장하지 않습니다.**

## 1. STM32CubeProgrammer로 기록

### 보드 USB / ST-LINK로 기록한 경우

STM32CubeProgrammer 연결 방식이 **ST-LINK**였다면 기록 후 Disconnect하고 보드 USB는 그대로 연결합니다. BOOT0은 기본 Main Flash 부팅 상태를 유지합니다. 터미널에서 Windows 장치 관리자에 보이는 ST-LINK Virtual COM Port를 **115200 / 8-N-1 / 흐름 제어 없음**으로 연 뒤 보드 RESET을 누릅니다. 이 경우 아래 USART1 배선과 BOOT0 전환은 필요하지 않습니다.

### 외장 USB-UART / 내장 ROM 부트로더로 기록한 경우

3.3 V 로직 USB-UART와 보드 GND를 연결합니다. RS-232 신호를 직접 연결하지 않습니다. 전원 공급 방식과 핀 공유 여부는 실제 보드 회로도로 확인합니다.

| USB-UART | 다운로드용 STM32F103RB 핀 |
| --- | --- |
| TX | PA10 / USART1_RX |
| RX | PA9 / USART1_TX |
| GND | GND |

1. BOOT0=1, BOOT1=0으로 설정하고 리셋합니다.
2. STM32CubeProgrammer의 연결 메뉴에서 **UART**와 실제 USB-UART의 COM 포트를 선택합니다. **115200 baud / Even parity / 8 data bits / 1 stop bit / flow control Off**로 맞추고 **Connect**를 누릅니다. 연결이 실패하면 BOOT 핀을 확인하고 리셋한 뒤 다시 시도합니다.
3. **Erasing & Programming**에서 `build/startup_uart2.bin`을 선택하고 **Start address `0x08000000`**을 입력합니다. **Verify programming**을 켜고 **Start Programming**을 실행합니다. 이 이미지는 Flash 시작점에 설치하는 단일 이미지이므로 기존 사용자 펌웨어를 덮어씁니다.
4. 성공과 Verify 결과를 확인한 뒤 **Disconnect**합니다. COM 포트를 사용하는 시리얼 터미널은 연결 전에 닫습니다.

PowerShell에서 CLI로 실행한다면 `COM5`를 실제 어댑터 번호로 바꿉니다. 저장소 루트에서 다음 예시를 실행할 수 있습니다. 현재 이 PC에는 STM32CubeProgrammer v2.23.0이 아래 경로에 설치되어 있습니다.

```powershell
$cubeprg = 'C:\Program Files\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin\STM32_Programmer_CLI.exe'
& $cubeprg -c port=COM5 br=115200 p=even db=8 sb=1 fc=off -w .\01_bootloader_baremetal\build\startup_uart2.bin 0x08000000 -v
```

`-w`가 BIN을 `0x08000000`에 기록하고 `-v`가 검증합니다. 실행 전에 **BOOT0=1, BOOT1=0으로 리셋**하고, 종료 뒤에는 **BOOT0=0으로 되돌려 다시 리셋**해야 사용자 코드가 실행됩니다. 현재 이 PC에서는 COM 포트가 탐지되지 않아 실제 기록은 검증하지 못했습니다. [STM32CubeProgrammer UART 설정](https://dev.st.com/stm32cube-docs/prog/2.23.0/en/docs/markup/Uart_Connection_page.html), [CLI 옵션](https://dev.st.com/stm32cube-docs/prog/2.23.0/en/docs/markup/CubeProg_Command_Lines.html)

## 2. USART2 에코 테스트

**NUCLEO-F103RB의 보드 USB 가상 COM 포트를 사용한다면 아래 외장 USB-UART 배선 표는 건너뜁니다.** 별도 USB-UART 하나로 내장 ROM 부트로더를 통해 기록했다면 TX/RX 배선을 USART1에서 USART2로 옮깁니다. 배선을 변경할 때는 전원을 끄고, 어댑터의 TX가 MCU RX로 연결되는지 확인합니다.

| USB-UART | 실행·에코용 STM32F103RB 핀 |
| --- | --- |
| TX | **PA3 / USART2_RX** |
| RX | **PA2 / USART2_TX** |
| GND | GND |

보드에 ST-LINK VCP 등 다른 UART 장치가 PA2/PA3에 연결되어 있다면 회로도의 점퍼·솔더 브리지 설정을 확인해 두 송신 출력이 PA3에서 충돌하지 않도록 합니다. 외부 발진원과 LED는 필요하지 않습니다.

1. **ROM 부트로더/UART로 Flash했던 경우에만** BOOT0=0으로 되돌립니다. ST-LINK/SWD로 Flash했고 BOOT0을 변경하지 않았다면 그대로 둡니다.
2. 보드 전원을 공급하고 터미널에서 **115200 baud / 8 data bits / No parity / 1 stop bit / Flow control None / Local echo Off**로 COM 포트를 엽니다.
3. 터미널이 열린 상태에서 보드의 NRST 리셋 버튼을 눌러 시작 메시지를 확인합니다.

```text
bootloader
startup: OK (.data/.bss)
USART2 PA2/PA3 | 115200 8N1 | HSI 8 MHz
echo ready
```

4. `hello`를 입력하면 MCU가 반환한 `hello`가 화면에 한 번 표시되어야 합니다. 터미널이 줄 단위 송신이면 Enter를 누른 뒤 표시됩니다.
5. CR/LF 변환과 편집 기능은 없습니다. Enter가 줄의 시작으로만 이동하면 터미널의 송신 줄바꿈을 CR+LF로 설정합니다. 한글도 바이트 그대로 반환하므로 터미널 인코딩은 UTF-8로 맞춥니다.

전역 초기값 검사에서 실패하면 `startup: FAIL (.data/.bss)`를 출력하고 정지합니다. 통신 오류가 있는 수신 바이트는 버리고 `uart_rx_errors`를 증가시킵니다. 입력 대기는 계속하며, 클록·송신 플래그 대기는 제한된 반복 횟수 이후 `fault_code`를 남기고 정지합니다. 반복 횟수 제한은 정밀한 시간 기반 타임아웃은 아닙니다.

## 출력이 없거나 깨질 때

| 증상 | 확인할 사항 |
| --- | --- |
| 시작 메시지 없음 | 실제 리셋했는지, 이미지 주소가 `0x08000000`인지, 터미널을 연 뒤 리셋했는지 확인. ROM/UART로 기록했다면 BOOT0 설정도 확인 |
| 다운로드 성공 후 출력 없음 | USB-UART RX가 다운로드 핀 PA9가 아닌 실행 핀 PA2에 연결되었는지 확인 |
| 배너는 보이나 입력이 안 돌아옴 | 어댑터 TX → PA3, 공통 GND, flow control None, 다른 장치의 PA3 구동 여부 확인 |
| 글자가 두 번 보임 | 터미널 Local echo를 끔 |
| 글자 깨짐 | 테스트 터미널이 115200 **No parity**인지 확인. ROM 다운로드의 even parity를 그대로 사용하지 않음 |
| 대량 붙여넣기 시 누락 | 현재는 수동 입력용 폴링 에코. 송신 간격을 두고 시험하고, 지속 트래픽은 향후 버퍼·인터럽트 구현 후 검증 |

HSI와 정수 분주를 사용하므로 보레이트 오차가 있습니다. 현재 BRR=`0x45`의 공칭 속도는 약 115942 baud이며 HSI 오차가 추가됩니다. 파형으로 확인할 때 공칭 비트 폭은 약 8.625 µs입니다. 실제 온도·전압 범위에서 통신 품질은 별도로 검증해야 합니다.

선택적으로 SWD를 연결하면 `Reset_Handler`, `main`, `Default_Handler`에 중단점을 설정하고 `fault_code`(1: HSI 준비, 2: 클록 전환, 3: TXE 대기, 4: 초기값 검사), `uart_rx_errors`를 관찰할 수 있습니다.

## 기준 문서

- [RM0008](https://www.st.com/resource/en/reference_manual/cd00171190-stm32f101-103-105-107-stm32f100-series-armbased-32bit-mcus-stmicroelectronics.pdf): RCC, GPIO, USART 레지스터와 USART2 기본 핀 배치.
- [PM0056](https://www.st.com/resource/en/programming_manual/cd00228163.pdf): Cortex-M3 벡터와 리셋 동작.
- [AN2606](https://www.st.com/resource/en/application_note/cd00167594.pdf): 내장 ROM 부트로더 진입 및 USART1 연결.
