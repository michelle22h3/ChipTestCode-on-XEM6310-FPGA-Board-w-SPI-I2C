module i2c_slave(
   // i2c ports
   input   wire [6:0]    slave_addr  ,
   input   wire          scl         ,
   input   wire          sda_in      ,
   output  reg           sda_oe      ,
   output  reg           sda_out     ,
   // general ports
   input   wire          hclk        ,
   input   wire          hresetn     ,
   output  wire          wr_en       ,
   output  reg  [7:0]    addr        ,
   output  wire [7:0]    wr_data     ,
   input   wire [7:0]    rd_data     
);
  
// parameter BYTE_IDLE     = 0;
parameter BYTE_SA       = 0  ;//send slave address
parameter BYTE_ACK_SA   = 1  ;//ack after write slave address
parameter BYTE_ADDR     = 2  ;//
parameter BYTE_ACK_ADDR = 3  ;   
parameter BYTE_WR       = 4  ;
parameter BYTE_ACK_WR   = 5  ;
parameter BYTE_RD       = 6  ;
parameter BYTE_ACK_RD   = 7  ;

reg        scl_d1;
reg        scl_d2;
reg        scl_d3;
reg        sda_in_d1;
reg        sda_in_d2;
reg        sda_in_d3;
wire       start, stop; 
wire       pe_scl, ne_scl;
reg  [6:0] sa;
reg        rw;  //rw= 1:read rw=0: write
reg  [7:0] wr_sr,rd_sr;
reg  [2:0] sr_cnt;
wire       sa_shift_en;
wire       addr_shift_en;
wire       addr_inc;
wire       wr_sr_shift_en;
wire       rd_sr_ld_en;
wire       rd_sr_shift_en;
wire       sr_cnt_reset;
wire       sr_cnt_inc;
wire       shift_done;
wire       sa_match;
reg  [3:0] state;
reg  [3:0] next_state;
reg        req_valid;

always @(posedge hclk or negedge hresetn) begin
    if (!hresetn) begin
        state <= BYTE_SA;
        req_valid <= 0;     
    end 
    else begin
        if (stop|start) begin
            state <= BYTE_SA;
        end
        else begin
            if (pe_scl & req_valid) begin
                state <= next_state;
            end
        end
        if (start) begin
            req_valid <= 1;
        end
        else begin
            if (stop | (pe_scl & (state == BYTE_ACK_SA) & !sa_match)) begin
                req_valid <= 0;         
            end
        end
    end      
end

always @(rw or sa_match or sda_in_d2 or shift_done or state) begin
    case (state)

        BYTE_SA:     if (shift_done)        
                         next_state = BYTE_ACK_SA;
                     else                   
                         next_state = state;   
        BYTE_ACK_SA: if (sa_match) begin
                         if (!rw)           
                             next_state = BYTE_ADDR;
                         else               
                             next_state = BYTE_RD;
                         end
                     else                   
                         next_state = BYTE_SA;
        
        BYTE_ADDR:   if (shift_done)        
                         next_state = BYTE_ACK_ADDR;
                     else                   
                         next_state = state;
 
        BYTE_ACK_ADDR:   next_state = BYTE_WR;

        BYTE_WR:     if (shift_done)        
                         next_state = BYTE_ACK_WR;
                     else                   
                         next_state = state;
 
        BYTE_ACK_WR:     next_state = BYTE_WR;
 
        BYTE_RD:     if (shift_done)        
                         next_state = BYTE_ACK_RD;
                     else                   
                         next_state = state;   
        BYTE_ACK_RD: if (sda_in_d2)         
                         next_state = BYTE_SA;
                     else                   
                         next_state = BYTE_RD; 
 
        default: next_state = 4'bx;  
    endcase 
end

always @(posedge hclk or negedge hresetn) begin
    if (!hresetn) begin
        sda_in_d1 <= 1;
        sda_in_d2 <= 1;
        sda_in_d3 <= 1;
        scl_d1 <= 1;    
        scl_d2 <= 1;    
        scl_d3 <= 1;    
    end
    else begin 
        sda_in_d1 <= sda_in;      //sda_in_d1 save last status of sda_in
        sda_in_d2 <= sda_in_d1;    //sda_in_d2 save last status of sda_in_d1
        sda_in_d3 <= sda_in_d2;    //sda_in_d3 save last status of sda_in_d2
        scl_d1 <= scl;  
        scl_d2 <= scl_d1;   
        scl_d3 <= scl_d2;   
    end
end

assign start = scl_d2 & scl_d3 & !sda_in_d2 & sda_in_d3;  //1->0
assign stop  = scl_d2 & scl_d3 & sda_in_d2 & !sda_in_d3;  //0->1
assign pe_scl = scl_d2 & !scl_d3;    //scl_d2 ,delay half cycle
assign ne_scl = !scl_d2 & scl_d3;    //scl_d3,delay one cycle

always @(posedge hclk or negedge hresetn) begin
    if (!hresetn) begin
        {sa,rw} <= 0;
        addr <= 0;
        wr_sr <= 0;
        rd_sr <= 0;
        sr_cnt <= 0;
    end else begin
        // Slave Addr
        if (sa_shift_en) begin
            {sa,rw} <= {sa,rw,sda_in_d2};
        end
        // Reg Addr
        if (addr_shift_en) begin
            addr <= {addr,sda_in_d2};
        end else begin
            if (addr_inc) begin
                addr <= addr + 1;       
            end 
        end
        // Wr data
        if (wr_sr_shift_en) begin
            wr_sr <= {wr_sr, sda_in_d2};    
        end
        // Rd data
        if (rd_sr_ld_en) begin    //change the default value of rd_sr,ready transfer data to sda_out
            rd_sr <= rd_data;
        end else begin
            if (rd_sr_shift_en) begin
                rd_sr <= {rd_sr,1'b0};     //left shift,transfer data to sda_out     
            end
        end   
        if (sr_cnt_reset) begin
            sr_cnt <= 0;
        end else begin
          if (sr_cnt_inc) begin
              sr_cnt <= sr_cnt + 1;       
          end
        end
    end // else: !if(!hresetn)
end // always@ (posedge hclk)

//assign sa_match = (sa == slave_addr);
assign sa_match = (sa == slave_addr) || (sa =={1'b0,slave_addr[6:1]});  //
assign sa_shift_en = pe_scl & (state == BYTE_SA);    //send the slave address
assign addr_shift_en = pe_scl & (state == BYTE_ADDR);  //sda_in transfer data to addr

assign addr_inc = pe_scl & ((state == BYTE_ACK_WR) |   
                  ((state == BYTE_ACK_SA) & rw) |      //finished write or read ,ready to go to next state
                  (state == BYTE_ACK_RD));

assign wr_sr_shift_en = pe_scl & (state == BYTE_WR);    //sda_in transfer data to wr_data

assign rd_sr_ld_en = pe_scl & (((state == BYTE_ACK_SA) & rw) |  //ready to read data from slave
                     (state == BYTE_ACK_RD) & !sda_in_d2);  //!sda_in_d2 means nack
assign rd_sr_shift_en = pe_scl & (state == BYTE_RD);    //send data to sda_out

assign sr_cnt_inc = pe_scl;
assign sr_cnt_reset = start | stop | (pe_scl & 
                      ((state == BYTE_ACK_SA) | (state == BYTE_ACK_ADDR) |
                      (state == BYTE_ACK_WR) | (state == BYTE_ACK_RD))) ;

assign shift_done = (sr_cnt == 7);  //8 bits data transfer finished
assign wr_en = pe_scl & (state == BYTE_ACK_WR);
assign wr_data = wr_sr;   

always @(posedge hclk or negedge hresetn) begin
    if (!hresetn) begin
        sda_oe <= 0;
        sda_out <= 0;   
    end
    else begin
        if (ne_scl) begin
            sda_oe <= ((state == BYTE_ACK_SA) & sa_match) |
                      (state == BYTE_ACK_ADDR) |
                      (state == BYTE_ACK_WR) | (state == BYTE_RD);     //recieve data from other
            sda_out <= (state == BYTE_RD) ? rd_sr[7] : !sa_match;  
        end
    end
end

//assign rd_en = rd_sr_ld_en & sa_match;  //read enable

endmodule 
