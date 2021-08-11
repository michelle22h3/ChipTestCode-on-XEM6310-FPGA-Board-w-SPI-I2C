module cfg_digiblk #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 16
)(
    input                           clk,
    input                           rst_n,
    input                           sta_wei_wr,
    input                           sta_act_wr,
    output reg                      sta_wei_wr_flag, // Flag register
    output reg                      sta_act_wr_flag,
    output reg  [2:0]               cfg_act_dat_end, // Configuration registers
    output reg  [1:0]               cfg_act_trigger,
    output reg  [1:0]               cfg_weight_drv,
    output reg  [2:0]               cfg_adc_msbwait,
    output reg  [2:0]               cfg_adc_bitwait,
    output reg  [3:0]               cfg_adc_msb_loc,
    output reg  [1:0]               cfg_adc_signlen,
    output reg  [1:0]               cfg_adc_begin,
    output reg                      ctrl_wei_sft,    // Control registers
    output reg                      ctrl_act_sft,
    output reg                      ctrl_force_trig,
    output reg                      ctrl_force_ww,
    output reg  [15:0]              data_wei,
    output reg  [15:0]              data_act,
    input       [15:0]              data_out,
    input       [15:0]              wei_sftout,
    input       [15:0]              act_sftout,
    input                           reg_ce,
    input       [ADDR_WIDTH-1:0]    reg_addr,
    input                           reg_we,
    input       [DATA_WIDTH-1:0]    reg_wdata,
    output reg  [DATA_WIDTH-1:0]    reg_rdata,
    // additional logic
    output reg                      data_wei_vld   ,// data_wei valid
    output wire                     loadw_st       ,// load weight start
    output reg                      data_act_vld   ,// data_act valid
    output wire                     loada_st       ,// load activation start
    output reg                      saout_ren      ,// SAOUT read enable
    output wire                     testw_st       ,// enable testpattern of wei start
    output reg                      testw_sft      ,// shift in testpattern
    output reg                      testa_sft       // shift in testpattern
);

localparam STATUS      = 8'h00;  // 0000_0000   
localparam CONFIG_W    = 8'h10;  // 0001_0000
localparam CONFIG_R    = 8'h14;  // 0001_0100
localparam CTRL_DBG    = 8'h24;  // 0010_0100
localparam CTRL_TEST   = 8'h28;  // 0010_1000
localparam CTRL_IN     = 8'h2C;  // 0010_1100
localparam WEIGHT      = 8'h30;  // 0011_0000
localparam ACTIVATION  = 8'h34;  // 0011_0100
localparam DOUT        = 8'h38;  // 0011_1000
localparam W_SFTOUT    = 8'h3C;  // 0011_1100
localparam A_SFTOUT    = 8'h40;  // 0100_0000

//address decoder
wire is_STATUS      = (reg_addr==STATUS);
wire is_CONFIG_W    = (reg_addr==CONFIG_W);
wire is_CONFIG_R    = (reg_addr==CONFIG_R);
wire is_CTRL_DBG    = (reg_addr==CTRL_DBG);
wire is_CTRL_TEST   = (reg_addr==CTRL_TEST);
wire is_CTRL_IN     = (reg_addr==CTRL_IN);
wire is_WEIGHT      = (reg_addr==WEIGHT);
wire is_ACTIVATION  = (reg_addr==ACTIVATION);
wire is_DOUT        = (reg_addr==DOUT);

reg  ctrl_wei_test_en;
reg  ctrl_wei_testptn;
reg  ctrl_act_test_en;
reg  ctrl_act_testptn;
reg  ctrl_loada_vld;
reg  ctrl_loadw_vld;

// additional logic
reg        loadw_vld_d1;
reg        loadw_vld_d2;
reg        loada_vld_d1;
reg        loada_vld_d2;
reg        wei_test_en_d1;
reg        wei_test_en_d2;
reg  [1:0] testw_sft_cnt;
reg        act_test_en_d1;
reg        act_test_en_d2;
reg  [3:0] testa_sft_cnt;
wire       testa_st;

//read/write control
wire read  = reg_ce & !reg_we;
wire write = reg_ce & reg_we;

//W1C
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        sta_wei_wr_flag    <= 'h0;
    else if (write && is_STATUS)
        sta_wei_wr_flag    <= reg_wdata[1] ? 1'b0 : sta_wei_wr_flag;
    else if (!sta_wei_wr_flag)
        sta_wei_wr_flag    <= sta_wei_wr;
end

//W1C
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        sta_act_wr_flag    <= 'h0;
    else if (write && is_STATUS)
        sta_act_wr_flag    <= reg_wdata[0] ? 1'b0 : sta_act_wr_flag;
    else if (!sta_act_wr_flag)
        sta_act_wr_flag    <= sta_act_wr;
end

//RW
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        cfg_act_dat_end  <= 'h2;
    else if (write && is_CONFIG_W)
        cfg_act_dat_end  <= reg_wdata[10:8];
end

//RW
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        cfg_act_trigger  <= 'h1;
    else if (write && is_CONFIG_W)
        cfg_act_trigger  <= reg_wdata[5:4];
end

//RW
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        cfg_weight_drv  <= 'h1;
    else if (write && is_CONFIG_W)
        cfg_weight_drv  <= reg_wdata[1:0];
end

//RW
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        cfg_adc_msbwait  <= 'h0;
    else if (write && is_CONFIG_R)
        cfg_adc_msbwait  <= reg_wdata[14:12];
end

//RW
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        cfg_adc_bitwait  <= 'h0;
    else if (write && is_CONFIG_R)
        cfg_adc_bitwait  <= reg_wdata[10:8];
end

//RW
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        cfg_adc_msb_loc  <= 'h9;
    else if (write && is_CONFIG_R)
        cfg_adc_msb_loc  <= reg_wdata[7:4];
end

//RW
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        cfg_adc_signlen  <= 'h0;
    else if (write && is_CONFIG_R)
        cfg_adc_signlen  <= reg_wdata[3:2];
end

//RW
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        cfg_adc_begin  <= 'h0;
    else if (write && is_CONFIG_R)
        cfg_adc_begin  <= reg_wdata[1:0];
end

//W1P
//assign ctrl_wei_sft = write & is_CTRL_DBG & reg_wdata[3];
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        ctrl_wei_sft  <= 1'b0;
    else if (write & is_CTRL_DBG & reg_wdata[3])
        ctrl_wei_sft  <= 1'b1;
    else
        ctrl_wei_sft  <= 1'b0;
end

//W1P
//assign ctrl_act_sft = write & is_CTRL_DBG & reg_wdata[2];
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        ctrl_act_sft  <= 1'b0;
    else if (write & is_CTRL_DBG & reg_wdata[2])
        ctrl_act_sft  <= 1'b1;
    else
        ctrl_act_sft  <= 1'b0;
end

//W1P
//assign ctrl_force_trig = write & is_CTRL_DBG & reg_wdata[1];
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        ctrl_force_trig  <= 1'b0;
    else if (write & is_CTRL_DBG & reg_wdata[1])
        ctrl_force_trig  <= 1'b1;
    else
        ctrl_force_trig  <= 1'b0;
end

//W1P
//assign ctrl_force_ww = write & is_CTRL_DBG & reg_wdata[0];
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        ctrl_force_ww  <= 1'b0;
    else if (write & is_CTRL_DBG & reg_wdata[0])
        ctrl_force_ww  <= 1'b1;
    else
        ctrl_force_ww  <= 1'b0;
end

//RW
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        ctrl_wei_test_en  <= 'h0;
    else if (write && is_CTRL_TEST)
        ctrl_wei_test_en  <= reg_wdata[3];
end

//RW
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        ctrl_wei_testptn  <= 'h0;
    else if (write && is_CTRL_TEST)
        ctrl_wei_testptn  <= reg_wdata[2];
end

//RW
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        ctrl_act_test_en  <= 'h0;
    else if (write && is_CTRL_TEST)
        ctrl_act_test_en  <= reg_wdata[1];
end

//RW
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        ctrl_act_testptn  <= 'h0;
    else if (write && is_CTRL_TEST)
        ctrl_act_testptn  <= reg_wdata[0];
end

//RW
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        ctrl_loada_vld  <= 'h0;
    else if (write && is_CTRL_IN)
        ctrl_loada_vld  <= reg_wdata[1];
end

//RW
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        ctrl_loadw_vld  <= 'h0;
    else if (write && is_CTRL_IN)
        ctrl_loadw_vld  <= reg_wdata[0];
end

//RW
// additional logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        data_wei  <= 'h0;
    else if (ctrl_wei_test_en)
        data_wei  <= (ctrl_wei_testptn) ? 16'hffff : 16'h0;
    else if (write && is_WEIGHT)
        data_wei  <= reg_wdata[15:0];
end

//RW
// additional logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        data_act  <= 'h0;
    else if (ctrl_act_test_en)
        data_act  <= (ctrl_act_testptn) ? 16'hffff : 16'h0;
    else if (write && is_ACTIVATION)
        data_act  <= reg_wdata[15:0];
end

//output mux
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n)
        reg_rdata <= 'h0;
    else if (read)
        case ({reg_addr[ADDR_WIDTH-1:2],2'h0})
        STATUS:     reg_rdata <= {14'b0,sta_wei_wr_flag,sta_act_wr_flag};
        CONFIG_W:   reg_rdata <= {5'b0,cfg_act_dat_end,2'd0,cfg_act_trigger,2'd0,cfg_weight_drv};
        CONFIG_R:   reg_rdata <= {1'b0,cfg_adc_msbwait,1'b0,cfg_adc_bitwait,cfg_adc_msb_loc,cfg_adc_signlen,cfg_adc_begin};
        CTRL_TEST:  reg_rdata <= {12'b0,ctrl_wei_test_en,ctrl_wei_testptn,ctrl_act_test_en,ctrl_act_testptn};
        CTRL_IN:    reg_rdata <= {14'b0,ctrl_loada_vld,ctrl_loadw_vld};
        WEIGHT:     reg_rdata <= {data_wei};
        ACTIVATION: reg_rdata <= {data_act};
        DOUT:       reg_rdata <= {data_out};
        W_SFTOUT:   reg_rdata <= {wei_sftout};
        A_SFTOUT:   reg_rdata <= {act_sftout};
        default:    reg_rdata <= 'h0;
    endcase
end

// ==============================================
// additional logic
// ==============================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        data_wei_vld  <= 1'b0;
    else if (write && is_WEIGHT && ctrl_loadw_vld)
        data_wei_vld  <= 1'b1;
    else
        data_wei_vld  <= 1'b0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        loadw_vld_d1  <= 1'b0;
        loadw_vld_d2  <= 1'b0;
    end else begin
        loadw_vld_d1  <= ctrl_loadw_vld;
        loadw_vld_d2  <= loadw_vld_d1;
    end
end
assign loadw_st = (loadw_vld_d1 && ~loadw_vld_d2);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        data_act_vld  <= 1'b0;
    else if (write && is_ACTIVATION && ctrl_loada_vld)
        data_act_vld  <= 1'b1;
    else
        data_act_vld  <= 1'b0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        loada_vld_d1  <= 1'b0;
        loada_vld_d2  <= 1'b0;
    end else begin
        loada_vld_d1  <= ctrl_loada_vld;
        loada_vld_d2  <= loada_vld_d1;
    end
end
assign loada_st = (loada_vld_d1 && ~loada_vld_d2);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        saout_ren  <= 1'b0;
    else if (read && is_DOUT)
        saout_ren  <= 1'b1;
    else
        saout_ren  <= 1'b0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wei_test_en_d1  <= 1'b0;
        wei_test_en_d2  <= 1'b0;
    end else begin
        wei_test_en_d1  <= ctrl_wei_test_en;
        wei_test_en_d2  <= wei_test_en_d1;
    end
end
assign testw_st = (wei_test_en_d1 && ~wei_test_en_d2);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        testw_sft  <= 1'b0;
    end else if (testw_sft_cnt==2'd3) begin
        testw_sft  <= 1'b0;
    end else if (testw_st) begin
        testw_sft  <= 1'b1;
    end else begin
        testw_sft  <= testw_sft;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        testw_sft_cnt  <= 2'd0;
    end else if (testw_sft_cnt==2'd3) begin
        testw_sft_cnt  <= 2'd0;
    end else if (testw_sft) begin
        testw_sft_cnt  <= testw_sft_cnt + 1'b1;
    end else begin
        testw_sft_cnt  <= testw_sft_cnt;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        act_test_en_d1  <= 1'b0;
        act_test_en_d2  <= 1'b0;
    end else begin
        act_test_en_d1  <= ctrl_act_test_en;
        act_test_en_d2  <= act_test_en_d1;
    end
end
assign testa_st = (act_test_en_d1 && ~act_test_en_d2);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        testa_sft  <= 1'b0;
    end else if (testa_sft_cnt==4'hf) begin
        testa_sft  <= 1'b0;
    end else if (testa_st) begin
        testa_sft  <= 1'b1;
    end else begin
        testa_sft  <= testa_sft;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        testa_sft_cnt  <= 4'd0;
    end else if (testa_sft_cnt==4'hf) begin
        testa_sft_cnt  <= 4'd0;
    end else if (testa_sft) begin
        testa_sft_cnt  <= testa_sft_cnt + 1'b1;
    end else begin
        testa_sft_cnt  <= testa_sft_cnt;
    end
end

endmodule
