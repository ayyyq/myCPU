module mycpu_top(
    input  [ 5:0] int, //high active

    input         aclk,
    input         aresetn, //low active
    
    output [ 3:0] arid,
    output [31:0] araddr,
    output [ 7:0] arlen,
    output [ 2:0] arsize,
    output [ 1:0] arburst,
    output [ 1:0] arlock,
    output [ 3:0] arcache,
    output [ 2:0] arprot,
    output        arvalid,
    input         arready,
    
    input [ 3:0] rid,
    input [31:0] rdata,
    input [ 1:0] rresp,
    input        rlast,
    input        rvalid,
    output       rready,
    
    output [ 3:0] awid,
    output [31:0] awaddr,
    output [ 7:0] awlen,
    output [ 2:0] awsize,
    output [ 1:0] awburst,
    output [ 1:0] awlock,
    output [ 3:0] awcache,
    output [ 2:0] awprot,
    output        awvalid,
    input         awready,
    
    output [ 3:0] wid,
    output [31:0] wdata,
    output [ 3:0] wstrb,
    output        wlast,
    output        wvalid,
    input         wready,
    
    input  [ 3:0] bid,
    input  [ 1:0] bresp,
    input         bvalid,
    output        bready,

    //debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

//cpu inst sram-like
wire        inst_req;
wire        inst_wr;
wire [1 :0] inst_size;
wire [31:0] inst_addr;
wire [ 3:0] inst_wstrb;
wire [31:0] inst_wdata;
wire [31:0] inst_rdata;
wire        inst_addr_ok;
wire        inst_data_ok;

//cpu data sram-like
wire        data_req;
wire        data_wr;
wire [1 :0] data_size;
wire [31:0] data_addr;
wire [ 3:0] data_wstrb;
wire [31:0] data_wdata;
wire [31:0] data_rdata;
wire        data_addr_ok;
wire        data_data_ok;

mycpu_core u_core(
    .clk          (aclk),
    .resetn       (aresetn),
    
    // external interrupt
    .ext_int_in   (int),
    
    // inst sram interface
    .inst_sram_req   (inst_req),
    .inst_sram_wr    (inst_wr),
    .inst_sram_size  (inst_size),
    .inst_sram_addr  (inst_addr),
    .inst_sram_wstrb (inst_wstrb),
    .inst_sram_wdata (inst_wdata),
    .inst_sram_rdata (inst_rdata),
    .inst_sram_addrok(inst_addr_ok),
    .inst_sram_dataok(inst_data_ok),
    // data sram interface
    .data_sram_req   (data_req),
    .data_sram_wr    (data_wr),
    .data_sram_size  (data_size),
    .data_sram_addr  (data_addr),
    .data_sram_wstrb (data_wstrb),
    .data_sram_wdata (data_wdata),
    .data_sram_rdata (data_rdata),
    .data_sram_addrok(data_addr_ok),
    .data_sram_dataok(data_data_ok),
    // trace debug interface
    .debug_wb_pc       (debug_wb_pc),
    .debug_wb_rf_wen   (debug_wb_rf_wen),
    .debug_wb_rf_wnum  (debug_wb_rf_wnum),
    .debug_wb_rf_wdata (debug_wb_rf_wdata)
);

//sram-like to axi bridge
cpu_axi_interface u_axi_ifc(
    .clk           ( aclk          ),
    .resetn        ( aresetn       ),

    //inst sram-like 
    .inst_req      ( inst_req     ),
    .inst_wr       ( inst_wr      ),
    .inst_size     ( inst_size    ),
    .inst_addr     ( inst_addr    ),
    .inst_wstrb    ( inst_wstrb   ),
    .inst_wdata    ( inst_wdata   ),
    .inst_rdata    ( inst_rdata   ),
    .inst_addr_ok  ( inst_addr_ok ),
    .inst_data_ok  ( inst_data_ok ),
    
    //data sram-like 
    .data_req      ( data_req     ),
    .data_wr       ( data_wr      ),
    .data_size     ( data_size    ),
    .data_addr     ( data_addr    ),
    .data_wstrb    ( data_wstrb   ),
    .data_wdata    ( data_wdata   ),
    .data_rdata    ( data_rdata   ),
    .data_addr_ok  ( data_addr_ok ),
    .data_data_ok  ( data_data_ok ),

    //axi
    //ar
    .arid      ( arid         ),
    .araddr    ( araddr       ),
    .arlen     ( arlen        ),
    .arsize    ( arsize       ),
    .arburst   ( arburst      ),
    .arlock    ( arlock       ),
    .arcache   ( arcache      ),
    .arprot    ( arprot       ),
    .arvalid   ( arvalid      ),
    .arready   ( arready      ),
    //r              
    .rid       ( rid          ),
    .rdata     ( rdata        ),
    .rresp     ( rresp        ),
    .rlast     ( rlast        ),
    .rvalid    ( rvalid       ),
    .rready    ( rready       ),
    //aw           
    .awid      ( awid         ),
    .awaddr    ( awaddr       ),
    .awlen     ( awlen        ),
    .awsize    ( awsize       ),
    .awburst   ( awburst      ),
    .awlock    ( awlock       ),
    .awcache   ( awcache      ),
    .awprot    ( awprot       ),
    .awvalid   ( awvalid      ),
    .awready   ( awready      ),
    //w          
    .wid       ( wid          ),
    .wdata     ( wdata        ),
    .wstrb     ( wstrb        ),
    .wlast     ( wlast        ),
    .wvalid    ( wvalid       ),
    .wready    ( wready       ),
    //b              
    .bid       ( bid          ),
    .bresp     ( bresp        ),
    .bvalid    ( bvalid       ),
    .bready    ( bready       )
);

endmodule
