`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //from data-sram-like
    input  [31                 :0] data_sram_rdata,
    input                          data_sram_dataok,
    //exception
    output ms_handle_ex,
    input ws_handle_ex
);

reg         ms_valid;
wire        ms_ready_go;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire        es_ex;
wire [ 4:0] es_exccode;
wire        ms_bd;
wire [31:0] ms_badvaddr;
wire        ms_eret_op;
wire        ms_mtc0_op;
wire [ 7:0] ms_cp0_addr;
wire [31:0] ms_cp0_wdata;
wire        ms_res_from_cp0;
wire        ms_res_from_mem;
wire [ 1:0] ms_mem_addr_low;
wire        ms_lb_op;
wire        ms_lbu_op;
wire        ms_lh_op;
wire        ms_lhu_op;
wire        ms_lwl_op;
wire        ms_lwr_op;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;
wire        ms_load_op;
assign {es_ex          ,  //160:160
        es_exccode     ,  //159:155
        ms_bd          ,  //154:154
        ms_badvaddr    ,  //153:122
        ms_eret_op     ,  //121:121
        ms_mtc0_op     ,  //120:120
        ms_cp0_addr    ,  //119:112
        ms_cp0_wdata   ,  //111:80
        ms_res_from_cp0,  //79:79
        ms_res_from_mem,  //78:78
        ms_mem_addr_low,  //77:76
        ms_lb_op       ,  //75:75
        ms_lbu_op      ,  //74:74
        ms_lh_op       ,  //73:73
        ms_lhu_op      ,  //72:72
        ms_lwl_op      ,  //71:71
        ms_lwr_op      ,  //70:70
        ms_gr_we       ,  //69:69
        ms_dest        ,  //68:64
        ms_alu_result  ,  //63:32
        ms_pc             //31:0
       } = es_to_ms_bus_r;

wire        ms_ex;
wire [ 4:0] ms_exccode;
wire [ 3:0] ms_rf_we;
wire [31:0] mem_result;
wire [31:0] ms_final_result;

assign ms_to_ws_bus = {ms_ex          ,  //154:154
                       ms_exccode     ,  //153:149
                       ms_bd          ,  //148:148
                       ms_badvaddr    ,  //147:116
                       ms_eret_op     ,  //115:115
                       ms_mtc0_op     ,  //114:114
                       ms_cp0_addr    ,  //113:106
                       ms_cp0_wdata   ,  //105:74
                       ms_res_from_cp0,  //73:73
                       ms_rf_we       ,  //72:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc             //31:0
                      };

assign ms_load_op = ms_res_from_mem;
assign ms_ready_go    = ms_load_op ? data_sram_dataok : 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ws_handle_ex)
        ms_valid <= 1'b0;
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r <= es_to_ms_bus; //bug 8
    end
end

//buffer
reg buf_rdata_valid;
reg [31:0] buf_rdata;
wire [31:0] true_rdata;

assign true_rdata = buf_rdata_valid ? buf_rdata : data_sram_rdata;
always @(posedge clk) begin
    if (reset)
        buf_rdata_valid <= 1'b0;
    else if (ws_allowin)
        buf_rdata_valid <= 1'b0;
    else if (!buf_rdata_valid)
        buf_rdata_valid <= 1'b1;
    
    if (!buf_rdata_valid)
        buf_rdata <= data_sram_rdata;
end

assign mem_result = ms_lb_op  ? (ms_mem_addr_low == 2'b00) ? {{24{true_rdata[7]}}, true_rdata[7:0]} : 
                                (ms_mem_addr_low == 2'b01) ? {{24{true_rdata[15]}}, true_rdata[15:8]} : 
                                (ms_mem_addr_low == 2'b10) ? {{24{true_rdata[23]}}, true_rdata[23:16]} : 
                                                             {{24{true_rdata[31]}}, true_rdata[31:24]} : 
                    ms_lbu_op ? (ms_mem_addr_low == 2'b00) ? true_rdata[7:0] : 
                                (ms_mem_addr_low == 2'b01) ? true_rdata[15:8] : 
                                (ms_mem_addr_low == 2'b10) ? true_rdata[23:16] : 
                                                             true_rdata[31:24] : 
                    ms_lh_op  ? (ms_mem_addr_low == 2'b00) ? {{16{true_rdata[15]}}, true_rdata[15:0]} : 
                                                             {{16{true_rdata[31]}}, true_rdata[31:16]} : 
                    ms_lhu_op ? (ms_mem_addr_low == 2'b00) ? true_rdata[15:0] : 
                                                             true_rdata[31:16] : 
                    ms_lwl_op ? (ms_mem_addr_low == 2'b00) ? {true_rdata[7:0], 24'b0} : 
                                (ms_mem_addr_low == 2'b01) ? {true_rdata[15:0], 16'b0} : 
                                (ms_mem_addr_low == 2'b10) ? {true_rdata[23:0], 8'b0} : 
                                                             true_rdata : 
                    ms_lwr_op ? (ms_mem_addr_low == 2'b11) ? true_rdata[31:24] : 
                                (ms_mem_addr_low == 2'b10) ? true_rdata[31:16] : 
                                (ms_mem_addr_low == 2'b01) ? true_rdata[31:8] : 
                                                             true_rdata : 
                                                             true_rdata;

assign ms_rf_we = ms_lwl_op ? (ms_mem_addr_low == 2'b00) ? 4'b1000 : 
                              (ms_mem_addr_low == 2'b01) ? 4'b1100 : 
                              (ms_mem_addr_low == 2'b10) ? 4'b1110 : 
                                                           4'b1111 : 
                  ms_lwr_op ? (ms_mem_addr_low == 2'b11) ? 4'b0001 : 
                              (ms_mem_addr_low == 2'b10) ? 4'b0011 : 
                              (ms_mem_addr_low == 2'b01) ? 4'b0111 : 
                                                           4'b1111 : 
                  ms_gr_we ? 4'b1111 : 
                             4'b0000 ;

assign ms_final_result = ms_res_from_mem ? mem_result
                                         : ms_alu_result;

//exception
assign ms_ex = ms_valid && es_ex;
assign ms_exccode = es_exccode;

assign ms_handle_ex = ms_valid && (ms_ex || ms_eret_op);

endmodule
