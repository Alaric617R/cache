`include "cache_def.svh"
`include "sys_defs.svh"
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
    logic [$clog2(`N_MSHR):0] dbg_n_mshr_entry_freed_cnt;
    logic [$clog2(`N_MSHR):0] dbg_n_mshr_entry_occupied_cnt;

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
        .dbg_dcache_request_on_wait(dbg_dcache_request_on_wait),
        .dbg_n_mshr_entry_freed_cnt(dbg_n_mshr_entry_freed_cnt ),
        .dbg_n_mshr_entry_occupied_cnt(dbg_n_mshr_entry_occupied_cnt)

    );

    mem mem(
        .clk(clock),

        .proc2mem_addr(proc2Dmem_addr),
        .proc2mem_data(proc2Dmem_data),
        .proc2mem_command(proc2Dmem_command),

        .mem2proc_response(Dmem2proc_response),
        .mem2proc_data(Dmem2proc_data),
        .mem2proc_tag(Dmem2proc_tag)
    );
    
    // print utilities
    task print_MSHR_TABLE;
        $display("/*** MSHR TABLE (0 for READ)***/");
        for (int i=0; i<`N_MSHR; i++) begin
            if (dbg_mshr_table[i].valid) begin
                $write("MSHR_ENTRY[%0d]:", i);
                $write("  valid: %0d", dbg_mshr_table[i].valid);
                $write("  is_req: %0d", dbg_mshr_table[i].is_req);
                $write("  mem_op: %0d", dbg_mshr_table[i].mem_op);
                $write("  Dmem2proc_tag: %0d", dbg_mshr_table[i].Dmem2proc_tag);
                $write("  Dmem2proc_data: %0h", dbg_mshr_table[i].Dmem2proc_data);
                $write("  cache_line_addr: %0b", dbg_mshr_table[i].cache_line_addr);
                $write("  write_content: %0h", dbg_mshr_table[i].write_content);
                $write("\n");
            end
        end
        $write("\n");
    endtask

    task print_MAIN_CACHE_LINES;
        $display("/*** MAIN CACHE LINES ***/");
        for (int i=0; i<`N_CL;i++) begin
            $write("CACHE_LINE[%0d]:", i);
            $write("  addr: %0b", dbg_main_cache_lines[i].addr);
            $write("  valid: %0d", dbg_main_cache_lines[i].valid);
            $write("  dirty: %0d", dbg_main_cache_lines[i].dirty);
            $write("  tag: %0b", dbg_main_cache_lines[i].tag);
            $write("  block: %0h", dbg_main_cache_lines[i].block);
            $write("\n");
        end
        $write("\n");
    endtask

    task print_VICTIM_CACHE_LINE;
        $display("/*** VICTIM CACHE LINE ***/");
        for (int i=0; i<`N_VC_CL;i++) begin
            $write("VICTIM_CACHE_LINE[%0d]:", i);
            $write("  addr: %0b", {dbg_victim_cache_lines[i].tag,3'b0});
            $write("  tag: %0b", dbg_victim_cache_lines[i].tag);
            $write("  valid: %0d", dbg_victim_cache_lines[i].valid);
            $write("  dirty: %0d", dbg_victim_cache_lines[i].dirty);
            $write("  lru: %0d", dbg_victim_cache_lines[i].lru);
            $write("  block: %0h", dbg_victim_cache_lines[i].block);
            $write("\n");
        end
        $write("\n");
    endtask

    task print_dcache_req_on_wait;
        $display("/*** DCACHE REQUEST ON WAIT ***/");
        if (~dbg_dcache_request_on_wait.valid) begin
            $display("No request on wait");
        end
        $write("  mem_op: %0d", dbg_dcache_request_on_wait.mem_op);
        $write("  addr: %0b", dbg_dcache_request_on_wait.addr);
        $write("  size: %0d", dbg_dcache_request_on_wait.size);
        $write("  write_content: %0h", dbg_dcache_request_on_wait.write_content);
        $write("  valid: %0d", dbg_dcache_request_on_wait.valid);
        $write("  pc: %0h", dbg_dcache_request_on_wait.pc);
        $write("\n");
        $write("\n");
    endtask

    task print_regs;
        $display("STALL_OUT: %0d", stall_out);
        $display("N_MSHR_AVAIL: %0d", dbg_n_mshr_avail);
        $display("N_VC_AVAIL: %0d", dbg_n_vc_avail);
    endtask

    task print_mem_bus;
        $display("/*** MEM BUS INFO ***/");
        case (proc2Dmem_command)
            BUS_NONE: begin 
                $display("BUS COMMAND: NONE");
            end
            BUS_LOAD: begin
                $display("BUS COMMAND: LOAD");
                $display("  proc2Dmem_addr: %0b", proc2Dmem_addr);
                $display("  Dmem2proc_data: %0h", Dmem2proc_data);
            end
            BUS_STORE: begin
                 $display("BUS COMMAND: STORE");
                 $display("  proc2Dmem_data: %0h", proc2Dmem_data);
            end
        endcase
        $display("  Dmem2proc_response: %0d", Dmem2proc_response);
        $display("  Dmem2proc_tag: %0d", Dmem2proc_tag);
    endtask

    task print_combs;
        $display("/*** COMBINATIONAL SIGNALS ***/");
        $display("MSHR_ENTRY_FREED_CNT: %0d", dbg_n_mshr_entry_freed_cnt);
        $display("MSHR_ENTRY_OCCUPIED_CNT: %0d", dbg_n_mshr_entry_occupied_cnt);
    endtask

    task print_this_cycle_state;
        $display("/********************* THIS CYCLE STATE *********************/");
        $display("/* TIME: %d */", $time);
        case(dbg_state)
            READY: $display("STATE: READY");
            WAIT: $display("STATE: WAIT");
            WAIT_MSHR : $display("STATE: WAIT_MSHR");
            FLUSH: $display("STATE: FLUSH");
        endcase
        print_mem_bus;
        print_regs;
        print_combs;
        print_dcache_req_on_wait;
        print_MAIN_CACHE_LINES;
        print_VICTIM_CACHE_LINE;
        print_MSHR_TABLE;
    endtask

    // signal generation function
    function DCACHE_REQUEST gen_dcache_read_request(MEM_ADDR_T addr, MEM_SIZE size, PC_T pc);
        DCACHE_REQUEST req = '0;
        req.mem_op = MEM_READ;
        req.addr = addr;
        req.size = size;
        req.valid = 1;
        req.pc = pc;
        return req;
    endfunction

    function DCACHE_REQUEST gen_dcache_write_request(MEM_ADDR_T addr, MEM_SIZE size, REG_DATA_T write_content, PC_T pc);
        DCACHE_REQUEST req = '0;
        req.mem_op = MEM_WRITE;
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
        $display("CLOCK: %d\n", `CLOCK_PERIOD);
        $display("/*** DCACHE INFO ***/\n");
        $display("CACHE SIZE: %dB\n", `DCACHE_SIZE);
        $display("CACHE BLOCK SIZE: %dB\n", `DC_BLK_SZ);
        $display("N_IDX_BITS: %d\n", `N_IDX_BITS);
        `ifdef DIRECT_MAPPED
            $display("ASSOCIATIVITY: DIRECT MAPPED");
        `elsif TWO_WAY_SET_ASSOCIATIVE 
            $display("ASSOCIATIVITY: TWO WAY SET ASSOCIATIVE");
        `else
            $display("ASSOCIATIVITY: NOT DEFINED! ABORT!");
            $finish;
        `endif 

        @(posedge clock)  #1;
        reset = 0;
        print_this_cycle_state;

        @(posedge clock)  #1;
        dcache_request = gen_dcache_read_request(32'h1000, BYTE, 1);

        @(posedge clock)  #1;
        print_this_cycle_state;

        @(posedge clock)  #1;
        print_this_cycle_state;

        @(posedge clock)  #1;
        print_this_cycle_state;

        
        @(posedge clock)  #1;
        print_this_cycle_state;


        
        $finish;
 end





endmodule