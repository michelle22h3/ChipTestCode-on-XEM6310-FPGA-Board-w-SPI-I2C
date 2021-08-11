module spi_master(
  // Global signals
  input wire CLK,        // System CLK  
  input wire RESET,      // RST: enable 1
  // SFR signals
  input wire psel,      // SPI Chip selected: Active 1
  input wire penable,   // SPI Enable: Active 0 (Pulse)
  input wire WE,        // Write data to SFR
  input wire RE,        // Read data from SFR
  input wire [7:0] ADDRD,  // SFR address
  output wire spim_busy,    // High means SPI Master is busy
  // Data bus
  input wire [7:0] DATABI,    // Main data bus input
  output reg [7:0] DATAB,    // Main data bus output
  // SPI ports
  output wire SCK,        // Serial clock output
  output wire MOSI,       // Master Out Slave In
  input  wire MISO,       // Master In Slave Out
  output reg  INT,        // SPI interrupt output
  output reg  SSn,        // SSn Slave Select Signal
  // Others
  input wire ES            // Interrupt Enable Register
);

parameter SPCR_ADDR = 8'h02;
parameter SPSR_ADDR = 8'h03;
parameter SPDR_ADDR = 8'h04;

// Module body
//
reg  [7:0] spcr;       // SPI Control Register
wire [7:0] spsr;       // SPI Status Register
reg  [7:0] spdr;       // SPI Data Register
reg  [7:0] spdr_rx;
reg  [7:0] spdr_tx;

// Misc signals
reg    tirq;        // Transfer interrupt (selected number of transfers done)
reg    tx;        // Transmission flag (level high when transmission in progress)
wire    spdr_ov;
reg    [1:0] state;    // Statemachine state
reg    [2:0] bcnt;

reg  sck_m; 
wire sck_s, miso_m;

wire wr_spdr, wr_spsr;
reg  wr_spdr_d1;

// modified by peng for apb slave
wire apb_wr = psel & ~penable & WE;
wire apb_rd = psel & ~penable & RE;

assign spim_busy = tx;

always @(*)
  case(ADDRD) // synopsys full_case parallel_case
    SPCR_ADDR: DATAB = spcr;
    SPSR_ADDR: DATAB = spsr;
    SPDR_ADDR: DATAB = spdr_rx;
      default: DATAB = 8'h00;
  endcase

//assign DATAB = (ADDRD == SPCR_ADDR && apb_rd) ? spcr : 8'hzz;
//assign DATAB = (ADDRD == SPSR_ADDR && apb_rd) ? spsr : 8'hzz;
//assign DATAB = (ADDRD == SPDR_ADDR && apb_rd) ? spdr : 8'hzz;

// SPDR - SPI Data Register
// SPCR - SPI Control Register
always @(posedge CLK or posedge RESET)
  if (RESET)
    begin
        spdr <= #1 8'h00;     // SPDR Reset Value 8'h00
        spcr <= #1 8'h00;     // SPCR Reset Value 8'h00 // cpol=0, cpha=0, speed=1 
    end
  else if (apb_wr)
    begin
      if (ADDRD == SPDR_ADDR) 
        begin
          if (~tx) spdr <= #1 DATABI; // Write data to SPDR
        end
      else if (ADDRD == SPCR_ADDR)
            spcr <= #1 DATABI;        // Write data to SPCR
    end

assign wr_spdr = apb_wr & (ADDRD == SPDR_ADDR);
assign spdr_ov = wr_spdr & tx;

always @(posedge CLK or posedge RESET)
  if (RESET)
     wr_spdr_d1 <= 1'b0;
  else
     wr_spdr_d1 <= wr_spdr;
    
// Decode SPCR
wire       spie = spcr[7];   // Interrupt enable bit
wire       spe  = spcr[6];   // System Enable bit
wire       dord = spcr[5];   // Data Transmission Order
wire       mstr = spcr[4];   // Master Mode Select Bit
wire       cpol = spcr[3];   // Clock Polarity Bit
wire       cpha = spcr[2];   // Clock Phase Bit
wire [1:0] spr  = spcr[1:0]; // Clock Rate Select Bits

// SPSR - SPI Status Register
assign wr_spsr = apb_wr & (ADDRD == SPSR_ADDR);

reg spif;
always @(posedge CLK)
  if (~spe)
    spif <= #1 1'b0;
  else
    spif <= #1 (tirq | spif) & ~(wr_spsr & DATABI[0]);     // Set by hardware, clear by software

reg wcol;
always @(posedge CLK)
  if (~spe)
    wcol <= #1 1'b0;
  else 
    wcol <= #1 (spdr_ov | wcol) & ~(wr_spsr & DATABI[1]);    // Set by hardware, clear by software

assign spsr[0]   = spif;
assign spsr[1]   = wcol;
assign spsr[7:2] = 6'b000000;
  
// Generate IRQ output
always @(posedge CLK)
  INT <= #1 spif & spie & ES;

// Clock Divider
//
// SPR1 SPR0 SCK=fosc divided by
// 0    0    4
// 0    1    16
// 1    0    64
// 1    1    128
reg [11:0] clkcnt;
always @(posedge CLK)
  if(spe & (|clkcnt & |state))     // pass when (spe = 1, clkcnt ~= 0, state ~= 0)
    clkcnt <= #1 clkcnt - 1;
  else
    case (spr) // synopsys full_case parallel_case
      2'b00: clkcnt <= #1 'h1;    // fosc/4
      2'b01: clkcnt <= #1 'h7;    // fosc/16
      2'b10: clkcnt <= #1 'h1f;    // fosc/64
      2'b11: clkcnt <= #1 'h3f;    // fosc/128
    endcase

// Generate clock enable signal for SCK (SPI Serial Clock)
wire ena = ~|clkcnt; // ena asserts when clkcnt = 0

// State machine for serial data transmission and SCK generation
always @(posedge CLK)
  if (~spe)
    begin
        state <= #1 2'b00; // Idle
        bcnt  <= #1 3'h0;
        tirq  <= #1 1'b0;
        sck_m <= #1 1'b0;
        tx    <= #1 1'b0;
        spdr_rx <= #1 8'h0;
        spdr_tx <= #1 8'h0;
    end
  else
    begin
       tirq  <= #1 1'b0;

       case (state) //synopsys full_case parallel_case
         2'b00: // Idle state
            begin
                bcnt  <= #1 3'h7; // Set transfer counter
                if (wr_spdr_d1) begin
                  state <= #1 2'b01;
                  sck_m <= #1 cpol^cpha;     // Initialize SCK
                  tx <= #1 1'b1;         // Transmission start flag
                  spdr_tx <= #1 spdr;
                end
            end

         2'b01: // Clock-phase2, next data
            if (ena) begin
              sck_m   <= #1 ~sck_m;
              state   <= #1 2'b11;
            end

         2'b11: // Clock phase1
            if (ena) begin
              if (dord) 
                spdr_tx <= #1 {1'b0, spdr_tx[7:1]}; // LSB first in data transmission
              else 
                spdr_tx <= #1 {spdr_tx[6:0], 1'b0}; // MSB first in data transmission
              
              if (dord) 
                spdr_rx <= #1 {miso_m, spdr_rx[7:1]}; // LSB first in data transmission
              else 
                spdr_rx <= #1 {spdr_rx[6:0], miso_m}; // MSB first in data transmission

              bcnt <= #1 bcnt - 3'h1;

              if (~|bcnt) begin     // True when bcnt = 0
                state <= #1 2'b00;
                sck_m <= #1 cpol;
                tirq <= #1 1'b1;     // tirq asserts when all bits have been transferred
                tx <= #1 1'b0;     // Transmission done flag
              end else begin
                state <= #1 2'b01;
                sck_m <= #1 ~sck_m;
              end
            end

         2'b10: state <= #1 2'b00;
       endcase
    end

//assign SCK = (mstr)? sck_m : 1'hz;
//assign MOSI = (mstr)? (dord)? spdr_tx[0]:spdr_tx[7] : 1'hz;
//assign miso_m = (mstr)? MISO : 1'hz;
assign SCK = sck_m;
assign MOSI = (dord)? spdr_tx[0]:spdr_tx[7];
assign miso_m = MISO;

// XJ: start cs from 1
//assign SSn = 1'b0;
always @(posedge CLK or posedge RESET) begin
  if (RESET)
    begin
        SSn <= #1 1'b1;  
    end
  else if (apb_wr && (ADDRD == SPCR_ADDR))
    begin
        SSn <= #1 1'b0; 
    end
end


endmodule
