//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
//   Modulename :  trace_driver.v                                               //
//                                                                              //
//   Description : load trace from file, issue one cache request each cycle;    //
//                                                                              //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////

`include "cache_def.svh"



module trace_driver(
    input logic clock, // clock
    input logic reset, // reset
    input int file_handle, // trace file descriptor
    input logic stall, // make no request

    output DCACHE_REQUEST dcache_request, // generated request; valid=0 means invalid
    output finish // end of trace file reached
);

    // line buffer
    string line;
    // internal parsed request args
    int cycle;
    logic [31:0] pc;
    logic [1:0] mem_op;
    logic [31:0] addr;
    logic [1:0] mem_size;
    logic [31:0] write_content_hi;
    logic [31:0] write_content_lo;
    // output
    DCACHE_REQUEST output_dcache_request;
    logic output_finish;
    assign dcache_request = output_dcache_request;
    assign finish = output_finish;
    
    // request generation
    function automatic DCACHE_REQUEST gen_dcache_request(MEM_OP_T mem_op, MEM_ADDR_T addr, MEM_SIZE size, REG_DATA_T write_content, PC_T pc);
        DCACHE_REQUEST req = '0;
        req.mem_op = mem_op;
        req.addr = addr;
        req.size = size;
        req.write_content = write_content;
        req.valid = 1;
        req.pc = pc;
        return req;
    endfunction

    // initialize file and default invalid request
    initial begin
        if (file_handle == 0) begin
            $display("Error: Could not open trace file %s", "mem_trace.log");
            $finish;
        end
    end

    // read one line on each posedge and parse
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            output_dcache_request.valid = 0;
            output_finish = 0;
        end else begin
            if (stall == 1) begin
                $display("Stall");
                output_dcache_request.valid = 0;
            end else if (!$feof(file_handle)) begin // more lines to read?
                // read one line
                line = "";
                $fgets(line, file_handle);
                // try to parse the line
                if ($sscanf(line, "cycle=%d pc=%d  @@@%d %d %d %d %d@@@", cycle, pc, mem_op, addr, mem_size, write_content_hi, write_content_lo) == 7) begin
                    // parse successful, generate request
                    output_dcache_request = gen_dcache_request(mem_op, addr, mem_size, write_content_lo, pc);
                end else begin
                    // parse failed, request invalid
                    output_dcache_request.valid = 0;
                end
            end else begin
                $display("End of trace file reached");
                output_finish = 1;
            end
        end
    end

endmodule