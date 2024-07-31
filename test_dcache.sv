`include "cache_def.svh"
`include "sys_defs.svh"
`include "mem.sv"


`define DEBUG

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

    // registers
    CACHE_LINE [`N_CL-1 : 0] dbg_main_cache_lines;
    VICTIM_CACHE_LINE [`N_VC_CL-1 : 0] dbg_victim_cache_lines;
    logic [$clog2(`N_VC_CL) : 0] dbg_n_vc_avail;
    MSHR_ENTRY [`N_MSHR-1 : 0] dbg_mshr_table;
    logic [$clog2(`N_MSHR) : 0] dbg_n_mshr_avail;
    DC_STATE_T dbg_state;
    DCACHE_REQUEST  dbg_dcache_request_on_wait;
    logic [$clog2(`N_MSHR):0] dbg_n_mshr_entry_freed_cnt;
    logic [$clog2(`N_MSHR):0] dbg_n_mshr_entry_occupied_cnt;
    // register peripherals
    CACHE_LINE [`N_CL-1 : 0] dbg_next_main_cache_lines;
    VICTIM_CACHE_LINE [`N_VC_CL-1 : 0] dbg_next_victim_cache_lines;
    logic [$clog2(`N_VC_CL) : 0] dbg_next_n_vc_avail;
    MSHR_ENTRY [`N_MSHR-1 : 0] dbg_next_mshr_table;
    logic [$clog2(`N_MSHR) : 0] dbg_next_n_mshr_avail;
    DC_STATE_T dbg_next_state;
    DCACHE_REQUEST  dbg_next_dcache_request_on_wait;
    // combinational signals
    logic dbg_cache_hit;
    logic dbg_main_cache_hit;
    logic [`N_IDX_BITS:0] dbg_main_cache_hit_index;
    logic dbg_vc_hit;
    logic [$clog2(`N_VC_CL) : 0] dbg_vc_hit_index;
    logic dbg_mshr_hit;
    logic dbg_mshr_real_hit;
    logic [$clog2(`N_MSHR): 0]  dbg_mshr_hit_index;
    logic dbg_request_finished;
    // commuication wires
    MSHR_ENTRY dbg_mshr2dcache_packet;  // when a memory response comes in; erase matched MSHR entry and transfer that cache line to main cache/victim cache
    VICTIM_CACHE_LINE dbg_vic_cache_line_evicted;  // must be from victim cache to MSHR
    CACHE_LINE dbg_main_cache_line_evicted; // from main cache to victim cache
    MEM_ADDR_T dbg_main_cache_line_evicted_addr; // address of CL evicted from main cache
    CACHE_LINE dbg_main_cache_line_upon_hit; // cache line hit at main cache
    VICTIM_CACHE_LINE dbg_vic_cache_line_upon_hit; //cache line hit at victim cache
    // main cache related
    logic [$clog2(`N_CL):0] dbg_cache_line_index_for_new_data;
    logic dbg_need_to_evict;
    logic dbg_mshr2dcache_packet_USED;
    logic dbg_loaded_CL_same_addr_as_evicted_CL;
    logic [$clog2(`N_CL):0] dbg_cache_line_index_for_MSHR_real_hit;
    logic dbg_need_to_evict_MSHR_real_hit;
    DBG_MAIN_CACHE_STATE_T dbg_main_cache_response_case;
// victim cache related
    logic dbg_vc_need_evict;
    VICTIM_CACHE_LINE dbg_vc_CL_evicted;
    logic [$clog2(`N_VC_CL) : 0] dbg_vc_CL_evicted_index;
    logic [$clog2(`N_VC_CL) : 0] dbg_vc_free_index;
    logic [$clog2(`N_VC_CL) : 0] dbg_current_smallest_index;
    logic [$clog2(`N_VC_CL) : 0] dbg_current_smallest_lru;
    logic [$clog2(`N_VC_CL) : 0] dbg_index_selector;
    // dcache response related
    // MSHR related
    PREFETCH_ADDR_T [`N_PF:0] dbg_addrs2mshr;
    MEM_ADDR_T dbg_base_addr;
    logic [`N_PF:0] [$clog2(`N_MSHR):0]   dbg_free_mshr_entry_idx;
    logic [`N_MSHR:0] [`N_PF:0] dbg_idx_wires;
    logic [$clog2(`N_MSHR):0] dbg_mshr_index_to_issue;
    logic [$clog2(`N_MSHR):0] dbg_mshr_index_to_issue_hi_priority;
    logic [$clog2(`N_MSHR):0] dbg_mshr_index_to_issue_mid_priority;
    logic [$clog2(`N_MSHR):0] dbg_mshr_index_to_issue_low_priority;
    logic dbg_high_priority_exist;
    logic dbg_mid_priority_exist;
    logic dbg_low_priority_exist;
    logic dbg_issue2mem;
    logic dbg_can_allocate_new_mshr_entry;
    MSHR_ENTRY [`N_MSHR - 1 : 0] dbg_tmp_next_1_mshr_table;
    MSHR_ENTRY [`N_MSHR - 1 : 0] dbg_tmp_next_2_mshr_table;
    MSHR_ENTRY [`N_MSHR - 1 : 0] dbg_tmp_next_3_mshr_table;
    logic [`N_MSHR:0] [$clog2(`N_MSHR):0]  dbg_n_mshr_avail_wires;

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
        // registers
        .dbg_main_cache_lines(dbg_main_cache_lines),
        .dbg_victim_cache_lines(dbg_victim_cache_lines),
        .dbg_n_vc_avail(dbg_n_vc_avail),
        .dbg_mshr_table(dbg_mshr_table),
        .dbg_n_mshr_avail(dbg_n_mshr_avail),
        .dbg_state(dbg_state),
        .dbg_dcache_request_on_wait(dbg_dcache_request_on_wait),
        .dbg_n_mshr_entry_freed_cnt(dbg_n_mshr_entry_freed_cnt ),
        .dbg_n_mshr_entry_occupied_cnt(dbg_n_mshr_entry_occupied_cnt),
        // register peripherals
        .dbg_next_main_cache_lines(dbg_next_main_cache_lines),
        .dbg_next_victim_cache_lines(dbg_next_victim_cache_lines),
        .dbg_next_n_vc_avail(dbg_next_n_vc_avail),
        .dbg_next_mshr_table(dbg_next_mshr_table),
        .dbg_next_n_mshr_avail(dbg_next_n_mshr_avail),
        .dbg_next_state(dbg_next_state),
        .dbg_next_dcache_request_on_wait(dbg_next_dcache_request_on_wait),
        // combinational signals
        .dbg_cache_hit(dbg_cache_hit),
        .dbg_main_cache_hit(dbg_main_cache_hit),
        .dbg_main_cache_hit_index(dbg_main_cache_hit_index),
        .dbg_vc_hit(dbg_vc_hit),
        .dbg_vc_hit_index(dbg_vc_hit_index),
        .dbg_mshr_hit(dbg_mshr_hit),
        .dbg_mshr_real_hit(dbg_mshr_real_hit),
        .dbg_mshr_hit_index(dbg_mshr_hit_index),
        .dbg_request_finished(dbg_request_finished),
        // commuication wires
        .dbg_mshr2dcache_packet(dbg_mshr2dcache_packet),
        .dbg_vic_cache_line_evicted(dbg_vic_cache_line_evicted),
        .dbg_main_cache_line_evicted(dbg_main_cache_line_evicted),
        .dbg_main_cache_line_evicted_addr(dbg_main_cache_line_evicted_addr),
        .dbg_main_cache_line_upon_hit(dbg_main_cache_line_upon_hit),
        .dbg_vic_cache_line_upon_hit(dbg_vic_cache_line_upon_hit),
        // main cache related
        .dbg_cache_line_index_for_new_data(dbg_cache_line_index_for_new_data),
        .dbg_need_to_evict(dbg_need_to_evict),
        .dbg_mshr2dcache_packet_USED(dbg_mshr2dcache_packet_USED),
        .dbg_loaded_CL_same_addr_as_evicted_CL(dbg_loaded_CL_same_addr_as_evicted_CL),
        .dbg_cache_line_index_for_MSHR_real_hit(dbg_cache_line_index_for_MSHR_real_hit),
        .dbg_need_to_evict_MSHR_real_hit(dbg_need_to_evict_MSHR_real_hit),
        .dbg_main_cache_response_case(dbg_main_cache_response_case),
        // victim cache related
        .dbg_vc_need_evict(dbg_vc_need_evict),
        .dbg_vc_CL_evicted(dbg_vc_CL_evicted),
        .dbg_vc_CL_evicted_index(dbg_vc_CL_evicted_index),
        .dbg_vc_free_index(dbg_vc_free_index),
        .dbg_current_smallest_index(dbg_current_smallest_index),
        .dbg_current_smallest_lru(dbg_current_smallest_lru),
        .dbg_index_selector(dbg_index_selector),
        // dcache response related
        // MSHR related
        .dbg_addrs2mshr(dbg_addrs2mshr),
        .dbg_base_addr(dbg_base_addr),
        .dbg_free_mshr_entry_idx(dbg_free_mshr_entry_idx),
        .dbg_idx_wires(dbg_idx_wires),
        .dbg_mshr_index_to_issue(dbg_mshr_index_to_issue),
        .dbg_mshr_index_to_issue_hi_priority(dbg_mshr_index_to_issue_hi_priority),
        .dbg_mshr_index_to_issue_mid_priority(dbg_mshr_index_to_issue_mid_priority),
        .dbg_mshr_index_to_issue_low_priority(dbg_mshr_index_to_issue_low_priority),
        .dbg_high_priority_exist(dbg_high_priority_exist),
        .dbg_mid_priority_exist(dbg_mid_priority_exist),
        .dbg_low_priority_exist(dbg_low_priority_exist),
        .dbg_issue2mem(dbg_issue2mem),
        .dbg_can_allocate_new_mshr_entry(dbg_can_allocate_new_mshr_entry),
        .dbg_tmp_next_1_mshr_table(dbg_tmp_next_1_mshr_table),
        .dbg_tmp_next_2_mshr_table(dbg_tmp_next_2_mshr_table),
        .dbg_tmp_next_3_mshr_table(dbg_tmp_next_3_mshr_table),
        .dbg_n_mshr_avail_wires(dbg_n_mshr_avail_wires)







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


    task print_req_combs;
        case(dbg_state)
            READY: $display("STATE: READY");
            WAIT: $display("STATE: WAIT");
            WAIT_MSHR: $display("STATE: WAIT_MSHR");
            FLUSH: $display("STATE: FLUSH");
        endcase
        case(dbg_next_state)
            READY: $display("NEXT STATE: READY");
            WAIT: $display("NEXT STATE: WAIT");
            WAIT_MSHR: $display("NEXT STATE: WAIT_MSHR");
            FLUSH: $display("NEXT STATE: FLUSH");
        endcase
        if (dcache_request.valid) begin
            $write("dcache_request: VALID  ");
            case(dcache_request.mem_op)
                MEM_READ: $write("MEM_OP: READ");
                MEM_WRITE: $write("MEM_OP: WRITE");
            endcase
            $write("  ADDR: %0b", dcache_request.addr);
            $write("  SIZE: %0d", dcache_request.size);
            $write("  WRITE_CONTENT: %0d", dcache_request.write_content);
            $write("  PC: %0h", dcache_request.pc);
            $write("\n");
        end else begin
            $display("dcache_request: NOT VALID");
        end
        if (dbg_dcache_request_on_wait.valid) begin
            $write("dbg_dcache_request_on_wait: VALID  ");
            case(dbg_dcache_request_on_wait.mem_op)
                MEM_READ: $write("MEM_OP: READ");
                MEM_WRITE: $write("MEM_OP: WRITE");
            endcase
            $write("  ADDR: %0b", dbg_dcache_request_on_wait.addr);
            $write("  SIZE: %0d", dbg_dcache_request_on_wait.size);
            $write("  WRITE_CONTENT: %0d", dbg_dcache_request_on_wait.write_content);
            $write("  PC: %0h", dbg_dcache_request_on_wait.pc);
            $write("\n");
        end else begin
            $display("dbg_dcache_request_on_wait: NOT VALID");
        end
    endtask

    task print_next_main_cache_combs;
        $display("/*** NEXT MAIN CACHE COMBINATIONAL SIGNALS | TIME: %0d ***/", $time);
        $display("CACHE_HIT: %0d", dbg_cache_hit);
        $display("MAIN_CACHE_HIT: %0d  MAIN_CACHE_HIT_INDEX: %0d", dbg_main_cache_hit, dbg_main_cache_hit_index);
        $display("VC_HIT: %0d  VC_HIT_INDEX: %0d", dbg_vc_hit, dbg_vc_hit_index);
        $display("MSHR_HIT: %0d  MSHR_REAL_HIT: %0d  MSHR_HIT_INDEX: %0d", dbg_mshr_hit, dbg_mshr_real_hit, dbg_mshr_hit_index);
        $display("CACHE_LINE_INDEX_FOR_NEW_DATA: %0d", dbg_cache_line_index_for_new_data);
        $display("NEED_TO_EVICT: %0d", dbg_need_to_evict);
        $display("MSHR2DCACHE_PACKET_USED: %0d", dbg_mshr2dcache_packet_USED);
        $display("LOADED_CL_SAME_ADDR_AS_EVICTED_CL: %0d", dbg_loaded_CL_same_addr_as_evicted_CL);
        $display("CACHE_LINE_INDEX_FOR_MSHR_REAL_HIT: %0d", dbg_cache_line_index_for_MSHR_real_hit);
        $display("NEED_TO_EVICT_MSHR_REAL_HIT: %0d", dbg_need_to_evict_MSHR_real_hit);
        case (dbg_main_cache_response_case)
            NONE: $display("MAIN_CACHE_RESPONSE_CASE: NONE");
            HIT: $display("MAIN_CACHE_RESPONSE_CASE: HIT");
            HIT_ON_MSHR_TABLE: $display("MAIN_CACHE_RESPONSE_CASE: HIT_ON_MSHR_TABLE");
            HIT_ON_MSHR_PKT: $display("MAIN_CACHE_RESPONSE_CASE: HIT_ON_MSHR_PKT");
            FWD_FROM_MSHR_PKT: $display("MAIN_CACHE_RESPONSE_CASE: FWD_FROM_MSHR_PKT");
        endcase
        if (dbg_main_cache_line_evicted.valid) begin
            $write("main_cache_line_evicted: VALID  ");
            $display(" addr: %0b, tag: %0b, dirty: %0d\n", dbg_main_cache_line_evicted.addr, dbg_main_cache_line_evicted.tag, dbg_main_cache_line_evicted.dirty);
            $display("main_cache_line_evicted_addr: %b", dbg_main_cache_line_evicted_addr);
        end else begin
            $display("main_cache_line_evicted: NOT VALID");
        end

        for (int i=0; i<`N_CL; i++) begin
            $write("NEXT_MAIN_CACHE_LINE[%0d]:", i);
            $write("  addr: %0b", dbg_next_main_cache_lines[i].addr);
            $write("  valid: %0d", dbg_next_main_cache_lines[i].valid);
            $write("  dirty: %0d", dbg_next_main_cache_lines[i].dirty);
            $write("  tag: %0b", dbg_next_main_cache_lines[i].tag);
            $write("  block: %0d", dbg_next_main_cache_lines[i].block);
            $write("\n");
        end
    endtask
    
    task print_next_MSHR;

    endtask
    // print utilities
    task print_MSHR_TABLE;
        $display("/*** MSHR TABLE (0 for READ)***/");
        for (int i=0; i<`N_MSHR; i++) begin
            if (dbg_mshr_table[i].valid) begin
                $write("MSHR_ENTRY[%0d]:", i);
                $write("  valid: %0d", dbg_mshr_table[i].valid);
                $write("  is_req: %0d", dbg_mshr_table[i].is_req);
                $write("  issued: %0d", dbg_mshr_table[i].issued);
                $write("  mem_op: %0d", dbg_mshr_table[i].mem_op);
                $write("  Dmem2proc_tag: %0d", dbg_mshr_table[i].Dmem2proc_tag);
                $write("  Dmem2proc_data: %0d", dbg_mshr_table[i].Dmem2proc_data);
                $write("  cache_line_addr: %0b", dbg_mshr_table[i].cache_line_addr);
                $write("  write_content: %0d", dbg_mshr_table[i].write_content);
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
            $write("  block: %0d", dbg_main_cache_lines[i].block);
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
            $write("  block: %0d", dbg_victim_cache_lines[i].block);
            $write("\n");
        end
        $write("\n");
    endtask

    task print_dcache_req_on_wait;
        $display("/*** DCACHE REQUEST ON WAIT ***/");
        if (~dbg_dcache_request_on_wait.valid) begin
            $display("No request on wait");
        end else begin
            $write("  mem_op: %0d", dbg_dcache_request_on_wait.mem_op);
            $write("  addr: %0b", dbg_dcache_request_on_wait.addr);
            $write("  size: %0d", dbg_dcache_request_on_wait.size);
            $write("  write_content: %0d", dbg_dcache_request_on_wait.write_content);
            $write("  valid: %0d", dbg_dcache_request_on_wait.valid);
            $write("  pc: %0h", dbg_dcache_request_on_wait.pc);
            $write("\n");
            $write("\n");
        end
    endtask

    task print_regs;
        $display("STALL_OUT: %0d", stall_out);
        $display("N_MSHR_AVAIL: %d, bit: %b", dbg_n_mshr_avail, dbg_n_mshr_avail);
        $display("N_VC_AVAIL: %d, bit: %b", dbg_n_vc_avail, dbg_n_vc_avail);
    endtask

    task print_mem_bus;
        $display("/*** MEM BUS INFO ***/");
        case (proc2Dmem_command)
            BUS_NONE: begin 
                $display("BUS COMMAND: NONE");
            end
            BUS_LOAD: begin
                $display("BUS COMMAND: LOAD");
            end
            BUS_STORE: begin
                 $display("BUS COMMAND: STORE");
                 $display("  proc2Dmem_data: %0d", proc2Dmem_data);
            end
        endcase
        $display("  proc2Dmem_addr: %0b", proc2Dmem_addr);
        $display("  Dmem2proc_data: %0d", Dmem2proc_data);
        $display("  Dmem2proc_response: %0d", Dmem2proc_response);
        $display("  Dmem2proc_tag: %0d", Dmem2proc_tag);
    endtask

    task print_combs;
        $display("/*** COMBINATIONAL SIGNALS ***/");
        // $display("MSHR_ENTRY_FREED_CNT: %0d", dbg_n_mshr_entry_freed_cnt);
        // $display("MSHR_ENTRY_OCCUPIED_CNT: %0d", dbg_n_mshr_entry_occupied_cnt);
        if (dbg_mshr2dcache_packet.valid) begin
            $display("MSHR2DCACHE_PACKET: VALID");
            $display("  valid: %0d", dbg_mshr2dcache_packet.valid);
            $display("  is_req: %0d", dbg_mshr2dcache_packet.is_req);
            $display("  mem_op: %0d", dbg_mshr2dcache_packet.mem_op);
            $display("  Dmem2proc_tag: %0d", dbg_mshr2dcache_packet.Dmem2proc_tag);
            $display("  Dmem2proc_data: %0d", dbg_mshr2dcache_packet.Dmem2proc_data);
            $display("  cache_line_addr: %0b", dbg_mshr2dcache_packet.cache_line_addr);
            $display("  write_content: %0d", dbg_mshr2dcache_packet.write_content);
        end
        if (dbg_vic_cache_line_evicted.valid) begin
            $display("VIC_CACHE_LINE_EVICTED: VALID");
            $display("  valid: %0d", dbg_vic_cache_line_evicted.valid);
            $display("  dirty: %0d", dbg_vic_cache_line_evicted.dirty);
            $display("  lru: %0d", dbg_vic_cache_line_evicted.lru);
            $display("  tag: %0b", dbg_vic_cache_line_evicted.tag);
            $display("  block: %0d", dbg_vic_cache_line_evicted.block);
        end
        if (dbg_main_cache_line_evicted_addr) begin
            $display("MAIN_CACHE_LINE_EVICTED_ADDR: %0b", dbg_main_cache_line_evicted_addr);
        end
    endtask

    task print_dcache_response;
        $display("/*** DCACHE RESPONSE ***/");
        $display("  reg_data: %0d", dcache_response.reg_data);
        $display("  valid: %0d", dcache_response.valid);
        case (dcache_response.mem_op)
            MEM_READ: $display("  mem_op: READ");
            MEM_WRITE: $display("  mem_op: WRITE");
        endcase
    endtask

    task print_this_cycle_request;
    if (~dcache_request.valid) begin
        $display("/******** THIS CYCLE REQUEST NOT VALID!!!! **********/");
    end else begin
        $display("/******** THIS CYCLE REQUEST **********/");
        $display("/* TIME: %d */", $time);
        case(dcache_request.mem_op)
            MEM_READ: $display("MEM_OP: READ");
            MEM_WRITE: $display("MEM_OP: WRITE");
        endcase
        $display("ADDR: %0b", dcache_request.addr);
        $display("SIZE: %0d", dcache_request.size);
        $display("WRITE_CONTENT: %0d", dcache_request.write_content);
        $display("VALID: %0d", dcache_request.valid);
        $display("PC: %0h", dcache_request.pc);
    end
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
        print_dcache_response;
        print_mem_bus;
        print_regs;
        print_combs;
        print_dcache_req_on_wait;
        print_MAIN_CACHE_LINES;
        print_VICTIM_CACHE_LINE;
        print_MSHR_TABLE;
        print_req_combs;
        print_next_main_cache_combs;
    endtask

    // signal generation function
    function DCACHE_REQUEST gen_dcache_read_request(MEM_ADDR_T addr, MEM_SIZE size, PC_T pc);
        DCACHE_REQUEST req = '0;
        req.mem_op = MEM_READ;
        req.addr = addr;
        req.size = size;
        req.valid = 1;
        req.pc = pc;
        $display("!!!!!!!@@@@@@@ TIME: %0d\nDCACHE REQUEST GENERATED: READ addr: %0b, size: %0d, pc: %0h",$time, addr, size, pc);
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
        $display("!!!!!!!@@@@@@@ TIME: %0d\nDCACHE REQUEST GENERATED: WRITE addr: %0b, size: %0d, write_content: %0d, pc: %0h",$time, addr, size, write_content, pc);
        return req;
    endfunction

 initial begin
        $display("/************* Start Testing! *************/");
        reset = 1;
        clock = 0;
        dcache_request = '0;
        $display("CLOCK: %d", `CLOCK_PERIOD);
        $display("/*** DCACHE INFO ***/");
        $display("CACHE SIZE: %dB", `DCACHE_SIZE);
        $display("CACHE BLOCK SIZE: %dB", `DC_BLK_SZ);
        $display("N_IDX_BITS: %d", `N_IDX_BITS);
        $display("NUMBER OF MAIN CACHE LINES: %d", `N_CL);
        $display("NUMBER OF VICTIM CACHE LINES: %d", `N_VC_CL);
        $display("NUMBER OF MSHR REGISTERS: %d", `N_MSHR);
        `ifdef DIRECT_MAPPED
            $display("ASSOCIATIVITY: DIRECT MAPPED");
        `elsif TWO_WAY_SET_ASSOCIATIVE 
            $display("ASSOCIATIVITY: TWO WAY SET ASSOCIATIVE");
        `else
            $display("ASSOCIATIVITY: NOT DEFINED! ABORT!");
            $finish;
        `endif 

        @(negedge clock)  #6;
        
        print_this_cycle_state;
        $display("RESET: %d", reset);

        @(negedge clock)  #6;
        reset = 0;
        print_this_cycle_state;
        $display("RESET: %d", reset);


        @(posedge clock);
        dcache_request = gen_dcache_read_request(32'h1010, WORD, 1);

        @(negedge clock)  #6;
        print_this_cycle_state;


        @(negedge clock)  #6;
        print_this_cycle_state;

        @(posedge clock);
        dcache_request = gen_dcache_write_request(32'h1020, HALF, 32'd66, 1); // mshr hit

        print_this_cycle_state;


        @(negedge clock)  #6;
        print_this_cycle_state;

        @(negedge clock)  #6;
        print_this_cycle_state;

        
        @(negedge clock)  #6;
        print_this_cycle_state;

                
        @(negedge clock)  #6;
        print_this_cycle_state;

                
        @(negedge clock)  #6;
        print_this_cycle_state;


        
        $finish;
 end





endmodule