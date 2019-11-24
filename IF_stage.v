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
reg         buf_br_valid;
reg  [33:0] br_bus_r;
wire [33:0] true_br_bus;
assign {br_op    ,
        br_taken ,
        br_target} = true_br_bus;

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
assign to_fs_valid  = ~reset && inst_sram_addrok; //表示有数据需要在下一拍传给IF级
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       = br_taken ? br_target : seq_pc; 

//buffer
reg         buf_npc_valid;
reg  [31:0] buf_npc;
wire [31:0] true_npc;

assign true_br_bus = buf_br_valid ? br_bus_r : br_bus;
always @(posedge clk) begin
    if (reset)
        buf_br_valid <= 1'b0;
    else if (br_taken && !(to_fs_valid && fs_allowin) && buf_npc_valid) begin//如果有效转移地址没有发出请求也没有被记下来，就保持住br_bus
        buf_br_valid <= 1'b1;
    end
    else if (!buf_npc_valid)
        buf_br_valid <= 1'b0;
    
    if (!buf_br_valid)
        br_bus_r <= br_bus;
end

assign true_npc = buf_npc_valid ? buf_npc : nextpc;
always @(posedge clk)begin
    if (reset)
        buf_npc_valid <= 1'b0;
    else if (to_fs_valid && fs_allowin)
        buf_npc_valid <= 1'b0;
    else if (!buf_npc_valid)
        buf_npc_valid <= 1'b1;
     
    if (!buf_npc_valid)
        buf_npc <=  nextpc;
end

// IF stage
reg fs_ready_go_r;
always @(posedge clk) begin
    if (reset)
        fs_ready_go_r <= 1'b0;
    else if (inst_sram_dataok)
        fs_ready_go_r <= 1'b1;
    else if (ds_allowin)
        fs_ready_go_r <= 1'b0;
end
assign fs_ready_go    = fs_ready_go_r; //表示IF级拿到指令可以传递到ID级了
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
        buf_rdata_valid <= inst_sram_dataok;
    
    if (!buf_rdata_valid && inst_sram_dataok)
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
//当IF级allowin时，preIF级才发req
assign inst_sram_req   = to_fs_valid && fs_allowin; //en
assign inst_sram_wr    = 1'h0; //wen
assign inst_sram_size  = 2'd2;
assign inst_sram_addr  = true_npc;
assign inst_sram_wstrb = 4'h0; //wen
assign inst_sram_wdata = 32'd0;

assign fs_inst         = buf_rdata_valid ? buf_rdata : inst_sram_rdata;

endmodule
