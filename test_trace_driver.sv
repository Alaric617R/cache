`timescale 1ns/100ps

`include "sys_defs.svh"
`include "cache_def.svh"

// arguments
`define TRACE_FILE_NAME "mem_trace_fib.log"

module tb;
    // cycle counter
    int cycle;
    // mimic cache stall
    logic cache_stall;
    // File handle
    int file_handle;
    // Line buffer
    string line;
    
    // output
    DCACHE_REQUEST dcache_request;
    logic finish;

    // signals
    logic clock;
    logic reset;
    logic cache_stall;

    // Clock generation
    always begin
        #(`VERILOG_CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    // Cycle counter
    always @(posedge clock) begin
        cycle = cycle + 1;
    end

    // Check request generation
    always @(negedge clock) begin
        if (dcache_request.valid) begin
            $display("Request: cycle=%d,    mem_op=%d,    addr=%d,    mem_size=%d,    write_content=%d,    pc=%d",
                cycle,
                dcache_request.mem_op,
                dcache_request.addr,
                dcache_request.size,
                dcache_request.write_content,
                dcache_request.pc
            );
        end
    end

    // generate new request on each positive cycle
    trace_driver driver(
        .clock(clock),
        .reset(reset),
        .file_handle(file_handle),
        .stall(cache_stall),

        .dcache_request(dcache_request),
        .finish(finish)
    );
    
    
    initial begin
        cycle = 0;
        clock = 1'b0;
        cache_stall = 1'b0;

        // Open the log file for reading
        file_handle = $fopen(`TRACE_FILE_NAME, "r");
        if (file_handle == 0) begin
            $display("Error: Could not open file");
            $finish;
        end
        
        // Pulse the reset signal
		$display("@@\n@@\n@@  %t  Asserting System reset......", $realtime);
		reset = 1'b1;
		@(posedge clock);
		@(posedge clock);
        reset = 1'b0;
        
        // test stall signal
        @(posedge clock) #3;
		@(posedge clock) #3;
        @(posedge clock) #3;
        @(posedge clock) #3;
		@(posedge clock) #3;   
        @(posedge clock) #3;
        @(posedge clock) #3;
		@(posedge clock) #3;
        @(posedge clock) #3;
        @(posedge clock) #3;
        @(negedge clock);
        cache_stall = 1'b1;
        @(posedge clock) #3;
		@(posedge clock) #3;
        @(posedge clock) #3;
        @(posedge clock) #3;
		@(posedge clock) #3;
        @(posedge clock) #3;
        @(posedge clock) #3;
		@(posedge clock) #3;
        @(posedge clock) #3;
        cache_stall = 1'b0;

        // wait until finish signal is set
        wait (finish == 1);

        // Close the file
        $fclose(file_handle);
        $finish;
    end
endmodule
