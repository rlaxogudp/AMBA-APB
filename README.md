# 🚀 RISC-V Multi-Cycle CPU & AMBA APB UART

![Verilog](https://img.shields.io/badge/Language-Verilog%20%7C%20SystemVerilog-blue)
![FPGA](https://img.shields.io/badge/FPGA-Basys3-green)
![Tool](https://img.shields.io/badge/Tool-Vivado-red)
![Architecture](https://img.shields.io/badge/Arch-RISC--V-orange)

**Basys3 FPGA 보드에서 동작하는 RV32I Multi-Cycle CPU와 AMBA APB 기반 UART Peripheral 설계 및 검증 프로젝트입니다.**

---

## 📝 목차 (Table of Contents)
1. [프로젝트 개요](#1-프로젝트-개요)
2. [하드웨어 아키텍처](#2-하드웨어-아키텍처)
    - [RISC-V Multi-Cycle CPU](#21-risc-v-multi-cycle-cpu)
    - [AMBA APB & UART](#22-amba-apb-bus--uart-peripheral)
3. [검증 (Verification)](#3-uart-peripheral-검증-testbench)
4. [소프트웨어 구현](#4-c-언어-application-및-동작-시연)
5. [트러블 슈팅](#5-trouble-shooting)
6. [고찰 및 배운 점](#6-고찰-key-learnings)

---

## 1. 프로젝트 개요
본 프로젝트는 RISC-V ISA를 이해하고, 표준 버스 프로토콜인 AMBA APB를 통해 주변 장치를 제어하는 SoC(System on Chip)의 기본 구조를 구현하는 것을 목표로 합니다.

* **Core**: RV32I 기반 Multi-Cycle CPU 설계
* **Bus**: AMBA APB 프로토콜 구현
* **Peripheral**: APB 기반 UART 모듈 설계 및 검증
* **SW**: C 코드 크로스 컴파일 및 하드웨어 동작 검증
* **HW**: Xilinx Basys3 보드 구현

---

## 2. 하드웨어 아키텍처

### 2.1. RISC-V Multi-Cycle CPU
단일 사이클(Single-Cycle) 방식의 긴 Critical Path 문제를 해결하기 위해, 하나의 명령어를 여러 단계(State)로 나누어 실행하는 구조를 채택했습니다.

| 특징 | 싱글사이클 (Single-Cycle) | 멀티사이클 (Multi-Cycle) |
| :--- | :--- | :--- |
| **CPI** | 1 | N (명령어마다 다름) |
| **클락 속도** | 느림 (가장 긴 명령어 기준) | **빠름 (가장 긴 단계 기준)** |
| **자원 효율** | 중복 유닛 필요 (Adder 등) | **ALU 등 유닛 재사용 가능** |
| **제어 로직** | 단순 | FSM 기반의 복잡한 구조 |

**🛠️ 실행 단계 (FSM States)**
1.  **Fetch**: PC 주소의 명령어 인출
2.  **Decode**: Opcode 분석 및 Register File 읽기
3.  **Execute**: ALU 연산 수행
4.  **Mem Access**: 메모리 읽기/쓰기 (Load/Store 명령어)
5.  **Write Back**: 레지스터에 결과 저장

> **Cycle Count:**
> * R, I, B, J, U Type: **3 Cycles**
> * S Type (Store): **4 Cycles**
> * L Type (Load): **5 Cycles**

### 2.2. AMBA APB Bus & UART Peripheral
CPU와 주변 장치 간의 통신을 위해 **AMBA APB (Advanced Peripheral Bus)** 프로토콜을 사용했습니다.

* **APB 특징**: 저전력, 저속 주변 장치에 최적화, 비-파이프라인 구조.
* **State Machine**: `IDLE` → `SETUP` → `ACCESS`

**UART Peripheral 설계**
CPU는 **APB Master**, UART 모듈은 **APB Slave**로 동작합니다.
* **Register Map**:
    * `reg0` (Control): UART 설정 및 상태 확인
    * `reg1` (WDATA): 송신 데이터 버퍼 (TX FIFO 연결)
    * `reg2` (RDATA): 수신 데이터 버퍼 (RX FIFO 연결)

---

## 3. UART Peripheral 검증 (Testbench)
SystemVerilog를 사용하여 랜덤 기반 검증 환경을 구축하였습니다.

* **Generator**: Random Data 생성
* **Driver**: UART RX 핀으로 직렬 데이터 전송 & APB Bus를 통한 데이터 Read/Write 수행
* **Monitor**: TX 핀 데이터를 캡처하여 패킷 조립
* **Scoreboard**: 송신 데이터와 수신 데이터를 비교하여 무결성 검증

> **📊 검증 결과**
> * Total Transactions: **256**
> * Pass Rate: **100.00%**

---

## 4. C 언어 Application 및 동작 시연
설계된 CPU 위에서 동작하는 C 프로그램을 작성하여 실제 하드웨어를 제어했습니다.

**🎮 동작 시나리오**
PC의 터미널(TeraTerm 등)을 통해 입력을 주면 FPGA가 반응합니다.

1.  **숫자 입력 (0~9)**
    * 7-Segment: 해당 숫자 표시
    * LED: 해당 인덱스의 LED 점등
2.  **명령어 입력 (l, r, s)**
    * `l`: LED 왼쪽으로 시프트 (Left)
    * `r`: LED 오른쪽으로 시프트 (Right)
    * `s`: LED 정지 및 7-Segment에 "STOP" 표시

---

## 5. Trouble Shooting

### 🚨 Issue: UART 데이터 깨짐 현상
**상황:**
C 코드에서 `uart_put_char` 함수를 연속으로 호출하여 문자열("stop")을 보낼 때, PC 터미널에서 문자가 누락되거나 깨지는 현상 발생 (예: "stpstpgolf").

**원인:**
CPU의 연산 속도가 UART 하드웨어의 전송 속도(Baudrate)보다 훨씬 빠르기 때문에, 이전 문자의 전송이 끝나기도 전에 다음 문자를 레지스터에 덮어써서 데이터 손실이 발생함.

**✅ Solution: Polling 방식 적용**
UART 상태 레지스터(`UART_USR`)를 확인하는 로직을 추가.
```c
void uart_put_char(char c) {
    // TX Buffer가 비어있을 때까지 대기 (Polling)
    while( (uart_reg[0] & UART_USR_TX_EMPTY) == 0 ); 
    
    uart_reg[1] = c; // 데이터 전송
}
