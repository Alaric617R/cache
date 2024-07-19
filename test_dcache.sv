`include "cache_def.svh"
`include "mem.sv"


`define DEBUG
`define CLOCK_PERIOD 10
module testbench;
    logic clock;
    logic reset;
    
    logic stall_out; // when stall is high, pipeline should be stalled

    // from and to pipeline
    DCACHE_REQUEST  dcache_request;
    DCACHE_RESPONSE dcache_response; // register

    // From memory
    logic [3:0]  Dmem2proc_response; // Should be zero unless there is a response
    logic [63:0] Dmem2proc_data;    // size of a cache block in bit
    logic [3:0]  Dmem2proc_tag;

    // To memory
    logic [1:0]  proc2Dmem_command;
    logic [`XLEN-1:0] proc2Dmem_addr;
    logic [63:0] proc2Dmem_data;

    // when program terminates
    logic done;
    logic flush_finished;


    CACHE_LINE [`N_CL-1 : 0] dbg_main_cache_lines;
    VICTIM_CACHE_LINE [`N_VC_CL-1 : 0] dbg_victim_cache_lines;
    logic [$clog2(`N_VC_CL)-1 : 0] dbg_n_vc_avail;
    MSHR_ENTRY [`N_MSHR-1 : 0] dbg_mshr_table;
    logic [$clog2(`N_MSHR)-1 : 0] dbg_n_mshr_avail;
    DC_STATE_T dbg_state;
    DCACHE_REQUEST  dbg_dcache_request_on_wait;

    // CLOCK_PERIOD is defined on the commandline by the makefile
    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    dcache dut(
        .clock(clock),
        .reset(reset),
        
        .stall_out(stall_out),

        .dcache_request(dcache_request),
        .dcache_response(dcache_response),

        .Dmem2proc_response(Dmem2proc_response),
        .Dmem2proc_data(Dmem2proc_data),
        .Dmem2proc_tag(Dmem2proc_tag),

        .proc2Dmem_command(proc2Dmem_command),
        .proc2Dmem_addr(proc2Dmem_addr),
        .proc2Dmem_data(proc2Dmem_data),

        .done(done),
        .flush_finished(flush_finished),

        .dbg_main_cache_lines(dbg_main_cache_lines),
        .dbg_victim_cache_lines(dbg_victim_cache_lines),
        .dbg_n_vc_avail(dbg_n_vc_avail),
        .dbg_mshr_table(dbg_mshr_table),
        .dbg_n_mshr_avail(dbg_n_mshr_avail),
        .dbg_state(dbg_state),
        .dbg_dcache_request_on_wait(dbg_dcache_request_on_wait)
    );

    mem mem(
        .clock(clock),

        .proc2mem_addr(proc2Dmem_addr),
        .proc2mem_data(proc2Dmem_data),
        .proc2mem_command(proc2Dmem_command),

        .mem2proc_response(Dmem2proc_response),
        .mem2proc_data(Dmem2proc_data),
        .mem2proc_tag(Dmem2proc_tag)
    );
    
    // print utilities
    task print_MSHR_TABLE;
        $display("/*** MSHR TABLE ***/");
        for (int i=0; i<`N_MSHR; i++) begin
            if (dbg_mshr_table[i].valid) begin
                $display("MSHR_ENTRY[%0d]:", i);
                $display("  valid: %0d", dbg_mshr_table[i].valid);
                $display("  is_req: %0d", dbg_mshr_table[i].is_req);
                $display("  mem_op: %0d", dbg_mshr_table[i].mem_op);
                $display("  Dmem2proc_tag: %0d", dbg_mshr_table[i].Dmem2proc_tag);
                $display("  Dmem2proc_data: %0h", dbg_mshr_table[i].Dmem2proc_data);
                $display("  cache_line_addr: %0b", dbg_mshr_table[i].cache_line_addr);
                $display("  write_content: %0h", dbg_mshr_table[i].write_content);
            end
        end
    endtask

    task print_MAIN_CACHE_LINES;
        $display("/*** MAIN CACHE LINES ***/");
        for (int i=0; i<`N_CL;i++) begin
            $display("CACHE_LINE[%0d]:", i);
            $display("  addr: %0b", dbg_main_cache_lines[i].addr);
            $display("  valid: %0d", dbg_main_cache_lines[i].valid);
            $display("  dirty: %0d", dbg_main_cache_lines[i].dirty);
            $display("  tag: %0b", dbg_main_cache_lines[i].tag);
            $display("  block: %0h", dbg_main_cache_lines[i].block);
        end
    endtask

    task print_VICTIM_CACHE_LINE;
        $display("/*** VICTIM CACHE LINE ***/");
        for (int i=0; i<`N_VC_CL;i++) begin
            $display("VICTIM_CACHE_LINE[%0d]:", i);
            $display("  addr: %0b", {dbg_victim_cache_lines[i].tag,3'b0});
            $display("  tag: %0b", dbg_victim_cache_lines[i].tag);
            $display("  valid: %0d", dbg_victim_cache_lines[i].valid);
            $display("  dirty: %0d", dbg_victim_cache_lines[i].dirty);
            $display("  lru: %0d", dbg_victim_cache_lines[i].lru);
            $display("  block: %0h", dbg_victim_cache_lines[i].block);
        end
    endtask

    task print_dcache_req_on_wait;
        $display("/*** DCACHE REQUEST ON WAIT ***/");
        if (~dbg_dcache_request_on_wait.valid) begin
            $display("No request on wait");
        end
        $display("  mem_op: %0d", dbg_dcache_request_on_wait.mem_op);
        $display("  addr: %0b", dbg_dcache_request_on_wait.addr);
        $display("  size: %0d", dbg_dcache_request_on_wait.size);
        $display("  write_content: %0h", dbg_dcache_request_on_wait.write_content);
        $display("  valid: %0d", dbg_dcache_request_on_wait.valid);
        $display("  pc: %0h", dbg_dcache_request_on_wait.pc);
    endtask

    task print_this_cycle_state;
        $display("/*** THIS CYCLE STATE ***/");
        case(dbg_state)
            READY: $display("STATE: READY");
            WAIT: $display("STATE: WAIT");
            WAIT_MSHR : $display("STATE: WAIT_MSHR");
            FLUSH: $display("STATE: FLUSH");
        endcase
        $display("STATE: %0d", dbg_state);
        print_MAIN_CACHE_LINES;
        print_VICTIM_CACHE_LINE;
        print_MSHR_TABLE;
    endtask

    // signal generation function
    function DCACHE_REQUEST gen_dcache_read_request(MEM_ADDR_T addr, MEM_SIZE size, PC_T pc);
        DCACHE_REQUEST req = '0;
        req.mem_op = READ;
        req.addr = addr;
        req.size = size;
        req.valid = 1;
        req.pc = pc;
        return req;
    endfunction

    function DCACHE_REQUEST gen_dcache_write_request(MEM_ADDR_T addr, MEM_SIZE size, REG_DATA_T write_content, PC_T pc);
        DCACHE_REQUEST req = '0;
        req.mem_op = READ;
        req.addr = addr;
        req.size = size;
        req.write_content = write_content;
        req.valid = 1;
        req.pc = pc;
        return req;
    endfunction

 initial begin
        $display("/************* Start Testing! *************/");
        reset = 1;
        clock = 0;
        dcache_request = '0;

        $display("/*** DCACHE INFO ***/\n");
        $display("CACHE SIZE: %d\n", `DCACHE_SIZE);
        $display("CACHE BLOCK SIZE: %d\n", `DC_BLK_SZ);
        $display("N_IDX_BITS: %d\n", `N_IDX_BITS);
        `ifdef DIRECT_MAPPED
            $display("ASSOCIATIVITY: DIRECT MAPPED");
        `elsif TWO_WAY_SET_ASSOCIATIVE 
            $display("ASSOCIATIVITY: TWO WAY SET ASSOCIATIVE");
        `else
            $display("ASSOCIATIVITY: NOT DEFINED! ABORT!");
            $finish;
        `endif 
        
        $finish;
 end





endmodule