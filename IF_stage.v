`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // inst sram-like interface
    output        inst_sram_req  ,
    output        inst_sram_wr   ,
    output [ 1:0] inst_sram_size ,
    output [31:0] inst_sram_addr ,
    output [ 3:0] inst_sram_wstrb,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,
    input         inst_sram_addrok,
    input         inst_sram_dataok,                       
    //exception
    input         ws_handle_ex      ,
    input  [31:0] ex_pc
);

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;

wire         br_op;
wire         br_taken;
wire [ 31:0] br_target;
assign {br_op    ,
        br_taken ,
        br_target} = br_bus;

wire        fs_ex;
wire [ 4:0] fs_exccode;
wire        fs_bd;
wire [31:0] fs_badvaddr;
wire [31:0] fs_inst;
reg  [31:0] fs_pc;
assign fs_to_ds_bus = {fs_ex      ,  //102:102
                       fs_exccode ,  //101:97
                       fs_bd      ,  //96:96
                       fs_badvaddr,  //95:64
                       fs_inst    ,  //63:32
                       fs_pc         //31:0
                      };

// pre-IF stage
assign to_fs_valid  = ~reset && inst_sram_addrok; //pre_ready_go = inst_sram_addrok
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       = br_taken ? br_target : seq_pc; 

//buffer
reg         buf_npc_valid;
reg  [31:0] buf_npc;
wire [31:0] true_npc;

assign true_npc = buf_npc_valid ? buf_npc : nextpc;
always @(posedge clk)begin
    if(reset)
        buf_npc_valid <= 1'b0;
    else if(to_fs_valid && fs_allowin)
        buf_npc_valid <= 1'b0;
    else if(!buf_npc_valid)
        buf_npc_valid <= 1'b1;
     
     if(!buf_npc_valid)
        buf_npc <=  nextpc;
end

// IF stage
assign fs_ready_go    = inst_sram_dataok;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (ws_handle_ex)
        fs_valid <= 1'b0;
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end

    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if (ws_handle_ex)
        fs_pc <= ex_pc - 3'h4;
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= true_npc;
    end
end

//buffer
reg buf_rdata_valid;
reg [31:0] buf_rdata;
always @(posedge clk) begin
    if (reset)
        buf_rdata_valid <= 1'b0;
    else if (ds_allowin)
        buf_rdata_valid <= 1'b0;
    else if (!buf_rdata_valid)
        buf_rdata_valid <= 1'b1;
    
    if (!buf_rdata_valid)
        buf_rdata <= inst_sram_rdata;
end

//exception
wire ex_adel;
assign ex_adel = fs_pc[1:0] != 2'b00;

assign fs_ex = fs_valid && ex_adel;
assign fs_exccode = ex_adel ? `EX_ADEL : 5'h00;
assign fs_bd = br_op;
assign fs_badvaddr = fs_pc;

//assign inst_sram_en    = to_fs_valid && fs_allowin;
//assign inst_sram_wen   = 4'h0;
assign inst_sram_req   = to_fs_valid && fs_allowin; //en
assign inst_sram_wr    = 1'h0; //wen
assign inst_sram_size  = 2'd2;
assign inst_sram_addr  = true_npc;
assign inst_sram_wstrb = 4'h0; //wen
assign inst_sram_wdata = 32'd0;

assign fs_inst         = buf_rdata_valid ? buf_rdata : inst_sram_rdata;

endmodule
