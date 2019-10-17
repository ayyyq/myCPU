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
    //from data-sram
    input  [31                 :0] data_sram_rdata,
    output reg ms_valid
);

wire        ms_ready_go;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
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
assign {ms_res_from_mem,  //78:78
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

wire [ 3:0] ms_rf_we;
wire [31:0] mem_result;
wire [31:0] ms_final_result;

assign ms_to_ws_bus = {ms_rf_we       ,  //72:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc             //31:0
                      };

assign ms_ready_go    = 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r <= es_to_ms_bus; //bug 8
    end
end

assign mem_result = ms_lb_op  ? (ms_mem_addr_low == 2'b00) ? {{24{data_sram_rdata[7]}}, data_sram_rdata[7:0]} : 
                                (ms_mem_addr_low == 2'b01) ? {{24{data_sram_rdata[15]}}, data_sram_rdata[15:8]} : 
                                (ms_mem_addr_low == 2'b10) ? {{24{data_sram_rdata[23]}}, data_sram_rdata[23:16]} : 
                                                             {{24{data_sram_rdata[31]}}, data_sram_rdata[31:24]} : 
                    ms_lbu_op ? (ms_mem_addr_low == 2'b00) ? data_sram_rdata[7:0] : 
                                (ms_mem_addr_low == 2'b01) ? data_sram_rdata[15:8] : 
                                (ms_mem_addr_low == 2'b10) ? data_sram_rdata[23:16] : 
                                                             data_sram_rdata[31:24] : 
                    ms_lh_op  ? (ms_mem_addr_low == 2'b00) ? {{16{data_sram_rdata[15]}}, data_sram_rdata[15:0]} : 
                                                             {{16{data_sram_rdata[31]}}, data_sram_rdata[31:16]} : 
                    ms_lhu_op ? (ms_mem_addr_low == 2'b00) ? data_sram_rdata[15:0] : 
                                                             data_sram_rdata[31:16] : 
                    ms_lwl_op ? (ms_mem_addr_low == 2'b00) ? {data_sram_rdata[7:0], 24'b0} : 
                                (ms_mem_addr_low == 2'b01) ? {data_sram_rdata[15:0], 16'b0} : 
                                (ms_mem_addr_low == 2'b10) ? {data_sram_rdata[23:0], 8'b0} : 
                                                             data_sram_rdata : 
                    ms_lwr_op ? (ms_mem_addr_low == 2'b11) ? data_sram_rdata[31:24] : 
                                (ms_mem_addr_low == 2'b01) ? data_sram_rdata[31:16] : 
                                (ms_mem_addr_low == 2'b10) ? data_sram_rdata[31:8] : 
                                                             data_sram_rdata : 
                                                             data_sram_rdata;

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

endmodule
