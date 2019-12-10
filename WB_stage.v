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
    output [31:0] new_pc,
    //TLB
    output [26:0] cp0_entryhi_bus,
    input  [ 5:0] tlbp_bus,
    
    output        we,
    output [ 3:0] w_index,
    output [18:0] w_vpn2,
    output [ 7:0] w_asid,
    output        w_g,
    output [19:0] w_pfn0,
    output [ 2:0] w_c0,
    output        w_d0,
    output        w_v0,
    output [19:0] w_pfn1,
    output [ 2:0] w_c1,
    output        w_d1,
    output        w_v1,
    
    output [ 3:0] r_index,
    input  [18:0] r_vpn2,
    input  [ 7:0] r_asid,
    input         r_g,
    input  [19:0] r_pfn0,
    input  [ 2:0] r_c0,
    input         r_d0,
    input         r_v0,
    input  [19:0] r_pfn1,
    input  [ 2:0] r_c1,
    input         r_d1,
    input         r_v1
);

wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire        ms_tlbwi_op;
wire        ms_tlbr_op;
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
assign {ms_tlbwi_op    ,  //156:156
        ms_tlbr_op     ,  //155:155
        ms_ex          ,  //154:154
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
wire        ws_tlbwi_op;
wire        ws_tlbr_op;

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
wire [31:0] cp0_index;
wire [31:0] cp0_entrylo0;
wire [31:0] cp0_entrylo1;
reg  [31:0] cp0_badvaddr;
reg  [31:0] cp0_count;
wire [31:0] cp0_entryhi;
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

wire        ws_tlbp_op;
wire        s1_found;
wire [ 3:0] s1_index;
assign {ws_tlbp_op,
        s1_found,
        s1_index
        } = tlbp_bus;

//CP0 Index
reg cp0_index_p;
always@(posedge clk) begin
    if (reset)
        cp0_index_p <= 1'b0;
    else if (ws_tlbp_op)
        cp0_index_p <= !s1_found;
end
reg [3:0] cp0_index_index;
always @(posedge clk) begin
    if (mtc0_we && cp0_addr == `CR_INDEX)
        cp0_index_index <= cp0_wdata[3:0];
    else if (ws_tlbp_op)
        cp0_index_index <= s1_index;
end
assign cp0_index = {cp0_index_p,
                    27'b0,
                    cp0_index_index
                    };

//CP0 EnrtyLo0
reg [19:0] cp0_entrylo0_pfn;
always @(posedge clk) begin
    if (mtc0_we && cp0_addr == `CR_ENTRYLO0)
        cp0_entrylo0_pfn <= cp0_wdata[25:6];
    else if (ws_tlbr_op)
        cp0_entrylo0_pfn <= r_pfn0;
end
reg [2:0] cp0_entrylo0_c;
always @(posedge clk) begin
    if (mtc0_we && cp0_addr == `CR_ENTRYLO0)
        cp0_entrylo0_c <= cp0_wdata[5:3];
    else if (ws_tlbr_op)
        cp0_entrylo0_c <= r_c0;
end
reg cp0_entrylo0_d;
always @(posedge clk) begin
    if (mtc0_we && cp0_addr == `CR_ENTRYLO0)
        cp0_entrylo0_d <= cp0_wdata[2];
    else if (ws_tlbr_op)
        cp0_entrylo0_d <= r_d0;
end
reg cp0_entrylo0_v;
always @(posedge clk) begin
    if (mtc0_we && cp0_addr == `CR_ENTRYLO0)
        cp0_entrylo0_v <= cp0_wdata[1];
    else if (ws_tlbr_op)
        cp0_entrylo0_v <= r_v0;
end
reg cp0_entrylo0_g;
always @(posedge clk) begin
    if (mtc0_we && cp0_addr == `CR_ENTRYLO0)
        cp0_entrylo0_g <= cp0_wdata[0];
    else if (ws_tlbr_op)
        cp0_entrylo0_g <= r_g;
end
assign cp0_entrylo0 = {6'b0,
                       cp0_entrylo0_pfn,
                       cp0_entrylo0_c,
                       cp0_entrylo0_d,
                       cp0_entrylo0_v,
                       cp0_entrylo0_g
                       };

//CP0 EnrtyLo1
reg [19:0] cp0_entrylo1_pfn;
always @(posedge clk) begin
    if (mtc0_we && cp0_addr == `CR_ENTRYLO1)
        cp0_entrylo1_pfn <= cp0_wdata[25:6];
    else if (ws_tlbr_op)
        cp0_entrylo1_pfn <= r_pfn1;
end
reg [2:0] cp0_entrylo1_c;
always @(posedge clk) begin
    if (mtc0_we && cp0_addr == `CR_ENTRYLO1)
        cp0_entrylo1_c <= cp0_wdata[5:3];
    else if (ws_tlbr_op)
        cp0_entrylo1_c <= r_c1;
end
reg cp0_entrylo1_d;
always @(posedge clk) begin
    if (mtc0_we && cp0_addr == `CR_ENTRYLO1)
        cp0_entrylo1_d <= cp0_wdata[2];
    else if (ws_tlbr_op)
        cp0_entrylo1_d <= r_d1;
end
reg cp0_entrylo1_v;
always @(posedge clk) begin
    if (mtc0_we && cp0_addr == `CR_ENTRYLO1)
        cp0_entrylo1_v <= cp0_wdata[1];
    else if (ws_tlbr_op)
        cp0_entrylo1_v <= r_v1;
end
reg cp0_entrylo1_g;
always @(posedge clk) begin
    if (mtc0_we && cp0_addr == `CR_ENTRYLO1)
        cp0_entrylo1_g <= cp0_wdata[0];
    else if (ws_tlbr_op)
        cp0_entrylo1_g <= r_g;
end
assign cp0_entrylo1 = {6'b0,
                       cp0_entrylo1_pfn,
                       cp0_entrylo1_c,
                       cp0_entrylo1_d,
                       cp0_entrylo1_v,
                       cp0_entrylo1_g
                       };

//CP0 EntryHi
reg [18:0] cp0_entryhi_vpn2;
always @(posedge clk) begin
    if (mtc0_we && cp0_addr == `CR_ENTRYHI)
        cp0_entryhi_vpn2 <= cp0_wdata[31:13];
    else if (ws_tlbr_op)
        cp0_entryhi_vpn2 <= r_vpn2;
    //TLB exception
end
reg [7:0] cp0_entryhi_asid;
always @(posedge clk) begin
    if (mtc0_we && cp0_addr == `CR_ENTRYHI)
        cp0_entryhi_asid <= cp0_wdata[7:0];
    else if (ws_tlbr_op)
        cp0_entryhi_asid <= r_asid;
end
assign cp0_entryhi = {cp0_entryhi_vpn2,
                      5'b0,
                      cp0_entryhi_asid
                      };
assign cp0_entryhi_bus = {cp0_entryhi_vpn2, cp0_entryhi_asid};

assign ws_ex = ws_valid && ms_ex;
assign ws_exccode = ms_exccode;
assign ws_final_result = ws_res_from_cp0 ? (cp0_addr == `CR_INDEX)    ? cp0_index : 
                                           (cp0_addr == `CR_ENTRYLO0) ? cp0_entrylo0 : 
                                           (cp0_addr == `CR_ENTRYLO1) ? cp0_entrylo1 : 
                                           (cp0_addr == `CR_BADVADDR) ? cp0_badvaddr : 
                                           (cp0_addr == `CR_COUNT)    ? cp0_count : 
                                           (cp0_addr == `CR_ENTRYHI)  ? cp0_entryhi : 
                                           (cp0_addr == `CR_COMPARE)  ? cp0_compare : 
                                           (cp0_addr == `CR_STATUS)   ? cp0_status : 
                                           (cp0_addr == `CR_CAUSE)    ? cp0_cause : 
                                           (cp0_addr == `CR_EPC)      ? cp0_epc : 
                                                                        ms_final_result : 
                                           ms_final_result ;
assign eret_flush = ws_valid && ws_eret_op;
assign ws_tlbwi_op = ws_valid && ms_tlbwi_op;
assign ws_tlbr_op = ws_valid && ms_tlbr_op;
assign ws_cancel = ws_ex || eret_flush || ws_tlbwi_op || ws_tlbr_op;
assign new_pc = (ws_tlbwi_op || ws_tlbr_op ) ? ws_pc + 3'h4 : 
                eret_flush                   ? cp0_epc : 
                                               32'hbfc00380;

//interrupt
assign ext_int_in = 6'h00;
assign has_int = (cp0_cause_ip & cp0_status_im) != 8'h00 && cp0_status_ie == 1'b1 && cp0_status_exl == 1'b0;

//TLB
assign we      = ws_tlbwi_op;
assign w_index = cp0_index_index;
assign w_vpn2  = cp0_entryhi_vpn2;
assign w_asid  = cp0_entryhi_asid;
assign w_g     = cp0_entrylo0_g & cp0_entrylo1_g;
assign w_pfn0  = cp0_entrylo0_pfn;
assign w_c0    = cp0_entrylo0_c;
assign w_d0    = cp0_entrylo0_d;
assign w_v0    = cp0_entrylo0_v;
assign w_pfn1  = cp0_entrylo1_pfn;
assign w_c1    = cp0_entrylo1_c;
assign w_d1    = cp0_entrylo1_d;
assign w_v1    = cp0_entrylo1_v;

assign r_index = cp0_index_index;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = rf_we;
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_final_result;

endmodule
