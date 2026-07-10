/*
    Design Specification (Verilog RTL) :
        1. Parameterize data width DATA_W (default 8) and depth DEPTH (default 16, must support any power-of-two depth).
        2. Use a circular buffer implemented with a register array (not SRAM macros). Read and write pointers must be one bit wider than needed to distinguish full from empty (the classic N+1 bit pointer trick).
        3. Implement standard flags: full, empty, and also programmable almost_full (asserted when occupancy >= AFULL_THRESH) and almost_empty (asserted when occupancy <= AEMPTY_THRESH), where both thresholds are runtime-configurable inputs.
        4. Push and pop must be single-cycle operations on the rising clock edge. Simultaneously asserting wr_en and rd_en when neither full nor empty must safely bypass data (show/write-first behavior, selectable via parameter).
        5. The design must handle back-pressure correctly: writes when full and reads when empty must silently ignored without corrupting the pointer state.
        6. Include an occupancy output port giving the exact number of valid entries at all times.
    
    Parameter :
        1. DATA_W : Width of data in bits
        2. DEPTH : Number of elements in the FIFO
        
    Inputs: 
        1. DIN
        2. WR_en
        3. RD_en
        4. AFULL_THRESH
        5. AEMPTY_THRESH
    
    Outputs:
        1. DOUT
        2. Empty
        3. Full
        4. Almost_FULL
        5. Almost_EMPTY
    
    File specific information: 
        This synchronous FIFO is used for simultaneous Read and Write access at two different addresses in same clock cycle, this is achieved using dual port.
*/

`timescale 1ns / 1ns
module Synchronous_FIFO#(
    parameter DATA_W = 8, DEPTH = 16
    )(
    output  reg     [DATA_W-1 : 0]          DOUT,
    output  wire                            Empty, 
                                            Full,
                                            Almost_Full,
                                            Almost_Empty,
    input   wire                            CLK,
    input   wire                            RST_N,
    input   wire    [$clog2(DEPTH) : 0]     AFULL_THRESH,
                                            AEMPTY_THRESH,                         
    input   wire    [DATA_W-1 : 0]          DIN,
    input   wire                            RD_en, 
                                            WR_en
    );
    
    localparam ADDR_W = $clog2(DEPTH);
    
    reg     [DATA_W-1 : 0]      MEM     [0 : DEPTH-1];
    
    reg     [ADDR_W : 0]        WR_ptr;
    reg     [ADDR_W : 0]        RD_ptr;
    
    wire    [ADDR_W : 0]        occupancy;
    
    integer i;
    
    initial begin
        WR_ptr  <=  0;
        RD_ptr  <=  0;
        DOUT    <=  0;
        for (i = 0; i < DEPTH; i = i + 1) begin
            MEM[i] = {DATA_W{1'b0}};
        end
    end
    
    always @(posedge CLK or negedge RST_N) begin
        if (!RST_N) begin
            WR_ptr  <=  0;
            RD_ptr  <=  0;
            DOUT    <=  0;
        end 
        
        else begin 
            if (WR_en && !Full) begin
                MEM[WR_ptr[ADDR_W-1 : 0]] <= DIN;
                WR_ptr <= WR_ptr + 1;
            end
            
            if (RD_en && !Empty) begin
                DOUT <= MEM[RD_ptr[ADDR_W-1 : 0]];
                RD_ptr <= RD_ptr + 1;
            end
        end
    end
    
    assign Empty = WR_ptr == RD_ptr;
    assign Full  = (WR_ptr[ADDR_W-1 : 0] == RD_ptr[ADDR_W-1 : 0]) && (WR_ptr[ADDR_W] != RD_ptr[ADDR_W]);
    
    assign occupancy    = WR_ptr - RD_ptr;
    
    assign Almost_Full  = occupancy >= AFULL_THRESH; 
    assign Almost_Empty = occupancy <= AEMPTY_THRESH;
    
endmodule
