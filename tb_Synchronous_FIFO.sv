/*
    Testbench Requirements (SystemVerilog)
        ✔ 1. Write a SystemVerilog testbench with a virtual interface and a class-based environment.
        ✔ 2. Implement a FIFO scoreboard class that maintains a queue as a golden reference model; every popped value is checked against the front of the reference queue.
        ❌ 3. Directed tests: fill FIFO to depth, read all, re-fill while reading simultaneously, verify almost_full/almost_empty toggle at correct threshold occupancies.
        ✔  4. Constrained-random test: randomize wr_en, rd_en, and wr_data each cycle for 10,000 cycles; the scoreboard must report zero mismatches.
        ❌ 5. Write SVA (SystemVerilog Assertions) properties: 
            ❌ (1) full -> !wr_en or data not corrupted
            ❌ (2) empty -> !rd_en
            ❌ (3) occupancy never exceeds DEPTH
            ❌ (4) almost_full asserts exactly when occupancy >= threshold.
        ❌ 6. Measure functional coverage: covergroup tracking occupancy bins (empty, 1-25%, 26-50%, 51-75%, 76-99%, full), and simultaneous read-write scenarios
    
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
        
*/

`timescale 1ns / 1ns

/*************************************************************************
                                Interface
**************************************************************************/

interface IF_Synchronous_FIFO#(
    DATA_W  =   8,
    DEPTH   =   16    
    )(
    input CLK,
    input RST_N
);
    logic   [DATA_W-1 : 0]          DOUT;
    logic                           Empty,
                                    Full,
                                    Almost_Full,
                                    Almost_Empty;
    logic   [$clog2(DEPTH) : 0]     AFULL_THRESH,
                                    AEMPTY_THRESH;                         
    logic   [DATA_W-1 : 0]          DIN;
    logic                           RD_en, 
                                    WR_en;
    
    modport dut_mp(
        input RD_en, WR_en, DIN, AFULL_THRESH, AEMPTY_THRESH, CLK, RST_N,
        output DOUT, Empty, Full, Almost_Full, Almost_Empty
    );
    modport tb_mp(
        output RD_en, WR_en, DIN, AFULL_THRESH, AEMPTY_THRESH, 
        input DOUT, Empty, Full, Almost_Full, Almost_Empty, CLK, RST_N
    );
                        
endinterface

/*************************************************************************
                                Classes
**************************************************************************/

class data_class #(parameter int DATA_W=8, parameter int DEPTH=16);
    randc   bit [$clog2(DEPTH) : 0] AFULL_THRESH,
                                    AEMPTY_THRESH;
    randc   bit [DATA_W-1 : 0]      DIN;
    rand    bit                     RD_en,
                                    WR_en;                               
    
    constraint full_empty_constraint{
        AFULL_THRESH    inside      {[DEPTH-4 : DEPTH-1]};
        AEMPTY_THRESH   inside      {[1 : 4]};
    }
endclass

class data_driver #(parameter int DATA_W=8, parameter int DEPTH=16);
    virtual IF_Synchronous_FIFO V_IF; 
    
    task data_assign(
        input   logic   [$clog2(DEPTH) : 0]     AFULL_THRESH,
        input   logic   [$clog2(DEPTH) : 0]     AEMPTY_THRESH,
        input   logic   [DATA_W-1 : 0]          DIN,
        input   logic                           RD_en,
        input   logic                           WR_en
        );
        @(negedge V_IF.CLK);
        V_IF.AFULL_THRESH        =   AFULL_THRESH;
        V_IF.AEMPTY_THRESH       =   AEMPTY_THRESH;
        V_IF.DIN                 =   DIN;
        V_IF.RD_en               =   RD_en;
        V_IF.WR_en               =   WR_en;
    endtask
    
    task reset_all_inputs();
        @(negedge V_IF.CLK);
        V_IF.DIN               =   0;
        V_IF.RD_en             =   0;
        V_IF.WR_en             =   0;
    endtask
endclass

class data_scoreboard#(parameter int DATA_W=8, parameter int DEPTH=16);

    logic   [DATA_W-1 : 0]      ref_model       [$]; // Queue
    virtual IF_Synchronous_FIFO V_IF;
    
    task data_assigned(
        input   logic   [$clog2(DEPTH) : 0]     AFULL_THRESH,
        input   logic   [$clog2(DEPTH) : 0]     AEMPTY_THRESH,
        input   logic   [DATA_W-1 : 0]          DIN,
        input   logic                           RD_en,
        input   logic                           WR_en
        );
        
        automatic logic [DATA_W-1 : 0] exp_DOUT;
        
        if (WR_en && !V_IF.Full) begin
            ref_model.push_back(DIN);
            $display("[SCOREBOARD PUSH] Pushed: %h | Queue Size: %0d", DIN, ref_model.size());
        end 
        if (RD_en && !V_IF.Empty) begin
            exp_DOUT = ref_model.pop_front();
            fork 
                begin
                    @(negedge V_IF.CLK);
                    if (exp_DOUT !== V_IF.DOUT) begin
                        $error("[SCOREBOARD FAIL] Data mismatch! Expected: %h | Actual: %h", exp_DOUT, V_IF.DOUT);
                    end else begin
                        $display("[SCOREBOARD PASS] Data matched! Popped: %h | Queue Size: %0d", exp_DOUT, ref_model.size());
                    end
                end
            join_none 
        end
        
    endtask

endclass

/*************************************************************************
                                Module
**************************************************************************/

module tb_Synchronous_FIFO;
    localparam      DATA_W      =   8;
    localparam      DEPTH       =   16;
    localparam      iterate_for =   10000;
    
    logic           CLK;
    logic           RST_N;
    
    IF_Synchronous_FIFO     #(.DATA_W(DATA_W), .DEPTH(DEPTH))   _IF     (.CLK(CLK), .RST_N(RST_N));
    data_class              #(.DATA_W(DATA_W), .DEPTH(DEPTH))   data;
    data_driver             #(.DATA_W(DATA_W), .DEPTH(DEPTH))   drive;
    data_scoreboard         #(.DATA_W(DATA_W), .DEPTH(DEPTH))   scoreboard;
    
    Synchronous_FIFO #(DATA_W, DEPTH) dut (
        .DOUT(_IF.DOUT),
        .Empty(_IF.Empty),
        .Full(_IF.Full),
        .Almost_Full(_IF.Almost_Full),
        .Almost_Empty(_IF.Almost_Empty),
        .CLK(_IF.CLK),
        .RST_N(_IF.RST_N),
        .AFULL_THRESH(_IF.AFULL_THRESH),
        .AEMPTY_THRESH(_IF.AEMPTY_THRESH),
        .DIN(_IF.DIN),
        .RD_en(_IF.RD_en),
        .WR_en(_IF.WR_en)
    );
    
    /*************************************************************************
                                    Tasks
    **************************************************************************/
    
    
       
    /*************************************************************************
                                    Functions
    **************************************************************************/
    
    
    
    /*************************************************************************
                                    Assertsions
    **************************************************************************/
    
    
    
    /*************************************************************************
                                Functional Coverage
    **************************************************************************/
    
    
    
    /*************************************************************************
                                Global Initial Begin
    **************************************************************************/ 
    
    // Clock
    initial begin
        RST_N   =   0;
        CLK     =   0;
        forever #5 CLK = ~CLK; 
    end

    // Global Timeout
    initial begin
        #105000;
        $display("[TIMEOUT] Global Timeout!");
        $finish;
    end
    
    /*************************************************************************
                                    Stimulus
    **************************************************************************/
    
    initial begin
        $dumpfile("tb_Synchronous_FIFO.vcd");
        $dumpvars(0, tb_Synchronous_FIFO);
    
        data        =   new();
        drive       =   new();
        scoreboard  =   new();
        
        drive.V_IF  =   _IF;
        scoreboard.V_IF =   _IF;
        
        drive.reset_all_inputs();
        RST_N = 0;
        @(posedge CLK)
        RST_N = 1;
        for (int i=0; i <= iterate_for; i++) begin
            if (!data.randomize()) $fatal("Randomization failed!");
            drive.data_assign(.DIN(data.DIN), .RD_en(data.RD_en), .WR_en(data.WR_en), .AFULL_THRESH(data.AFULL_THRESH), .AEMPTY_THRESH(data.AEMPTY_THRESH)); //, .RST_N(data.RST_N)
            scoreboard.data_assigned(.DIN(data.DIN), .RD_en(data.RD_en), .WR_en(data.WR_en), .AFULL_THRESH(data.AFULL_THRESH), .AEMPTY_THRESH(data.AEMPTY_THRESH));
        end
        @(posedge CLK);
        $display("[COMPLETED] Simulation Completed!");
        $finish;
    end
    
endmodule
