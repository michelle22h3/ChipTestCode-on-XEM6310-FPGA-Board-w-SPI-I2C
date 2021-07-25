//`define I2C_DISP
module i2c_master(
  // CLK, Reset and addr signals
  input  wire          hclk,
  input  wire          hresetn,
  input  wire [6:0]    slave_addr,
  // I2C Interface with on chip Logic
  output reg           scl,
  output reg           sda_out,
  input  wire          sda_in,
  output reg           sda_oe,
  // Interface with Testbench
  input  wire          rw,
  input  wire [31:0]   addr,
  input  wire [31:0]   wr_data,
  output reg  [31:0]   rd_data,
  output reg           rd_valid,
  input  wire          valid,
  output reg           stall,

  input  wire          i2aen,
  input  wire [1:0]    i2ac,
  input  wire [1:0]    i2dc
);

   
reg           rw_d1;
reg  [31:0]   addr_d1;
reg  [31:0]   wr_data_d1;
reg           valid_d1;
reg  [6:0]    slave_addr_d1;
reg  [3:0]    hclk_cnt;

parameter BYTE_IDLE = 0;
parameter BYTE_START = 1;
parameter BYTE_SAW = 2;   
parameter BYTE_ACK_SAW = 3;   
parameter BYTE_ADDR = 4;   
parameter BYTE_ACK_ADDR = 5;   
parameter BYTE_WR = 6;
parameter BYTE_ACK_WR = 7;
parameter BYTE_RESTART = 8;
parameter BYTE_SAR = 9;   
parameter BYTE_ACK_SAR = 10;   
parameter BYTE_RD = 11;
parameter BYTE_ACK_RD = 12;
parameter BYTE_STOP = 13;

parameter BIT_IDLE = 0;
parameter BIT_START = 1;
parameter BIT_STOP = 2;
parameter BIT_READ = 3;
parameter BIT_WRITE = 4;
parameter BIT_RESTART = 5;
parameter BIT_ACK = 6;

reg  [4:0]    state,next_state;
reg  [2:0]    btype;
reg  [1:0]    cycle;
reg           cycle_done;
reg  [31:0]   dout;
reg  [2:0]    shift_cnt;
reg           shift_done;
reg           sda_reg;
reg           sda_out_pre;
reg  [1:0]    addr_cnt;
reg  [1:0]    data_cnt;
wire          addr_cnt_min;
wire          data_cnt_min;
   
   
`ifdef I2C_DISP   
   always@(posedge hclk) begin
      if (valid & !stall & rw) begin
          //$display("i2c: sa %x addr %x wr_data %b",slave_addr,addr,wr_data);         
      end
      if (rd_valid) begin
          //$display("i2c: sa %x addr %x rd_data %b",slave_addr_d1,addr_d1,rd_data);      
      end
   end
`endif

always@(*) begin     
    cycle_done = (cycle == 2'b11) & (hclk_cnt==4'b1111);
    //stall = valid & ~((state == BYTE_IDLE) & cycle_done);
    //stall = (state != BYTE_IDLE) | (valid & (state == BYTE_IDLE) & !cycle_done);
    stall = (state != BYTE_IDLE);
    rd_valid = (state == BYTE_ACK_RD) & cycle_done & data_cnt_min;
    rd_data = dout;
    shift_done = (shift_cnt == 3'b111);      
end

always@(posedge hclk or negedge hresetn) begin
    if (!hresetn) begin
        state <= 0;
        cycle <= 0;
        hclk_cnt <= 0;
        sda_reg <= 0;
    end
    else begin
        if ((state == BYTE_IDLE) | cycle_done) begin
            state <= next_state;
        end

        hclk_cnt <= (state == BYTE_IDLE) ? 0 : hclk_cnt + 1;

        if ((valid | (state != BYTE_IDLE)) & (hclk_cnt==4'b1111))
            cycle <= cycle + 1;    
        
        if ((btype == BIT_READ) & (cycle == 1))
            sda_reg <= sda_in;
    end      
end

wire sar_bypass = !i2aen & !rw_d1;
   
always@(*) begin
    next_state = state;     
    case (state)
        BYTE_IDLE:     if (valid & !stall)             
                           next_state = BYTE_START;
        BYTE_START:    if (sar_bypass)                 
                           next_state = BYTE_SAR;
                       else                            
                           next_state = BYTE_SAW;
        BYTE_SAW:      if (shift_done)                 
                           next_state = BYTE_ACK_SAW;
        BYTE_ACK_SAW:  if (!sda_reg) begin
                         if (i2aen)                    
                             next_state = BYTE_ADDR;
                         else                          
                             next_state = BYTE_WR;
                       end
                       else                            
                           next_state = BYTE_STOP;
        BYTE_ADDR:     if (shift_done)                 
                          next_state = BYTE_ACK_ADDR;
        BYTE_ACK_ADDR: if (!sda_reg) begin
                           if (addr_cnt_min) begin 
                               if (rw_d1)                  
                                   next_state = BYTE_WR;
                               else                       
                                   next_state = BYTE_RESTART;
                           end
                           else                         
                               next_state = BYTE_ADDR;
                       end                     
                       else                           
                           next_state = BYTE_STOP;
        BYTE_WR:       if (shift_done)                
                           next_state = BYTE_ACK_WR;
        BYTE_ACK_WR:   if (!sda_reg) begin                 
                           if (data_cnt_min)             
                               next_state = BYTE_STOP;
                           else                         
                               next_state = BYTE_WR;
                       end
                       else                           
                           next_state = BYTE_STOP;
        BYTE_RESTART:  next_state = BYTE_SAR;
        BYTE_SAR:      if (shift_done)                
                           next_state = BYTE_ACK_SAR;
        BYTE_ACK_SAR:  next_state = BYTE_RD;  
        BYTE_RD:       if (shift_done)                
                           next_state = BYTE_ACK_RD;
        BYTE_ACK_RD:   if (data_cnt_min)              
                           next_state = BYTE_STOP;
                       else                           
                           next_state = BYTE_RD;
        BYTE_STOP:     next_state = BYTE_IDLE;
        default:       next_state = 4'bx;  
    endcase // case(state)  
end
   
always@(*) begin
    case (state)
        BYTE_IDLE:             btype = BIT_IDLE;
        BYTE_START:            btype = BIT_START;
        BYTE_SAW:              btype = BIT_WRITE;
        BYTE_ACK_SAW:          btype = BIT_READ;
        BYTE_ADDR:             btype = BIT_WRITE;
        BYTE_ACK_ADDR:         btype = BIT_READ;
        BYTE_WR:               btype = BIT_WRITE;
        BYTE_ACK_WR:           btype = BIT_READ;
        BYTE_RESTART:          btype = BIT_RESTART;  
        BYTE_SAR:              btype = BIT_WRITE;
        BYTE_ACK_SAR:          btype = BIT_READ;
        BYTE_RD:               btype = BIT_READ;
        BYTE_ACK_RD:           btype = BIT_ACK;
        BYTE_STOP:             btype = BIT_STOP;
        default btype = 4'bx;  
    endcase // case(state)  
end 

always@(posedge hclk or negedge hresetn) begin
    if (!hresetn) begin
        valid_d1 <= 0;
        rw_d1 <= 0;
        addr_d1 <= 0;
        wr_data_d1 <= 0;   
        slave_addr_d1 <= 0;
        dout <= 0;
        shift_cnt <= 0;
    end
    else begin
        if (!stall) begin
            valid_d1 <= valid;
            rw_d1 <= rw; 
            addr_d1 <= addr;
            wr_data_d1 <= wr_data;
            slave_addr_d1 <= slave_addr;      
        end

        if (cycle_done) begin
            case (state) 
                BYTE_START:    begin dout <= {slave_addr_d1,sar_bypass};        shift_cnt <= 0; end     
                BYTE_RESTART:  begin dout <= {slave_addr_d1,1'b1};              shift_cnt <= 0; end  
                BYTE_ACK_SAW:  begin dout <= (i2aen)? {addr_d1} : {wr_data_d1}; shift_cnt <= 0; end  
                BYTE_ACK_ADDR: begin 
                                   if (addr_cnt_min) begin
                                     dout <= {wr_data_d1};
                                   end
                                   shift_cnt <= 0; 
                               end  
                BYTE_ACK_SAR:  begin dout <= 0;                    shift_cnt <= 0; end
                BYTE_ACK_WR:   begin                               shift_cnt <= 0; end
                BYTE_ACK_RD:   begin                               shift_cnt <= 0; end     
                default:       begin dout <= {dout,sda_reg};       shift_cnt <= shift_cnt + 1; end
            endcase // case(next_state)
        end
    end
end

always@(*) begin
    case (state)
        BYTE_SAW: sda_out_pre = dout[7];
        BYTE_SAR: sda_out_pre = dout[7];
        BYTE_ADDR: case(i2ac)
                       0: sda_out_pre = dout[7];
                       1: sda_out_pre = dout[15];
                       2: sda_out_pre = dout[23];
                       3: sda_out_pre = dout[31];
                       default: sda_out_pre = 1'bx;
                   endcase // case (i2ac)
        default: case(i2dc)
                     0: sda_out_pre = dout[7];
                     1: sda_out_pre = dout[15];
                     2: sda_out_pre = dout[23];
                     3: sda_out_pre = dout[31];
                     default: sda_out_pre = 1'bx;
                endcase // case (i2ac)
    endcase  
end
     
always@(posedge hclk or negedge hresetn) begin
    if (!hresetn) begin
        {scl,sda_out} <= 2'b11;
        sda_oe <= 1;
    end
    else begin   
        case (btype)
            BIT_IDLE:  
                begin
                  case(cycle)
                    0: {scl,sda_out} <= 2'b11;
                    1: {scl,sda_out} <= 2'b11;
                    2: {scl,sda_out} <= 2'b11;
                    3: {scl,sda_out} <= 2'b11;
                  endcase // case(cycle)
                  sda_oe <= 1;
                end   
            BIT_START:  
                begin
                  case(cycle)       
                      0: {scl,sda_out} <= 2'b11;
                      1: {scl,sda_out} <= 2'b11;
                      2: {scl,sda_out} <= 2'b10;
                      3: {scl,sda_out} <= 2'b00;
                  endcase // case(cycle)
                  sda_oe <= 1;
                end     
            BIT_STOP:  
                begin
                  case(cycle)
                    0: {scl,sda_out} <= 2'b00;
                    1: {scl,sda_out} <= 2'b10;
                    2: {scl,sda_out} <= 2'b11;
                    3: {scl,sda_out} <= 2'b11;
                  endcase // case(cycle)
                  sda_oe <= 1;
                end     
            BIT_WRITE:  
                begin
                  case(cycle)
                    0: {scl,sda_out} <= {1'b0,sda_out_pre};
                    1: {scl,sda_out} <= {1'b1,sda_out_pre};
                    2: {scl,sda_out} <= {1'b1,sda_out_pre};
                    3: {scl,sda_out} <= {1'b0,sda_out_pre};
                  endcase // case(cycle)
                  sda_oe <= 1;
                end     
            BIT_READ:  
                begin
                  case(cycle)
                    0: {scl,sda_out} <= {1'b0,1'bx};
                    1: {scl,sda_out} <= {1'b1,1'bx};
                    2: {scl,sda_out} <= {1'b1,1'bx};
                    3: {scl,sda_out} <= {1'b0,1'bx};
                  endcase // case(cycle)
                  sda_oe <= 0;
                end     
            BIT_RESTART:  
                begin
                  case(cycle)
                    0: {scl,sda_out} <= {1'b0,1'b1};
                    1: {scl,sda_out} <= {1'b1,1'b1};
                    2: {scl,sda_out} <= {1'b1,1'b0};
                    3: {scl,sda_out} <= {1'b0,1'b0};
                  endcase // case(cycle)
                  sda_oe <= 1;
                end     
            BIT_ACK:  
                begin
                  case(cycle)
                    0: {scl,sda_out} <= {1'b0,data_cnt_min};
                    1: {scl,sda_out} <= {1'b1,data_cnt_min};
                    2: {scl,sda_out} <= {1'b1,data_cnt_min};
                    3: {scl,sda_out} <= {1'b0,data_cnt_min};
                  endcase // case(cycle)
                  sda_oe <= 1;
                end     
        endcase    
    end
end
   
always@(posedge hclk or negedge hresetn) begin
    if (!hresetn) begin
        addr_cnt <= 0;
        data_cnt <= 0;
    end
    else begin
        if (valid & !stall) begin
            addr_cnt <= i2ac;
            data_cnt <= i2dc;      
        end
        else begin
            if ((state == BYTE_ACK_ADDR) & cycle_done) begin
                addr_cnt <= addr_cnt - 1;         
            end
            if (((state == BYTE_ACK_WR)|(state == BYTE_ACK_RD)) & cycle_done) begin
                data_cnt <= data_cnt - 1;         
            end      
        end
    end
end // always@ (posedge hclk or negedge hresetn)

assign addr_cnt_min = (addr_cnt == 0);
assign data_cnt_min = (data_cnt == 0);
 

endmodule //
