# RISC-V Multi-Cycle CPU 및 AMBA APB Peripheral 설계

**Basys3 보드에서 동작하는 RV32I Multi-Cycle CPU와 APB 기반 UART Peripheral을 설계하고 검증한 프로젝트입니다.**

---

## [cite_start]1. 🚀 프로젝트 개요 [cite: 9]

본 프로젝트의 주요 목표는 다음과 같습니다.

* [cite_start]**RV32I 기반 Multi-Cycle CPU 설계** [cite: 11]
* [cite_start]**AMBA APB 기반 Peripheral (UART) 설계 및 검증** [cite: 12]
* [cite_start]**C 코드 작성 및 컴파일**을 통한 하드웨어 동작 검증 [cite: 13]
* [cite_start]**Basys3** FPGA 보드에 구현 [cite: 14]

---

## 2. 🛠️ 주요 설계 내용

### 2.1. [cite_start]RISC-V Multi-Cycle CPU [cite: 15]

[cite_start]**Multi-Cycle CPU란?** [cite: 16]
[cite_start]하나의 명령어를 여러 단계(State)로 나누어 실행하는 CPU 구조입니다. [cite: 17, 18] [cite_start]각 단계는 하나의 클락 사이클 동안 처리되며, 명령어 하나를 완료하는 데 여러 클락 사이클이 소요됩니다. [cite: 19, 20]

**장점:**
* [cite_start]각 단계의 길이가 짧아져 더 빠른 클록 속도를 사용할 수 있습니다. [cite: 21]
* [cite_start]명령어 종류에 따라 필요한 클록 사이클 수가 다르므로, 자원을 효율적으로 사용할 수 있습니다. [cite: 22, 23]

[cite_start]**Single-Cycle vs Multi-Cycle 비교** [cite: 24]

| 특징 | [cite_start]싱글사이클 [cite: 26] | [cite_start]멀티사이클 [cite: 27] |
| :--- | :--- | :--- |
| **명령어당 클록 수** | [cite_start]1 [cite: 29] | [cite_start]여러 개 [cite: 30] |
| **클락 속도** | [cite_start]느림 (가장 느린 명령어 기준) [cite: 32] | [cite_start]빠름 (가장 느린 단계 기준) [cite: 33] |
| **하드웨어 사용** | [cite_start]중복 유닛 필요 가능 [cite: 35] | [cite_start]유닛 재사용 가능 [cite: 36, 37] |
| **제어 유닛** | [cite_start]단순 [cite: 39] | [cite_start]복잡 [cite: 40] |
| **효율성** | [cite_start]빠른 명령어 실행 시 비효율적 [cite: 42] | [cite_start]시간 사용 효율성 높음 [cite: 43] |

[cite_start]**CPU 5단계 (Datapath)** [cite: 44]
1.  [cite_start]**Fetch**: 명령어 출력 [cite: 45]
2.  [cite_start]**Decode**: 명령어 Type 및 Opcode 분석 [cite: 46]
3.  [cite_start]**Execute**: 명령어 실행 및 연산 [cite: 47]
4.  [cite_start]**Mem Access**: RAM 입력 (S-type 명령어) [cite: 48, 97]
5.  [cite_start]**Write Back**: RAM Data 출력 (L-type 명령어) [cite: 49, 104]

* [cite_start]R, I, B, J, L, U-type 명령어는 3 사이클 (F-D-E) 소요 [cite: 51-92]
* [cite_start]S-type (Store) 명령어는 4 사이클 (F-D-E-M) 소요 [cite: 93-98]
* [cite_start]L-type (Load) 명령어는 5 사이클 (F-D-E-M-W) 소요 [cite: 99-104]

[cite_start] [cite: 44]

---

### 2.2. AMBA APB Bus 및 UART Peripheral

**AMBA (Advanced Microcontroller Bus Architecture)**
* [cite_start]ARM에서 만든 SoC 내부 구성 요소를 연결하는 표준 버스 규격입니다. [cite: 115, 116]

[cite_start]**APB (Advanced Peripheral Bus)** [cite: 109]
* [cite_start]저속 / 저전력 주변 장치(Peripheral) 연결에 최적화된 버스입니다. [cite: 117]
* [cite_start]**장점**: UART, GPIO 등 동일한 APB 프로토콜을 사용하므로 새로운 장치 추가 및 재사용이 쉽고 시스템 확장이 용이합니다. [cite: 110-114]
* **특징**:
    * [cite_start]단순한 신호 및 프로토콜 [cite: 119]
    * [cite_start]저전력 소모 [cite: 120]
    * [cite_start]비-파이프라인 구조 (한 번에 하나의 전송만 처리) [cite: 121]
    * [cite_start]상태 기반 동작: `IDLE` → `SETUP` → `ACCESS` [cite: 122-124]

[cite_start]**UART Peripheral 설계** [cite: 125]
* RV32I CPU가 **APB Master** 역할을 수행하여 UART Peripheral과 통신합니다.
* [cite_start]UART Peripheral은 **APB-Slave**로 동작하며, 내부 레지스터 (Control, WDATA, RDATA)를 통해 데이터를 주고받습니다. [cite: 125, 126]
    * [cite_start]`reg0 (Control)`: UART 상태 제어 [cite: 129]
    * [cite_start]`reg1 (WDATA)`: UART TX Data 저장 [cite: 127]
    * [cite_start]`reg2 (RDATA)`: UART RX Data 저장 [cite: 128]
* [cite_start]FIFO (TX/RX)를 포함하여 데이터 송수신을 관리합니다. [cite: 125]

[cite_start] [cite: 125]

---

## [cite_start]3. 🧪 UART Peripheral 검증 (Testbench) [cite: 130]

SystemVerilog를 이용한 테스트벤치 환경을 구축하여 UART Peripheral을 검증했습니다.

* [cite_start]**Generator**: 무작위 `uart_send_data`를 생성하여 Driver로 전송 [cite: 131]
* **Driver**:
    1.  [cite_start]Generator로부터 데이터를 받아 UART RX 핀으로 1 bit씩 전송 [cite: 133]
    2.  [cite_start]APB-Master 역할을 수행하여 UART RX FIFO의 데이터를 읽음 (APB Read) [cite: 135]
    3.  [cite_start]읽은 데이터를 다시 UART TX FIFO에 씀 (APB Write) [cite: 137]
* [cite_start]**Monitor**: DUT의 TX 핀에서 1 bit씩 데이터를 읽어 패킷으로 조립 [cite: 139]
* [cite_start]**Scoreboard**: Generator가 처음에 생성한 랜덤값과 Monitor가 최종적으로 수신한 값을 비교하여 일치 여부 확인 [cite: 141, 142]

[cite_start]**검증 결과**: 256개의 트랜잭션 모두 통과 (Pass Rate: 100.00 %) [cite: 142]

---

## 4. 🖥️ C 언어 Application 및 동작 시연

[cite_start]작성된 C 코드를 컴파일하여 CPU의 ROM에 로드하고, Basys3 보드에서 실제 동작을 확인했습니다. [cite: 13, 158]

* **동작 로직**:
    * [cite_start]PC에서 UART 터미널을 통해 숫자 또는 문자열을 입력 [cite: 148, 149]
    * [cite_start]**숫자 (0-9) 입력**: 7-Segment에 해당 숫자가 출력 [cite: 144, 145] [cite_start]되고, 숫자에 해당하는 LED가 ON 됩니다. [cite: 146, 156]
    * [cite_start]**문자열 ('l', 'r', 's') 입력**: LED가 Left, Right, Stop 상태로 변경되고, 7-Segment에 "L", "r", "STOP"이 출력됩니다. [cite: 147, 152]
* **주요 코드**:
    * [cite_start]`#define`을 사용하여 GPIO, UART, FND 레지스터의 실제 메모리 주소를 C 코드 변수처럼 정의 [cite: 151]
    * [cite_start]`decimal_to_bcd` 함수로 10진수 입력을 7-Segment용 BCD로 변환 [cite: 157]
    * [cite_start]주기적으로 현재 상태(left, right, fnd, stop)를 UART를 통해 PC로 다시 전송 [cite: 154, 155]

[cite_start] [cite: 158]

---

## 5. ⚠️ Trouble Shooting

* [cite_start]**문제 (Trouble)**[cite: 162]:
    [cite_start]C 코드에서 `uart_put_char` 함수를 연속 호출 시, C 코드 실행 속도가 UART 하드웨어 전송 속도보다 빨라 문자가 누락되거나 깨지는 현상 발생 [cite: 161] (예: "stop" 전송 시 "stpstpgolf" 수신) [cite_start][cite: 159]
* [cite_start]**해결 (Solution)**[cite: 163]:
    [cite_start]문자 전송 함수(`uart_put_char`) 내부에 **`while` 루프를 추가**하여, UART의 상태 레지스터(`UART_USR`)를 확인하고 `UART_USR_TX_EMPTY` 비트가 1 (전송 완료)이 될 때까지 대기하도록 수정 [cite: 160]

---

## [cite_start]6. 💡 고찰 (Key Learnings) [cite: 164]

* **하드웨어/소프트웨어 동기화의 중요성**: 동일한 C 코드라도 하드웨어의 구현 방식이나 타이밍에 따라 동작이 실패할 수 있음을 깨달았습니다. (Trouble Shooting 참고) [cite_start][cite: 165-168]
* [cite_start]**표준 버스 프로토콜의 장점**: APB 같은 표준 버스를 사용함으로써, FND, UART 등 서로 다른 기능의 모듈을 쉽게 추가하고 재사용할 수 있는 **확장성**의 장점을 이해했습니다. [cite: 169, 170]
