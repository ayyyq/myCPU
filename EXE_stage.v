`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // data sram interface
    output        data_sram_en   ,
    output [ 3:0] data_sram_wen  ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata,
    output reg es_valid,
    input ms_ex,
    input handle_ex
);

wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire        ds_ex         ;
wire [ 4:0] ds_exccode    ;
wire        es_bd         ;
wire [31:0] ds_badvaddr   ;
wire        es_eret_op    ;
wire        es_mfc0_op    ;
wire        es_mtc0_op    ;
wire [ 7:0] es_cp0_addr   ;
wire [11:0] es_alu_op     ;
wire        es_lb_op      ;
wire        es_lbu_op     ;
wire        es_lh_op      ;
wire        es_lhu_op     ;
wire        es_lw_op      ;
wire        es_lwl_op     ;
wire        es_lwr_op     ;
wire        es_sb_op      ;
wire        es_sh_op      ;
wire        es_sw_op      ;
wire        es_swl_op     ;
wire        es_swr_op     ;
wire        es_mul_op     ;
wire        es_mulu_op    ;
wire        es_div_op     ;
wire        es_divu_op    ;
wire        es_src1_is_sa ;  
wire        es_src1_is_pc ;
wire        es_src2_is_signed_imm;
wire        es_src2_is_zero_imm;
wire        es_src2_is_8  ;
wire        es_gr_we      ;
wire        es_mem_we     ;
wire        es_hi_re      ;
wire        es_lo_re      ;
wire        es_hi_we      ;
wire        es_lo_we      ;
wire [ 4:0] es_dest       ;
wire [15:0] es_imm        ;
wire [31:0] es_rs_value   ;
wire [31:0] es_rt_value   ;
wire [31:0] es_pc         ;
assign {ds_ex          ,  //205:205
        ds_exccode     ,  //204:200
        es_bd          ,  //199:199
        ds_badvaddr    ,  //198:167
        es_eret_op     ,  //166:166
        es_mfc0_op     ,  //165:165
        es_mtc0_op     ,  //164:164
        es_cp0_addr    ,  //163:156
        es_alu_op      ,  //155:144
        es_lb_op       ,  //143:143
        es_lbu_op      ,  //142:142
        es_lh_op       ,  //141:141
        es_lhu_op      ,  //140:140
        es_lw_op       ,  //139:139
        es_lwl_op      ,  //138:138
        es_lwr_op      ,  //137:137
        es_sb_op       ,  //136:136
        es_sh_op       ,  //135:135
        es_sw_op       ,  //134:134
        es_swl_op      ,  //133:133
        es_swr_op      ,  //132:132
        es_mul_op      ,  //131:131
        es_mulu_op     ,  //130:130
        es_div_op      ,  //129:129
        es_divu_op     ,  //128:128
        es_src1_is_sa  ,  //127:127
        es_src1_is_pc  ,  //126:126
        es_src2_is_signed_imm ,  //125:125
        es_src2_is_zero_imm,  //124:124
        es_src2_is_8   ,  //123:123
        es_gr_we       ,  //122:122
        es_mem_we      ,  //121:121
        es_hi_re       ,  //120:120
        es_lo_re       ,  //119:119
        es_hi_we       ,  //118:118
        es_lo_we       ,  //117:117
        es_dest        ,  //116:112
        es_imm         ,  //111:96
        es_rs_value    ,  //95 :64
        es_rt_value    ,  //63 :32
        es_pc             //31 :0
       } = ds_to_es_bus_r;

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] aluout        ;

wire [32:0] prod_src1     ;
wire [32:0] prod_src2     ;
wire [63:0] pout          ;

wire dividend_tready; //in
wire dividend_tvalid; //out
wire divisor_tready; //in
wire divisor_tvalid; //out
wire dout_tvalid; //in
wire [31:0] dividend      ;
wire [31:0] divisor       ;
wire [63:0] dout          ;
wire [31:0] quotient      ;
wire [31:0] remainder     ;

wire [31:0] es_alu_result ;

reg  [31:0] hi;
reg  [31:0] lo;
wire [31:0] hi_rdata;
wire [31:0] lo_rdata;

wire        es_ex;
wire [ 4:0] es_exccode;
wire [31:0] es_badvaddr;
wire [31:0] es_cp0_wdata;
wire        es_res_from_cp0;
wire        es_res_from_mem;
wire [ 1:0] es_mem_addr_low;

assign es_res_from_cp0 = es_mfc0_op;
assign es_res_from_mem = es_lb_op | es_lbu_op | es_lh_op | es_lhu_op | es_lw_op | es_lwl_op | es_lwr_op;
assign es_to_ms_bus = {es_ex          ,  //160:160
                       es_exccode     ,  //159:155
                       es_bd          ,  //154:154
                       es_badvaddr    ,  //153:122
                       es_eret_op     ,  //121:121
                       es_mtc0_op     ,  //120:120
                       es_cp0_addr    ,  //119:112
                       es_cp0_wdata   ,  //111:80
                       es_res_from_cp0,  //79:79
                       es_res_from_mem,  //78:78
                       es_mem_addr_low,  //77:76
                       es_lb_op       ,  //75:75
                       es_lbu_op      ,  //74:74
                       es_lh_op       ,  //73:73
                       es_lhu_op      ,  //72:72
                       es_lwl_op      ,  //71:71
                       es_lwr_op      ,  //70:70
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       es_alu_result  ,  //63:32
                       es_pc             //31:0
                      };

wire es_div_block = es_valid && (es_div_op || es_divu_op) && !dout_tvalid;

assign es_ready_go    = !es_div_block;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (handle_ex)
        es_valid <= 1'b0;
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

assign es_alu_src1 = es_src1_is_sa  ? {27'b0, es_imm[10:6]} : 
                     es_src1_is_pc  ? es_pc[31:0] :
                                      es_rs_value;
assign es_alu_src2 = es_src2_is_signed_imm ? {{16{es_imm[15]}}, es_imm[15:0]} : 
                     es_src2_is_zero_imm   ? {{16{1'b0}}, es_imm[15:0]} : 
                     es_src2_is_8          ? 32'd8 :
                                             es_rt_value;

alu u_alu(
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ), //bug 4
    .alu_src2   (es_alu_src2  ),
    .alu_result (aluout       )
    );

assign prod_src1 = es_mul_op ? {es_alu_src1[31], es_alu_src1[31:0]} : 
                               {1'b0, es_alu_src1[31:0]};
assign prod_src2 = es_mul_op ? {es_alu_src2[31], es_alu_src2[31:0]} : 
                               {1'b0, es_alu_src2[31:0]};
assign pout = $signed(prod_src1) * $signed(prod_src2);

reg dividend_valid;
assign dividend_tvalid = (es_div_op || es_divu_op) && !dividend_valid;
always @(posedge clk) begin
    if (reset)
        dividend_valid <= 1'b0;
    else if (!es_valid)
        dividend_valid <= 1'b0;
    else if ((es_div_op || es_divu_op) && dividend_tready)
        dividend_valid <= 1'b1;
    else if ((es_div_op || es_divu_op) && dout_tvalid)
        dividend_valid <= 1'b0;
end

reg divisor_valid;
assign divisor_tvalid = (es_div_op || es_divu_op) && !divisor_valid;
always @(posedge clk) begin
    if (reset)
        divisor_valid <= 1'b0;
    else if (!es_valid)
        divisor_valid <= 1'b0;
    else if ((es_div_op || es_divu_op) && divisor_tready)
        divisor_valid <= 1'b1;
    else if ((es_div_op || es_divu_op) && dout_tvalid)
        divisor_valid <= 1'b0;
end

assign dividend = es_div_op ? (es_alu_src1[31:0] ^ {32{es_alu_src1[31]}}) + es_alu_src1[31] : 
                              es_alu_src1[31:0];
assign divisor = es_div_op ? (es_alu_src2[31:0] ^ {32{es_alu_src2[31]}}) + es_alu_src2[31] : 
                              es_alu_src2[31:0];
unsigned_div unsigned_div(
    .aclk                   (clk),
    .s_axis_dividend_tdata  (dividend),
    .s_axis_dividend_tready (dividend_tready),
    .s_axis_dividend_tvalid (dividend_tvalid),
    .s_axis_divisor_tdata   (divisor),
    .s_axis_divisor_tready  (divisor_tready),
    .s_axis_divisor_tvalid  (divisor_tready),
    .m_axis_dout_tdata      (dout),
    .m_axis_dout_tvalid     (dout_tvalid)
);
assign quotient  = es_div_op ? (dout[63:32] ^ {32{(es_alu_src1[31] ^ es_alu_src2[31])}}) + (es_alu_src1[31] ^ es_alu_src2[31]) : 
                               dout[63:32];
assign remainder = es_div_op ? (dout[31:0] ^ {32{es_alu_src1[31]}}) + es_alu_src1[31] : 
                               dout[31:0];

always @(posedge clk) begin
    if (es_ex || ms_ex || handle_ex)
        hi <= hi;
    else if (es_mul_op || es_mulu_op)
        hi <= pout[63:32];
    else if ((es_div_op || es_divu_op) && dout_tvalid)
        hi <= remainder;
    else if (es_hi_we)
        hi <= es_alu_src1;
end
always @(posedge clk) begin
    if (es_ex || ms_ex || handle_ex)
        lo <= lo;
    else if (es_mul_op || es_mulu_op)
        lo <= pout[31:0];
    else if ((es_div_op || es_divu_op) && dout_tvalid)
        lo <= quotient;
    else if (es_lo_we)
        lo <= es_alu_src1;
end

assign hi_rdata = hi;
assign lo_rdata = lo;

assign es_alu_result = es_hi_re ? hi_rdata : 
                       es_lo_re ? lo_rdata : 
                                  aluout;

assign es_mem_addr_low = es_alu_result[1:0];

assign data_sram_en    = 1'b1;
assign data_sram_wen   = (es_ex || ms_ex || handle_ex)     ? 4'b0000 : 
                         es_mem_we && es_valid ? es_sb_op  ? (es_mem_addr_low == 2'b00) ? 4'b0001 : 
                                                             (es_mem_addr_low == 2'b01) ? 4'b0010 : 
                                                             (es_mem_addr_low == 2'b10) ? 4'b0100 : 
                                                                                          4'b1000 : 
                                                 es_sh_op  ? (es_mem_addr_low == 2'b00) ? 4'b0011 : 
                                                                                          4'b1100 : 
                                                 es_swl_op ? (es_mem_addr_low == 2'b00) ? 4'b0001 : 
                                                             (es_mem_addr_low == 2'b01) ? 4'b0011 : 
                                                             (es_mem_addr_low == 2'b10) ? 4'b0111 : 
                                                                                          4'b1111 : 
                                                 es_swr_op ? (es_mem_addr_low == 2'b11) ? 4'b1000 : 
                                                             (es_mem_addr_low == 2'b10) ? 4'b1100 : 
                                                             (es_mem_addr_low == 2'b01) ? 4'b1110 : 
                                                                                          4'b1111 : 
                                                                                          4'b1111 : 
                                                                                          4'b0000 ;
assign data_sram_addr  = {es_alu_result[31:2], 2'b00};
assign data_sram_wdata = es_sb_op  ? {4{es_rt_value[7:0]}} : 
                         es_sh_op  ? {2{es_rt_value[15:0]}} : 
                         es_swl_op ? (es_mem_addr_low == 2'b00) ? es_rt_value[31:24] : 
                                     (es_mem_addr_low == 2'b01) ? es_rt_value[31:16] : 
                                     (es_mem_addr_low == 2'b10) ? es_rt_value[31:8] : 
                                                                  es_rt_value : 
                         es_swr_op ? (es_mem_addr_low == 2'b11) ? {es_rt_value[7:0], 24'b0} : 
                                     (es_mem_addr_low == 2'b10) ? {es_rt_value[15:0], 16'b0} : 
                                     (es_mem_addr_low == 2'b01) ? {es_rt_value[23:0], 8'b0} : 
                                                                  es_rt_value : 
                                     es_rt_value;

assign es_cp0_wdata = es_rt_value;

//exception
wire ex_adel;
wire ex_ades;
assign ex_adel  = es_lw_op && es_mem_addr_low != 2'b00
               || (es_lh_op || es_lhu_op) && es_mem_addr_low[0] != 1'b0; 
assign ex_ades  = es_sw_op && es_mem_addr_low != 2'b00
               || es_sh_op && es_mem_addr_low[0] != 1'b0; 

assign es_ex = (ex_adel || ex_ades) ? 1'b1: ds_ex;
assign es_exccode = ex_adel ? `EX_ADEL : 
                    ex_ades ? `EX_ADES : 
                              ds_exccode;
assign es_badvaddr = (ex_adel || ex_ades) ? es_pc : ds_badvaddr;

endmodule
