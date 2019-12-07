`include "mycpu.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
    //external interrupt
    input  [ 5:0]                   ext_int_in    ,                        
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    //to ds
    output reg ws_valid,
    //to es
    output has_int,
    //trace debug interface
    output [31:0] debug_wb_pc      ,
    output [ 3:0] debug_wb_rf_wen  ,
    output [ 4:0] debug_wb_rf_wnum ,
    output [31:0] debug_wb_rf_wdata,
    //exception
    output ws_cancel,
    output [31:0] new_pc            
);

wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire        ms_ex;
wire [ 4:0] ms_exccode;
wire        ws_bd;
wire [31:0] ws_badvaddr;
wire        ws_eret_op;
wire        mtc0_op;
wire [ 7:0] cp0_addr;
wire [31:0] cp0_wdata;
wire        ws_res_from_cp0;
wire [ 3:0] ws_rf_we;
wire [ 4:0] ws_dest;
wire [31:0] ms_final_result;
wire [31:0] ws_pc;
assign {ms_ex          ,  //154:154
        ms_exccode     ,  //153:149
        ws_bd          ,  //148:148
        ws_badvaddr    ,  //147:116
        ws_eret_op     ,  //115:115
        mtc0_op        ,  //114:114
        cp0_addr       ,  //113:106
        cp0_wdata      ,  //105:74
        ws_res_from_cp0,  //73:73
        ws_rf_we       ,  //72:69
        ws_dest        ,  //68:64
        ms_final_result,  //63:32
        ws_pc             //31:0
       } = ms_to_ws_bus_r;

wire        ws_ex;
wire [ 4:0] ws_exccode;
wire [31:0] ws_final_result;
wire        eret_flush;

wire [3 :0] rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = {rf_we   ,  //40:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_cancel)
        ws_valid <= 1'b0;
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign rf_we    = ws_ex    ? 4'b0 : 
                  ws_valid ? ws_rf_we : 
                             4'b0;
assign rf_waddr = ws_dest;
assign rf_wdata = ws_final_result;

//exception
reg  [31:0] cp0_badvaddr;
reg  [31:0] cp0_count;
reg  [31:0] cp0_compare;
wire [31:0] cp0_status;  
wire [31:0] cp0_cause;
reg  [31:0] cp0_epc;

wire mtc0_we;
assign mtc0_we = ws_valid && mtc0_op && !ws_ex;

wire count_eq_compare;
assign count_eq_compare = cp0_count == cp0_compare;

//CP0 Status
reg cp0_status_bev;
always @(posedge clk) begin
    if (reset)
        cp0_status_bev <= 1'b1;
end
reg [7:0] cp0_status_im;
always @(posedge clk) begin
    if (mtc0_we && cp0_addr == `CR_STATUS)
        cp0_status_im <= cp0_wdata[15:8];
end
reg cp0_status_exl;
always @(posedge clk) begin
    if (reset)
        cp0_status_exl <= 1'b0;
    else if (ws_ex)
        cp0_status_exl <= 1'b1;
    else if (eret_flush)
        cp0_status_exl <= 1'b0;
    else if (mtc0_we && cp0_addr == `CR_STATUS)
        cp0_status_exl <= cp0_wdata[1];
end
reg cp0_status_ie;
always @(posedge clk) begin
    if (reset)
        cp0_status_ie <= 1'b0;
    else if (mtc0_we && cp0_addr == `CR_STATUS)
        cp0_status_ie <= cp0_wdata[0];
end
assign cp0_status = {9'b0, 
                     cp0_status_bev, 
                     6'b0, 
                     cp0_status_im, 
                     6'b0, 
                     cp0_status_exl, 
                     cp0_status_ie
                     };

//CP0 Cause
reg cp0_cause_bd;
always @(posedge clk) begin
    if (reset)
        cp0_cause_bd <= 1'b0;
    else if (ws_ex && !cp0_status_exl)
        cp0_cause_bd <= ws_bd;
end
reg cp0_cause_ti;
always @(posedge clk) begin
    if (reset)
        cp0_cause_ti <= 1'b0;
    else if (mtc0_we && cp0_addr == `CR_COMPARE)
        cp0_cause_ti <= 1'b0;
    else if (count_eq_compare)
        cp0_cause_ti <= 1'b1;
end
reg [7:0] cp0_cause_ip;
//cp0_cause_ip[7:2]
always @(posedge clk) begin
    if (reset)
        cp0_cause_ip[7:2] <= 6'b0;
    else begin
        cp0_cause_ip[7] <= ext_int_in[5] | cp0_cause_ti;
        cp0_cause_ip[6:2] <= ext_int_in[4:0];
    end
end
//cp0_cause_ip[1:0]
always @(posedge clk) begin
    if (reset)
        cp0_cause_ip[1:0] <= 2'b0;
    else if (mtc0_we && cp0_addr == `CR_CAUSE)
        cp0_cause_ip[1:0] <= cp0_wdata[9:8];
end
reg [4:0] cp0_cause_exccode;
always @(posedge clk) begin
    if (reset)
        cp0_cause_exccode <= 1'b0;
    else if (ws_ex)
        cp0_cause_exccode <= ws_exccode;
end
assign cp0_cause = {cp0_cause_bd, 
                    cp0_cause_ti, 
                    14'b0, 
                    cp0_cause_ip, 
                    1'b0, 
                    cp0_cause_exccode, 
                    2'b0
                    };

//CP0 EPC
always @(posedge clk) begin
    if (ws_ex && !cp0_status_exl)
        cp0_epc <= ws_bd ? ws_pc - 3'h4 : ws_pc;
    else if (mtc0_we && cp0_addr == `CR_EPC)
        cp0_epc <= cp0_wdata;
end

//CP0 BadVAddr
always @(posedge clk) begin
    if (ws_ex && (ws_exccode == `EX_ADEL || ws_exccode == `EX_ADES))
        cp0_badvaddr <= ws_badvaddr;
end

//CP0 Count
reg tick;
always @(posedge clk) begin
    if (reset)
        tick <= 1'b0;
    else
        tick <= ~tick;
        
    if (mtc0_we && cp0_addr == `CR_COUNT)
        cp0_count <= cp0_wdata;
    else if (tick)
        cp0_count <= cp0_count + 1'b1;
end

//CP0 Compare
always @(posedge clk) begin
    if (mtc0_we && cp0_addr == `CR_COMPARE)
        cp0_compare <= cp0_wdata;
end

assign ws_ex = ws_valid && ms_ex;
assign ws_exccode = ms_exccode;
assign ws_final_result = ws_res_from_cp0 ? (cp0_addr == `CR_BADVADDR) ? cp0_badvaddr : 
                                           (cp0_addr == `CR_COUNT) ? cp0_count : 
                                           (cp0_addr == `CR_COMPARE) ? cp0_compare : 
                                           (cp0_addr == `CR_STATUS) ? cp0_status : 
                                           (cp0_addr == `CR_CAUSE) ? cp0_cause : 
                                           (cp0_addr == `CR_EPC) ? cp0_epc : 
                                           ms_final_result : 
                                           ms_final_result ;
assign eret_flush = ws_valid && ws_eret_op;
assign ws_cancel = ws_ex || eret_flush;
assign new_pc = eret_flush ? cp0_epc: 32'hbfc00380;

//interrupt
assign ext_int_in = 6'h00;
assign has_int = (cp0_cause_ip & cp0_status_im) != 8'h00 && cp0_status_ie == 1'b1 && cp0_status_exl == 1'b0;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = rf_we;
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_final_result;

endmodule
